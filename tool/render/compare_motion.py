"""Ảnh động so sánh chuyển động trước/sau, phát lại khung ĐÚNG như game vẽ
(SpriteAtlas.draw): 30 hình/giây, hoà mờ hai khung kề nhau, khung chia đều
hoặc theo `phases`, `snap` quanh cú đánh của bản cũ. Dùng soát độ mượt mà
không cần chạy app.

    python -I tool/render/compare_motion.py OLD_DIR NEW_DIR OUT.webp \\
        --anim attack --seconds 1.2 [--snap] [--phases '[0,0.05,...]']
    python -I tool/render/compare_motion.py OLD NEW OUT.webp --anim idle --seconds 3.2 --loop

OLD_DIR / NEW_DIR: thư mục khung render (build/blender/sprites/<tên>/, có
_atlas.json). `--phases` mặc định đọc `extra.phases[anim]` trong _atlas.json.
"""

import argparse
import glob
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FPS = 30


def frames(dirpath, anim):
    files = sorted(glob.glob(os.path.join(dirpath, f"{anim}_*.png")))
    return [np.asarray(Image.open(f).convert("RGBA")).astype(np.float32) / 255 for f in files]


def phases_of(dirpath, anim):
    try:
        meta = json.load(open(os.path.join(dirpath, "_atlas.json"), encoding="utf-8"))
        return meta.get("extra", {}).get("phases", {}).get(anim)
    except OSError:
        return None


def position(phases, n, t, loop):
    if loop:
        return (t % 1) * n
    t = min(max(t, 0.0), 1.0)
    if phases and len(phases) == n:
        if t <= phases[0]:
            return 0.0
        if t >= phases[-1]:
            return n - 1.0
        i = 0
        while phases[i + 1] < t:
            i += 1
        return i + (t - phases[i]) / (phases[i + 1] - phases[i])
    return t * (n - 1)


def over(dst, src, a):
    """Vẽ [src] (RGBA thẳng) lên [dst] với độ đục nhân [a] (như drawImageRect)."""
    sa = src[..., 3:4] * a
    dst[..., :3] = src[..., :3] * sa + dst[..., :3] * (1 - sa)
    dst[..., 3:4] = sa + dst[..., 3:4] * (1 - sa)


def sample(fr, phases, t, loop, snap):
    n = len(fr)
    pos = position(phases, n, t, loop)
    i = int(np.floor(pos)) % n
    j = (i + 1) % n if loop else min(i + 1, n - 1)
    mix = pos - np.floor(pos)
    out = np.zeros_like(fr[0])
    if snap:
        over(out, fr[int(round(pos)) % n], 1.0)
        return out
    over(out, fr[i], 1.0)
    if mix > 0.02 and j != i:
        over(out, fr[j], mix)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old")
    ap.add_argument("new")
    ap.add_argument("out")
    ap.add_argument("--anim", default="attack")
    ap.add_argument("--seconds", type=float, default=1.2)
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--snap", action="store_true", help="cả hai bản chỉ vẽ một khung trong 0,48–0,70 (như game)")
    ap.add_argument("--width", type=int, default=360)
    args = ap.parse_args()
    a, b = frames(args.old, args.anim), frames(args.new, args.anim)
    pa, pb = phases_of(args.old, args.anim), phases_of(args.new, args.anim)
    # Khung chung (cắt theo alpha của mọi khung cả hai bản).
    box = None
    for f in a + b:
        ys, xs = np.nonzero(f[..., 3] > 0.03)
        if len(xs):
            bb = (xs.min(), ys.min(), xs.max(), ys.max())
            box = bb if box is None else (min(box[0], bb[0]), min(box[1], bb[1]), max(box[2], bb[2]), max(box[3], bb[3]))
    pad = 10
    h0, w0 = a[0].shape[:2]
    box = (max(0, box[0] - pad), max(0, box[1] - pad), min(w0, box[2] + pad), min(h0, box[3] + pad))
    cw, ch = box[2] - box[0], box[3] - box[1]
    k = args.width / cw
    tw, th = args.width, round(ch * k)
    try:
        font = ImageFont.truetype("arialbd.ttf", 18)
    except OSError:
        font = ImageFont.load_default()
    count = round(args.seconds * FPS)
    hold = 0 if args.loop else round(0.5 * FPS)
    out = []
    for f in range(count + hold):
        t = min(f, count - 1) / (count if args.loop else count - 1)
        tiles = []
        for fr, ph, snap_old, label in ((a, pa, args.snap, f"TRUOC: {len(a)} khung"),
                                        (b, pb, args.snap, f"SAU: {len(b)} khung")):
            snap = snap_old and not args.loop and 0.48 < t < 0.7
            img = sample(fr, ph, t, args.loop, snap)[box[1]:box[3], box[0]:box[2]]
            tile = Image.new("RGBA", (cw, ch), (233, 228, 218, 255))
            tile.alpha_composite(Image.fromarray((img * 255).astype(np.uint8), "RGBA"))
            tile = tile.convert("RGB").resize((tw, th), Image.LANCZOS)
            d = ImageDraw.Draw(tile)
            d.rectangle([0, 0, tw, 26], fill=(28, 22, 18))
            d.text((8, 3), label, font=font, fill=(240, 200, 120))
            tiles.append(tile)
        frame = Image.new("RGB", (tw * 2 + 8, th), (28, 22, 18))
        frame.paste(tiles[0], (0, 0))
        frame.paste(tiles[1], (tw + 8, 0))
        out.append(frame)
    out[0].save(args.out, save_all=True, append_images=out[1:], duration=round(1000 / FPS), loop=0,
                quality=78, method=4)
    print(args.out, out[0].size, len(out), os.path.getsize(args.out) // 1024, "KB")


if __name__ == "__main__":
    main()
