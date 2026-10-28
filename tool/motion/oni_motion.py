"""Chuyển động Shuten-dōji (phòng Chuyển động, rules/dohoa/chuyendong.md): tay vác/vung
chuỳ, tay lửa, và `OniMotion` — dáng sprite theo biên đạo + mocap võ học.

Phần dựng hình ở tool/blender/characters/oni_boss.py; `OniMotion` nhận module đó
qua [model] (dùng `model.S`, `model.dress_lower` dựng lại hakama mỗi khung).
"""
import math
import os

import bpy
from mathutils import Matrix, Vector

from japan_kit import fist


# Chuỳ tay phải theo pha đòn: (góc vị trí nắm quanh vai trong mặt phẳng
# trước–lên (độ, 0 = thẳng trước, 90 = thẳng lên), khoảng cách ×S, lệch
# sang phải ×S, góc hướng chuỳ cùng mặt phẳng, khuỷu hướng về (trước, phải,
# lên) mét tính từ vai). Nội suy theo GÓC: vung chuỳ là vòng cung qua đầu;
# nội suy thẳng thì tay cắt ngang mặt và hướng chuỳ lật đột ngột.
CLUB_KEYS = {
    "carry": (-14, 0.165, 0.08, 148, (0.0, 0.6, -0.5)),     # vác vai (bản duyệt 10c)
    "windup": (112, 0.42, 0.2, 185, (0.3, 0.75, 0.2)),      # giơ cao, chuỳ ngả ra sau đầu (tay ra ngoài, không che mặt)
    "strike": (-35, 0.55, 0.05, -68, (0.0, 0.6, -0.45)),    # nện xuống trước mặt, đầu chuỳ sát đất
    "defeat": (-78, 0.5, 0.1, -74, (0.0, 0.5, -0.6)),       # buông, đầu chuỳ chống đất
}


def club_arm(poser, ang, dist, side, club_ang, pole, sign=None, sweep=0.0, cant=0.32):
    """Đặt tay phải nắm chuỳ: IK tới vị trí nắm, xoay bàn tay sao cho trục
    đốt ngón (trỏ → út) chỉ về đuôi chuỳ, ngón cái về đầu chuỳ. [sweep] xoay
    cả vị trí nắm, hướng khuỷu và hướng chuỳ quanh trục đứng qua vai (độ, +
    = sang trái nhân vật) — đòn quét ngang. Trả về (chiều lòng bàn tay, hướng chuỳ)."""
    from mathutils import Quaternion
    fwd, left, up = poser.frame()
    q = Quaternion(up, math.radians(sweep))
    fwd, left = q @ fwd, q @ left
    right = -left
    sh_r = poser.world("upperarm_r", 0.0)
    a = math.radians(ang)
    grip = sh_r + (fwd * math.cos(a) + up * math.sin(a)) * dist * poser.scale + right * side * poser.scale
    poser.arm("r", grip, sh_r + fwd * pole[0] + right * pole[1] + up * pole[2])
    c = math.radians(club_ang)
    # [cant]: chuỳ nghiêng ra phía phải (vác vai cần ~0,32; chống như trượng = 0).
    want = (fwd * math.cos(c) + up * math.sin(c) + right * cant).normalized()
    fist(poser.rig, "r")
    fa = (poser.world("hand_r", 0.0) - poser.world("lowerarm_r", 0.0)).normalized()
    cd = (want - fa * want.dot(fa)).normalized()
    for sg in ((sign,) if sign else (1, -1)):
        poser.palm("r", fa, fa.cross(cd) * sg)
        knuckle = poser.world("pinky_01_r", 0.0) - poser.world("index_01_r", 0.0)
        if knuckle.dot(cd) < 0:
            break
    if sign:
        # palm() coi trục đốt ngón vuông góc hướng ngón ở dáng nghỉ — sai với
        # bàn tay MPFB đã nắm (lệch tới 30–60° khi tay duỗi ra trước): đo trục
        # chuỳ thật rồi xoay bù cổ tay quanh cổ tay cho khớp hướng mong muốn.
        h = poser.ik["r"][2]
        for _ in range(2):
            actual = -(poser.world("pinky_01_r", 0.0) - poser.world("index_01_r", 0.0)).normalized()
            fix = actual.rotation_difference(want).to_matrix().to_4x4()
            loc = h.matrix_world.to_translation()
            h.matrix_world = Matrix.Translation(loc) @ fix @ Matrix.Translation(-loc) @ h.matrix_world
            bpy.context.view_layer.update()
        knuckle = poser.world("pinky_01_r", 0.0) - poser.world("index_01_r", 0.0)
    return sg, -knuckle.normalized()


def fire_arm(poser, drop=0.0, aim=0.0, drink=0.0, face=0.0):
    """Tay trái chìa ra trước, ngửa bàn tay nâng lửa ma; [drop] 0–1 buông
    xuống (gục); [aim] 1 = vươn thẳng ra trước ngắm đích lúc lấy đà (tay
    "găng" của người ném), âm = kéo về sát sườn lúc ra đòn (xoay ngược chiều
    vai); [drink] 1 = đưa vò sake lên miệng, lòng bàn tay ngửa về sau cho vò
    nghiêng rót; [face] 1 = bàn tay bịt miệng (sặc rượu)."""
    fwd, left, up = poser.frame()
    sh_l = poser.world("upperarm_l", 0.0)
    reach = poser.a + poser.b
    a = max(0.0, aim)
    back = min(0.0, aim)
    # Ngắm: vươn thẳng về phía người chơi, cao ngang vai (critic: tay lửa co trước ngực).
    hand = (sh_l + left * reach * (0.6 - 0.25 * drop - 0.55 * a + 0.1 * back)
            + fwd * reach * (0.45 - 0.3 * drop + 0.5 * a + 0.5 * back)
            - up * reach * (0.38 + 0.5 * drop - 0.38 * a))
    head = poser.world("head", 0.35)
    mouth = head + fwd * 0.16 * poser.scale - up * 0.04 * poser.scale
    if drink > 0:
        hand = hand.lerp(mouth - fwd * 0.02 * poser.scale + left * 0.05 * poser.scale, drink)
    if face > 0:
        hand = hand.lerp(mouth + fwd * 0.03 * poser.scale, face)
    poser.arm("l", hand, sh_l + left * 0.3 - up * 0.8 - fwd * 0.1)
    # Ngửa lòng bàn tay, ngón vuốt quặp nhẹ ôm lửa; uống thì ngửa về sau, bịt miệng thì úp vào mặt.
    fa_l = (poser.world("hand_l", 0.0) - poser.world("lowerarm_l", 0.0)).normalized()
    flat_l = (fa_l - up * fa_l.dot(up)).normalized()
    palm_dir = up.lerp((-fwd * 0.8 + up * 0.6).normalized(), drink).lerp(-fwd, face)
    poser.palm("l", (flat_l - up * 0.1).normalized(), palm_dir.normalized())
    fist(poser.rig, "l", curl=0.45 + 0.3 * max(drink, face))


def attack_pose(phase):
    """(lấy đà, ra đòn, thu về) 0–1 — bản Python của AttackPose.at (lib/art/motion.dart)."""
    if phase < 0 or phase > 1:
        return 0.0, 0.0, 0.0
    if phase < 0.5:
        t = phase / 0.5
        return 1 - (1 - t) ** 2, 0.0, 0.0
    if phase < 0.65:
        t = (phase - 0.5) / 0.15
        return 1 - t, math.sin(t * math.pi / 2), 0.0
    t = (phase - 0.65) / 0.35
    return 0.0, 1 - t, math.sin(t * math.pi)


def rot_world(rig, bone, axis, deg):
    """Xoay [bone] quanh trục thế giới [axis] qua đầu xương, theo dáng hiện tại."""
    bpy.context.view_layer.update()
    pb = rig.pose.bones[bone]
    ax = (rig.matrix_world.inverted().to_3x3() @ axis).normalized()
    h = pb.head.copy()
    pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, ax) @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()


class OniMotion:
    """Dáng sprite theo biên đạo (tool/motion/choreo/shuten_doji.json): nhịp
    thở [t] (0–1, lặp) hoặc đòn [move] tại tiến độ [phase]. Chân IK bám đất
    (bàn chân phải bước theo `step`/`lift`), hông dịch/hạ trọng tâm, độ vặn
    chia hông → lưng → ngực (hông đi trước), chuỳ vung theo góc quanh vai,
    hakama/tạp dề/khoá đai dựng lại theo dáng từng khung."""

    SPINE = ("pelvis", "spine_02", "spine_03", "neck_01", "head")
    ARMS = ("clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r")

    def club_floor(self, v, floor=0.005):
        """Chuỳ chạm sàn chứ không cắm xuống: sau cú nện và trong vòng thu dưới, đầu chuỳ
        lún tới ~31 cm (motion_review 19/10). NHẤC tay nắm lên đúng độ lún, giữ nguyên góc
        chuỳ — liên tục theo tiến độ (xoay chuỳ thì bật 58° khi chuỳ qua phương thẳng
        đứng). Không đụng khi chuỳ đã ở trên sàn."""
        if not self.club:
            return
        poser, S = self.poser, self.model.S
        a, dist = math.radians(v["hand"]), v["reach"]
        for _ in range(3):  # IK có thể không với tới đủ cao → đo lại
            bpy.context.view_layer.update()
            low = min((o.matrix_world @ c).z for o, pts in self.club for c in pts)
            if low >= floor - 1e-4:
                return
            x, y = math.cos(a) * dist, math.sin(a) * dist + (floor - low) / S
            a, dist = math.atan2(y, x), math.hypot(x, y)
            club_arm(poser, math.degrees(a), dist, v["side"], v["club"], (v["poleF"], 0.6, v["poleU"]),
                     sign=poser.club_sign, sweep=v["sweep"], cant=v.get("cant", 0.32))

    def reset_arms(self):
        for b, m in self.arm_basis.items():
            self.rig.pose.bones[b].matrix_basis = m

    def __init__(self, poser, body, mats, model):
        self.model = model
        import re
        from choreo import Choreo
        self.poser, self.body, self.mats = poser, body, mats
        self.rig = rig = poser.rig
        self.choreo = Choreo("shuten_doji")
        bpy.context.view_layer.update()
        self.basis = {b: rig.pose.bones[b].matrix_basis.copy() for b in self.SPINE}
        # Dáng gốc hai tay (vác chuỳ đã duyệt): IK của Blender giải lặp TỪ dáng hiện tại →
        # không đặt lại thì độ xoắn cẳng tay (và hướng chuỳ) phụ thuộc khung trước — idle
        # và khung đầu đòn lệch chuỳ ~35 cm (motion_review 19/10).
        self.arm_basis = {b: rig.pose.bones[b].matrix_basis.copy() for b in self.ARMS if b in rig.pose.bones}
        self.wisps = [(o, o.matrix_world.copy(), int(re.match(r"Wisp(\d+)", o.name).group(1)))
                      for o in bpy.data.objects if o.name.startswith("Wisp")]
        self.fire = [o for o in bpy.data.objects if o.name.startswith("Onibi")]
        # Điểm mẫu của chuỳ (đầu, gai) để giữ chuỳ không cắm xuống sàn (club_floor).
        self.club = [(o, [v.co.copy() for v in o.data.vertices][::7])
                     for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Kanabo")]
        self.jar = [o for o in bpy.data.objects if o.name.startswith("SakeJar")]
        self.move = None
        # IK chân: đích = bàn chân dáng duyệt, gối hướng ra trước.
        fwd, left, up = poser.frame()
        self.feet = {}
        for s_ in "lr":
            pb = rig.pose.bones[f"foot_{s_}"]
            head = rig.matrix_world @ pb.head
            knee = rig.matrix_world @ rig.pose.bones[f"calf_{s_}"].head
            tgt = bpy.data.objects.new(f"LegIK_{s_}", None)
            pole = bpy.data.objects.new(f"LegPole_{s_}", None)
            for o in (tgt, pole):
                bpy.context.scene.collection.objects.link(o)
            tgt.location = head
            pole.location = knee + fwd * 1.5 * self.model.S
            c = rig.pose.bones[f"calf_{s_}"].constraints.new("IK")
            c.target, c.pole_target, c.chain_count = tgt, pole, 2
            c.pole_angle = math.radians(-90)
            self.feet[s_] = (tgt, pole, head.copy(), knee - head, pb.matrix.copy())
        bpy.context.view_layer.update()
        self.dress = None
        self.defeat = 0.0
        self._mtracks = {}
        self.minfo = None

    # ------------------------------------------------ đòn mocap (rules/dohoa/chuyendong.md)
    def anchor(self):
        """Dáng chờ biên đạo → (gốc đất dưới hông, độ cao hông) — mốc chung để
        xuất dáng chờ cho compose.py và để đọc lại đòn đã ghép."""
        import mocap_drive as md
        self.apply(dict(self.choreo.ready))
        if self.minfo is None:
            self.minfo = md.RigInfo(self.rig)
        pel = self.rig.matrix_world @ self.rig.pose.bones["pelvis"].head
        return Vector((pel.x, pel.y, self.minfo.ground)), pel.z

    def mocap(self, move):
        """Đòn ghép từ mocap võ học (art_src/mocap/moves/shuten_doji_<move>.npz)
        hoặc None (chưa có / ONI_MOCAP=0) → dùng biên đạo cũ."""
        if move in self._mtracks:
            return self._mtracks[move]
        import mocap_drive as md
        tr = None
        if move and os.environ.get("ONI_MOCAP", "1") != "0" and os.path.exists(
                os.path.join(md.MOVES, f"shuten_doji_{move}.npz")):
            origin, pz = self.anchor()
            self.mready = md.capture(self.minfo, self.mocap_ik())
            tr = md.Track(self.minfo, "shuten_doji", move, self.poser.frame(), origin, pelvis_z=pz)
            self.mlean = float(tr.meta.get("lean", 0.0))
            self.mtwist = float(tr.meta.get("twist", 0.0))
            self.mshift = float(tr.meta.get("shift", 0.0))
        self._mtracks[move] = tr
        return tr

    def mocap_ik(self):
        return {"arm_l": self.poser.ik["l"][:2], "arm_r": self.poser.ik["r"][:2],
                "leg_l": self.feet["l"][:2], "leg_r": self.feet["r"][:2]}

    def apply_mocap(self, v, T, w=1.0):
        """Lớp thân từ mocap (hông, cột sống, đầu, chân, tay lửa) + lớp tay chuỳ
        theo biên đạo — khung tay chuỳ xoay theo độ vặn ngực của mocap."""
        import mocap_drive as md
        poser = self.poser
        fwd, left, up = poser.frame()
        iko = self.mocap_ik()
        iko.pop("arm_r")

        def palm(s, d, n):
            if s == "l":  # lòng bàn tay trái ngửa nâng lửa ma
                poser.palm("l", d, (n * 0.35 + up * 0.65).normalized())

        iko.pop("arm_l")  # tay lửa theo biên đạo: vươn ra trước ngắm = thế báo (critic v2)
        if self.mshift:  # dồn trọng tâm theo biên đạo (dậm, hạ tấn) cộng lên hông mocap
            T = dict(T, pelvis=T["pelvis"] + (fwd * v["shift"] - up * v["drop"]) * self.model.S * self.mshift * w)
        self.reset_arms()
        md.apply(self.minfo, T, iko, palm=None)
        # Gập/ngả + vặn thân theo biên đạo cộng lên mocap (karate giữ thân thẳng,
        # đòn nện cần gập người, đòn quét cần hông xoay).
        # [w]: lớp cộng hoà cùng mocap — dáng chờ (mready) đã có sẵn twist/lean của biên đạo.
        md.twist_add(self.minfo, v["twist"] * self.mtwist * w)
        md.lean_add(self.minfo, v["lean"] * self.mlean * w, left)
        md.look_at(self.minfo, fwd)  # sau mọi lớp cộng: mặt nhìn Hercules
        fire_arm(poser, drop=self.defeat, aim=v["aim"], drink=v.get("drink", 0.0), face=v.get("face", 0.0))
        # Vị trí tay chuỳ trong biên đạo tính theo khung CỐ ĐỊNH (không theo độ vặn
        # thân) — giữ nguyên, chỉ gốc vai đi theo thân mocap.
        club_arm(poser, v["hand"], v["reach"], v["side"], v["club"], (v["poleF"], 0.6, v["poleU"]),
                 sign=poser.club_sign, sweep=v["sweep"], cant=v.get("cant", 0.32))
        self.club_floor(v)
        self.redress()
        bpy.context.view_layer.update()

    def apply(self, v):
        rig, poser = self.rig, self.poser
        for b, m in self.basis.items():
            rig.pose.bones[b].matrix_basis = m
        self.reset_arms()
        bpy.context.view_layer.update()
        fwd, left, up = poser.frame()
        # Hông: dịch trước/sau, hạ trọng tâm (chân IK tự gập gối).
        pb = rig.pose.bones["pelvis"]
        d = (fwd * v["shift"] - up * v["drop"]) * self.model.S
        pb.matrix = Matrix.Translation(rig.matrix_world.inverted().to_3x3() @ d) @ pb.matrix
        bpy.context.view_layer.update()
        # Bàn chân phải bước tới (lift = nhấc khỏi đất giữa bước); bàn chân trái bám đất.
        for s_ in "lr":
            tgt, pole, head, knee_off, _ = self.feet[s_]
            step = (fwd * v["step"] + up * v["lift"]) * self.model.S if s_ == "r" else Vector()
            tgt.location = head + step
            pole.location = head + step + knee_off + fwd * 1.5 * self.model.S
        bpy.context.view_layer.update()
        # Vặn: hông dẫn trước, rồi lưng, rồi ngực; ngả thân trước/sau.
        tw, lean = v["twist"], v["lean"]
        rot_world(rig, "pelvis", up, tw * 0.4)
        rot_world(rig, "spine_02", up, tw * 0.35)
        rot_world(rig, "spine_03", up, tw * 0.25)
        rot_world(rig, "spine_02", left, lean * 0.6)
        rot_world(rig, "spine_03", left, lean * 0.4)
        rot_world(rig, "head", left, v["head"] - 0.45 * lean)
        rot_world(rig, "head", up, -0.5 * tw)  # mắt giữ nhìn đích khi thân vặn
        # Bàn chân phẳng như dáng duyệt (IK làm bàn chân nghiêng theo cẳng chân).
        for s_ in "lr":
            pbf = rig.pose.bones[f"foot_{s_}"]
            cur = pbf.matrix.to_translation()
            pbf.matrix = Matrix.Translation(cur) @ self.feet[s_][4].to_3x3().to_4x4()
        bpy.context.view_layer.update()
        club_arm(poser, v["hand"], v["reach"], v["side"], v["club"], (v["poleF"], 0.6, v["poleU"]),
                 sign=poser.club_sign, sweep=v["sweep"], cant=v.get("cant", 0.32))
        self.club_floor(v)
        fire_arm(poser, drop=self.defeat, aim=v["aim"], drink=v.get("drink", 0.0), face=v.get("face", 0.0))
        self.redress()
        bpy.context.view_layer.update()

    def dress_objects(self):
        """Object vải đang có (bộ dựng theo dáng duyệt trước lần redress đầu) — cho bake."""
        if self.dress is None:
            return [o for o in bpy.data.objects if o.name.startswith(("Hakama", "Apron", "Buckle")) or o.name == "Oni"]
        return list(self.dress)

    def redress(self):
        """Dựng lại hakama, tạp dề, khoá đai theo dáng hiện tại (vải rủ từ chỗ rộng nhất)."""
        if self.dress is None:  # lần đầu: bỏ bộ dựng theo dáng duyệt
            self.dress = self.dress_objects()
        for o in self.dress:
            bpy.data.objects.remove(o, do_unlink=True)
        before = set(bpy.data.objects)
        self.model.dress_lower(self.body, self.rig, self.poser, self.mats)
        self.dress = [o for o in bpy.data.objects if o not in before]

    def pose(self, t=0.0, move=None, phase=0.0):
        r = self.choreo.ready
        self.defeat = 0.0
        if move is None:  # thở: hơi nhún, ngực phồng, chuỳ nhấp theo vai, đầu khẽ gật
            w = 2 * math.pi * t
            v = dict(r)
            v.update(drop=0.012 * (1 - math.cos(w)), lean=1.2 * math.sin(w), hand=r["hand"] + 2.5 * math.sin(w),
                     head=-1.0 * math.sin(w), aim=0.06 * math.sin(w), twist=1.5 * math.sin(w + 1))
        else:
            v = self.choreo[move](phase)
            if move == "defeat":
                self.defeat = phase
            if move == "drink" and 0.18 < phase < 0.88:
                # Tu ừng ực 4 ngụm: đầu ngửa thêm, vai + bụng nảy theo từng ngụm.
                g = max(0.0, math.sin((phase - 0.18) / 0.7 * 2 * math.pi * 4))
                v["head"] = v["head"] - 8 * g
                v["lean"] = v["lean"] - 4 * g
                v["drop"] = v["drop"] - 0.02 * g
        self.move = move
        tr = self.mocap(move)
        if tr is not None:
            self.apply_mocap(v, *tr.from_ready(self.mready, phase))
        else:
            self.apply(v)
        gone = self.defeat > 0.6
        drinking = move == "drink" and 0.05 < phase < 0.9  # đổi lửa → vò ở đầu, vò → lửa ở cuối
        for o in self.fire:
            o.hide_render = gone or drinking or move == "stagger"  # lửa tắt khi gục / cầm vò / sặc
        for o in self.jar:
            o.hide_render = not drinking
        up = Vector((0, 0, 1))
        for o, m0, i in self.wisps:
            o.matrix_world = Matrix.Translation(up * 0.03 * self.model.S * math.sin(2 * math.pi * t + i * 0.8)) @ m0
            o.hide_render = gone
        bpy.context.view_layer.update()
