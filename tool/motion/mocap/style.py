"""Nắn nhịp đòn mocap vào nhịp sân khấu (rules/dohoa/chuyendong.md).

Sân khấu chạy đòn theo tiến độ 0–1 (lấy đà → giữ báo hiệu → chạm → thu), còn
mocap có nhịp riêng của người diễn. Ở đây ánh xạ tiến độ sân khấu → khung
mocap bằng đường cong đơn điệu qua các mốc:

    0            → trước lấy đà (đứng thế)
    hold_from    → khung "nạp" (chi rút về sau xa nhất trước khi ra đòn)
    hold_to      → nạp + chút (giữ báo hiệu: gần như đứng hình, căng)
    impact       → khung chạm (duỗi xa nhất)
    impact + kime→ chạm + chút (dừng lực kiểu karate / Shadow Fight)
    1            → thu về xong

Đoạn nạp → chạm bị nén (ra đòn bật nhanh), đoạn lấy đà và thu được giãn —
"chậm–nhanh–chậm" của hoạt hình đối kháng.
"""

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))  # tool/motion: choreo.py
from choreo import Track  # noqa: E402  (nội suy cubic đơn điệu, không vọt)

sys.path.insert(0, HERE)
from skeleton import J  # noqa: E402

LIMB_ROOT = {"wrist_r": "shoulder_r", "wrist_l": "shoulder_l", "ankle_r": "hip_r", "ankle_l": "hip_l"}


def cock_frame(seg):
    """Khung nạp: chi gần gốc nhất (co về) giữa lấy đà và chạm."""
    m = seg.meta
    e, r = J[m["eff"]], J[LIMB_ROOT[m["eff"]]]
    a, c = m["start"], m["contact"]
    if c - a < 3:
        return a
    ext = np.linalg.norm(seg.pos[a:c, e] - seg.pos[a:c, r], axis=1)
    # Lấy khung co nhất trong 85% đầu đoạn (cuối đoạn là lúc bật ra).
    k = int(np.argmin(ext[: max(1, int(0.85 * len(ext)))]))
    return a + k


def stage_track(seg, impact=0.6, hold=(0.36, 0.46), kime=0.05, settle=0.94):
    """Track tiến độ sân khấu → chỉ số khung (float) trong [seg]."""
    m = seg.meta
    n = len(seg) - 1
    a, c, e = m["start"], m["contact"], m["end"]
    k = cock_frame(seg)
    # Nạp → chạm: thời gian thật của cú bật (giữ nguyên tốc độ mocap, không làm chậm).
    keys = [(0.0, 0.0),
            (hold[0], float(k)),
            (hold[1], float(k) + 0.25 * (c - k) * 0.15),
            (impact, float(c)),
            (min(impact + kime, settle - 0.05), float(c) + 0.25 * max(1, e - c) * 0.3),
            (settle, float(e)),
            (1.0, float(n))]
    # Đảm bảo tăng ngặt (khung có thể trùng khi đòn quá ngắn).
    out = []
    for t, f in keys:
        if out and f <= out[-1][1]:
            f = out[-1][1] + 0.01
        out.append((t, min(float(n), f)))
    return Track(out)


def sample(seg, track, phase):
    """Tư thế (24, 3) tại tiến độ sân khấu [phase] — nội suy tuyến tính giữa khung."""
    f = track(phase)
    i = int(np.floor(f))
    u = f - i
    i = max(0, min(len(seg) - 1, i))
    j = min(len(seg) - 1, i + 1)
    return seg.pos[i] * (1 - u) + seg.pos[j] * u
