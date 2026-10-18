"""Ghép đòn boss: dáng chờ của boss → đòn mocap đã nắn nhịp → dáng chờ.

    tool/.venv-ml/Scripts/python tool/mocap/compose.py            # mọi đòn trong moves.json
    tool/.venv-ml/Scripts/python tool/mocap/compose.py shuten_doji attack

Đầu vào: art_src/mocap/moves.json (đòn nào của boss nào lấy đòn mocap nào,
mốc sân khấu) + dáng chờ boss do Blender xuất (art_src/mocap/ready/<boss>.json,
`render.sh <boss> --dry` với MOCAP_READY=1). Mô hình (model.py) điền hai đoạn
nối, rồi chiếu lại về đúng độ dài xương. Đầu ra: art_src/mocap/moves/
<boss>_<move>.npz — khung chuẩn theo tiến độ sân khấu, script Blender đọc
(không cần torch / GPU khi xuất sprite).
"""

import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from skeleton import J, JOINTS, Motion  # noqa: E402
import style  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
MOC = os.path.join(ROOT, "art_src", "mocap")
LIB = os.path.join(MOC, "_cache", "strikes")
FK = [("pelvis", "spine"), ("spine", "chest"), ("chest", "neck"), ("neck", "head"), ("head", "head_top"),
      ("chest", "shoulder_l"), ("shoulder_l", "elbow_l"), ("elbow_l", "wrist_l"), ("wrist_l", "hand_tip_l"),
      ("wrist_l", "thumb_l"),
      ("chest", "shoulder_r"), ("shoulder_r", "elbow_r"), ("elbow_r", "wrist_r"), ("wrist_r", "hand_tip_r"),
      ("wrist_r", "thumb_r"),
      ("pelvis", "hip_l"), ("hip_l", "knee_l"), ("knee_l", "ankle_l"), ("ankle_l", "toe_l"),
      ("pelvis", "hip_r"), ("hip_r", "knee_r"), ("knee_r", "ankle_r"), ("ankle_r", "toe_r")]


def bone_lengths(pos):
    return {b: float(np.median(np.linalg.norm(pos[:, J[b[1]]] - pos[:, J[b[0]]], axis=-1))) for b in FK}


def refit(pos, lengths):
    """Giữ hướng từng xương, đặt lại đúng độ dài (FK từ hông) — bỏ trôi độ dài."""
    out = pos.copy()
    for a, b in FK:
        d = pos[..., J[b], :] - pos[..., J[a], :]
        n = np.linalg.norm(d, axis=-1, keepdims=True)
        out[..., J[b], :] = out[..., J[a], :] + d / np.maximum(n, 1e-9) * lengths[(a, b)]
    return out


def leg_len(p):
    return float(np.linalg.norm(p[J["hip_l"]] - p[J["knee_l"]]) + np.linalg.norm(p[J["knee_l"]] - p[J["ankle_l"]]))


def ready_as_actor(ready, lengths):
    """Dáng chờ boss (toạ độ trước/trái/lên, đơn vị rig) → cùng dáng trên xương
    người diễn: giữ hướng xương, đổi độ dài; hông hạ theo tỉ lệ chân."""
    r = np.asarray(ready, dtype=np.float64)
    k = (lengths[("hip_l", "knee_l")] + lengths[("knee_l", "ankle_l")]) / leg_len(r)
    base = r.copy()
    base[J["pelvis"]] = r[J["pelvis"]] * k
    out = refit(base[None], lengths)[0]
    # Bàn chân chạm đất như dáng boss: hạ/nâng cả người cho mắt cá thấp nhất ở độ cao chuẩn.
    low = min(out[J["ankle_l"], 2], out[J["ankle_r"], 2])
    out[:, 2] += 0.08 - low
    return out


def resolve(spec):
    """Đòn mocap theo (clip, chi, thời điểm chạm ~giây trong clip) — mã đòn
    trong thư viện đổi khi dựng lại, ba khoá này thì bền."""
    idx = json.load(open(os.path.join(LIB, "index.json"), encoding="utf-8"))
    cand = [s for s in idx if s["clip"] == spec["clip"] and s["eff"] == spec["eff"]]
    if not cand:
        raise SystemExit(f"không thấy đòn {spec}")
    return min(cand, key=lambda s: abs(s.get("at", 0) - spec.get("at", 0)))["id"]


def compose(spec, ready, model, n=37):
    """Một đòn: trả về (pos (n, 24, 3), phases, meta)."""
    spec = dict(spec, strike=resolve(spec))
    seg = Motion.load(os.path.join(LIB, f"{spec['strike']}.npz"))
    if spec.get("mirror"):
        from model import MIRROR
        seg.pos = seg.pos[:, MIRROR].copy()
        seg.pos[..., 1] *= -1
        eff = seg.meta["eff"]
        seg.meta["eff"] = eff[:-1] + ("l" if eff.endswith("r") else "r")
    ev = spec.get("events", {})
    tr = style.stage_track(seg, impact=ev.get("impact", 0.6), hold=(ev.get("hold_from", 0.36), ev.get("hold_to", 0.46)))
    lengths = bone_lengths(seg.pos)
    rd = ready_as_actor(ready, lengths)
    phases = np.linspace(0, 1, n)
    pos = np.stack([style.sample(seg, tr, p) for p in phases])
    # Mocap đứng ở gốc riêng: dời cho hông đầu đòn trùng hông dáng chờ (X, Y).
    pos[:, :, :2] -= pos[:1, J["pelvis"]:J["pelvis"] + 1, :2]
    pos[:, :, :2] += rd[J["pelvis"], :2]
    a_in, b_in = spec.get("in", (0.06, 0.2))
    a_out, b_out = spec.get("out", (0.88, 0.97))
    known = np.ones(n, np.float32)
    for i, p in enumerate(phases):
        if p <= a_in or p >= b_out:
            pos[i] = rd
        elif a_in < p < b_in or a_out < p < b_out:
            known[i] = 0
    filled = model.fill(pos, known)
    filled = refit(filled, lengths)
    meta = {"strike": spec["strike"], "events": ev, "eff": seg.meta["eff"], "src": seg.meta.get("src"),
            "clip": seg.meta.get("clip"), "turn": spec.get("turn", 0.0), "lean": spec.get("lean", 0.0)}
    return filled, phases, meta, model.score(filled)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    from model import Model
    model = Model.load()
    specs = json.load(open(os.path.join(MOC, "moves.json"), encoding="utf-8"))
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    os.makedirs(os.path.join(MOC, "moves"), exist_ok=True)
    for boss, moves in specs.items():
        if boss.startswith("_") or (args and boss != args[0]):
            continue
        ready = json.load(open(os.path.join(MOC, "ready", f"{boss}.json"), encoding="utf-8"))["points"]
        for move, spec in moves.items():
            if len(args) > 1 and move != args[1]:
                continue
            pos, phases, meta, sc = compose(spec, ready, model)
            out = os.path.join(MOC, "moves", f"{boss}_{move}.npz")
            np.savez_compressed(out, pos=pos.astype(np.float32), phases=phases.astype(np.float32),
                                meta=np.array(json.dumps(meta)), score=sc.astype(np.float32))
            print(f"{boss:13} {move:8} ← {meta['strike']:20} lạ trung bình {sc.mean():.2f} max {sc.max():.2f}")
            if "--sheet" in sys.argv:
                from preview import sheet
                sheet(Motion(pos, (n := len(pos)) / 1.2), 0, 1.2, 12, cols=12, size=150).save(out[:-4] + ".png")


if __name__ == "__main__":
    main()
