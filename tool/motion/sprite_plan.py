"""Kế hoạch khung sprite cho một boss có lớp chuyển động (phòng Chuyển động →
Render & xuất): mỗi hoạt ảnh bao nhiêu khung, tại tiến độ nào.

Đòn có mốc `impact` (biên đạo `events`) lấy khung DÀY quanh mốc chạm, THƯA trong
đoạn giữ thế (`hold_from`–`hold_to`): cùng 20 khung, pha ra đòn 0,5–0,65 được ~6
khung thay vì ~3 (trước phải `snap` để không hiện hai cây chuỳ chồng nhau). Tiến độ
từng khung ghi vào atlas (`phases`) — SpriteAtlas.draw tra theo đó.
"""
import json
import os

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FOCUS = (-0.12, 0.08)  # quanh mốc chạm (tiến độ) lấy khung dày
GAIN, HOLD_GAIN = 3.0, 0.5


def phases(n, impact=None, hold=None, focus=FOCUS, gain=GAIN, hold_gain=HOLD_GAIN, grid=4000):
    """[n] tiến độ 0…1 (gồm hai đầu); không có [impact] thì chia đều."""
    if impact is None:
        return [round(k / (n - 1), 4) for k in range(n)]
    x = np.linspace(0.0, 1.0, grid + 1)
    w = np.ones_like(x)
    w[(x >= impact + focus[0]) & (x <= impact + focus[1])] = gain
    if hold:
        w[(x >= hold[0]) & (x <= hold[1])] = hold_gain
    c = np.concatenate([[0.0], np.cumsum((w[1:] + w[:-1]) / 2)])
    c /= c[-1]
    p = np.interp(np.linspace(0.0, 1.0, n), c, x)
    k = int(np.argmin(np.abs(p[1:-1] - impact))) + 1  # có đúng một khung tại mốc chạm
    p[k] = impact
    return [round(float(v), 4) for v in p]


def plan(motion, choreo_id, counts, idle="idle"):
    """{hoạt ảnh: số khung} → ({hoạt ảnh: [setup()]}, {hoạt ảnh: [tiến độ]}).
    [idle] lặp: t = k/n (không gồm 1). Đòn khác: motion.pose(move=, phase=)."""
    spec = json.load(open(os.path.join(ROOT, "tool", "motion", "choreo", f"{choreo_id}.json"), encoding="utf-8"))
    anims, table = {}, {}
    for anim, n in counts.items():
        if anim == idle:
            anims[anim] = [lambda t=k / n: motion.pose(t=t) for k in range(n)]
            continue
        ev = (spec["attacks"].get(anim) or {}).get("events") or {}
        hold = (ev["hold_from"], ev["hold_to"]) if "hold_from" in ev else None
        ps = phases(n, ev.get("impact"), hold)
        anims[anim] = [lambda p=p, a=anim: motion.pose(move=a, phase=p) for p in ps]
        if ev.get("impact") is not None:
            table[anim] = ps
    return anims, table
