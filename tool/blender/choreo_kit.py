"""Biên đạo theo khoá cho quái Tripo (bản gọn của tool/motion/choreo.py nhánh
chương Nhật): mỗi động tác là các khoá thưa (t, {kênh: giá trị}) quanh dáng
chờ [ready]; nội suy cubic đơn điệu Fritsch–Carlson (mượt, không vọt quá
khoá — vọt thì vũ khí xuyên đất); [lag] trễ từng kênh để lực đi theo chuỗi
hông → thân → tay → vũ khí → đầu. Khoá lặp lại cùng giá trị = giữ thế.
"""

import math


def _monotone(xs, ys):
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
            k = 3 / math.sqrt(s)
            m[i], m[i + 1] = k * a * d[i], k * b * d[i]
    return m


class Track:
    def __init__(self, keys):
        keys = sorted(keys)
        self.xs = [k[0] for k in keys]
        self.ys = [k[1] for k in keys]
        self.ms = _monotone(self.xs, self.ys)

    def at(self, t):
        xs, ys, ms = self.xs, self.ys, self.ms
        if t <= xs[0]:
            return ys[0]
        if t >= xs[-1]:
            return ys[-1]
        i = 0
        while xs[i + 1] <= t:
            i += 1
        h = xs[i + 1] - xs[i]
        u = (t - xs[i]) / h
        h00 = (1 + 2 * u) * (1 - u) ** 2
        h10 = u * (1 - u) ** 2
        h01 = u * u * (3 - 2 * u)
        h11 = u * u * (u - 1)
        return h00 * ys[i] + h10 * h * ms[i] + h01 * ys[i + 1] + h11 * h * ms[i + 1]


class Move:
    """Một động tác: [keys] = [(t, {kênh: giá trị})], kênh thiếu ở t = 0 / 1
    lấy theo [ready] (động tác bắt đầu và kết thúc ở dáng chờ, trừ khi khoá
    t = 0 / 1 ghi khác)."""

    def __init__(self, ready, keys, lag=None):
        self.lag = lag or {}
        chans = {c: [] for c in ready}
        for t, v in keys:
            for c, x in v.items():
                chans.setdefault(c, []).append((t, x))
        self.tracks = {}
        for c, ks in chans.items():
            r = ready.get(c, 0.0)
            if not any(k[0] <= 0 for k in ks):
                ks = [(0.0, r)] + ks
            if not any(k[0] >= 1 for k in ks):
                ks = ks + [(1.0, r)]
            self.tracks[c] = Track(ks)

    def at(self, t):
        return {c: tr.at(max(0.0, t - self.lag.get(c, 0.0))) for c, tr in self.tracks.items()}
