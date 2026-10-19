"""Khung xương chuẩn của thư viện võ học: 24 điểm (khớp + đầu ngón, ngón cái), mét, trục Z lên, mặt
nhìn về +X (về phía đối thủ — sân khấu game: boss đứng phải, nhìn sang trái
thì lật X khi đưa vào Blender).

Mọi nguồn (BVH CMU, MediaPipe từ video) quy về đây; mô hình và bộ chuyển
sang boss chỉ làm việc với dạng này.

    from skeleton import from_bvh, J
    m = from_bvh("art_src/mocap/_cache/135_07.bvh")   # Motion
    m.pos[:, J["wrist_r"]]                             # (khung, 3)
"""

import numpy as np

JOINTS = ("pelvis", "spine", "chest", "neck", "head",
          "shoulder_l", "elbow_l", "wrist_l", "shoulder_r", "elbow_r", "wrist_r",
          "hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r",
          "toe_l", "toe_r", "head_top", "hand_tip_l", "hand_tip_r", "thumb_l", "thumb_r")
J = {n: i for i, n in enumerate(JOINTS)}
BONES = [("pelvis", "spine"), ("spine", "chest"), ("chest", "neck"), ("neck", "head"), ("head", "head_top"),
         ("chest", "shoulder_l"), ("shoulder_l", "elbow_l"), ("elbow_l", "wrist_l"),
         ("chest", "shoulder_r"), ("shoulder_r", "elbow_r"), ("elbow_r", "wrist_r"),
         ("pelvis", "hip_l"), ("hip_l", "knee_l"), ("knee_l", "ankle_l"), ("ankle_l", "toe_l"),
         ("pelvis", "hip_r"), ("hip_r", "knee_r"), ("knee_r", "ankle_r"), ("ankle_r", "toe_r"),
         ("wrist_l", "hand_tip_l"), ("wrist_r", "hand_tip_r")]

CMU = {"pelvis": "Hips", "spine": "Spine", "chest": "Spine1", "neck": "Neck1", "head": "Head",
       "head_top": "Head_end",
       "shoulder_l": "LeftArm", "elbow_l": "LeftForeArm", "wrist_l": "LeftHand",
       "shoulder_r": "RightArm", "elbow_r": "RightForeArm", "wrist_r": "RightHand",
       "hip_l": "LeftUpLeg", "knee_l": "LeftLeg", "ankle_l": "LeftFoot", "toe_l": "LeftToeBase",
       "hip_r": "RightUpLeg", "knee_r": "RightLeg", "ankle_r": "RightFoot", "toe_r": "RightToeBase",
       # Bàn tay: gốc ngón (hướng lòng bàn tay) + ngón cái (xoay cổ tay quanh cẳng tay).
       "hand_tip_l": "LeftHandIndex1", "hand_tip_r": "RightHandIndex1", "thumb_l": "LThumb_end", "thumb_r": "RThumb_end"}


class Motion:
    """pos: (khung, 24, 3) mét, Z lên; fps; meta: nguồn, nhãn."""

    def __init__(self, pos, fps, meta=None):
        self.pos, self.fps, self.meta = pos, fps, dict(meta or {})

    def __len__(self):
        return len(self.pos)

    def joint(self, name):
        return self.pos[:, J[name]]

    def slice(self, a, b):
        return Motion(self.pos[a:b].copy(), self.fps, self.meta)

    def resample(self, fps):
        n = len(self.pos)
        t_old = np.arange(n) / self.fps
        t_new = np.arange(0, t_old[-1] + 1e-9, 1.0 / fps)
        flat = self.pos.reshape(n, -1)
        out = np.stack([np.interp(t_new, t_old, flat[:, k]) for k in range(flat.shape[1])], axis=1)
        return Motion(out.reshape(len(t_new), -1, 3), fps, self.meta)

    def smooth(self, window_s=0.1, order=3):
        from scipy.signal import savgol_filter  # Blender không có scipy: chỉ dùng ngoài Blender

        w = max(order + 2, int(round(window_s * self.fps)) | 1)
        if len(self.pos) <= w:
            return self
        return Motion(savgol_filter(self.pos, w, order, axis=0), self.fps, self.meta)

    def height(self):
        """Chiều cao đứng (đỉnh đầu − mắt cá thấp nhất), trung vị theo khung."""
        top = self.pos[:, J["head_top"], 2]
        low = np.minimum(self.pos[:, J["ankle_l"], 2], self.pos[:, J["ankle_r"], 2])
        return float(np.median(top - low)) + 0.08  # + mắt cá → gót

    def save(self, path):
        np.savez_compressed(path, pos=self.pos.astype(np.float32), fps=self.fps,
                            meta=np.array(repr(self.meta)))

    @staticmethod
    def load(path):
        import ast
        d = np.load(path)
        return Motion(d["pos"].astype(np.float64), float(d["fps"]), ast.literal_eval(str(d["meta"])))


def facing(pos):
    """Hướng mặt (khung, 2) trong mặt phẳng đất: vuông góc trục hông, chiều
    theo vai + hông (hai trục cùng gợi ý, bớt nhiễu khi thân vặn)."""
    across = (pos[:, J["hip_l"]] - pos[:, J["hip_r"]]) + (pos[:, J["shoulder_l"]] - pos[:, J["shoulder_r"]])
    f = np.stack([across[:, 1], -across[:, 0]], axis=1)  # xoay −90° quanh Z: trái → trước
    return f / np.maximum(1e-9, np.linalg.norm(f, axis=1, keepdims=True))


def canonical(pos, fps, meta=None, height=None):
    """Chuẩn hoá: mét theo [height] (None = giữ), gốc tại hông khung đầu chiếu
    xuống đất, mặt khung đầu nhìn +X, chân thấp nhất chạm Z = 0."""
    m = Motion(pos, fps, meta)
    if height:
        pos = pos * ((height - 0.08) / (m.height() - 0.08))
    f0 = facing(pos[: max(1, int(fps * 0.25))]).mean(axis=0)
    a = np.arctan2(f0[1], f0[0])
    c, s = np.cos(-a), np.sin(-a)
    R = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
    pos = pos @ R.T
    o = pos[0, J["pelvis"]].copy()
    o[2] = 0
    pos = pos - o
    low = np.minimum(pos[:, J["toe_l"], 2], pos[:, J["toe_r"], 2])
    low = np.minimum(low, np.minimum(pos[:, J["ankle_l"], 2], pos[:, J["ankle_r"], 2]) - 0.06)
    pos[:, :, 2] -= np.percentile(low, 2)
    return Motion(pos, fps, meta)


def from_bvh(path, height=1.75, meta=None):
    from bvh import load
    clip = load(path)
    idx = [clip.index(CMU[n]) for n in JOINTS]
    p = clip.pos[:, idx]
    # BVH CMU: Y lên, mặt nhìn +Z → đổi sang Z lên (X, Y, Z) = (x, −z, y).
    p = np.stack([p[..., 0], -p[..., 2], p[..., 1]], axis=-1)
    return canonical(p, clip.fps, meta, height=height)


def from_c3d(path, height=1.75, meta=None):
    """C3D Plug-in Gait (bộ karate Kyokushin, CC0): dùng tâm khớp mô hình đã
    tính sẵn (LHJC, LKJC, LAJC, LSJC, LEJC, LWJC…) + marker gốc ngón tay (FIN),
    mũi chân (TOE), cổ tay phía ngón cái (WRA) — chính xác hơn tự suy từ marker."""
    import ezc3d

    c = ezc3d.c3d(path)
    # Nhãn có thể kèm tiền tố tên người ("B0367:LASI"); khiên tập ("Tarcza:…") bỏ qua.
    labels = [n.split(":")[-1] if not n.startswith("Tarcza") else n for n in c["parameters"]["POINT"]["LABELS"]["value"]]
    pts = c["data"]["points"][:3].transpose(2, 1, 0) / 1000.0  # (khung, điểm, 3) mét
    fps = float(c["parameters"]["POINT"]["RATE"]["value"][0])

    def g(n):
        return pts[:, labels.index(n)]

    def unit(v):
        return v / np.maximum(1e-9, np.linalg.norm(v, axis=-1, keepdims=True))

    def perp(v, axis):
        a = unit(axis)
        return unit(v - a * np.sum(v * a, axis=-1, keepdims=True))

    if "LHJC" in labels:  # tâm khớp mô hình Plug-in Gait đã tính sẵn
        jc = {k: g(k) for k in ("LHJC", "RHJC", "LKJC", "RKJC", "LAJC", "RAJC", "LSJC", "RSJC",
                                "LEJC", "REJC", "LWJC", "RWJC", "TRXO", "HEDO")}
    else:
        # Chỉ có marker thô: tự suy tâm khớp (Bell 1990 cho hông; lệch vào trong
        # nửa bề rộng khớp cho gối / cổ chân / khuỷu; cổ tay = giữa hai marker).
        asi_l, asi_r = g("LASI"), g("RASI")
        mid_asi = (asi_l + asi_r) / 2
        mid_psi = (g("LPSI") + g("RPSI")) / 2
        W = np.linalg.norm(asi_l - asi_r, axis=1, keepdims=True)
        lat = unit(asi_l - asi_r)
        ant = perp(mid_asi - mid_psi, lat)
        upv = np.cross(lat, ant)
        jc = {}
        for S_, sg in (("L", 1), ("R", -1)):
            jc[f"{S_}HJC"] = mid_asi + W * (0.36 * sg * lat - 0.19 * ant - 0.30 * upv)
        for S_, O_ in (("L", "R"), ("R", "L")):
            hj = jc[f"{S_}HJC"]
            med = jc[f"{O_}HJC"] - hj
            kne, ank = g(f"{S_}KNE"), g(f"{S_}ANK")
            jc[f"{S_}KJC"] = kne + perp(med, hj - kne) * 0.05
            jc[f"{S_}AJC"] = ank + perp(med, kne - ank) * 0.035
            sho, elb = g(f"{S_}SHO"), g(f"{S_}ELB")
            wr = (g(f"{S_}WRA") + g(f"{S_}WRB")) / 2
            jc[f"{S_}SJC"] = sho + unit(elb - sho) * 0.05
            jc[f"{S_}EJC"] = elb + perp(med, sho - elb) * 0.035
            jc[f"{S_}WJC"] = wr
        jc["TRXO"] = (g("C7") + g("CLAV")) / 2
        jc["HEDO"] = (g("LFHD") + g("RFHD") + g("LBHD") + g("RBHD")) / 4

    hip_l, hip_r = jc["LHJC"], jc["RHJC"]
    pel = (hip_l + hip_r) / 2
    neck = jc["TRXO"]
    head = jc["HEDO"]
    up = neck - pel
    up /= np.maximum(1e-9, np.linalg.norm(up, axis=1, keepdims=True))
    hu = head - neck
    hu /= np.maximum(1e-9, np.linalg.norm(hu, axis=1, keepdims=True))
    out = {
        "pelvis": pel, "spine": pel + (neck - pel) * 0.33, "chest": pel + (neck - pel) * 0.66, "neck": neck,
        "head": neck + (head - neck) * 0.5, "head_top": head + hu * 0.13,
        "hip_l": hip_l, "hip_r": hip_r, "knee_l": jc["LKJC"], "knee_r": jc["RKJC"],
        "ankle_l": jc["LAJC"], "ankle_r": jc["RAJC"], "toe_l": g("LTOE"), "toe_r": g("RTOE"),
        "shoulder_l": jc["LSJC"], "shoulder_r": jc["RSJC"], "elbow_l": jc["LEJC"], "elbow_r": jc["REJC"],
        "wrist_l": jc["LWJC"], "wrist_r": jc["RWJC"], "hand_tip_l": g("LFIN"), "hand_tip_r": g("RFIN"),
    }
    for s, S_ in (("l", "L"), ("r", "R")):
        rad = g(f"{S_}WRA") - g(f"{S_}WRB")  # cổ tay: ngón cái ← ngón út
        rad /= np.maximum(1e-9, np.linalg.norm(rad, axis=1, keepdims=True))
        out[f"thumb_{s}"] = out[f"wrist_{s}"] + rad * 0.05 + (out[f"hand_tip_{s}"] - out[f"wrist_{s}"]) * 0.4
    p = np.stack([out[n] for n in JOINTS], axis=1)
    # Marker mất dấu (0,0,0) → nội suy theo thời gian.
    bad = np.all(np.abs(p) < 1e-6, axis=2) | ~np.isfinite(p).all(axis=2)
    for j in range(p.shape[1]):
        if bad[:, j].any() and (~bad[:, j]).sum() > 2:
            t = np.arange(len(p))
            for k in range(3):
                p[bad[:, j], j, k] = np.interp(t[bad[:, j]], t[~bad[:, j]], p[~bad[:, j], j, k])
    return canonical(p, fps, meta, height=height)
