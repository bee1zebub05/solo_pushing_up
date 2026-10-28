"""Ảnh động một chuỗi sprite phát lại ĐÚNG như game vẽ (cùng cách tính của
compare_motion.py: 30 hình/giây, hoà hai khung kề nhau, `phases`, snap quanh
cú đánh) — cho báo cáo, khi khung không chia đều.

    python -I tool/render/game_anim.py FRAMES_DIR OUT.webp --anim attack --seconds 1.2 [--snap] [--loop]
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from compare_motion import frames, phases_of, sample  # noqa: E402

FPS = 20  # ảnh báo cáo: đủ thấy độ mượt, nhẹ hơn 30 hình/giây


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("out")
    ap.add_argument("--anim", default="attack")
    ap.add_argument("--seconds", type=float, default=1.2)
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--snap", action="store_true")
    ap.add_argument("--hold", type=float, default=0.5)
    ap.add_argument("--width", type=int, default=560)
    args = ap.parse_args()
    fr = frames(args.dir, args.anim)
    ph = phases_of(args.dir, args.anim)
    box = None
    for f in fr:
        ys, xs = np.nonzero(f[..., 3] > 0.03)
        if len(xs):
            bb = (xs.min(), ys.min(), xs.max(), ys.max())
            box = bb if box is None else (min(box[0], bb[0]), min(box[1], bb[1]), max(box[2], bb[2]), max(box[3], bb[3]))
    h0, w0 = fr[0].shape[:2]
    pad = 12
    box = (max(0, box[0] - pad), max(0, box[1] - pad), min(w0, box[2] + pad), min(h0, box[3] + pad))
    cw, ch = box[2] - box[0], box[3] - box[1]
    size = (args.width, round(ch * args.width / cw))
    count = round(args.seconds * FPS)
    hold = 0 if args.loop else round(args.hold * FPS)
    out = []
    for i in range(count + hold):
        t = min(i, count - 1) / (count if args.loop else count - 1)
        snap = args.snap and not args.loop and 0.48 < t < 0.7
        img = sample(fr, ph, t, args.loop, snap)[box[1]:box[3], box[0]:box[2]]
        tile = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        tile.alpha_composite(Image.fromarray((img * 255).astype(np.uint8), "RGBA"))
        out.append(tile.resize(size, Image.LANCZOS))
    out[0].save(args.out, save_all=True, append_images=out[1:], duration=round(1000 / FPS), loop=0,
                quality=62, method=4)
    print(args.out, size, len(out), os.path.getsize(args.out) // 1024, "KB")


if __name__ == "__main__":
    main()
