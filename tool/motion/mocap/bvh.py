"""Đọc BVH → vị trí khớp theo thời gian (numpy, không cần Blender).

    from bvh import load
    clip = load("art_src/mocap/_cache/135_07.bvh")
    clip.pos        # (khung, khớp, 3) — đơn vị file, trục Y lên như BVH
    clip.names      # tên khớp theo thứ tự cột
    clip.fps
"""

import numpy as np
from scipy.spatial.transform import Rotation


class Clip:
    def __init__(self, names, parents, offsets, pos, fps):
        self.names, self.parents, self.offsets = names, parents, offsets
        self.pos, self.fps = pos, fps

    def index(self, name):
        return self.names.index(name)


def _parse(text):
    tok = text.split()
    i = 0
    names, parents, offsets, channels, ends = [], [], [], [], []
    stack = []
    while tok[i] != "MOTION":
        t = tok[i]
        if t in ("ROOT", "JOINT"):
            names.append(tok[i + 1])
            parents.append(stack[-1] if stack else -1)
            channels.append([])
            offsets.append(None)
            stack.append(len(names) - 1)
            i += 2
        elif t == "End":
            # Điểm cuối (đầu ngón, đỉnh đầu): khớp giả không có kênh.
            names.append(names[stack[-1]] + "_end")
            parents.append(stack[-1])
            channels.append([])
            offsets.append(None)
            ends.append(len(names) - 1)
            stack.append(len(names) - 1)
            i += 2
        elif t == "OFFSET":
            offsets[stack[-1]] = [float(tok[i + 1]), float(tok[i + 2]), float(tok[i + 3])]
            i += 4
        elif t == "CHANNELS":
            n = int(tok[i + 1])
            channels[stack[-1]] = tok[i + 2:i + 2 + n]
            i += 2 + n
        elif t == "}":
            stack.pop()
            i += 1
        else:
            i += 1
    i += 1
    assert tok[i] == "Frames:"
    nf = int(tok[i + 1])
    assert tok[i + 2] == "Frame" and tok[i + 3] == "Time:"
    dt = float(tok[i + 4])
    data = np.array(tok[i + 5:], dtype=np.float64)
    nch = sum(len(c) for c in channels)
    data = data[: nf * nch].reshape(nf, nch)
    return names, parents, np.array(offsets), channels, data, 1.0 / dt


def load(path):
    with open(path, encoding="latin1") as f:
        names, parents, offsets, channels, data, fps = _parse(f.read())
    nf, nj = data.shape[0], len(names)
    pos = np.zeros((nf, nj, 3))
    rot = [None] * nj
    col = 0
    for j in range(nj):
        ch = channels[j]
        local_t = np.tile(offsets[j], (nf, 1))
        r = None
        if ch:
            vals = data[:, col:col + len(ch)]
            col += len(ch)
            rot_axes = "".join(c[0] for c in ch if c.endswith("rotation"))
            rot_idx = [k for k, c in enumerate(ch) if c.endswith("rotation")]
            for k, c in enumerate(ch):
                if c.endswith("position"):
                    local_t[:, "XYZ".index(c[0])] = vals[:, k]
            if rot_axes:
                # BVH: kênh xoay ghi theo thứ tự áp dụng nội tại (intrinsic).
                r = Rotation.from_euler(rot_axes.upper(), vals[:, rot_idx], degrees=True)
        p = parents[j]
        if p < 0:
            pos[:, j] = local_t
            rot[j] = r if r is not None else Rotation.identity(nf)
        else:
            pos[:, j] = pos[:, p] + rot[p].apply(local_t)
            rot[j] = rot[p] * r if r is not None else rot[p]
    return Clip(names, parents, offsets, pos, fps)
