"""Nhập phông vẽ tay (ChatGPT, art_src/backdrop_prompts/) vào game.

    python -I tool/import_painted_backdrops.py

- `1.1.png` … `1.8.png` (1536×1024, khung bố cục `3_khung_bo_cuc.png`): cắt
  dải giữa đúng tỉ lệ sân khấu (448×260 đơn vị kể cả lề trôi camera) →
  `assets/backdrops/nemea_stage_1_X.webp` (1344×780).
- `ban_do.png` (khung `5_phac_ban_do.png`): cắt 4:3 giữa → `nemea_map.webp`
  (1200×900); dò lối đất (màu đất sáng) và dòng sông (màu nước) thành đường
  gấp khúc theo toạ độ bản đồ 400×300, in ra hằng số Dart cho
  lib/art/nemea_map_art.dart (`nemeaMapTrail`, `_nodeOnTrail`, `_riverLine`).
"""

import math
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.graph import route_through_array

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "art_src", "backdrop_prompts")
OUT = os.path.join(ROOT, "assets", "backdrops")
sys.stdout.reconfigure(encoding="utf-8")

STAGE_PX = (1344, 780)  # 448 × 260 đơn vị sân khấu × 3
MAP_PX = (1200, 900)  # 400 × 300 đơn vị bản đồ × 3
K = 3

# Mốc trên bản đồ (đơn vị bản đồ) mà mỗi điểm màn bám vào: điểm màn đặt ở
# chỗ lối đất gần mốc nhất (theo thứ tự đi).
LANDMARKS = [
    (52, 250),  # 1.1 rừng ô liu (đầu đường)
    (84, 196),  # 1.2 ruộng cày
    (165, 168),  # 1.3 bờ sông dưới đồi đền
    (222, 186),  # 1.4 cạnh bụi rậm
    (251, 209),  # 1.5 trên cầu
    (283, 150),  # 1.6 cạnh đầm lầy
    (320, 96),  # 1.7 vùng đất chết dưới vách
    (349, 60),  # 1.8 cửa hang
]


def stages():
    for i in range(1, 9):
        src = os.path.join(SRC, f"1.{i}.png")
        im = Image.open(src).convert("RGB")
        w, h = im.size
        band = round(w * STAGE_PX[1] / STAGE_PX[0])
        top = (h - band) // 2
        out = im.crop((0, top, w, top + band)).resize(STAGE_PX, Image.LANCZOS)
        path = os.path.join(OUT, f"nemea_stage_1_{i}.webp")
        out.save(path, quality=82, method=6)
        print(path, os.path.getsize(path) // 1024, "KB")


def _route(mask, start, end, gap_cost):
    m = ndi.binary_closing(mask, iterations=3)
    m = ndi.binary_opening(m, iterations=2)
    lab, n = ndi.label(m)
    sizes = ndi.sum(m, lab, range(1, n + 1))
    keep = np.isin(lab, 1 + np.nonzero(sizes > 800)[0])
    dist = ndi.distance_transform_edt(keep)
    cost = np.where(keep, 1.0 / (1 + dist), gap_cost)
    ys, xs = np.nonzero(keep)

    def snap(p):
        i = ((xs - p[0] * K) ** 2 + (ys - p[1] * K) ** 2).argmin()
        return ys[i], xs[i]

    path, _ = route_through_array(cost, snap(start), snap(end), fully_connected=True, geometric=True)
    return [(x / K, y / K) for y, x in path]


def _smooth(pts, r=6):
    out = []
    for i in range(len(pts)):
        a, b = max(0, i - r), min(len(pts), i + r + 1)
        out.append((sum(p[0] for p in pts[a:b]) / (b - a), sum(p[1] for p in pts[a:b]) / (b - a)))
    out[0], out[-1] = pts[0], pts[-1]
    return out


def _resample(pts, step):
    out = [pts[0]]
    acc = 0.0
    for a, b in zip(pts, pts[1:]):
        d = math.dist(a, b)
        while acc + d >= step:
            t = (step - acc) / d
            a = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            d = math.dist(a, b)
            out.append(a)
            acc = 0.0
        acc += d
    if math.dist(out[-1], pts[-1]) > step * 0.3:
        out.append(pts[-1])
    return out


def map_():
    im = Image.open(os.path.join(SRC, "ban_do.png")).convert("RGB")
    w, h = im.size
    cw = round(h * 4 / 3)
    x0 = (w - cw) // 2
    m = im.crop((x0, 0, x0 + cw, h)).resize(MAP_PX, Image.LANCZOS)
    path = os.path.join(OUT, "nemea_map.webp")
    m.save(path, quality=84, method=6)
    print(path, os.path.getsize(path) // 1024, "KB")
    px = np.asarray(m).astype(float)
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    dirt = (r > 185) & (g > 145) & (b > 80) & (b < 170) & (r - b > 65) & (r - g > 20) & (r - g < 70)
    water = (b > r + 25) & (b > 90) & (g > r)
    trail = _resample(_smooth(_route(dirt, LANDMARKS[0], LANDMARKS[-1], 25.0)), 6.0)
    nodes = []
    last = 0
    for lm in LANDMARKS:
        i = min(range(last, len(trail)), key=lambda j: math.dist(trail[j], lm))
        nodes.append(i)
        last = i + 1
    river = _resample(_smooth(_route(water, (0, 133), (338, 299), 25.0), 10), 14.0)
    fmt = lambda pts: ",\n".join(f"  Offset({x:.0f}, {y:.0f})" for x, y in pts)
    print("\nconst nemeaMapTrail = <Offset>[\n" + fmt(trail) + ",\n];")
    print("\nconst _nodeOnTrail = " + str(nodes) + ";")
    print("\nconst _riverLine = <Offset>[\n" + fmt(river) + ",\n];")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    stages()
    map_()
