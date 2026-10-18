"""Gom mọi clip võ học (CMU + Kyokushin) thành một tập huấn luyện 30 fps.

    python tool/mocap/dataset.py      # → art_src/mocap/_cache/dataset_30.npz

Mỗi clip: khung xương chuẩn 24 điểm (skeleton.py), bỏ đoạn T-pose, lọc mượt
nhẹ, 30 fps. Lưu nối liền + chỉ số đầu clip + nhãn nguồn — mô hình (model.py,
chạy trong tool/.venv-ml có torch CUDA) chỉ cần numpy để nạp.
"""

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fetch import CACHE  # noqa: E402
from segment import all_clips, drop_tpose  # noqa: E402

FPS = 30
OUT = os.path.join(CACHE, f"dataset_{FPS}.npz")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    pos, starts, names, srcs = [], [], [], []
    n = 0
    for cid, load, tags, desc in all_clips():
        try:
            m = load()
        except Exception as e:
            print(f"{cid}: bỏ qua ({e!r})"[:100])
            continue
        m = drop_tpose(m).resample(FPS).smooth(0.1)
        if len(m) < 70:
            continue
        p = m.pos.astype(np.float32)
        if not np.isfinite(p).all() or np.abs(p).max() > 50:
            print(f"{cid}: dữ liệu hỏng")
            continue
        pos.append(p)
        starts.append(n)
        names.append(cid)
        srcs.append(m.meta.get("src", "cmu"))
        n += len(p)
    np.savez_compressed(OUT, pos=np.concatenate(pos), starts=np.array(starts), names=np.array(names),
                        srcs=np.array(srcs), fps=FPS)
    print(f"{len(names)} clip, {n} khung ({n / FPS / 60:.1f} phút) → {OUT}")


if __name__ == "__main__":
    main()
