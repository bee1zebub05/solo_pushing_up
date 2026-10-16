"""Đóng lại atlas sprite từ khung đã render (build/blender/sprites/<tên>/),
không phải chạy Blender: cắt theo thân (bỏ bóng trải hết ảnh), thu nhỏ nếu
cần cho vừa ngân sách trang, rồi nén WebP (tool/sprites_webp.py).

    python tool/repack_sprites.py nemea_lion --scale 0.8
    python tool/repack_sprites.py                 # mọi sprite có khung

Thông số điểm neo lấy từ `_atlas.json` (sprite_kit ghi lúc render). Atlas
render trước khi có file đó: suy ra từ json cũ trong assets/sprites (khung
cũ cắt theo alpha > 0,004 nên tính lại được góc cắt).
"""

import argparse
import glob
import json
import os
import sys

import numpy as np

sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tool", "blender"))
from atlas_pack import crop, pack, resize  # noqa: E402

SCRATCH = os.path.join(ROOT, "build", "blender", "sprites")
PAGES = os.path.join(SCRATCH, "pages")
ASSETS = os.path.join(ROOT, "assets", "sprites")


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0


def save(arr, path):
    a = np.clip(arr * 255 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(a, "RGBA").save(path)


def manifest(name):
    """(điểm neo, ppu, extra, [(chuỗi, file)]) của sprite [name]."""
    path = os.path.join(SCRATCH, name, "_atlas.json")
    if os.path.exists(path):
        m = json.load(open(path, encoding="utf-8"))
        return tuple(m["anchor"]), m["ppu"], m["extra"], [tuple(f) for f in m["frames"]]
    old = json.load(open(os.path.join(ASSETS, f"{name}.json"), encoding="utf-8"))
    ppu = 1 / old["unitsPerPixel"]
    extra = {k: v for k, v in old.items() if k not in ("unitsPerPixel", "pages", "anims")}
    files = [(anim, f"{anim}_{k:02d}.png") for anim, fs in old["anims"].items() for k in range(len(fs))]
    # Góc cắt cũ (alpha > 0,004, lề 1 điểm ảnh) → điểm neo = góc − dx·ppu.
    anim, fname = files[0]
    px = load(os.path.join(SCRATCH, name, fname))
    ys, xs = np.nonzero(px[:, :, 3] > 0.004)
    x0, y0 = max(xs.min() - 1, 0), max(ys.min() - 1, 0)
    f0 = old["anims"][anim][0]
    anchor = (x0 - f0["dx"] * ppu, y0 - f0["dy"] * ppu)
    return anchor, ppu, extra, files


def repack(name, scale):
    anchor, ppu, extra, files = manifest(name)
    frames = []
    for anim, fname in files:
        px = resize(load(os.path.join(SCRATCH, name, fname)), scale)
        c, x0, y0 = crop(px)
        frames.append((anim, c, x0, y0))
    _, n = pack(name, frames, (anchor[0] * scale, anchor[1] * scale), ppu * scale, extra, PAGES, ASSETS, save)
    print(f"[repack] {name}: {len(frames)} khung, {n} trang, {ppu * scale:.2f} px/đơn vị")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--scale", type=float, default=1.0)
    args = ap.parse_args()
    names = args.names or sorted(os.path.basename(os.path.dirname(p))
                                 for p in glob.glob(os.path.join(SCRATCH, "*", "*.png"))
                                 if os.path.exists(os.path.join(ASSETS, os.path.basename(os.path.dirname(p)) + ".json")))
    for name in dict.fromkeys(names):
        repack(name, args.scale)
    import subprocess
    subprocess.run([sys.executable, os.path.join(ROOT, "tool", "sprites_webp.py"), *dict.fromkeys(names)], check=True)


if __name__ == "__main__":
    main()
