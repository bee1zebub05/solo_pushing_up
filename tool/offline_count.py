"""Bộ đếm "thầy" offline cho bản ghi KHÔNG có nhãn (ví dụ bộ Mendeley).

Khác bộ đếm của app (chạy thời gian thực, chỉ thấy quá khứ), bộ này thấy cả
đoạn tín hiệu: làm mượt hai chiều, nội suy chỗ mất dấu, rồi đếm các đáy của
góc khuỷu tay có độ nổi bật đủ lớn. Dùng làm nhãn tạm để tìm chỗ bộ đếm của
app lệch; luôn kiểm tra bằng mắt (--plot) trước khi tin.

    python tool/offline_count.py dataset/public/mendeley_form/recordings
    python tool/offline_count.py <thư mục> --write   # ghi expectedCount (tag label=offline)
    python tool/offline_count.py <thư mục> --plot subject_001_push_up_good_front
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys

import numpy as np

MIN_CONF = 0.5


def elbow_series(recording: dict) -> tuple[np.ndarray, np.ndarray]:
    """Góc khuỷu tay theo thời gian (trung bình hai tay nếu thấy cả hai)."""
    times, angles = [], []
    for frame in recording["frames"]:
        values = []
        for side in ("left", "right"):
            pts = [frame["lm"].get(side + k) for k in ("Shoulder", "Elbow", "Wrist")]
            if all(p and p[2] >= MIN_CONF for p in pts):
                (ax, ay, _), (bx, by, _), (cx, cy, _) = pts
                v1, v2 = (ax - bx, ay - by), (cx - bx, cy - by)
                n = math.hypot(*v1) * math.hypot(*v2)
                if n:
                    cos = max(-1.0, min(1.0, (v1[0] * v2[0] + v1[1] * v2[1]) / n))
                    values.append(math.degrees(math.acos(cos)))
        times.append(frame["t"] / 1000)
        angles.append(sum(values) / len(values) if values else np.nan)
    return np.array(times), np.array(angles)


def smooth(t: np.ndarray, a: np.ndarray, window_s: float = 0.25) -> np.ndarray:
    """Nội suy chỗ mất dấu (ngắn) rồi làm mượt trung bình trượt hai chiều."""
    ok = ~np.isnan(a)
    if ok.sum() < 5:
        return a
    filled = np.interp(t, t[ok], a[ok])
    dt = np.median(np.diff(t)) if len(t) > 1 else 0.05
    k = max(1, int(round(window_s / dt)))
    kernel = np.ones(k) / k
    smoothed = np.convolve(np.pad(filled, (k // 2, k - 1 - k // 2), mode="edge"), kernel, mode="valid")
    # Chỗ mất dấu dài (> 1 s) không tin được: bỏ.
    gap = np.zeros_like(ok)
    last = -1e9
    for i, good in enumerate(ok):
        if good:
            last = t[i]
        gap[i] = (t[i] - last) > 1.0
    smoothed[gap] = np.nan
    return smoothed


def count_valleys(a: np.ndarray, min_prominence: float = 30, max_valley: float = 120) -> list[int]:
    """Đáy cục bộ có độ nổi bật (so với đỉnh hai bên) ≥ min_prominence."""
    idx = []
    n = len(a)
    i = 1
    while i < n - 1:
        if np.isnan(a[i]):
            i += 1
            continue
        if a[i] <= a[i - 1] and a[i] < a[i + 1] and a[i] <= max_valley:
            # đỉnh cao nhất bên trái/phải cho tới khi gặp đáy thấp hơn
            left = a[i]
            j = i - 1
            while j >= 0 and not np.isnan(a[j]) and a[j] >= a[i]:
                left = max(left, a[j])
                j -= 1
            right = a[i]
            j = i + 1
            while j < n and not np.isnan(a[j]) and a[j] >= a[i]:
                right = max(right, a[j])
                j += 1
            if min(left, right) - a[i] >= min_prominence:
                idx.append(i)
        i += 1
    return idx


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--write", action="store_true", help="ghi expectedCount vào bản ghi chưa có nhãn")
    parser.add_argument("--plot", help="tên bản ghi (không .json) để vẽ ra PNG")
    parser.add_argument("--prominence", type=float, default=30)
    args = parser.parse_args()

    for path in sorted(args.directory.glob("*.json")):
        if args.plot and path.stem != args.plot:
            continue
        recording = json.loads(path.read_text(encoding="utf-8"))
        t, a = elbow_series(recording)
        s = smooth(t, a)
        valleys = count_valleys(s, args.prominence)
        print(f"{path.stem}\t{len(valleys)}")
        if args.write and recording.get("expectedCount") is None:
            recording["expectedCount"] = len(valleys)
            recording["tags"]["label"] = "offline"
            path.write_text(json.dumps(recording, ensure_ascii=False), encoding="utf-8")
        if args.plot:
            import matplotlib

            matplotlib.use("Agg")
            import matplotlib.pyplot as plt

            plt.figure(figsize=(14, 3))
            plt.plot(t, a, lw=0.6, alpha=0.5, label="thô")
            plt.plot(t, s, lw=1, label="mượt")
            plt.plot(t[valleys], s[valleys], "rv", label=f"đáy ({len(valleys)})")
            plt.legend(fontsize=7)
            out = pathlib.Path(f"{args.plot}.png")
            plt.tight_layout()
            plt.savefig(out, dpi=70)
            print(f"→ {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
