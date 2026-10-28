"""Vẽ người que để soát chuyển động (không cần Blender).

    python tool/motion/mocap/preview.py art_src/mocap/_cache/135_07.bvh out.png [--from 2.0 --to 4.0 --n 12]
    python tool/motion/mocap/preview.py clip.npz out.gif --gif

Nhìn ngang như sân khấu game (máy quay ở −Y, +X sang phải); tay/chân phải
màu đậm, trái màu nhạt; vệt cổ tay/mắt cá mờ để thấy quỹ đạo đòn.
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from skeleton import BONES, J, Motion, from_bvh  # noqa: E402

COL = {"r": (220, 70, 50), "l": (240, 170, 150), "c": (40, 40, 50)}


def side(name):
    return name[-1] if name[-2:] in ("_l", "_r") else "c"


def draw(pos, size=260, span=2.4, ground=True, trail=None, label=None, view="side"):
    """Một khung: pos (20, 3) → ảnh vuông. view: side (XZ) | front (YZ)."""
    im = Image.new("RGB", (size, size), (236, 233, 226))
    d = ImageDraw.Draw(im)
    k = size / span
    cx = pos[J["pelvis"], 0] if view == "side" else pos[J["pelvis"], 1]

    def pt(p):
        h = p[0] if view == "side" else -p[1]
        c = cx if view == "side" else -cx
        return (size / 2 + (h - c) * k, size - 18 - p[2] * k)

    if ground:
        d.line([(0, size - 18), (size, size - 18)], fill=(180, 175, 165), width=1)
    if trail is not None:
        for jn, pts in trail.items():
            q = [pt(p) for p in pts]
            if len(q) > 1:
                d.line(q, fill=(200, 200, 215) if jn.endswith("_l") else (150, 150, 200), width=2)
    # Vẽ bên trái trước (xa máy quay hơn khi mặt nhìn +X).
    for a, b in sorted(BONES, key=lambda ab: {"l": 0, "c": 1, "r": 2}[side(ab[1])]):
        d.line([pt(pos[J[a]]), pt(pos[J[b]])], fill=COL[side(b)], width=4)
    hx, hy = pt(pos[J["head"]])
    d.ellipse([hx - 9, hy - 14, hx + 9, hy + 4], outline=COL["c"], width=3)
    if label:
        d.text((6, 4), label, fill=(60, 60, 60))
    return im


def sheet(m, t0, t1, n, cols=6, size=260):
    idx = np.linspace(t0 * m.fps, min(len(m) - 1, t1 * m.fps), n).astype(int)
    rows = (n + cols - 1) // cols
    out = Image.new("RGB", (cols * size, rows * size), (255, 255, 255))
    for i, f in enumerate(idx):
        a = max(0, f - int(0.3 * m.fps))
        trail = {jn: m.pos[a:f + 1, J[jn]] for jn in ("wrist_r", "wrist_l", "ankle_r", "ankle_l")}
        out.paste(draw(m.pos[f], size, trail=trail, label=f"{f / m.fps:5.2f}s"), ((i % cols) * size, (i // cols) * size))
    return out


def gif(m, path, fps=30, size=300):
    mm = m.resample(fps)
    frames = [draw(p, size, label=f"{i / fps:5.2f}s") for i, p in enumerate(mm.pos)]
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0)


def load_any(path):
    return Motion.load(path) if path.endswith(".npz") else from_bvh(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--from", dest="t0", type=float, default=0.0)
    ap.add_argument("--to", dest="t1", type=float, default=None)
    ap.add_argument("--n", type=int, default=12)
    ap.add_argument("--gif", action="store_true")
    a = ap.parse_args()
    m = load_any(a.src)
    if a.gif:
        t1 = a.t1 if a.t1 is not None else len(m) / m.fps
        gif(m.slice(int(a.t0 * m.fps), int(t1 * m.fps)), a.out)
    else:
        sheet(m, a.t0, a.t1 if a.t1 is not None else len(m) / m.fps, a.n).save(a.out)


if __name__ == "__main__":
    main()
