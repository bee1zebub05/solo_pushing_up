"""Nén trang atlas PNG (bản gốc không mất dữ liệu do tool/blender/sprite_kit.py
xuất vào build/blender/sprites/pages/) thành WebP trong assets/sprites/, và
các tầng phông nền (tool/blender/nemea_valley.py → build/blender/backdrops/
<vùng>_<tầng>.png) thành assets/backdrops/.

    python tool/sprites_webp.py              # trang mới hơn bản WebP
    python tool/sprites_webp.py harpy boar   # chỉ các quái này (nén lại hết)

WebP chất lượng 90, alpha giữ nguyên: 6 quái chương 1 từ 21 MB PNG còn ~3 MB,
sai lệch màu trung bình 1–3/255 (sân khấu còn phóng sprite ~2 lần, không thấy).
Cần Pillow.
"""

import glob
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PAGES = os.path.join(ROOT, "build", "blender", "sprites", "pages")
OUT = os.path.join(ROOT, "assets", "sprites")
QUALITY = 90
BACKDROPS = os.path.join(ROOT, "build", "blender", "backdrops")
BACKDROP_OUT = os.path.join(ROOT, "assets", "backdrops")
# Phông nền phủ cả màn hình, không phóng to như sprite: q85 đủ, nhẹ hơn.
BACKDROP_QUALITY = 85
BACKDROP_LAYERS = ("sky", "far", "mid", "near", "fg")


def convert(png):
    base = os.path.splitext(os.path.basename(png))[0]
    dst = os.path.join(OUT, base + ".webp")
    Image.open(png).convert("RGBA").save(
        dst, "WEBP", quality=QUALITY, alpha_quality=100, method=6
    )
    print(f"{base}: {os.path.getsize(png) // 1024} KB PNG -> {os.path.getsize(dst) // 1024} KB WebP")


def _sprite(path):
    return os.path.basename(path).rsplit("_", 1)[0]


def _stale(png):
    dst = os.path.join(OUT, os.path.splitext(os.path.basename(png))[0] + ".webp")
    return not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(png)


def backdrops():
    os.makedirs(BACKDROP_OUT, exist_ok=True)
    for png in sorted(glob.glob(os.path.join(BACKDROPS, "*.png"))):
        base = os.path.splitext(os.path.basename(png))[0]
        if base.rsplit("_", 1)[-1] not in BACKDROP_LAYERS:
            continue  # ảnh xem nhanh (--still)
        dst = os.path.join(BACKDROP_OUT, base + ".webp")
        if os.path.exists(dst) and os.path.getmtime(dst) >= os.path.getmtime(png):
            continue
        img = Image.open(png).convert("RGBA")
        if base.endswith("_sky"):
            img = img.convert("RGB")
        img.save(dst, "WEBP", quality=BACKDROP_QUALITY, alpha_quality=90, method=6)
        print(f"{base}: {os.path.getsize(png) // 1024} KB PNG -> {os.path.getsize(dst) // 1024} KB WebP")


def main(names):
    backdrops()
    pngs = sorted(glob.glob(os.path.join(PAGES, "*.png")))
    if not pngs:
        return
    todo = [p for p in pngs if _sprite(p) in names] if names else [p for p in pngs if _stale(p)]
    os.makedirs(OUT, exist_ok=True)
    # Số trang có thể giảm sau khi render lại: bỏ trang WebP thừa của quái đó.
    for name in {_sprite(p) for p in todo}:
        keep = {os.path.splitext(os.path.basename(p))[0] for p in pngs if _sprite(p) == name}
        for old in glob.glob(os.path.join(OUT, f"{name}_*.webp")):
            if os.path.splitext(os.path.basename(old))[0] not in keep:
                os.remove(old)
    for png in todo:
        convert(png)


if __name__ == "__main__":
    main(sys.argv[1:])
