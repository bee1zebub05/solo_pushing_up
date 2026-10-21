"""Chuyển động tengu Sutoku (phòng Chuyển động, rules/dohoa/chuyendong.md): `TenguMotion`
— IK tay/chân thêm vào rig Tripo tự gắn, quạt theo biên đạo, thân từ mocap võ học.

Phần dựng hình ở tool/blender/characters/tengu_boss.py; `TenguMotion` nhận module đó
qua [model] (`rest`, `rot`, `face_game`, `FAN_HANDLE`/`FAN_FACE` — fan() đặt lại
nên đọc lúc tạo dáng, không chép lúc import).
"""
import math
import os

import bpy
from mathutils import Matrix, Quaternion, Vector

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)  # trục thế giới, như tengu_boss.py
STEP_LIFT, STEP_LIFT_MAX = 0.05, 0.12  # nhấc chân (m) theo tốc độ bước (m / đơn vị tiến độ)


# Góc pole IK theo khung xương tự gắn (roll 0): đo bằng TENGU_POLE (in độ nhô
# của gối/khuỷu ra trước ở dáng khuỵu), không đoán.
# Xương gương roll 0 → hai bên cần góc ngược nhau (đo 18/10: chân trái 0°, phải 180°; tay trái 180°, phải 0°).
POLE_ANGLE = {"leg_l": 0, "leg_r": 180, "arm_l": 180, "arm_r": 0}
if os.environ.get("TENGU_POLE"):
    POLE_ANGLE["arm_l"] = POLE_ANGLE["arm_r"] = float(os.environ["TENGU_POLE"])


class TenguMotion:
    """Dáng sprite theo biên đạo (tool/motion/choreo/tengu_sutoku.json).

    Mọi hướng tính trong khung rig (mặt quay −Y) nên rig xoay ¾ (face_game)
    không ảnh hưởng. Hông dịch/hạ/bay lên; chân IK bám đất (chân phải bước,
    co chân khi bay); tay phải IK tới vị trí cầm quạt quanh vai rồi xoay bàn
    tay theo hai vector (cán quạt đúng hướng `fan`, ngón nối cẳng tay); tay
    trái IK giơ đỡ kiểu tessen; cánh dựng/đập/quạt tới/cụp đốt ngoài."""

    FWD, UP, LEFT = Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))

    def __init__(self, rig, model):
        self.model = model
        from choreo import Choreo
        self.rig = rig
        self.choreo = Choreo("tengu_sutoku")
        bl = rig.data.bones
        self.ik = {}
        for name, chain_bone in (("arm_l", "lowerarm_l"), ("arm_r", "lowerarm_r"), ("leg_l", "calf_l"), ("leg_r", "calf_r")):
            t = bpy.data.objects.new(f"IK_{name}", None)
            pole = bpy.data.objects.new(f"Pole_{name}", None)
            for o in (t, pole):
                bpy.context.scene.collection.objects.link(o)
            c = rig.pose.bones[chain_bone].constraints.new("IK")
            c.target, c.pole_target, c.chain_count = t, pole, 2
            c.pole_angle = math.radians(POLE_ANGLE[name])
            self.ik[name] = (t, pole, c)
        self.foot = {s_: bl[f"foot_{s_}"].head_local.copy() for s_ in "lr"}
        self.facing = None  # đặt True khi đang ở góc sân khấu (face_game)
        self.knee = {s_: bl[f"calf_{s_}"].head_local.copy() for s_ in "lr"}

    def _set(self, name, target, pole):
        mw = self.rig.matrix_world
        t, p, _ = self.ik[name]
        t.location = mw @ target
        p.location = mw @ pole

    def apply(self, v):
        rig = self.rig
        F, U, L = self.FWD, self.UP, self.LEFT
        R = -L
        self.model.rest(rig)
        # Xoay cả người quanh chân về phía người chơi (+ = sang trái màn hình), chồng lên ¾ sân khấu.
        if self.facing is not None:
            self.model.face_game(rig, True, extra=v.get("turn", 0.0))
        # Hông: dịch tới/lui, hạ trọng tâm, bay lên (khung rig).
        pb = rig.pose.bones["pelvis"]
        bpy.context.view_layer.update()
        pb.matrix = Matrix.Translation(F * v["shift"] + U * (v["lift"] - v["drop"])) @ pb.matrix
        bpy.context.view_layer.update()
        # Thân: hông vặn trước, rồi lưng, ngực; ngả tới (+X) / ra sau.
        tw, lean = v["twist"], v["lean"]
        self.model.rot(rig, "pelvis", Z, tw * 0.4)
        self.model.rot(rig, "spine_02", Z, tw * 0.35)
        self.model.rot(rig, "spine_03", Z, tw * 0.25)
        self.model.rot(rig, "spine_02", X, lean * 0.6)
        self.model.rot(rig, "spine_03", X, lean * 0.4)
        self.model.rot(rig, "head", X, v["head"] - 0.45 * lean)
        self.model.rot(rig, "head", Z, -0.5 * tw)  # mắt giữ nhìn đích khi thân vặn
        self._wings(v)
        self._legs(v)
        self._arms(v)

    def _wings(self, v):
        rig = self.rig
        F, U, L = self.FWD, self.UP, self.LEFT
        R = -L
        # Cánh: dựng (+) / đập xuống (−), quạt ra trước, đốt ngoài cụp.
        for sd, k in (("l", 1), ("r", -1)):
            self.model.rot(rig, f"wing_01_{sd}", Y, -v["wing"] * k)
            self.model.rot(rig, f"wing_01_{sd}", Z, -v["wingFwd"] * k)
            self.model.rot(rig, f"wing_02_{sd}", Y, v["wingFold"] * k)
            self.model.rot(rig, f"wing_03_{sd}", Y, v["wingFold"] * 1.2 * k)
        bpy.context.view_layer.update()

    def _legs(self, v):
        rig = self.rig
        F, U, L = self.FWD, self.UP, self.LEFT
        R = -L
        # Chân: bàn chân bám đất (chân phải bước tới), co lên khi bay.
        # Bay: bàn chân lên theo hông (lift) và co thêm lên ngực (tuck × 0,55): gối gập.
        air = U * (max(0.0, v["lift"]) + 0.55 * v["tuck"])
        # Bước = nhấc chân: dời bàn chân phải trên sàn mà không nhấc là trượt (motion_review).
        stride = U * min(STEP_LIFT_MAX, STEP_LIFT * abs(v.get("_dstep", 0.0)))
        # Đá kéo kiểu smash cầu lông (`kick`, chỉ dùng khi bay): + = ưỡn người, chân
        # phải (bên quạt) vung ra sau gót lên, chân trái nhích tới; − = hai chân đổi
        # chỗ lúc quất (chân phải ra trước, chân trái ra sau) để đáp chân trái trước.
        k = v.get("kick", 0.0)
        kp, kn = max(k, 0.0), max(-k, 0.0)
        # Hai chân phải KHÁC nhau (critic 21/10: cùng gập = "quỳ trên không"): chân
        # trái gần duỗi ra trước khi chân phải đá ra sau; cắt kéo thì chân phải vọt lên trước.
        kick = {"r": -F * 0.55 * kp + U * 0.38 * kp + F * 0.40 * kn + U * 0.30 * kn,
                "l": F * 0.25 * kp + U * 0.02 * kp - F * 0.40 * kn + U * 0.25 * kn}
        for s_ in "lr":
            step = F * v["step"] + stride if s_ == "r" else Vector()
            step = step + kick[s_]
            # Chân đá ra sau: gối chĩa xuống đất (không co lên trước ngực như khi tuck).
            bend = (F * 1.2).lerp(-U * 1.2 + F * 0.3, kp) if s_ == "r" else F * 1.2
            self._set(f"leg_{s_}", self.foot[s_] + step + air, self.knee[s_] + step + air + bend)
        # Bàn chân phẳng bám đất: IK chỉ đặt cổ chân, bàn chân xoay theo cẳng → ngồi sâu
        # gối 90° (Thiên cẩu phi) thì mũi chân cắm đất ~10 cm (motion_review 19/10).
        # Đang bay (lift/tuck) thì nhả dần về hướng tự nhiên của cẳng.
        flat = max(0.0, 1.0 - (max(0.0, v["lift"]) + 0.55 * v["tuck"]) / 0.15)
        if flat > 0:
            bpy.context.view_layer.update()
            for s_ in "lr":
                pb = rig.pose.bones[f"foot_{s_}"]
                cur = pb.matrix.copy()
                q = cur.to_quaternion().slerp(pb.bone.matrix_local.to_quaternion(), flat)
                pb.matrix = Matrix.Translation(cur.translation) @ q.to_matrix().to_4x4()
            bpy.context.view_layer.update()

    def _arms(self, v, yaw=0.0, left_arm=True):
        """Tay phải cầm quạt (biên đạo; [yaw] = bù độ vặn ngực khi thân do mocap lái), tay trái (nếu [left_arm])."""
        rig = self.rig
        F, U, L = self.FWD, self.UP, self.LEFT
        R = -L
        # Tay phải cầm quạt: vị trí quanh vai theo góc, cả tay xoay `sweep` quanh trục đứng.
        q = Quaternion(U, math.radians(v["sweep"] + yaw))
        f2, r2 = q @ F, q @ R
        sh = rig.pose.bones["upperarm_r"].head
        a = math.radians(v["hand"])
        grip = sh + (f2 * math.cos(a) + U * math.sin(a)) * v["reach"] + r2 * v["side"]
        self._set("arm_r", grip, sh + f2 * v["poleF"] + r2 * 0.35 + U * v["poleU"])
        if left_arm:
            # Tay trái: buông (0) → giơ ra trước đỡ (1) / kéo về sát sườn (−).
            shl = rig.pose.bones["upperarm_l"].head
            g = v["guard"]
            hang = shl + U * -0.5 + F * 0.1 + L * 0.06
            # Đỡ kiểu tessen: bàn tay dựng trước mặt (ngang mắt), không ngang bụng.
            aim = shl + F * 0.45 + U * 0.22 + R * 0.08 if g >= 0 else shl + U * -0.38 - F * 0.12 + L * 0.1
            target = hang.lerp(aim, abs(g))
            # Ngắm kiểu smash (`aim` 0–1): tay trái duỗi thẳng chỉ lên trời phía trước
            # — dáng báo đòn đọc được ở dạng bóng; quất thì kéo về (guard âm).
            if v.get("aim", 0.0) > 0:
                target = target.lerp(shl + U * 0.52 + F * 0.2 + R * 0.04, v["aim"])  # ~90 % tầm với: duỗi căng thì IK giật khuỷu
            # Cắn ngón tay (`mouth`) rồi vạch ấn máu trong không trung (`stroke` 0–1: hai vòng nét).
            if v.get("mouth", 0.0) > 0:
                mouth = rig.pose.bones["head"].head + F * 0.13 + U * 0.03
                target = target.lerp(mouth, v["mouth"])
            if v.get("sigil", 0.0) > 0:
                # Vạch ấn trước mặt hướng về người chơi, cao ngang đầu: nét ngang → nét
                # chéo xuống → chấm → ấn lòng bàn tay ra trước (stroke 0–1).
                st = v.get("stroke", 0.0)
                # Xa phía trước–trên đầu (về phía người chơi) để tay không che mặt ở góc ¾.
                # Nét vung cả cánh tay quanh trên đầu (tengu quay gần chính diện máy quay,
                # 'trước' = về phía máy quay): ngang rộng → chéo dài xuống → chấm.
                o = shl + F * 0.3 + U * 0.58
                if st < 0.33:
                    pos = o + L * (0.45 - 0.9 * st / 0.33)
                elif st < 0.66:
                    u = (st - 0.33) / 0.33
                    pos = o + L * (0.4 - 0.7 * u) - U * 0.55 * u
                else:
                    pos = o - U * 0.15 + F * 0.08 * math.sin((st - 0.66) / 0.34 * math.pi)
                target = target.lerp(pos, v["sigil"])
            self._set("arm_l", target, shl + L * 0.4 + U * -0.2 - F * 0.2)
        bpy.context.view_layer.update()
        # Bàn tay phải: cán quạt chĩa đúng `fan`, mặt quạt quay về máy quay
        # (giữ ngón nối cẳng tay thì quạt hay quay cạnh, thành cái que).
        c = math.radians(v["fan"])
        H1 = (f2 * math.cos(c) + U * math.sin(c)).normalized()
        hb = rig.pose.bones["hand_r"]
        cam = bpy.context.scene.camera
        view = -(cam.matrix_world.to_3x3() @ Vector((0, 0, -1))) if cam else Vector((0, -1, 0))
        N1 = (rig.matrix_world.inverted().to_3x3() @ view).normalized()
        N1 = N1 - H1 * N1.dot(H1)
        if N1.length > 0.2:
            N1.normalize()
            h = self.model.FAN_HANDLE
            n = (self.model.FAN_FACE - h * self.model.FAN_FACE.dot(h)).normalized()
            src = Matrix((h, n, h.cross(n))).transposed()
            dst = Matrix((H1, N1, H1.cross(N1))).transposed()
            hb.matrix = Matrix.Translation(hb.head) @ (dst @ src.inverted()).to_4x4()
        bpy.context.view_layer.update()
        # Cổ tay người bẻ tối đa ~50–60°: hướng cán + mặt quạt theo biên đạo có thể đòi
        # bàn tay gập 90–140° so với cẳng tay ("cổ cò", người dùng 21/10) → xoay cả bàn
        # tay (kèm quạt) về trong giới hạn; quạt lệch biên đạo một chút còn hơn tay gãy.
        lim = getattr(self, "wrist_max", None)
        if lim:
            fa = (hb.head - rig.pose.bones["lowerarm_r"].head).normalized()
            d = (hb.tail - hb.head).normalized()
            if d.angle(fa) > math.radians(lim):
                want = Quaternion(fa.cross(d).normalized(), math.radians(lim)) @ fa
                q = d.rotation_difference(want)
                hb.matrix = Matrix.Translation(hb.head) @ (q.to_matrix() @ hb.matrix.to_3x3()).to_4x4()
                bpy.context.view_layer.update()
        # Ngón nắm cán quạt (xương ngón tự dựng — tripo_kit.add_fingers).
        import mocap_drive as md
        md.fingers(rig, "r", 0.72, thumb=0.6)
        if left_arm:
            curl = 0.25 + 0.4 * max(0.0, v.get("guard", 0.0))
            md.fingers(rig, "l", curl + (0.08 - curl) * v.get("aim", 0.0))  # ngắm: bàn tay mở

    # ------------------------------------------------ đòn mocap (rules/dohoa/chuyendong.md)
    def basis(self):
        m3 = self.rig.matrix_world.to_3x3().normalized()
        return m3 @ self.FWD, m3 @ self.LEFT, Vector((0, 0, 1))

    def anchor(self):
        """Dáng chờ biên đạo (góc sân khấu) → (gốc đất dưới hông, độ cao hông)."""
        import mocap_drive as md
        self.facing = True
        self.apply(dict(self.choreo.ready))
        if getattr(self, "minfo", None) is None:
            self.minfo = md.RigInfo(self.rig)
        pel = self.rig.matrix_world @ self.rig.pose.bones["pelvis"].head
        return Vector((pel.x, pel.y, self.minfo.ground)), pel.z

    def mocap_ik(self):
        return {k: self.ik[k][:2] for k in ("arm_l", "arm_r", "leg_l", "leg_r")}

    def mocap(self, move):
        """Đòn ghép từ mocap (art_src/mocap/moves/tengu_sutoku_<move>.npz) hoặc None."""
        cache = self.__dict__.setdefault("_mtracks", {})
        if move in cache:
            return cache[move]
        import mocap_drive as md
        tr = None
        if move and os.environ.get("TENGU_MOCAP", "1") != "0" and os.path.exists(
                os.path.join(md.MOVES, f"tengu_sutoku_{move}.npz")):
            origin, pz = self.anchor()
            self.mready = md.capture(self.minfo, self.mocap_ik())
            tr = md.Track(self.minfo, "tengu_sutoku", move, self.basis(), origin, pelvis_z=pz)
            self.mlean = float(tr.meta.get("lean", 0.0))
            self.mtwist = float(tr.meta.get("twist", 0.0))
            self.mshift = float(tr.meta.get("shift", 0.0))
        cache[move] = tr
        return tr

    def apply_mocap(self, v, T, w=1.0):
        """Thân + chân + tay trái từ mocap; cánh + tay quạt theo biên đạo (tay quạt
        xoay theo phần ngực mocap vặn khác biên đạo); ngón nắm cán quạt."""
        import mocap_drive as md
        rig = self.rig
        self.model.rest(rig)
        self.model.face_game(rig, True)  # xoay thêm (turn) do thân mocap lo — giữ khung rig như lúc đo RigInfo
        fwd, left, up = self.basis()
        iko = self.mocap_ik()
        iko.pop("arm_r")

        def palm(s, d, n):
            if s == "l":
                md.set_hand(self.minfo, "l", d, n)

        if self.mshift:  # dồn trọng tâm theo biên đạo cộng lên hông mocap
            T = dict(T, pelvis=T["pelvis"] + (fwd * v["shift"] - up * (v["drop"] - v["lift"])) * self.mshift * w)
        md.apply(self.minfo, T, iko, palm=palm)
        # [w]: lớp cộng hoà cùng mocap — dáng chờ (mready) đã có sẵn twist/lean của biên đạo.
        md.twist_add(self.minfo, v["twist"] * self.mtwist * w)
        md.lean_add(self.minfo, v["lean"] * self.mlean * w, left)
        md.look_at(self.minfo, fwd)  # sau mọi lớp cộng: mặt nhìn Hercules
        self._wings(v)
        # Tay quạt theo biên đạo trong khung rig (không bù độ vặn thân mocap).
        self._arms(v, left_arm=False)
        md.fingers(rig, "l", 0.15, thumb=0.2)  # bàn tay trái mở, lòng bàn tay hướng đối thủ

    # Đòn có giới hạn cổ tay (độ). Phong kesa đã duyệt giữ nguyên cách cũ.
    WRIST_MAX = {"attack2": 50}

    def pose(self, t=0.0, move=None, phase=0.0):
        # Giới hạn cổ tay nới dần về "không giới hạn" ở hai đầu đòn: dáng chờ cổ tay gập
        # hơn 50°, kẹp tới khung cuối thì đòn không khớp dáng chờ (motion_review: quạt lệch 15 cm).
        lim = self.WRIST_MAX.get(move)
        if lim:
            w = max(0.0, min(1.0, phase / 0.1, (1.0 - phase) / 0.12))
            lim = lim + (180 - lim) * (1 - w * w * (3 - 2 * w))
        self.wrist_max = lim if lim and lim < 179.9 else None
        tr = self.mocap(move) if move else None
        if tr is not None:
            self.apply_mocap(self.choreo[move](phase), *tr.from_ready(self.mready, phase))
            return
        if move is None:  # thở: cánh khẽ nâng hạ, quạt phe phẩy, đầu nghiêng
            w = 2 * math.pi * t
            v = dict(self.choreo.ready)
            v.update(drop=0.01 * (1 - math.cos(w)), wing=4 * math.sin(w), wingFold=-3 * math.sin(w - 0.6),
                     fan=v["fan"] + 10 * math.sin(2 * w), hand=v["hand"] + 4 * math.sin(w), head=-2 * math.sin(w),
                     lean=1.0 * math.sin(w))
        else:
            v = self.choreo[move](phase)
            e = 0.01  # tốc độ đổi step (m / đơn vị tiến độ) cho nhấc chân khi bước
            v["_dstep"] = (self.choreo[move](min(1.0, phase + e))["step"]
                           - self.choreo[move](max(0.0, phase - e))["step"]) / (2 * e)
        self.apply(v)
