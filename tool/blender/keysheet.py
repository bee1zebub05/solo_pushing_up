"""Ghép ảnh tư thế khoá (render.sh <boss> --still [--game]) thành tấm có nhãn tiến độ: python -I tool/blender/keysheet.py build/blender/oni/keys attack out.png [cột]"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

d, prefix, out = sys.argv[1:4]
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 10
files = sorted(glob.glob(os.path.join(d, f"{prefix}_*.png")))
ims = [Image.open(f).convert("RGBA") for f in files]
w, h = ims[0].size
s = 0.6
tw, th = int(w * s), int(h * s)
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (tw * min(cols, len(ims)), th * rows), (200, 196, 192))
font = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 20)
dr = ImageDraw.Draw(sheet)
for i, (f, im) in enumerate(zip(files, ims)):
    x, y = (i % cols) * tw, (i // cols) * th
    bg = Image.new("RGBA", im.size, (200, 196, 192, 255))
    bg.alpha_composite(im)
    sheet.paste(bg.convert("RGB").resize((tw, th)), (x, y))
    dr.text((x + 6, y + 4), os.path.basename(f)[len(prefix) + 1:-4], fill=(30, 30, 30), font=font)
sheet.save(out)
print(sheet.size)
