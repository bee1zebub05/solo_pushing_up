"""Ghép bộ ảnh soát (review_kit) thành một tấm có nhãn + danh sách cảnh báo.

    python -I tool/blender/kits/review_sheet.py build/blender/review/oni_boss

render.sh tự gọi sau khi chạy script boss với cờ --review. Ra sheet.png cùng thư mục.
"""

import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

from PIL import Image, ImageDraw, ImageFont

TILE_H = 360
BIG_H = 560  # ảnh toàn thân to hơn ảnh cận
MAX_W = 2200
BG = (36, 34, 32)
FG = (238, 231, 223)
WARN = (255, 170, 80)


def font(size):
    for f in (r"C:\Windows\Fonts\segoeui.ttf", r"C:\Windows\Fonts\arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main(folder):
    man = json.load(open(os.path.join(folder, "manifest.json"), encoding="utf-8"))
    f_lab, f_txt, f_head = font(17), font(16), font(22)
    tiles = []
    for s in man["shots"]:
        th = BIG_H if s.get("big") else TILE_H
        im = Image.open(os.path.join(folder, s["file"])).convert("RGBA")
        im = im.resize((max(1, round(im.width * th / im.height)), th), Image.LANCZOS)
        if im.width > 2 * th:  # ảnh quá dẹt (hai bàn chân) → thu cho vừa
            im = im.resize((2 * th, max(1, round(im.height * 2 * th / im.width))), Image.LANCZOS)
        tile = Image.new("RGBA", (im.width, th + 26), BG + (255,))
        # Nền ô xám hơi sáng để thấy viền đen / bóng của nhân vật trên ảnh trong suốt.
        tile.paste((58, 56, 54, 255), (0, 26, im.width, th + 26))
        tile.alpha_composite(im, (0, 26 + th - im.height))
        ImageDraw.Draw(tile).text((6, 3), s["label"], fill=FG, font=f_lab)
        tiles.append(tile)
    rows, cur, cur_w = [], [], 0
    for t in tiles:  # xếp hàng theo bề ngang tối đa thay vì số cột cố định
        if cur and cur_w + t.width + 8 > MAX_W:
            rows.append(cur)
            cur, cur_w = [], 0
        cur.append(t)
        cur_w += t.width + 8
    if cur:
        rows.append(cur)
    width = max(sum(t.width for t in r) + 8 * (len(r) + 1) for r in rows)
    warns = man["warnings"]
    checks = open(os.path.join(folder, "checks.txt"), encoding="utf-8").read().splitlines()
    text_h = 40 + 22 * (len(checks) + 1)
    height = sum(max(t.height for t in r) + 8 for r in rows) + 8 + text_h
    sheet = Image.new("RGBA", (width, height), BG + (255,))
    y = 8
    for r in rows:
        x = 8
        for t in r:
            sheet.alpha_composite(t, (x, y))
            x += t.width + 8
        y += max(t.height for t in r) + 8
    d = ImageDraw.Draw(sheet)
    d.text((10, y), f"{man['name']} — {len(warns)} cảnh báo", fill=WARN if warns else FG, font=f_head)
    y += 34
    for ln in checks:
        bad = ln.startswith("⚠")  # Segoe UI không có ⚠ → ô vuông
        d.text((14, y), ("(!) " + ln[2:]) if bad else ln, fill=WARN if bad else FG, font=f_txt)
        y += 22
    out = os.path.join(folder, "sheet.png")
    sheet.convert("RGB").save(out)
    print("sheet:", out, f"({len(warns)} cảnh báo)")


if __name__ == "__main__":
    main(sys.argv[1])
