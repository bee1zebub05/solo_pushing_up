"""Mô hình chuyển động võ học — autoencoder 1D-UNet khử nhiễu có che khung.

Học trên toàn bộ kho mocap (CMU + Kyokushin, dataset.py): cửa sổ 64 khung
(30 fps ≈ 2,1 s), 24 điểm khớp. Đầu vào là chuyển động đã CHE một phần
(khung / khớp chưa biết) + nhiễu; đầu ra là chuyển động đủ và tự nhiên.
Ràng buộc vật lý trong hàm mất mát: độ dài xương không đổi, chân chạm đất
không trượt, vận tốc liền.

Dùng cho boss (compose.py):
- dựng đoạn chuyển: ghim dáng chờ của boss ở đầu/cuối + đòn mocap ở giữa →
  mô hình điền phần nối (thay cho nội suy tuyến tính trông gượng);
- khử nhiễu chuyển động lấy từ video (MediaPipe);
- chấm độ tự nhiên: sai số tái dựng khi không che (khung lạ → lỗi cao).

Chạy trong tool/.venv-ml (torch CUDA, RTX 3050 4 GB đủ):
    tool/.venv-ml/Scripts/python tool/motion/mocap/model.py train [--steps 40000]
    tool/.venv-ml/Scripts/python tool/motion/mocap/model.py eval
Trọng số: art_src/mocap/_cache/model/motion_ae.pt (huấn luyện lại được; đòn đã ghép
mới commit — art_src/mocap/moves/).
"""

import math
import os
import sys
import time

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
DATA = os.path.join(ROOT, "art_src", "mocap", "_cache", "dataset_30.npz")
CKPT = os.path.join(ROOT, "art_src", "mocap", "_cache", "model", "motion_ae.pt")

JOINTS = ("pelvis", "spine", "chest", "neck", "head",
          "shoulder_l", "elbow_l", "wrist_l", "shoulder_r", "elbow_r", "wrist_r",
          "hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r",
          "toe_l", "toe_r", "head_top", "hand_tip_l", "hand_tip_r", "thumb_l", "thumb_r")
J = {n: i for i, n in enumerate(JOINTS)}
NJ = len(JOINTS)
MIRROR = [J[n.replace("_l", "_X").replace("_r", "_l").replace("_X", "_r")] if n[-2:] in ("_l", "_r") else J[n]
          for n in JOINTS]
BONES = [("pelvis", "spine"), ("spine", "chest"), ("chest", "neck"), ("neck", "head"), ("head", "head_top"),
         ("chest", "shoulder_l"), ("shoulder_l", "elbow_l"), ("elbow_l", "wrist_l"), ("wrist_l", "hand_tip_l"),
         ("chest", "shoulder_r"), ("shoulder_r", "elbow_r"), ("elbow_r", "wrist_r"), ("wrist_r", "hand_tip_r"),
         ("pelvis", "hip_l"), ("hip_l", "knee_l"), ("knee_l", "ankle_l"), ("ankle_l", "toe_l"),
         ("pelvis", "hip_r"), ("hip_r", "knee_r"), ("knee_r", "ankle_r"), ("ankle_r", "toe_r")]
BI = torch.tensor([[J[a], J[b]] for a, b in BONES])
FEET = [J["ankle_l"], J["toe_l"], J["ankle_r"], J["toe_r"]]
W = 64


# ---------------------------------------------------------------- dữ liệu (trên GPU)


def canon(x):
    """x (B, T, 24, 3) → xoay quanh Z cho mặt (khung giữa) nhìn +X, hông khung
    giữa về gốc (X, Y); Z giữ nguyên (độ cao so với đất có nghĩa)."""
    c = x.shape[1] // 2
    across = (x[:, c, J["hip_l"]] - x[:, c, J["hip_r"]]) + (x[:, c, J["shoulder_l"]] - x[:, c, J["shoulder_r"]])
    ang = torch.atan2(-across[:, 0], across[:, 1])  # mặt = across xoay −90°
    cs, sn = torch.cos(-ang), torch.sin(-ang)
    R = torch.zeros(x.shape[0], 3, 3, device=x.device)
    R[:, 0, 0], R[:, 0, 1], R[:, 1, 0], R[:, 1, 1], R[:, 2, 2] = cs, -sn, sn, cs, 1
    o = x[:, c, J["pelvis"]].clone()
    o[:, 2] = 0
    return torch.einsum("bij,btkj->btki", R, x - o[:, None, None])


class Data:
    def __init__(self, path, device):
        d = np.load(path)
        self.pos = torch.tensor(d["pos"], device=device)          # (N, 24, 3)
        starts = list(d["starts"]) + [len(d["pos"])]
        self.srcs = d["srcs"]
        self.device = device
        valid, weight = [], []
        span = int(W * 1.3) + 2
        for i in range(len(starts) - 1):
            a, b = starts[i], starts[i + 1]
            if b - a > span:
                idx = np.arange(a, b - span)
                valid.append(idx)
                # Kyokushin (người diễn chuyên) nặng ký hơn CMU đi bộ.
                weight.append(np.full(len(idx), 1.0 if self.srcs[i] == "kyokushin" else 0.6))
        self.valid = torch.tensor(np.concatenate(valid), device=device)
        w = np.concatenate(weight)
        self.w = torch.tensor(w / w.sum(), device=device, dtype=torch.float32)
        x = self.batch(4096, aug=False)
        self.mean = x.mean(dim=(0, 1))
        self.std = x.std(dim=(0, 1)).clamp_min(0.02)

    def batch(self, B, aug=True):
        s = self.valid[torch.multinomial(self.w, B, replacement=True)]
        rate = (torch.rand(B, device=self.device) * 0.45 + 0.8) if aug else torch.ones(B, device=self.device)
        t = s[:, None].float() + torch.arange(W, device=self.device)[None].float() * rate[:, None]
        i0 = t.floor().long()
        u = (t - i0.float())[..., None, None]
        x = self.pos[i0] * (1 - u) + self.pos[i0 + 1] * u          # (B, W, 24, 3)
        if aug:
            m = torch.rand(B, device=self.device) < 0.5
            xm = x[:, :, MIRROR].clone()
            xm[..., 1] = -xm[..., 1]
            x = torch.where(m[:, None, None, None], xm, x)
            x = x * (torch.rand(B, 1, 1, 1, device=self.device) * 0.2 + 0.9)
        return canon(x)


def make_mask(B, device):
    """Mặt nạ "đã biết" (B, W, 24): trộn các kiểu che dùng thật khi dựng đòn."""
    known = torch.ones(B, W, NJ, device=device)
    mode = torch.randint(0, 5, (B,), device=device)
    t = torch.arange(W, device=device)[None]
    # 0: đoạn chuyển — biết đầu + cuối, che giữa (chiều dài che 6–40 khung).
    a = torch.randint(4, 30, (B, 1), device=device)
    L = torch.randint(6, 40, (B, 1), device=device)
    gap = (t >= a) & (t < a + L)
    # 1: hai khe (vào đòn + ra đòn), giữ đầu, giữa, cuối.
    a2 = torch.randint(36, 56, (B, 1), device=device)
    L2 = torch.randint(4, 14, (B, 1), device=device)
    gap2 = gap | ((t >= a2) & (t < a2 + L2))
    # 2: thưa — chỉ biết các khung khoá cách nhau 4–10 khung.
    step = torch.randint(4, 11, (B, 1), device=device)
    sparse = (t % step) != 0
    for k, g in ((0, gap), (1, gap2), (2, sparse)):
        sel = (mode == k)[:, None]
        known = torch.where((sel & g)[..., None], torch.zeros_like(known), known)
    # 3: khớp thiếu cả đoạn (ví dụ tay cầm vũ khí do biên đạo lo, không có mocap).
    jm = (torch.rand(B, 1, NJ, device=device) < 0.15) & (mode == 3)[:, None, None]
    known = torch.where(jm, torch.zeros_like(known), known)
    # 4: không che — chỉ khử nhiễu.
    return known


def interp_fill(x, known):
    """Điền khung chưa biết bằng nội suy tuyến tính giữa khung biết gần nhất
    trước/sau (từng khớp) — mạng chỉ phải học phần dư so với nền này."""
    B, T, NJ_, _ = x.shape
    t = torch.arange(T, device=x.device)[None, :, None].expand(B, T, NJ_)
    k = known > 0.5
    prev = torch.where(k, t, torch.full_like(t, -1)).cummax(1).values
    nxt = torch.where(k, t, torch.full_like(t, T)).flip(1).cummin(1).values.flip(1)
    has_p, has_n = prev >= 0, nxt < T
    p_i, n_i = prev.clamp(0, T - 1), nxt.clamp(0, T - 1)
    gp = torch.gather(x, 1, p_i[..., None].expand(-1, -1, -1, 3))
    gn = torch.gather(x, 1, n_i[..., None].expand(-1, -1, -1, 3))
    u = ((t - prev).float() / (nxt - prev).clamp_min(1).float())[..., None]
    lin = gp * (1 - u) + gn * u
    lin = torch.where((has_p & ~has_n)[..., None], gp, lin)
    lin = torch.where((~has_p & has_n)[..., None], gn, lin)
    return torch.where(k[..., None], x, lin)


# ---------------------------------------------------------------- mạng


class Res(nn.Module):
    def __init__(self, c, k=5):
        super().__init__()
        self.n1, self.c1 = nn.GroupNorm(8, c), nn.Conv1d(c, c, k, padding=k // 2)
        self.n2, self.c2 = nn.GroupNorm(8, c), nn.Conv1d(c, c, k, padding=k // 2)

    def forward(self, x):
        h = self.c1(F.silu(self.n1(x)))
        return x + self.c2(F.silu(self.n2(h)))


class Attn(nn.Module):
    def __init__(self, c):
        super().__init__()
        self.n = nn.GroupNorm(8, c)
        self.a = nn.MultiheadAttention(c, 8, batch_first=True)

    def forward(self, x):
        h = self.n(x).transpose(1, 2)
        return x + self.a(h, h, h, need_weights=False)[0].transpose(1, 2)


class MotionAE(nn.Module):
    def __init__(self, cin=NJ * 3 + NJ, cout=NJ * 3, ch=(96, 192, 288, 384)):
        super().__init__()
        self.inp = nn.Conv1d(cin, ch[0], 5, padding=2)
        self.down = nn.ModuleList()
        self.enc = nn.ModuleList()
        for i in range(len(ch)):
            self.enc.append(nn.Sequential(Res(ch[i]), Res(ch[i])))
            if i < len(ch) - 1:
                self.down.append(nn.Conv1d(ch[i], ch[i + 1], 4, stride=2, padding=1))
        self.mid = nn.Sequential(Attn(ch[-1]), Res(ch[-1]), Attn(ch[-1]))
        self.up = nn.ModuleList()
        self.dec = nn.ModuleList()
        for i in range(len(ch) - 1, 0, -1):
            self.up.append(nn.ConvTranspose1d(ch[i], ch[i - 1], 4, stride=2, padding=1))
            self.dec.append(nn.Sequential(nn.Conv1d(ch[i - 1] * 2, ch[i - 1], 1), Res(ch[i - 1]), Res(ch[i - 1])))
        self.out = nn.Sequential(nn.GroupNorm(8, ch[0]), nn.SiLU(), nn.Conv1d(ch[0], cout, 5, padding=2))

    def forward(self, x):
        h = self.inp(x)
        skips = []
        for i, e in enumerate(self.enc):
            h = e(h)
            if i < len(self.down):
                skips.append(h)
                h = self.down[i](h)
        h = self.mid(h)
        for u, d in zip(self.up, self.dec):
            h = u(h)
            h = d(torch.cat([h, skips.pop()], 1))
        return self.out(h)


# ---------------------------------------------------------------- vào / ra


class Model:
    """Bọc mạng + chuẩn hoá: làm việc trực tiếp với (B, T, 24, 3) mét."""

    def __init__(self, net, mean, std, device):
        self.net, self.mean, self.std, self.device = net, mean.to(device), std.to(device), device

    def encode_in(self, x, known, noise=0.0):
        """Đầu vào mạng: nền nội suy (khung biết giữ nguyên) + mặt nạ."""
        B, T = x.shape[:2]
        base = interp_fill(x, known)
        xn = (base - self.mean) / self.std
        if noise:
            xn = xn + torch.randn_like(xn) * noise
        return torch.cat([xn.reshape(B, T, -1), known], -1).transpose(1, 2), base

    def decode_out(self, y, base):
        """Đầu ra = nền nội suy + phần dư mạng dự đoán."""
        B, _, T = y.shape
        return base + y.transpose(1, 2).reshape(B, T, NJ, 3) * self.std

    def __call__(self, x, known):
        inp, base = self.encode_in(x, known)
        return self.decode_out(self.net(inp), base)

    @staticmethod
    def load(path=CKPT, device=None):
        device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        ck = torch.load(path, map_location=device, weights_only=False)
        net = MotionAE().to(device)
        net.load_state_dict(ck["net"])
        net.eval()
        return Model(net, ck["mean"], ck["std"], device)

    @torch.no_grad()
    def fill(self, pos, known, keep_known=True):
        """pos (T, 24, 3) numpy (khung chưa biết = gì cũng được), known (T, 24)
        hoặc (T,) — điền chuyển động; dài hơn 64 khung thì trượt cửa sổ chồng
        nửa và hoà tam giác. Trả về numpy (T, 24, 3) trong khung toạ độ gốc."""
        pos = np.asarray(pos, dtype=np.float32)
        known = np.asarray(known, dtype=np.float32)
        if known.ndim == 1:
            known = np.repeat(known[:, None], NJ, 1)
        T = len(pos)
        out = np.zeros_like(pos)
        wsum = np.zeros((T, 1, 1), np.float32)
        starts = [0] if T <= W else list(range(0, T - W + 1, W // 2))
        if T > W and starts[-1] != T - W:
            starts.append(T - W)
        for s in starts:
            seg = np.zeros((W, NJ, 3), np.float32)
            kn = np.zeros((W, NJ), np.float32)
            n = min(W, T - s)
            seg[:n], kn[:n] = pos[s:s + n], known[s:s + n]
            if n < W:  # đệm: lặp khung cuối, đánh dấu chưa biết
                seg[n:] = pos[s + n - 1]
            # Khung toạ độ mô hình: mặt khung giữa nhìn +X — tính từ khung biết gần giữa nhất.
            x = torch.tensor(seg, device=self.device)[None]
            k = torch.tensor(kn, device=self.device)[None]
            c = W // 2
            kc = kn.sum(1) > NJ * 0.6
            ref = int(np.argmin(np.where(kc, np.abs(np.arange(W) - c), 999)))
            xr = x.clone()
            xr[:, c] = x[:, ref]
            Rm, o = _frame(xr)
            xl = torch.einsum("bij,btkj->btki", Rm, x - o[:, None, None])
            y = self(xl, k)
            y = torch.einsum("bji,btkj->btki", Rm, y) + o[:, None, None]
            y = y[0].cpu().numpy()
            if keep_known:
                y = np.where(kn[..., None] > 0.5, seg, y)
            tri = np.minimum(np.arange(1, W + 1), np.arange(W, 0, -1)).astype(np.float32)[:n, None, None]
            if len(starts) == 1:
                tri = np.ones_like(tri)
            out[s:s + n] += y[:n] * tri
            wsum[s:s + n] += tri
        return out / np.maximum(wsum, 1e-6)

    @torch.no_grad()
    def score(self, pos):
        """Độ "lạ" từng khung (≈ 1 = như dữ liệu thật, > 2 = gượng / sai): sai
        số tái dựng khi chỉ che ngẫu nhiên thưa, chia cho mức trung bình kiểm định."""
        pos = np.asarray(pos, dtype=np.float32)
        T = len(pos)
        errs = np.zeros(T)
        cnt = np.zeros(T)
        for rep in range(4):
            known = np.ones((T, NJ), np.float32)
            known[rep::4] = 0
            y = self.fill(pos, known, keep_known=False)
            e = np.linalg.norm(y - pos, axis=2).mean(1)
            m = known[:, 0] == 0
            errs[m] += e[m]
            cnt[m] += 1
        return errs / np.maximum(cnt, 1) / SCORE_REF


SCORE_REF = 0.0307  # m — mức che thưa 1/4 trên dữ liệu kiểm định (model.py eval, 15k bước)


def _frame(x):
    c = x.shape[1] // 2
    across = (x[:, c, J["hip_l"]] - x[:, c, J["hip_r"]]) + (x[:, c, J["shoulder_l"]] - x[:, c, J["shoulder_r"]])
    ang = torch.atan2(-across[:, 0], across[:, 1])
    cs, sn = torch.cos(-ang), torch.sin(-ang)
    R = torch.zeros(x.shape[0], 3, 3, device=x.device)
    R[:, 0, 0], R[:, 0, 1], R[:, 1, 0], R[:, 1, 1], R[:, 2, 2] = cs, -sn, sn, cs, 1
    o = x[:, c, J["pelvis"]].clone()
    o[:, 2] = 0
    return R, o


# ---------------------------------------------------------------- huấn luyện


def losses(pred, target, known):
    unk = 1 - known
    d = (pred - target).abs().sum(-1)                                   # (B, T, 24) mét
    rec = (d * (1 + 2 * unk)).mean()
    vel = ((pred[:, 1:] - pred[:, :-1]) - (target[:, 1:] - target[:, :-1])).abs().sum(-1).mean()
    acc = ((pred[:, 2:] - 2 * pred[:, 1:-1] + pred[:, :-2]) - (target[:, 2:] - 2 * target[:, 1:-1] + target[:, :-2])).abs().sum(-1).mean()
    bi = BI.to(pred.device)
    bl_p = (pred[:, :, bi[:, 0]] - pred[:, :, bi[:, 1]]).norm(dim=-1)
    bl_t = (target[:, :, bi[:, 0]] - target[:, :, bi[:, 1]]).norm(dim=-1)
    bone = (bl_p - bl_t).abs().mean()
    # Trượt chân: nơi chân thật đang chạm đất (thấp + gần đứng yên), chân dự đoán phải đứng yên.
    ft = target[:, :, FEET]
    fp = pred[:, :, FEET]
    vt = (ft[:, 1:] - ft[:, :-1]).norm(dim=-1)
    contact = ((ft[:, 1:, :, 2] < 0.12) & (vt < 0.012)).float()
    skate = ((fp[:, 1:] - fp[:, :-1])[..., :2].norm(dim=-1) * contact).sum() / contact.sum().clamp_min(1)
    return rec, vel, acc, bone, skate


def train(steps=40000, B=128, lr=3e-4):
    dev = "cuda"
    # cuDNN trên RTX 3050 laptop lỗi thực thi (CUDNN_STATUS_EXECUTION_FAILED) ở lượt
    # lùi conv1d bf16 khi dữ liệu lớn
    # → huấn luyện FP32 (bỏ autocast bf16), cuDNN bật.
    amp = os.environ.get("MOTION_BF16", "0") == "1"
    torch.manual_seed(0)
    data = Data(DATA, dev)
    print(f"dữ liệu: {data.pos.shape[0]} khung, {len(data.valid)} điểm bắt đầu cửa sổ")
    net = MotionAE().to(dev)
    print(f"tham số: {sum(p.numel() for p in net.parameters()) / 1e6:.1f} M")
    model = Model(net, data.mean, data.std, dev)
    opt = torch.optim.AdamW(net.parameters(), lr=lr, weight_decay=1e-4)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=lr, total_steps=steps, pct_start=0.05)
    scaler = torch.amp.GradScaler()
    t0 = time.time()
    hist = []
    for step in range(1, steps + 1):
        x = data.batch(B)
        known = make_mask(B, dev)
        noise = torch.rand(B, 1, 1, 1, device=dev) * 0.025               # mét
        xin = x + torch.randn_like(x) * noise
        # Mối nối lệch (dáng boss ↔ mocap không khớp tuyệt đối): dịch cả cụm biết phía sau.
        shift = (torch.rand(B, 1, 1, 1, device=dev) < 0.3).float() * torch.randn(B, 1, 1, 3, device=dev) * 0.03
        late = (torch.arange(W, device=dev) > W // 2).float()[None, :, None, None]
        xin = xin + shift * late
        inp, base = model.encode_in(xin, known)
        with torch.autocast("cuda", dtype=torch.bfloat16, enabled=amp):
            y = net(inp)
        pred = model.decode_out(y.float(), base)
        rec, vel, acc, bone, skate = losses(pred, x, known)
        loss = rec + 0.5 * vel + 0.5 * acc + 2.0 * bone + 1.0 * skate
        opt.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(net.parameters(), 1.0)
        opt.step()
        sched.step()
        hist.append([loss.item(), rec.item(), bone.item(), skate.item()])
        if step % 500 == 0 or step == 1:
            h = np.mean(hist[-500:], 0)
            print(f"{step:6d}  loss {h[0]:.4f}  rec {h[1]:.4f}  bone {h[2]:.4f}  skate {h[3]:.4f}  "
                  f"{(time.time() - t0) / step * 1000:.0f} ms/bước", flush=True)
        if step % 5000 == 0 or step == steps:
            os.makedirs(os.path.dirname(CKPT), exist_ok=True)
            torch.save({"net": net.state_dict(), "mean": data.mean.cpu(), "std": data.std.cpu(), "step": step}, CKPT)
    print(f"xong {steps} bước trong {(time.time() - t0) / 60:.1f} phút → {CKPT}")


@torch.no_grad()
def evaluate():
    """Sai số điền đoạn chuyển trên dữ liệu (so với nội suy tuyến tính) + mức tham chiếu cho score()."""
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    data = Data(DATA, dev)
    model = Model.load(device=dev)
    torch.manual_seed(1)
    x = data.batch(512, aug=False)
    t = torch.arange(W, device=dev)
    for L in (8, 16, 24, 32):
        known = torch.ones(512, W, NJ, device=dev)
        a = (W - L) // 2
        known[:, a:a + L] = 0
        y = model(x, known)
        e_m = (y - x).norm(dim=-1)[:, a:a + L].mean().item()
        u = ((t[a:a + L] - a + 1).float() / (L + 1))[None, :, None, None]
        lin = x[:, a - 1:a] * (1 - u) + x[:, a + L:a + L + 1] * u
        e_l = (lin - x[:, a:a + L]).norm(dim=-1).mean().item()
        print(f"che {L:2d} khung: mô hình {e_m * 100:5.1f} cm   nội suy tuyến tính {e_l * 100:5.1f} cm")
    known = torch.ones(512, W, NJ, device=dev)
    known[:, ::4] = 0
    y = model(x, known)
    ref = (y - x).norm(dim=-1)[:, ::4].mean().item()
    print(f"SCORE_REF (che thưa 1/4): {ref:.4f} m")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    cmd = sys.argv[1] if len(sys.argv) > 1 else "train"
    if cmd == "train":
        steps = int(sys.argv[sys.argv.index("--steps") + 1]) if "--steps" in sys.argv else 40000
        train(steps)
    elif cmd == "eval":
        evaluate()
    elif cmd == "clean":
        # Khử nhiễu chuyển động từ video (video.py): che khớp tin cậy thấp, cho mô hình
        # điền; đi hai lượt so le (chẵn/lẻ) để khung nào cũng được làm mượt một lần.
        src, dst = sys.argv[2], sys.argv[3]
        d = np.load(src)
        pos = d["pos"].astype(np.float32)
        vis = d["vis"] if "vis" in d else np.ones(pos.shape[:2], np.float32)
        fps = float(d["fps"])
        # Mô hình học ở 30 fps: nội suy về 30 rồi trả lại nhịp gốc.
        t0 = np.arange(len(pos)) / fps
        t1 = np.arange(0, t0[-1] + 1e-9, 1 / 30)
        rs = lambda a: np.stack([np.interp(t1, t0, a.reshape(len(a), -1)[:, k]) for k in range(a.reshape(len(a), -1).shape[1])], 1)
        p30 = rs(pos).reshape(len(t1), NJ, 3).astype(np.float32)
        v30 = rs(vis).reshape(len(t1), NJ)
        model = Model.load()
        known = (v30 > 0.6).astype(np.float32)
        out = p30.copy()
        for par in (0, 1):
            k = known.copy()
            k[par::2] = 0
            out = np.where(np.arange(len(t1))[:, None, None] % 2 == par, model.fill(out, k, keep_known=True), out)
        back = np.stack([np.interp(t0, t1, out.reshape(len(t1), -1)[:, k]) for k in range(NJ * 3)], 1).reshape(len(t0), NJ, 3)
        np.savez_compressed(dst, pos=back.astype(np.float32), fps=fps, vis=vis, meta=d["meta"] if "meta" in d else np.array("{}"))
        jit = lambda a: np.linalg.norm(np.diff(a, 2, axis=0), axis=-1).mean()
        print(f"rung (gia tốc trung bình): {jit(pos) * 1000:.1f} → {jit(back) * 1000:.1f} mm/khung²  → {dst}")
