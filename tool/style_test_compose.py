"""Ghép cảnh thử phong cách (tool/blender/style_test.py) như sân khấu game
và đặt hai phong cách cạnh nhau:

    python -I tool/style_test_compose.py

→ build/style/compare.png (trên: hiện tại, dưới: painted), và
build/style/<real|painted>.png. Cách đặt giống lib/art: phông theo tầng phủ
sân khấu 400×260 (+24 đơn vị lề mỗi bên), sư tử tại (335, 220) ×0,72, nhân
vật neo tại (40, 220), da/tóc nhân màu, tiền cảnh đè lên, cả sân khấu tăng
bão hoà ×1,25 (BattleStageGame.saturation). KUWAHARA=<bán kính>: thử lọc
Kuwahara cho bản painted (lần 1: ra ô vuông vỡ hạt, không giống nét cọ).
Cần Pillow, numpy.
"""

import json
import os

import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BASE = os.path.join(ROOT, "build", "style")
PX = 3.0  # điểm ảnh mỗi đơn vị sân khấu
MARGIN = 24
SKIN = (0xE2, 0xA7, 0x7C)  # HeroLook mặc định
HAIR = (0x3B, 0x24, 0x16)


def stage_px(x, y):
    return ((x + MARGIN) * PX, y * PX)


def place(canvas, img, anchor, ppu, at, scale=1.0):
    """Dán [img] (ảnh render, [ppu] điểm ảnh/đơn vị, điểm neo [anchor]) sao
    cho điểm neo trùng điểm sân khấu [at], phóng thêm [scale]."""
    f = PX * scale / ppu
    w, h = img.size
    img = img.resize((max(1, round(w * f)), max(1, round(h * f))), Image.LANCZOS)
    x, y = stage_px(*at)
    canvas.alpha_composite(img, (round(x - anchor[0] * f), round(y - anchor[1] * f)))


def tint(img, rgb):
    a = np.asarray(img).astype(np.float32)
    a[..., :3] *= np.array(rgb, dtype=np.float32) / 255.0
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def _box(img, r):
    """Trung bình hộp (2r+1)² bằng ảnh tích phân, biên kéo dài."""
    p = np.pad(img, ((r + 1, r), (r + 1, r)) + ((0, 0),) * (img.ndim - 2), mode="edge")
    c = p.cumsum(0).cumsum(1)
    k = 2 * r + 1
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return s / (k * k)


def kuwahara(img, r=3):
    """Kuwahara cổ điển: mỗi điểm lấy trung bình của góc phần tư (trong 4
    góc bán kính [r]) có độ biến thiên độ sáng nhỏ nhất."""
    rgb = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    h = r // 2
    mean = _box(rgb, h)
    m1 = _box(lum, h)
    m2 = _box(lum * lum, h)
    var = m2 - m1 * m1
    H, W = lum.shape
    best = np.full((H, W), np.inf, dtype=np.float32)
    out = np.zeros_like(rgb)
    for dy in (-h, h):
        for dx in (-h, h):
            v = np.roll(np.roll(var, dy, 0), dx, 1)
            m = np.roll(np.roll(mean, dy, 0), dx, 1)
            pick = v < best
            best[pick] = v[pick]
            out[pick] = m[pick]
    return Image.fromarray((out * 255).clip(0, 255).astype(np.uint8), "RGB")


def compose(variant):
    d = os.path.join(BASE, variant)
    meta = json.load(open(os.path.join(d, "meta.json"), encoding="utf-8"))
    canvas = None
    for ln in ("sky", "far", "mid", "near"):
        layer = Image.open(os.path.join(d, f"backdrop_{ln}.png")).convert("RGBA")
        canvas = layer if canvas is None else (canvas.alpha_composite(layer) or canvas)
    lion = Image.open(os.path.join(d, "lion.png")).convert("RGBA")
    place(canvas, lion, meta["lion"]["anchor"], meta["lion"]["ppu"], (335, 220), 0.72)
    hm = meta["hero"]
    for name, col in (("skin", SKIN), ("cloth", None), ("hair", HAIR)):
        img = Image.open(os.path.join(d, f"hero_{name}.png")).convert("RGBA")
        place(canvas, tint(img, col) if col else img, hm["anchor"], hm["ppu"], (40, 220))
    canvas.alpha_composite(Image.open(os.path.join(d, "backdrop_fg.png")).convert("RGBA"))
    out = canvas.convert("RGB").crop((round(MARGIN * PX), 0, round((MARGIN + 400) * PX), round(260 * PX)))
    out = ImageEnhance.Color(out).enhance(1.25)
    if variant == "painted" and os.environ.get("KUWAHARA"):
        out = kuwahara(out, r=int(os.environ["KUWAHARA"]))
    out.save(os.path.join(BASE, f"{variant}.png"))
    return out


def main():
    shots = [compose(v) for v in ("real", "painted") if os.path.exists(os.path.join(BASE, v, "meta.json"))]
    w, h = shots[0].size
    sheet = Image.new("RGB", (w, h * len(shots)))
    for i, s in enumerate(shots):
        sheet.paste(s, (0, h * i))
    sheet.save(os.path.join(BASE, "compare.png"))
    print("build/style/compare.png")


if __name__ == "__main__":
    main()
