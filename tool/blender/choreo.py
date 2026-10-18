"""Biên đạo đòn đánh theo khoá (rules/dohoa.md mục 14).

Một file JSON mỗi boss (tool/blender/choreo/<tên>.json) là nguồn duy nhất cho
cả script Blender (sprite) lẫn bản vector Flutter (tool/gen_choreo.py sinh
lib/art/bosses/choreo_data.dart) — hai bản cùng nhịp, cùng tư thế khoá.

- Mỗi đòn: danh sách khoá {t, v: {kênh: giá trị}}; khoá có thể thiếu kênh.
  Tư thế "ready" tự thêm ở t = 0 và t = 1 (trừ "hold_end": đòn gục giữ cuối).
- Nội suy cubic đơn điệu (Fritsch–Carlson): mượt nhưng KHÔNG vọt quá khoá —
  vọt quá thì chuỳ xuyên đất, tay gập ngược.
- `lag` = độ trễ từng kênh (theo tiến độ): chuỗi lực hông → thân → tay → vũ
  khí; mút cánh/tua trễ nhất (chuyển động theo sau, follow-through).
"""

import bisect
import json
import os

HERE = os.path.join(os.path.dirname(__file__), "choreo")


def _monotone(xs, ys):
    """Hệ số tiếp tuyến Fritsch–Carlson cho dãy điểm (xs tăng)."""
    n = len(xs)
    if n < 2:
        return [0.0] * n
    d = [(ys[i + 1] - ys[i]) / max(1e-9, xs[i + 1] - xs[i]) for i in range(n - 1)]
    m = [d[0]] + [(d[i - 1] + d[i]) / 2 if d[i - 1] * d[i] > 0 else 0.0 for i in range(1, n - 1)] + [d[-1]]
    for i in range(n - 1):
        if d[i] == 0:
            m[i] = m[i + 1] = 0.0
            continue
        a, b = m[i] / d[i], m[i + 1] / d[i]
        s = a * a + b * b
        if s > 9:
            k = 3 / s ** 0.5
            m[i], m[i + 1] = k * a * d[i], k * b * d[i]
    return m


class Track:
    def __init__(self, keys):
        keys = sorted(keys)
        self.xs = [k[0] for k in keys]
        self.ys = [k[1] for k in keys]
        self.ms = _monotone(self.xs, self.ys)

    def __call__(self, t):
        xs, ys, ms = self.xs, self.ys, self.ms
        if t <= xs[0]:
            return ys[0]
        if t >= xs[-1]:
            return ys[-1]
        i = bisect.bisect_right(xs, t) - 1
        h = xs[i + 1] - xs[i]
        u = (t - xs[i]) / h
        h00 = (1 + 2 * u) * (1 - u) ** 2
        h10 = u * (1 - u) ** 2
        h01 = u * u * (3 - 2 * u)
        h11 = u * u * (u - 1)
        return h00 * ys[i] + h10 * h * ms[i] + h01 * ys[i + 1] + h11 * h * ms[i + 1]


class Move:
    """Một đòn (hoặc chuỗi gục): mẫu tư thế tại tiến độ t → {kênh: giá trị}."""

    def __init__(self, ready, lag, spec):
        self.ready = ready
        self.lag = lag
        self.events = spec.get("events", {})
        chans = {c: [] for c in ready}
        for k in spec["keys"]:
            for c, v in k["v"].items():
                chans.setdefault(c, []).append((k["t"], v))
        self.tracks = {}
        for c, ks in chans.items():
            r = ready.get(c, 0.0)
            ks = [(0.0, r)] + ks
            if not spec.get("hold_end") and not any(t >= 1.0 for t, _ in ks):
                ks.append((1.0, r))
            self.tracks[c] = Track(ks)

    def __call__(self, t):
        return {c: tr(max(0.0, t - self.lag.get(c, 0.0))) for c, tr in self.tracks.items()}


class Choreo:
    def __init__(self, name):
        with open(os.path.join(HERE, f"{name}.json"), encoding="utf-8") as f:
            data = json.load(f)
        self.ready = data["ready"]
        self.lag = data.get("lag", {})
        self.moves = {k: Move(self.ready, self.lag, v) for k, v in data["attacks"].items()}

    def __getitem__(self, move):
        return self.moves[move]
