"""Vẽ sheet.png cho bộ soát chuyển động (tool/motion/motion_review.py):

    python -I tool/motion/motion_sheet.py build/blender/motion_review/<boss>

Mỗi đòn một hàng, bốn biểu đồ theo tiến độ 0–1 (nền ba pha lấy đà / ra đòn / thu
về, vạch mốc chạm): đáy bàn chân so với đất · tốc độ trượt chân khi chạm đất ·
vũ khí lún vào thân · gia tốc khớp chính. Khung có cảnh báo: vạch đỏ.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding="utf-8")
W, H, PAD = 430, 230, 46
PHASES = [(0.0, 0.5, (226, 232, 244)), (0.5, 0.65, (248, 224, 220)), (0.65, 1.0, (228, 240, 228))]
COLORS = {"l": (40, 90, 200), "r": (200, 80, 40), "pelvis": (60, 60, 60), "spine_03": (120, 80, 160),
          "head": (30, 150, 150), "hand_l": (40, 90, 200), "hand_r": (200, 80, 40), "foot_l": (110, 150, 230),
          "foot_r": (235, 150, 110), "vũ khí": (0, 0, 0)}


def font(size, bold=False):
    for f in ((r"C:\Windows\Fonts\segoeuib.ttf",) if bold else ()) + (r"C:\Windows\Fonts\segoeui.ttf",):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def chart(title, series, n, lo, hi, limits, flags, impact, unit):
    im = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(im)
    x0, x1, y0, y1 = PAD, W - 12, 26, H - 30
    X = lambda k: x0 + (x1 - x0) * k / (n - 1)
    Y = lambda v: y1 - (y1 - y0) * (min(max(v, lo), hi) - lo) / (hi - lo)
    for a, b, c in PHASES:
        d.rectangle([x0 + (x1 - x0) * a, y0, x0 + (x1 - x0) * b, y1], fill=c)
    for k in flags:
        d.line([X(k), y0, X(k), y1], fill=(230, 40, 40), width=2)
    if impact is not None:
        d.line([x0 + (x1 - x0) * impact, y0, x0 + (x1 - x0) * impact, y1], fill=(30, 30, 30), width=1)
        d.text((x0 + (x1 - x0) * impact + 2, y0), "chạm", fill=(30, 30, 30), font=font(11))
    for v, lab in limits:
        d.line([x0, Y(v), x1, Y(v)], fill=(230, 40, 40), width=1)
        d.text((x1 - 4, Y(v) - 13), lab, fill=(200, 30, 30), font=font(11), anchor="ra")
    for key, vals in series.items():
        d.line([(X(k), Y(v)) for k, v in enumerate(vals)], fill=COLORS.get(key, (90, 90, 90)), width=2)
    d.rectangle([x0, y0, x1, y1], outline=(150, 150, 150))
    d.text((6, 4), title, fill=(20, 20, 20), font=font(14, True))
    for v in (lo, hi):
        d.text((x0 - 4, Y(v)), f"{v:g}", fill=(90, 90, 90), font=font(11), anchor="rm")
    d.text((x0 - 4, (y0 + y1) / 2), unit, fill=(90, 90, 90), font=font(11), anchor="rm")
    lx = x0
    for key in series:
        d.text((lx, y1 + 6), key, fill=COLORS.get(key, (90, 90, 90)), font=font(11))
        lx += 8 + d.textlength(key, font=font(11))
    return im


def main(folder):
    data = json.load(open(os.path.join(folder, "data.json"), encoding="utf-8"))
    n = data["frames"]
    rows = []
    for move, m in data["moves"].items():
        impact = m["events"].get("impact")
        fl = lambda kinds: sorted({f["frame"] for f in m["flags"] if f["kind"] in kinds})
        cells = [
            chart(f"{move} · đáy bàn chân (cm)", {s: [v * 100 for v in m["foot_min"][s]] for s in "lr"},
                  n, -6, 40, [(-2, "xuyên đất")], fl({"chân xuyên đất"}), impact, "cm"),
            chart(f"{move} · trượt chân khi chạm đất", m["slide"], n, 0, 1.5, [(0.3, "0,3 m/s")],
                  fl({"trượt chân"}), impact, "m/s"),
        ]
        if "weapon_depth" in m:
            cells.append(chart(f"{move} · vũ khí lún vào thân (cm)", {"vũ khí": [v * 100 for v in m["weapon_depth"]]},
                               n, 0, 15, [(3, "3 cm")], fl({"vũ khí xuyên thân", "vũ khí xuyên đất"}), impact, "cm"))
        top = max(max(v) for v in m["accel"].values())
        cells.append(chart(f"{move} · gia tốc khớp (m/s²)", m["accel"], n, 0, max(100, round(top * 1.1)), [],
                           fl({"khung giật"}), impact, "m/s²"))
        rows.append(cells)
    cols = max(len(r) for r in rows)
    lines = open(os.path.join(folder, "checks.txt"), encoding="utf-8").read().splitlines()
    text_h = 20 * min(len(lines), 30) + 20
    sheet = Image.new("RGB", (cols * W, len(rows) * H + text_h), "white")
    for r, cells in enumerate(rows):
        for c, im in enumerate(cells):
            sheet.paste(im, (c * W, r * H))
    d = ImageDraw.Draw(sheet)
    for i, line in enumerate(lines[:30]):
        d.text((10, len(rows) * H + 10 + 20 * i), line, fill=(200, 30, 30) if line.startswith("[") else (20, 20, 20),
               font=font(14, i == 0))
    out = os.path.join(folder, "sheet.png")
    sheet.save(out)
    print(out)


main(sys.argv[1])
