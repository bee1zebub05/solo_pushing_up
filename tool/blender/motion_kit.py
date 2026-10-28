"""Thư viện chuyển động mượt cho quái / nhân vật render sprite bằng Blender
(dùng chung mọi chương — hướng dẫn: rules/chuyendong.md).

Biên đạo theo khoá: mỗi động tác là các khoá thưa (t, {kênh: giá trị}) quanh
dáng chờ [ready]; nội suy cubic đơn điệu Fritsch–Carlson (mượt, không vọt quá
khoá — vọt thì vũ khí xuyên đất); [lag] trễ từng kênh để lực đi theo chuỗi
hông → thân → tay → vũ khí → đầu. Khoá lặp lại cùng giá trị = giữ thế.

    Move / Track     động tác một lượt (đòn, trồi lên, gục)
    Loop             kênh lặp tuần hoàn, nối vòng không gãy (đứng chờ)
    wingbeat         một nhịp vỗ cánh theo số đo chim thật
    dense_phases     tiến độ khung đòn: thưa lúc lấy đà / thu, dày quanh cú đánh
    attack_phases    dense_phases tính từ thời lượng đòn và số hình/giây mong muốn
    idle_count       số khung vòng đứng chờ theo chu kỳ và số hình/giây
    loop_frames / move_frames   danh sách hàm đặt dáng cho sprite_kit.export_sprites

Atlas ghi `phases` (extra={"phases": {anim: phases}}) để game đọc tiến độ
từng khung (lib/art/sprite_motion.dart). Xương nằm gần song song trục mốc
xoắn mặc định (cánh dọc chiều sâu) cần mốc riêng: rig.up = {tên: Vector}
(boss_kit.Rig.set).
"""

import math


def _monotone(xs, ys):
    n = len(xs)
    if n < 2:
        return [0.0] * n
    d = [(ys[i + 1] - ys[i]) / max(1e-9, xs[i + 1] - xs[i]) for i in range(n - 1)]
    m = [d[0]] + [(d[i - 1] + d[i]) / 2 if d[i - 1] * d[i] > 0 else 0.0 for i in range(1, n - 1)] + [d[-1]]
    for i in range(n - 1):
        if d[i] == 0:
            m[i] = m[i + 1] = 0.0
            continue
        a, b = m[i] / d[i], m[i + 1] / d[i]
        s = a * a + b * b
        if s > 9:
            k = 3 / math.sqrt(s)
            m[i], m[i + 1] = k * a * d[i], k * b * d[i]
    return m


class Track:
    def __init__(self, keys):
        keys = sorted(keys)
        self.xs = [k[0] for k in keys]
        self.ys = [k[1] for k in keys]
        self.ms = _monotone(self.xs, self.ys)

    def at(self, t):
        xs, ys, ms = self.xs, self.ys, self.ms
        if t <= xs[0]:
            return ys[0]
        if t >= xs[-1]:
            return ys[-1]
        i = 0
        while xs[i + 1] <= t:
            i += 1
        h = xs[i + 1] - xs[i]
        u = (t - xs[i]) / h
        h00 = (1 + 2 * u) * (1 - u) ** 2
        h10 = u * (1 - u) ** 2
        h01 = u * u * (3 - 2 * u)
        h11 = u * u * (u - 1)
        return h00 * ys[i] + h10 * h * ms[i] + h01 * ys[i + 1] + h11 * h * ms[i + 1]


class Move:
    """Một động tác: [keys] = [(t, {kênh: giá trị})], kênh thiếu ở t = 0 / 1
    lấy theo [ready] (động tác bắt đầu và kết thúc ở dáng chờ, trừ khi khoá
    t = 0 / 1 ghi khác)."""

    def __init__(self, ready, keys, lag=None):
        self.lag = lag or {}
        chans = {c: [] for c in ready}
        for t, v in keys:
            for c, x in v.items():
                chans.setdefault(c, []).append((t, x))
        self.tracks = {}
        for c, ks in chans.items():
            r = ready.get(c, 0.0)
            if not any(k[0] <= 0 for k in ks):
                ks = [(0.0, r)] + ks
            if not any(k[0] >= 1 for k in ks):
                ks = ks + [(1.0, r)]
            self.tracks[c] = Track(ks)

    def at(self, t):
        return {c: tr.at(max(0.0, t - self.lag.get(c, 0.0))) for c, tr in self.tracks.items()}


def dense_phases(sparse_step, dense_from, dense_to, dense_step):
    """Tiến độ khung đòn: thưa ở lấy đà/thu về, dày quanh cú ra đòn (khung
    nhanh nhất) — cùng số khung mà cú đâm mượt hơn nhiều khung chia đều."""
    out, t = [], 0.0
    while t < dense_from - 1e-6:
        out.append(round(t, 4))
        t += sparse_step
    t = dense_from
    while t < dense_to - 1e-6:
        out.append(round(t, 4))
        t += dense_step
    t = dense_to
    while t < 1.0 - 1e-6:
        out.append(round(t, 4))
        t += sparse_step
    out.append(1.0)
    return out


class Loop:
    """Kênh lặp tuần hoàn qua các khoá (t ∈ [0, 1), giá trị): Catmull–Rom
    vòng — khoá cuối nối mượt về khoá đầu (không gãy ở chỗ nối vòng lặp)."""

    def __init__(self, keys):
        keys = sorted(keys)
        self.xs = [k[0] for k in keys]
        self.ys = [k[1] for k in keys]

    def at(self, t):
        t %= 1.0
        xs, ys, n = self.xs, self.ys, len(self.xs)
        i = n - 1
        while i > 0 and xs[i] > t:
            i -= 1
        if t < xs[0]:
            i = n - 1

        def x(k):
            return xs[k % n] + (k // n)

        x0 = x(i)
        if x0 > t:
            x0 -= 1
        x1 = x0 + ((xs[(i + 1) % n] - xs[i]) % 1.0 or 1.0)
        xp = x0 - ((xs[i] - xs[(i - 1) % n]) % 1.0 or 1.0)
        xn = x1 + ((xs[(i + 2) % n] - xs[(i + 1) % n]) % 1.0 or 1.0)
        yp, y0, y1, yn = ys[(i - 1) % n], ys[i], ys[(i + 1) % n], ys[(i + 2) % n]
        m0 = (y1 - yp) / (x1 - xp) * (x1 - x0)
        m1 = (yn - y0) / (xn - x0) * (x1 - x0)
        u = (t - x0) / (x1 - x0)
        return ((2 * u ** 3 - 3 * u ** 2 + 1) * y0 + (u ** 3 - 2 * u ** 2 + u) * m0
                + (-2 * u ** 3 + 3 * u ** 2) * y1 + (u ** 3 - u ** 2) * m1)


# Nhịp vỗ cánh theo số đo chim thật (bồ câu bay chậm, quay động học 3D —
# PMC12068018; Tobalske & Dial): đập xuống và nâng lên gần bằng thời gian;
# cánh DUỖI HẾT khi đập xuống, mút cánh trễ ~0,1 chu kỳ nên hơi cong lên;
# nâng lên thì cổ tay dẫn lên trước, khuỷu + cổ tay gập (sải cánh co lại),
# mút cánh RỦ XUỐNG và QUẶT RA SAU (~-80° so với cánh trong, quét ~25° về
# sau), ~3/5 nhịp nâng mới bật lên duỗi ra ở đỉnh. Thân cao nhất cuối nhịp
# đập (lực nâng dồn ở nhịp đập), thấp nhất cuối nhịp nâng.
WING_DOWN = 0.52  # phần chu kỳ đập xuống
_BEND = Loop([(0.0, 0.0), (0.2, 0.22), (0.42, 0.12), (0.56, -0.3), (0.68, -0.85), (0.76, -1.0),
              (0.86, -0.62), (0.95, -0.12)])
_SWEEP = Loop([(0.0, 0.0), (0.25, -0.3), (0.48, -0.2), (0.62, 0.45), (0.75, 1.0), (0.87, 0.65),
               (0.96, 0.12)])
_FLEX = Loop([(0.0, 0.0), (0.3, -0.02), (0.48, 0.02), (0.62, 0.55), (0.75, 1.0), (0.87, 0.55),
              (0.96, 0.05)])


def wingbeat(t):
    """Một nhịp vỗ cánh tại [t] (0 = cánh ở đỉnh, lặp mỗi 1): arm 1 (đỉnh) …
    -1 (đáy) — góc cánh trong; bend mút cánh so với cánh trong (+ = cong lên,
    -1 = rủ hết); sweep quét về sau (-0,3 hơi với tới trước … 1); flex gập
    khuỷu/cổ tay 0 … 1 (sải cánh co); lift thân -1 … 1 (+ = lên)."""
    t %= 1.0
    if t < WING_DOWN:
        arm = math.cos(math.pi * t / WING_DOWN)
    else:
        arm = -math.cos(math.pi * (t - WING_DOWN) / (1 - WING_DOWN))
    return dict(arm=arm, bend=_BEND.at(t), sweep=_SWEEP.at(t), flex=_FLEX.at(t),
                lift=math.cos(2 * math.pi * (t - 0.55)))


# Nhịp game (lib/art/battle_stage.dart, BossArt.attackSeconds của chương 1):
# đòn 1,6 s, cú đánh trong khoảng 0,46–0,70 của đòn. Mức hình/giây đã duyệt
# ở chương 1: đứng chờ ≥ 15, đòn ~18 lúc lấy đà / thu, ~40 quanh cú đánh.
ATTACK_SECONDS = 1.6
STRIKE = (0.46, 0.70)
IDLE_FPS = 16
ATTACK_FPS = 18
STRIKE_FPS = 40


def attack_phases(seconds=ATTACK_SECONDS, fps=ATTACK_FPS, strike_fps=STRIKE_FPS, strike=STRIKE):
    """Tiến độ khung một đòn dài [seconds] giây: [fps] hình/giây lúc lấy đà /
    thu, [strike_fps] quanh cú đánh [strike] (game không hoà khung ở đó)."""
    return dense_phases(1 / (seconds * fps), strike[0], strike[1], 1 / (seconds * strike_fps))


def idle_count(period, fps=IDLE_FPS, even=True):
    """Số khung vòng đứng chờ chu kỳ [period] giây (idlePeriod trong atlas)."""
    n = max(8, round(period * fps))
    return n + (n % 2) if even else n


def loop_frames(pose, channels, n):
    """[n] hàm đặt dáng chia đều một vòng lặp: pose(channels(k / n))."""
    return [lambda k=k: pose(channels(k / n)) for k in range(n)]


def move_frames(pose, move, phases):
    """Hàm đặt dáng cho từng tiến độ trong [phases]: pose(move.at(p)) — [move]
    là Move hoặc hàm p → kênh."""
    at = move.at if hasattr(move, "at") else move
    return [lambda p=p: pose(at(p)) for p in phases]
