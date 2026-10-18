"""Lái rig boss bằng chuyển động võ học (tool/mocap; rules/dohoa.md mục 16).

Retarget "tuyệt đối": không phụ thuộc quy ước trục xương của rig (MPFB,
Tripo… đều dùng được, miễn tên xương kiểu Unreal):

- Hông / ngực / đầu: khung xoay dựng từ điểm mocap (trục hông, trục vai,
  hướng cột sống) ánh xạ lên khung tương ứng dựng từ đầu xương của rig ở
  dáng nghỉ → xoay thế giới; độ vặn chia dần spine_01 → spine_03.
- Tay, chân: IK hai đốt với pole đặt đúng phía khuỷu / gối của mocap (không
  xoắn, không bẻ ngược); chiều dài chi co giãn theo tỉ lệ rig.
- Cổ tay: hướng đốt ngón + ngón cái, giới hạn gập; bàn chân: khoá khi chạm
  đất (không trượt), nhón gót thì ngón chân (ball) gập bám đất.
- Ngón tay: siết nắm đấm theo pha đòn, trễ một nhịp (do biên đạo gọi).

Kết quả mỗi khung là một bộ "đích" (Targets) — hoà được với đích đọc từ dáng
hiện có của boss (dáng chờ theo biên đạo) để vào/ra đòn liền mạch.
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "mocap"))
from skeleton import J, Motion  # noqa: E402

LIB = os.path.join(os.path.dirname(os.path.dirname(HERE)), "art_src", "mocap", "_cache", "strikes")
SPINE = (("spine_01", 0.3), ("spine_02", 0.65), ("spine_03", 1.0))
SIDES = "lr"


def V(a):
    return Vector((float(a[0]), float(a[1]), float(a[2])))


def frame_from(across, up):
    """Khung trực chuẩn: cột x = across (vuông góc up), y = up, z = x × y."""
    u = up.normalized()
    x = (across - u * across.dot(u)).normalized()
    return Matrix((x, u, x.cross(u))).transposed()


def load_strike(sid):
    return Motion.load(os.path.join(LIB, f"{sid}.npz"))


class RigInfo:
    """Số đo rig ở dáng nghỉ (thế giới) để ánh xạ tỉ lệ."""

    def __init__(self, rig):
        self.rig = rig
        mw = rig.matrix_world
        self.A = mw.to_3x3().normalized()          # xoay armature → thế giới
        self.Ai = self.A.inverted()
        bl = rig.data.bones
        self.head = {b.name: mw @ b.head_local for b in bl}
        self.tail = {b.name: mw @ b.tail_local for b in bl}
        self.rest_rot = {b.name: (self.A @ b.matrix_local.to_3x3()).normalized() for b in bl}
        h = self.head
        self.leg = sum((h[a] - h[b]).length for a, b in (("thigh_l", "calf_l"), ("calf_l", "foot_l")))
        self.arm = sum((h[a] - h[b]).length for a, b in (("upperarm_l", "lowerarm_l"), ("lowerarm_l", "hand_l")))
        self.f_pelvis = frame_from(h["thigh_l"] - h["thigh_r"], h["spine_01"] - h["pelvis"])
        self.f_chest = frame_from(h["upperarm_l"] - h["upperarm_r"], h["neck_01"] - h["spine_03"])
        self.f_head = frame_from(h["upperarm_l"] - h["upperarm_r"], self.tail["head"] - h["neck_01"])
        self.foot = {}
        for s in SIDES:
            fwd = (h[f"ball_{s}"] - h[f"foot_{s}"])
            fwd.z = 0
            self.foot[s] = frame_from(Vector((0, 0, 1)).cross(fwd.normalized()), fwd)
        self.hip_off = {s: self.f_pelvis.transposed() @ (h[f"thigh_{s}"] - h["pelvis"]) for s in SIDES}
        self.ground = min(h["ball_l"].z, h["ball_r"].z, h["foot_l"].z, h["foot_r"].z)
        self.ankle_h = min(h["foot_l"].z, h["foot_r"].z) - self.ground


class MocapDrive:
    """Đích từng khung cho một đoạn mocap đã chuẩn hoá (đòn chạy về +X).

    [basis] = (trước mặt boss, bên trái boss, lên) thế giới; mocap +X → trước mặt.
    [origin] = điểm đất dưới hông boss ở dáng chờ.
    """

    def __init__(self, info, motion, basis, origin, lock_feet=True, travel=0.35, pelvis_z=None, yaw_keep=1.0):
        self.info, self.m = info, motion
        self.yaw_keep = yaw_keep
        fwd, left, up = basis
        self.B = Matrix((fwd, left, up)).transposed()
        self.origin = origin.copy()
        self.origin.z = info.ground
        p = motion.pos
        legm = float(np.median(np.linalg.norm(p[:, J["hip_l"]] - p[:, J["knee_l"]], axis=1)
                               + np.linalg.norm(p[:, J["knee_l"]] - p[:, J["ankle_l"]], axis=1)))
        armm = float(np.median(np.linalg.norm(p[:, J["shoulder_l"]] - p[:, J["elbow_l"]], axis=1)
                               + np.linalg.norm(p[:, J["elbow_l"]] - p[:, J["wrist_l"]], axis=1)))
        self.k_leg = info.leg / legm
        self.k_arm = info.arm / armm
        # Đứng thế: hông cao bao nhiêu so với mắt cá (mocap) ↔ rig.
        # Trục đứng neo đất ↔ đất (Z mocap = 0 là mặt sàn) — neo theo hông dáng
        # chờ thì khi hạ tấn cả người bị đẩy lên, chân IK với không tới đất.
        self.z_off = 0.0
        # Đi xa quá thì sprite trượt khỏi chỗ đứng: kẹp quãng tiến/lùi của hông.
        xy = p[:, J["pelvis"], :2] - p[0, J["pelvis"], :2]
        self.root_xy = xy * self.k_leg
        span = np.linalg.norm(self.root_xy, axis=1).max()
        lim = travel * (info.leg / 0.9)
        if span > lim:
            self.root_xy *= lim / span
        self.contacts = self._contacts() if lock_feet else None

    # ------------------------------------------------------------ mocap → thế giới
    def w(self, v):
        return self.B @ V(v)

    def _contacts(self):
        """Chân chạm đất: mắt cá thấp + gần đứng yên. Trả về {s: mảng bool}."""
        p, fps = self.m.pos, self.m.fps
        out = {}
        for s in SIDES:
            a = p[:, J[f"ankle_{s}"]]
            sp = np.linalg.norm(np.gradient(a, axis=0) * fps, axis=1)
            low = a[:, 2] < np.percentile(a[:, 2], 10) + 0.05
            c = low & (sp < 0.45)
            # Lấp lỗ ngắn (rung) ≤ 3 khung.
            for i in range(1, len(c) - 1):
                if not c[i] and c[i - 1] and c[min(len(c) - 1, i + 2)]:
                    c[i] = True
            out[s] = c
        return out

    def rot_pelvis(self, q):
        f = frame_from(self.w(q[J["hip_l"]] - q[J["hip_r"]]), self.w(q[J["spine"]] - q[J["pelvis"]]))
        return (f @ self.info.f_pelvis.transposed()).to_quaternion()

    def rot_chest(self, q):
        f = frame_from(self.w(q[J["shoulder_l"]] - q[J["shoulder_r"]]), self.w(q[J["neck"]] - q[J["chest"]]))
        return (f @ self.info.f_chest.transposed()).to_quaternion()

    def rot_head(self, q):
        f = frame_from(self.w(q[J["shoulder_l"]] - q[J["shoulder_r"]]), self.w(q[J["head_top"]] - q[J["neck"]]))
        return (f @ self.info.f_head.transposed()).to_quaternion()

    def targets(self, q, frame=None):
        """Đích cho tư thế mocap q (24, 3). [frame]: chỉ số khung (để khoá chân)."""
        info = self.info
        T = {"rot": {}, "ik": {}, "hand": {}, "foot": {}}
        rp, rc, rh = self.rot_pelvis(q), self.rot_chest(q), self.rot_head(q)
        if self.yaw_keep < 1.0:
            # Sân khấu nhìn ngang: đòn tay sau karate "mở hông" xoay thân ra máy quay
            # — chỉ giữ một phần độ xoay quanh trục đứng (biên đạo `twist` lo phần còn lại).
            up = Vector((0, 0, 1))
            fwd = self.B.col[0]

            def unyaw(r):
                f = r.to_matrix() @ fwd
                f2 = Vector((f.x, f.y, 0))
                if f2.length < 1e-6:
                    return r
                yaw = math.atan2(fwd.cross(f2).z, fwd.dot(f2))
                return Quaternion(up, -yaw * (1 - self.yaw_keep)) @ r
            rp, rc, rh = unyaw(rp), unyaw(rc), unyaw(rh)
        T["rot"]["pelvis"] = rp
        for b, u in SPINE:
            T["rot"][b] = rp.slerp(rc, u)
        T["rot"]["neck_01"] = rc.slerp(rh, 0.5)
        T["rot"]["head"] = rh
        # Hông: quãng tiến/lùi đã kẹp + độ cao theo tỉ lệ chân.
        i = frame if frame is not None else 0
        i = max(0, min(len(self.root_xy) - 1, i))
        rxy = self.root_xy[i]
        pel = self.origin + self.B @ Vector((rxy[0], rxy[1], 0)) + Vector((0, 0, q[J["pelvis"], 2] * self.k_leg + self.z_off))
        h = info.head
        R_c = rc.to_matrix()
        R_p = rp.to_matrix()
        # Chân với không tới (bước dài hơn chân rig): hạ hông thay vì nhấc chân.
        dz = 0.0
        for s in SIDES:
            an = pel + self.w(q[J[f"ankle_{s}"]] - q[J["pelvis"]]) * self.k_leg
            hip = pel + R_p @ (h[f"thigh_{s}"] - h["pelvis"])
            d = an - hip
            reach = 0.97 * info.leg
            if d.length > reach:
                horiz = Vector((d.x, d.y, 0)).length
                if horiz < reach:
                    dz = max(dz, -d.z - math.sqrt(reach * reach - horiz * horiz))
        pel = pel - Vector((0, 0, max(0.0, dz)))
        T["pelvis"] = pel
        an_fixed = {s: pel + Vector((0, 0, max(0.0, dz))) + self.w(q[J[f"ankle_{s}"]] - q[J["pelvis"]]) * self.k_leg
                    for s in SIDES}
        chest_base = pel + R_p @ (h["spine_01"] - h["pelvis"])
        for s in SIDES:
            sh = chest_base + R_c @ (h[f"upperarm_{s}"] - h["spine_01"])
            wr = sh + self.w(q[J[f"wrist_{s}"]] - q[J[f"shoulder_{s}"]]) * self.k_arm
            el = sh + self.w(q[J[f"elbow_{s}"]] - q[J[f"shoulder_{s}"]]) * self.k_arm
            mid = (sh + wr) / 2
            bend = el - mid
            if bend.length < 0.02 * info.arm:  # tay gần thẳng: khuỷu hướng xuống–ra sau
                bend = -self.B.col[2] * 0.5 - self.B.col[0] * 0.3
            T["ik"][f"arm_{s}"] = (wr, el + bend.normalized() * info.arm * 0.6)
            # Bàn tay: hướng ngón (đốt) + ngón cái → (hướng ngón, hướng lòng bàn tay).
            d = self.w(q[J[f"hand_tip_{s}"]] - q[J[f"wrist_{s}"]])
            t = self.w(q[J[f"thumb_{s}"]] - q[J[f"wrist_{s}"]])
            fa = (wr - el).normalized()
            if d.length < 1e-6:
                d = fa.copy()
            d.normalize()
            # Giới hạn gập cổ tay 55°: quá mức thì kéo về phía cẳng tay.
            ang = fa.angle(d)
            if ang > math.radians(55):
                d = fa.slerp(d, math.radians(55) / ang) if hasattr(fa, "slerp") else d
            n = d.cross(t) if s == "l" else t.cross(d)
            if n.length < 1e-6:
                n = -self.B.col[2]
            T["hand"][s] = (d, n.normalized())
            # Chân tính từ khung chậu (đất mocap ↔ đất rig); tính từ khớp hông rig
            # thì hông rig thấp/cao hơn người diễn bao nhiêu, chân hẫng bấy nhiêu.
            hip = pel + R_p @ (h[f"thigh_{s}"] - h["pelvis"])
            an = an_fixed[s]
            kn = pel + self.w(q[J[f"knee_{s}"]] - q[J["pelvis"]]) * self.k_leg
            # Gối: giữ hướng gập của mocap quanh đường hông rig → mắt cá.
            kn = hip + (kn - hip).normalized() * (kn - hip).length
            T["ik"][f"leg_{s}"] = [an, kn + (kn - (hip + an) / 2).normalized() * info.leg * 0.6]
            toe = self.w(q[J[f"toe_{s}"]] - q[J[f"ankle_{s}"]])
            T["foot"][s] = toe
        T["contact"] = {s: bool(self.contacts[s][i]) if self.contacts else False for s in SIDES}
        return T

    def lock(self, Ts):
        """Khoá chân chạm đất qua cả chuỗi đích (in-place): trong một lần chạm
        bàn chân giữ nguyên chỗ đặt, mắt cá ở độ cao đứng."""
        info = self.info
        for s in SIDES:
            anchor = None
            for T in Ts:
                tgt = T["ik"][f"leg_{s}"]
                if T["contact"][s]:
                    if anchor is None:
                        anchor = tgt[0].copy()
                        anchor.z = info.ground + info.ankle_h
                    d = anchor - tgt[0]
                    tgt[0] = anchor.copy()
                    tgt[1] = tgt[1] + d
                else:
                    anchor = None
                    tgt[0].z = max(tgt[0].z, info.ground + info.ankle_h)
        return Ts


# ---------------------------------------------------------------- hoà trộn


def blend(a, b, u):
    """Đích a → b theo u (0–1): vị trí lerp, xoay slerp, hướng bàn tay/chân lerp."""
    if u <= 0:
        return a
    if u >= 1:
        return b
    out = {"rot": {}, "ik": {}, "hand": {}, "foot": {}, "contact": b.get("contact", {})}
    out["pelvis"] = a["pelvis"].lerp(b["pelvis"], u)
    for k in a["rot"]:
        out["rot"][k] = a["rot"][k].slerp(b["rot"][k], u)
    for k in a["ik"]:
        out["ik"][k] = [a["ik"][k][0].lerp(b["ik"][k][0], u), a["ik"][k][1].lerp(b["ik"][k][1], u)]
    for k in a["hand"]:
        out["hand"][k] = tuple(x.lerp(y, u).normalized() for x, y in zip(a["hand"][k], b["hand"][k]))
    for k in a["foot"]:
        out["foot"][k] = a["foot"][k].lerp(b["foot"][k], u)
    return out


def capture(info, ik_objects, hand_dirs=None):
    """Đích đọc từ dáng hiện tại của rig (dáng chờ biên đạo) — để hoà vào/ra."""
    rig = info.rig
    bpy.context.view_layer.update()
    mw = rig.matrix_world
    T = {"rot": {}, "ik": {}, "hand": {}, "foot": {}, "contact": {"l": True, "r": True}}
    for b in ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head"):
        cur = (info.A @ rig.pose.bones[b].matrix.to_3x3()).normalized()
        T["rot"][b] = (cur @ info.rest_rot[b].transposed()).to_quaternion()
    T["pelvis"] = mw @ rig.pose.bones["pelvis"].head
    for k, (t, p) in ik_objects.items():
        T["ik"][k] = [t.matrix_world.to_translation(), p.matrix_world.to_translation()]
    for s in SIDES:
        h = mw @ rig.pose.bones[f"hand_{s}"].head
        mid = mw @ rig.pose.bones[f"middle_01_{s}"].head if f"middle_01_{s}" in rig.pose.bones else mw @ rig.pose.bones[f"hand_{s}"].tail
        d = (mid - h).normalized()
        cur = (info.A @ rig.pose.bones[f"hand_{s}"].matrix.to_3x3()).normalized()
        # Lòng bàn tay: trục z cục bộ của xương bàn tay ở dáng nghỉ quay vào trong (chữ A).
        n = (cur @ info.rest_rot[f"hand_{s}"].transposed()) @ (info.A @ Vector((-1 if s == "l" else 1, 0, 0)))
        T["hand"][s] = hand_dirs[s] if hand_dirs and s in hand_dirs else (d, n.normalized())
        f = mw @ rig.pose.bones[f"ball_{s}"].head - mw @ rig.pose.bones[f"foot_{s}"].head
        T["foot"][s] = f
    return T


# ---------------------------------------------------------------- đặt dáng


def set_world_rot(info, bone, q, head=None):
    """Đặt xoay thế giới của [bone] = q · xoay nghỉ (giữ đầu xương tại chỗ / [head])."""
    rig = info.rig
    pb = rig.pose.bones[bone]
    R_w = q.to_matrix() @ info.rest_rot[bone]
    R_a = info.Ai @ R_w
    loc = pb.head.copy() if head is None else rig.matrix_world.inverted() @ head
    pb.matrix = Matrix.Translation(loc) @ R_a.to_4x4()
    bpy.context.view_layer.update()


def apply(info, T, ik_objects, palm=None, look=None, foot_flat=True):
    """Đặt rig theo đích T. [ik_objects] = {"arm_l": (target, pole), ...} — các
    empty IK đã có ràng buộc; [palm]: hàm (s, fingers, palm_dir) xoay bàn tay
    (None = đặt thẳng xương hand); [look] = hướng thế giới mắt nhìn (đối thủ)."""
    rig = info.rig
    for pb in rig.pose.bones:
        if pb.name.startswith(("pelvis", "spine", "neck", "head", "foot", "ball")):
            pb.matrix_basis = Matrix()
    bpy.context.view_layer.update()
    set_world_rot(info, "pelvis", T["rot"]["pelvis"], head=T["pelvis"])
    for b in ("spine_01", "spine_02", "spine_03", "neck_01", "head"):
        set_world_rot(info, b, T["rot"][b])
    if look is not None:
        # Mắt khoá về đối thủ: xoay đầu (và cổ một nửa) quanh trục đứng cho mặt nhìn [look].
        face = T["rot"]["head"].to_matrix() @ (info.A @ Vector((0, -1, 0)))
        f2 = Vector((face.x, face.y, 0))
        l2 = Vector((look.x, look.y, 0))
        if f2.length > 1e-6 and l2.length > 1e-6:
            yaw = f2.angle(l2) * (1 if f2.cross(l2).z > 0 else -1)
            yaw = max(-math.radians(55), min(math.radians(55), yaw))
            qn = Quaternion(Vector((0, 0, 1)), yaw * 0.4)
            set_world_rot(info, "neck_01", qn @ T["rot"]["neck_01"])
            qh = Quaternion(Vector((0, 0, 1)), yaw * 0.85) @ T["rot"]["head"]
            # Ngẩng/cúi: đưa mặt về gần ngang tầm nhìn đối thủ (thế ngả lưng làm đầu ngửa trời).
            f3 = qh.to_matrix() @ (info.A @ Vector((0, -1, 0)))
            pitch = math.atan2(f3.z, Vector((f3.x, f3.y, 0)).length)
            side = Vector((f3.x, f3.y, 0)).normalized().cross(Vector((0, 0, 1)))
            if side.length > 1e-6:
                qh = Quaternion(side.normalized(), -pitch * 0.7) @ qh
            set_world_rot(info, "head", qh)
    for k, (t, p) in T["ik"].items():
        if k in ik_objects:
            ik_objects[k][0].location = t
            ik_objects[k][1].location = p
    bpy.context.view_layer.update()
    for s in SIDES:
        d, n = T["hand"][s]
        if palm:
            palm(s, d, n)
    bpy.context.view_layer.update()
    # Bàn chân: hướng theo mocap; chạm đất thì phẳng; ngón chân gập bám đất khi nhón gót.
    for s in SIDES:
        pbf = rig.pose.bones[f"foot_{s}"]
        f = T["foot"][s].copy()
        # Phẳng khi chạm đất HOẶC mắt cá sát đất (mocap bước nhón gót kiểu múa — critic v7).
        low = T["ik"][f"leg_{s}"][0].z < info.ground + info.ankle_h * 1.35
        if (T["contact"].get(s) or low) and foot_flat:
            f.z = 0
        if f.length < 1e-6:
            continue
        f.normalize()
        lat = Vector((0, 0, 1)).cross(Vector((f.x, f.y, 0)).normalized() if Vector((f.x, f.y, 0)).length > 1e-6 else f)
        F = frame_from(lat, f)
        R_w = F @ info.foot[s].transposed() @ info.rest_rot[f"foot_{s}"]
        # Giới hạn cổ chân so với cẳng chân: gập mu ≤ 30°, duỗi ≤ 50° (đo theo góc dốc).
        cur = pbf.matrix.to_translation()
        pbf.matrix = Matrix.Translation(cur) @ (info.Ai @ R_w).to_4x4()
        bpy.context.view_layer.update()
        ball = rig.pose.bones[f"ball_{s}"]
        tip = rig.matrix_world @ ball.tail
        root = rig.matrix_world @ ball.head
        floor = info.ground + 0.004
        if tip.z < floor and root.z > floor:
            # Ngón chân xuyên đất: gập ngón lên quanh khớp ball cho mũi chạm đất.
            v = tip - root
            want = Vector((v.x, v.y, 0)).normalized() * v.length
            want.z = floor - root.z
            if abs(want.z) < v.length:
                want = Vector((v.x, v.y, 0)).normalized() * math.sqrt(v.length ** 2 - want.z ** 2)
                want.z = floor - root.z
                q = v.rotation_difference(want)
                ang = min(q.angle, math.radians(60))
                q = Quaternion(q.axis, ang)
                cur_w = (info.A @ ball.matrix.to_3x3()).normalized()
                ball.matrix = Matrix.Translation(ball.matrix.to_translation()) @ (info.Ai @ (q.to_matrix() @ cur_w)).to_4x4()
                bpy.context.view_layer.update()


def fingers(rig, s, curl, spread=0.0, thumb=None):
    """Ngón tay tự nhiên: [curl] 0 (duỗi) – 1 (nắm đấm chặt); đốt giữa gập
    nhiều nhất, đốt gốc ít hơn ở ngón trỏ (nắm đấm thật: trỏ–giữa phẳng mặt
    đấm, út cuộn chặt hơn); [spread] xoè ngón (bàn tay chém); ngón cái ốp
    ngang mặt ngón trỏ–giữa khi nắm."""
    base = {"index": (62, 92, 58), "middle": (68, 95, 58), "ring": (74, 98, 60), "pinky": (80, 100, 62)}
    fan = {"index": -1.0, "middle": -0.3, "ring": 0.4, "pinky": 1.0}
    for f, angs in base.items():
        for j, ang in zip(("01", "02", "03"), angs):
            pb = rig.pose.bones.get(f"{f}_{j}_{s}")
            if not pb:
                continue
            # Ngón ngoài cuộn trước một chút (nắm tay tự nhiên cuộn từ út vào).
            c = min(1.0, curl * (1.0 + 0.12 * fan[f]))
            pb.rotation_mode = "XYZ"
            pb.rotation_euler.x = math.radians(ang * c)
            pb.rotation_euler.z = math.radians(8 * spread * fan[f]) if j == "01" else 0.0
    t = curl if thumb is None else thumb
    for j, ang in (("01", 18), ("02", 30), ("03", 40)):
        pb = rig.pose.bones.get(f"thumb_{j}_{s}")
        if pb:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler.x = math.radians(ang * t)
    bpy.context.view_layer.update()


# ---------------------------------------------------------------- rig → khung chuẩn

RIG_POINTS = {"pelvis": ("pelvis", 0), "spine": ("spine_01", 0), "chest": ("spine_03", 0), "neck": ("neck_01", 0),
              "head": ("head", 0), "head_top": ("head", 1),
              "shoulder_l": ("upperarm_l", 0), "elbow_l": ("lowerarm_l", 0), "wrist_l": ("hand_l", 0),
              "shoulder_r": ("upperarm_r", 0), "elbow_r": ("lowerarm_r", 0), "wrist_r": ("hand_r", 0),
              "hip_l": ("thigh_l", 0), "knee_l": ("calf_l", 0), "ankle_l": ("foot_l", 0), "toe_l": ("ball_l", 0),
              "hip_r": ("thigh_r", 0), "knee_r": ("calf_r", 0), "ankle_r": ("foot_r", 0), "toe_r": ("ball_r", 0),
              "hand_tip_l": ("middle_01_l", 0), "hand_tip_r": ("middle_01_r", 0),
              "thumb_l": ("thumb_02_l", 0), "thumb_r": ("thumb_02_r", 0)}


def rig_points(info, basis, origin):
    """24 điểm khung chuẩn từ dáng HIỆN TẠI của rig, toạ độ (trước, trái, lên)
    tính từ [origin] — để compose.py nối dáng chờ của boss với mocap. Rig thiếu
    xương ngón (Tripo) thì đầu ngón = đuôi xương bàn tay, ngón cái ước lượng."""
    rig = info.rig
    bpy.context.view_layer.update()
    mw = rig.matrix_world
    Bi = Matrix(basis).transposed().inverted() if not isinstance(basis, Matrix) else basis.inverted()
    out = []
    for n in ("pelvis", "spine", "chest", "neck", "head", "shoulder_l", "elbow_l", "wrist_l", "shoulder_r",
              "elbow_r", "wrist_r", "hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r", "toe_l", "toe_r",
              "head_top", "hand_tip_l", "hand_tip_r", "thumb_l", "thumb_r"):
        b, end = RIG_POINTS[n]
        if b not in rig.pose.bones:
            s = n[-1]
            hb = rig.pose.bones[f"hand_{s}"]
            if n.startswith("hand_tip"):
                p = mw @ hb.tail
            else:  # ngón cái: lệch khỏi trục bàn tay về phía trong thân 1/3 dài bàn tay
                h, t = mw @ hb.head, mw @ hb.tail
                z = (mw.to_3x3() @ hb.matrix.to_3x3() @ Vector((0, 0, 1))).normalized()
                p = h + (t - h) * 0.4 + z * (t - h).length * 0.35
        else:
            pb = rig.pose.bones[b]
            p = mw @ (pb.tail if end else pb.head)
        out.append(list(Bi @ (p - origin)))
    return out


READY = os.path.join(os.path.dirname(os.path.dirname(HERE)), "art_src", "mocap", "ready")
MOVES = os.path.join(os.path.dirname(os.path.dirname(HERE)), "art_src", "mocap", "moves")


def dump_ready(info, basis, origin, name):
    """Ghi dáng chờ hiện tại → art_src/mocap/ready/<name>.json (compose.py đọc)."""
    import json
    os.makedirs(READY, exist_ok=True)
    pts = rig_points(info, basis, origin)
    with open(os.path.join(READY, f"{name}.json"), "w", encoding="utf-8") as f:
        json.dump({"points": pts, "leg": info.leg, "arm": info.arm}, f, indent=0)
    print(f"[mocap] dáng chờ {name}: {len(pts)} điểm")


class Track:
    """Đòn đã ghép (compose.py) → đích retarget theo tiến độ sân khấu."""

    def __init__(self, info, name, move, basis, origin, pelvis_z=None):
        import json
        d = np.load(os.path.join(MOVES, f"{name}_{move}.npz"))
        self.phases = d["phases"].astype(np.float64)
        self.meta = json.loads(str(d["meta"]))
        m = Motion(d["pos"].astype(np.float64), (len(self.phases) - 1) / 1.2, self.meta)
        turn = float(self.meta.get("turn", 0.0))
        if turn:  # thế tấn karate mở ngực ra máy quay → xoay thân về phía đối thủ
            q = Quaternion(Vector((0, 0, 1)), math.radians(turn))
            basis = (q @ basis[0], q @ basis[1], basis[2])
        self.drive = MocapDrive(info, m, basis, origin, pelvis_z=pelvis_z,
                                yaw_keep=float(self.meta.get("yaw_keep", 1.0)))
        self.Ts = self.drive.lock([self.drive.targets(m.pos[i], i) for i in range(len(m))])

    def __call__(self, phase):
        f = float(np.interp(phase, self.phases, np.arange(len(self.phases))))
        i = min(len(self.Ts) - 2, int(f))
        return blend(self.Ts[i], self.Ts[i + 1], f - i)


def yaw_of(q):
    """Góc xoay quanh trục đứng (độ) của một xoay thế giới (hướng −Y nghỉ → ?)."""
    v = q.to_matrix() @ Vector((1, 0, 0))
    return math.degrees(math.atan2(v.y, v.x))


def set_hand(info, s, d, n, palm_rest_local=Vector((0, 0, -1))):
    """Xoay xương hand_[s]: ngón theo [d], lòng bàn tay quay về [n] (thế giới).
    Dáng nghỉ: ngón = trục xương, lòng bàn tay = [palm_rest_local] (khung rig —
    Tripo chữ T úp bàn tay: −Z). Cho rig không có bộ palm() như StandPoser."""
    rig = info.rig
    bpy.context.view_layer.update()
    bl = rig.data.bones[f"hand_{s}"]
    rd = (info.A @ (bl.tail_local - bl.head_local)).normalized()
    rn = (info.A @ palm_rest_local).normalized()
    F_rest = frame_from(rn.cross(rd), rd)
    F_new = frame_from(n.normalized().cross(d.normalized()), d.normalized())
    q = (F_new @ F_rest.transposed()).to_quaternion()
    set_world_rot(info, f"hand_{s}", q)


def lean_add(info, deg, left):
    """Gập (+) / ngả (−) thân thêm [deg] độ quanh trục ngang [left] (thế giới),
    chia lưng 60 % / ngực 40 %, đầu bù ngược để mắt giữ đích — lớp biên đạo
    cộng lên thân mocap (karate giữ thân thẳng; đòn nện cần gập người)."""
    if abs(deg) < 1e-3:
        return
    rig = info.rig
    for b, k in (("spine_02", 0.6), ("spine_03", 0.4)):
        pb = rig.pose.bones[b]
        bpy.context.view_layer.update()
        ax = (info.Ai @ left).normalized()
        h = pb.head.copy()
        pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg * k), 4, ax) @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()


def twist_add(info, deg):
    """Vặn thân thêm [deg] độ quanh trục đứng (hông 40 % → lưng 35 % → ngực
    25 %, hông dẫn trước), đầu bù ngược để mắt giữ đích — lớp biên đạo cộng
    lên thân mocap cho đòn quét bằng hông."""
    if abs(deg) < 1e-3:
        return
    rig = info.rig
    up = Vector((0, 0, 1))
    for b, k in (("pelvis", 0.4), ("spine_02", 0.35), ("spine_03", 0.25)):
        pb = rig.pose.bones[b]
        bpy.context.view_layer.update()
        ax = (info.Ai @ up).normalized()
        h = pb.head.copy()
        pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg * k), 4, ax) @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()


def look_at(info, look, yaw_w=0.85, pitch_w=1.0, limit=55, pitch_bias=-10.0):
    """Mắt khoá về đối thủ — chạy SAU mọi lớp cộng (vặn/gập thân): đo hướng mặt
    thật của xương đầu, xoay cổ (40 %) + đầu cho mặt nhìn [look] theo phương
    ngang, và kéo đầu về gần ngang tầm (thế ngả lưng làm mặt ngửa trời)."""
    rig = info.rig
    up = Vector((0, 0, 1))

    def face():
        bpy.context.view_layer.update()
        cur = (info.A @ rig.pose.bones["head"].matrix.to_3x3()).normalized()
        return (cur @ info.rest_rot["head"].transposed()) @ (info.A @ Vector((0, -1, 0)))

    def turn(bone, q):
        pb = rig.pose.bones[bone]
        ax, ang = q.to_axis_angle()
        h = pb.head.copy()
        pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(ang, 4, (info.Ai @ ax).normalized()) @ Matrix.Translation(-h) @ pb.matrix
        bpy.context.view_layer.update()

    f = face()
    f2, l2 = Vector((f.x, f.y, 0)), Vector((look.x, look.y, 0))
    if f2.length > 1e-6 and l2.length > 1e-6:
        yaw = f2.angle(l2) * (1 if f2.cross(l2).z > 0 else -1)
        yaw = max(-math.radians(limit), min(math.radians(limit), yaw)) * yaw_w
        turn("neck_01", Quaternion(up, yaw * 0.4))
        turn("head", Quaternion(up, yaw * 0.6))
    f = face()
    h2 = Vector((f.x, f.y, 0))
    if h2.length > 1e-6:
        # Cằm hơi cúi ([pitch_bias] độ): võ sĩ nhìn đối thủ dưới hàng mày, không ngửa cổ.
        pitch = math.atan2(f.z, h2.length) - math.radians(pitch_bias)
        side = h2.normalized().cross(up)
        # Xoay quanh side = ngang × lên theo chiều dương thì mặt NGẨNG thêm → dùng −pitch.
        turn("head", Quaternion(side.normalized(), -pitch * pitch_w))
