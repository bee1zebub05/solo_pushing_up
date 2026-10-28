"""Thiên hoàng Sutoku hoá đại tengu (Kỳ công Heian) — model sinh bằng Tripo AI
(art_src/tripo/tengu_001/, thay hẳn bản dựng MPFB cũ 16/10/2026). Mặt đỏ mũi
dài, kimono xanh lá hoa tròn vàng, hakama lam, cánh đại bàng nâu; Tripo sinh
dáng chữ T, không xương → xương gắn ở đây (tripo_kit.build_rig), khớp đọc
trên ảnh lưới toạ độ cao 2 m. Cánh to ×1,25 và rũ xuống (dáng nền, mọi dáng).

Đòn đánh: quạt lông hauchiwa (tay phải, như bản MPFB cũ) giơ cao sau đầu,
cánh dựng xoè (lấy đà) → quạt chém xuống về phía người chơi, cánh đập tới
(ra đòn) — nhịp AttackPose của game (lib/art/motion.dart).

    bash tool/blender/render.sh tengu_boss --still           # ảnh duyệt + dáng đòn + dáng thử xương
    bash tool/blender/render.sh tengu_boss --review --quick  # bộ soát nhân vật (+ --strike: khung ra đòn)
    bash tool/blender/render.sh tengu_boss                   # xuất sprite → assets/sprites/tengu_sutoku.*
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import paths  # noqa: E402,F401  (kits/, motion/, render/ — rules/dohoa/README.md)
from bird_kit import feather_material  # noqa: E402
from boss_kit import ROOT, gold_material, render_to, reset_scene, skin_material  # noqa: E402
from human_kit import camera, shadow_catcher  # noqa: E402
from japan_kit import feather_fan, parent_posed  # noqa: E402
import tripo_kit  # noqa: E402

NAME = "tengu_001"
H = 2.0  # cao tới đỉnh búi tóc, như bản MPFB cũ (S = 1,15)
WING_SCALE = 1.25  # người dùng duyệt: cánh to hơn bản Tripo gốc
WING_DROOP = (14, 6, 10)
# Sân khấu: boss đứng bên phải nhìn sang trái (người chơi) — xoay ¾.
# Quay gần nghiêng về phía Hercules như game đối kháng (Shadow Fight, Street
# Fighter); −55° còn ló đầu cánh xa sau lưng (−70° cánh gần che hết). Mục 16.
FACING = float(os.environ.get("TENGU_FACING", -55))
UNITS_PER_M = 78  # cao 2 m ≈ 156 đơn vị sân khấu (lính đá ~145)
# Mon vàng mặt sau (người dùng yêu cầu): khuôn = mon trên ống hakama phải
# (tâm x, z; bán kính, m — đọc trên front_map có lưới), đóng tại các tâm (x, z)
# nhìn từ sau, so le như bố cục mặt trước.
MON_TEMPLATE = ((0.15, 0.65), 0.088)
MON_R = 0.08
MON_BACK = [
    (-0.11, 1.40), (0.11, 1.40),                       # lưng trên (dưới gốc cánh)
    (-0.15, 1.07), (0.15, 1.07),                       # dưới đai
    (-0.30, 0.86), (0.0, 0.88), (0.30, 0.86),          # vạt áo sau
    (-0.43, 1.45), (0.43, 1.45),                       # lưng tay áo
    (-0.21, 0.55), (0.21, 0.55),                       # hakama sau (dưới vạt áo)
]  # độ hạ từng đốt cánh (gốc, giữa, đầu) — cánh rũ, không vểnh cao

# (tên, đầu, đuôi, cha) — mặt quay −Y, thân nằm quanh y ≈ −0,38 (cánh kéo khung ra sau).
BONES = [
    ("pelvis", (0, -0.38, 0.98), (0, -0.38, 1.10), None),
    ("spine_01", (0, -0.38, 1.10), (0, -0.39, 1.25), "pelvis"),
    ("spine_02", (0, -0.39, 1.25), (0, -0.40, 1.40), "spine_01"),
    ("spine_03", (0, -0.40, 1.40), (0, -0.40, 1.55), "spine_02"),
    ("neck_01", (0, -0.40, 1.55), (0, -0.43, 1.68), "spine_03"),
    ("head", (0, -0.43, 1.68), (0, -0.43, 1.98), "neck_01"),
    ("clavicle_l", (0.04, -0.38, 1.55), (0.21, -0.36, 1.58), "spine_03"),
    ("upperarm_l", (0.21, -0.36, 1.58), (0.53, -0.33, 1.57), "clavicle_l"),
    ("lowerarm_l", (0.53, -0.33, 1.57), (0.83, -0.31, 1.56), "upperarm_l"),
    ("hand_l", (0.83, -0.31, 1.56), (1.02, -0.31, 1.55), "lowerarm_l"),
    ("thigh_l", (0.12, -0.37, 0.95), (0.20, -0.34, 0.48), "pelvis"),
    ("calf_l", (0.20, -0.34, 0.48), (0.24, -0.30, 0.09), "thigh_l"),
    ("foot_l", (0.24, -0.30, 0.09), (0.29, -0.43, 0.02), "calf_l"),
    ("ball_l", (0.29, -0.43, 0.02), (0.31, -0.50, 0.02), "foot_l"),
    # Cánh: gốc sau bả vai, vươn ra ngoài và ra sau, đầu cánh trĩu xuống.
    ("wing_01_l", (0.10, -0.20, 1.62), (0.35, 0.02, 1.84), "spine_03"),
    ("wing_02_l", (0.35, 0.02, 1.84), (0.62, 0.22, 1.86), "wing_01_l"),
    ("wing_03_l", (0.62, 0.22, 1.86), (0.95, 0.40, 1.70), "wing_02_l"),
]


def _ramp(x, a, b):
    return np.clip((x - a) / (b - a), 0, 1)


def gold_mon(rgb):
    """Độ "vàng đồng xu" của hoạ tiết mon (hoa tròn vàng): sắc 20–62°, hơi bão
    hoà, đủ sáng — loại da đỏ (~8°), tóc xám. Nới rộng để vòng mon liền nét
    (mép vòng ngả cam/tối); chỉ chép lên vải nên không lem sang da/cánh."""
    h, sat, val = tripo_kit._hsv(rgb)
    return _ramp(h, 16, 24) * (1 - _ramp(h, 60, 70)) * _ramp(sat, 0.15, 0.28) * _ramp(val, 0.32, 0.45)


def cloth(rgb):
    """Vải kimono xanh lá / hakama lam (không phải da, đai nhạt, cánh)."""
    h, sat, val = tripo_kit._hsv(rgb)
    return _ramp(h, 80, 95) * (1 - _ramp(h, 235, 250)) * _ramp(sat, 0.15, 0.25)


def build():
    m = tripo_kit.load(NAME)
    tripo_kit.normalize(m, height=H)
    # Tripo chỉ vẽ mon vàng mặt trước → đóng khuôn một mon trọn vẹn (ống hakama
    # phải, không bị đai/nếp che) lên lưng áo, lưng tay áo, hakama sau.
    img, (x0, z0, res) = tripo_kit.front_map(m, res=0.001)
    (cx, cz), r = MON_TEMPLATE
    i0, j0, k = int((cz - r - z0) / res), int((cx - r - x0) / res), int(2 * r / res)
    n = tripo_kit.stamp_back(m, img[i0:i0 + k, j0:j0 + k], [(x, z, MON_R) for x, z in MON_BACK], gold_mon, cloth,
                             out_png=os.path.join(ROOT, "build", "blender", "tengu", "texture_back.png"))
    print(f"[tengu_boss] mon vàng đóng ra sau: {len(MON_BACK)} con, {n} điểm ảnh")
    before, quads = tripo_kit.densify(m)
    print(f"[tengu_boss] lưới: {before} tam giác → {quads} mặt (ghép quad) × subsurf")
    rig, unweighted = tripo_kit.build_rig(m, BONES)
    # Tripo không có xương ngón: tự tách ngón từ lưới để nắm cán quạt, nắm đấm,
    # xoè tay chém (rules/dohoa/chuyendong.md — khớp ngón tự nhiên).
    for s_ in "lr":
        tripo_kit.add_fingers(m, rig, s_)
    return m, rig, unweighted


def rot(rig, bone, axis, deg):
    """Xoay [bone] [deg]° quanh trục THẾ GIỚI [axis] (dáng nghỉ, rig chưa xoay) — khỏi đoán
    trục cục bộ của từng xương. Cộng dồn nếu gọi nhiều lần."""
    pb = rig.pose.bones[bone]
    pb.rotation_mode = "QUATERNION"
    local = pb.bone.matrix_local.to_3x3().inverted() @ Vector(axis)  # trục theo khung rig (rig xoay được)
    pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion(local.normalized(), math.radians(deg))


def rest(rig):
    """Dáng nền: chữ T của Tripo, cánh phóng to và rũ xuống."""
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
        pb.location = (0, 0, 0)
    for s, k in (("l", 1), ("r", -1)):
        rig.pose.bones[f"wing_01_{s}"].scale = (WING_SCALE,) * 3  # đốt con thừa hưởng
        for i, deg in enumerate(WING_DROOP):
            rot(rig, f"wing_0{i + 1}_{s}", Y, deg * k)  # +x quanh +Y = hạ xuống


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def attack_pose(phase):
    """(lấy đà, ra đòn, thu về) 0–1 — bản Python của AttackPose.at (motion.dart)."""
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


def pose(rig, t=0.0, attack=-1.0, defeat=0.0):
    """Dáng tại nhịp thở [t] (0–1, lặp), tiến độ đòn [attack] (âm = không
    đánh), gục [defeat] 0–1. Mọi góc là hàm liên tục để sprite hoà khung mượt."""
    rest(rig)
    w, s_, _ = attack_pose(attack)
    d = defeat
    br = math.sin(2 * math.pi * t)  # thở: ngực phồng, cánh khẽ nâng
    # Thân: lấy đà ngả ra sau, ra đòn đổ tới; gục thì gập hẳn.
    rot(rig, "spine_02", X, -9 * w + 14 * s_ + 12 * d + 1.2 * br)
    rot(rig, "spine_03", X, -5 * w + 6 * s_ + 6 * d)
    rot(rig, "spine_02", Z, -10 * w + 14 * s_)  # vặn vai phải ra sau rồi quất tới
    rot(rig, "head", X, 6 * w - 10 * s_ + 30 * d)
    rot(rig, "neck_01", X, -4 * w)
    # Tay phải cầm quạt: hạ (chờ) → giơ cao sau đầu (lấy đà) → chém xuống trước (ra đòn).
    idle_r = 1 - max(w, s_, d)
    rot(rig, "upperarm_r", Y, -62 * idle_r + 80 * w - 18 * s_ - 70 * d)
    rot(rig, "upperarm_r", Z, -22 * w + 62 * s_)  # −: ra sau, +: ra trước (về phía người chơi)
    rot(rig, "lowerarm_r", Z, 25 * idle_r - 12 * w + 10 * s_ + 15 * d)
    # Cổ tay bẻ: quạt ngả ra sau trên đầu (lấy đà, phải lộ rõ — đây là dấu
    # hiệu đòn) rồi quất; gục thì quạt trĩu xuống theo tay buông.
    rot(rig, "hand_r", Y, 20 * w - 30 * s_ - 40 * d)
    rot(rig, "hand_r", X, -65 * idle_r + 70 * w - 95 * s_)  # lật cổ tay: quạt dựng / ngả sau / quất tới
    # Tay trái: đưa tới giữ thăng bằng khi lấy đà, kéo về khi chém.
    rot(rig, "upperarm_l", Y, 62 * (1 - w * 0.55) + 8 * d)
    rot(rig, "upperarm_l", Z, 35 * w - 20 * s_)
    rot(rig, "lowerarm_l", Z, -25 - 30 * w + 10 * s_)
    # Cánh: dựng xoè lên (lấy đà) → đập xuống và tới (ra đòn) → rũ cụp (gục).
    for sd, k in (("l", 1), ("r", -1)):
        # Gục: thân gập tới làm cánh (chĩa ra sau) vểnh lên → hạ bù mạnh.
        rot(rig, f"wing_01_{sd}", Y, (-38 * w + 26 * s_ + 72 * d - 3 * br) * k)
        rot(rig, f"wing_01_{sd}", Z, (-10 * w - 30 * s_ - 15 * d) * k)  # −k: tới trước
        rot(rig, f"wing_02_{sd}", Y, (-16 * w + 14 * s_ + 30 * d) * k)
        rot(rig, f"wing_03_{sd}", Y, (-8 * w + 18 * s_ + 22 * d) * k)
    # Chân: tấn hơi chùng; ra đòn khuỵu sâu; gục quỵ gối (hông hạ theo góc gối).
    knee = 6 + 4 * w + 10 * s_ + 44 * d
    for sd in ("l", "r"):
        rot(rig, f"thigh_{sd}", X, -knee)
        rot(rig, f"calf_{sd}", X, 2 * knee)
        rot(rig, f"foot_{sd}", X, -knee)
    drop = 0.87 * (1 - math.cos(math.radians(knee))) - 0.87 * (1 - math.cos(math.radians(6)))
    rig.pose.bones["pelvis"].location = (0, -drop, -0.04 * d)  # xương pelvis dọc +Z: y cục bộ = lên
    bpy.context.view_layer.update()


def idle(rig):
    """Dáng chờ trận (ảnh duyệt, bộ soát)."""
    pose(rig)


def fan(rig):
    """Quạt lông hauchiwa trong tay phải — dựng ở dáng nền (chữ T), gắn xương tay."""
    rest(rig)
    bpy.context.view_layer.update()
    pb = rig.pose.bones["hand_r"]
    mw = rig.matrix_world
    grip = mw @ pb.head.lerp(pb.tail, 0.4)
    # Lông sẫm: quạt nâu nhạt chìm vào cánh nâu ở khung ra đòn.
    feather = feather_material("FanFeather", "#141010", "#4A3C34", sheen="#C8A060", metallic=0.2, rough=0.45)
    black = skin_material("Lacquer", "#0C0A0C", rough=0.4)
    gold = gold_material("TenguGold", "#D8A848", rough=0.3)
    # Cán vuông góc với ngón, xuyên lòng bàn tay (dáng chữ T úp bàn tay: cán
    # chĩa ra trước); quạt dựng lên nhờ xoay cổ tay quanh trục cánh tay (pose).
    up = mw.to_3x3() @ Vector((0, -1, 0.1))
    face = mw.to_3x3() @ Vector((0, 0, 1))
    objs = feather_fan("Fan", grip, up, face, (feather, black, gold), scale=1.15)
    for o in objs:
        parent_posed(o, rig, "hand_r")
    global FAN_HANDLE, FAN_FACE
    inv = rig.data.bones["hand_r"].matrix_local.to_3x3().inverted()
    FAN_HANDLE = (inv @ Vector((0, -1, 0.1))).normalized()
    FAN_FACE = (inv @ Vector((0, 0, 1))).normalized()  # pháp tuyến mặt quạt (feather_fan: face)
    return objs


FAN_HANDLE = Vector((0, 0, 1))  # hướng cán quạt trong khung xương hand_r (fan() đặt lại)
FAN_FACE = Vector((1, 0, 0))  # pháp tuyến mặt quạt trong khung xương hand_r


def test_poses(rig):
    """Dáng thử xương: tay giơ, cánh vỗ lên, chân co, thân vặn — lộ chỗ trọng số sai."""
    rest(rig)
    rot(rig, "upperarm_l", Y, -40)
    rot(rig, "lowerarm_l", Z, -80)
    rot(rig, "upperarm_r", Y, 70)
    for s, k in (("l", 1), ("r", -1)):
        rot(rig, f"wing_01_{s}", Y, -30 * k)
        rot(rig, f"wing_02_{s}", Y, -20 * k)
    rot(rig, "thigh_l", X, -55)
    rot(rig, "calf_l", X, 75)
    rot(rig, "spine_02", Z, 15)
    rot(rig, "head", X, -12)
    bpy.context.view_layer.update()


from tengu_motion import TenguMotion as _TenguMotion  # noqa: E402


def TenguMotion(rig):
    """Lớp chuyển động (tool/motion/tengu_motion.py) gắn với nhân vật này."""
    return _TenguMotion(rig, sys.modules[__name__])


def face_game(rig, on=True, extra=0.0):
    """Xoay rig ¾ quanh trục đứng qua chân (thân ở y ≈ −0,38, không ở gốc) —
    chân giữ nguyên ở (0, 0): điểm neo sprite. [extra]: xoay thêm (độ) theo
    biên đạo (kênh `turn`)."""
    a = math.radians((FACING - extra) if on else 0)  # FACING âm = quay trái; turn + = quay thêm sang trái
    body = Vector((0, -0.38, 0))
    rig.rotation_euler.z = a
    rig.location = -(Quaternion(Z, a) @ body) + (Vector() if on else body)
    bpy.context.view_layer.update()


def game_camera(scene, ppm):
    """Góc sân khấu: rig xoay ¾ nhìn sang trái màn hình, máy quay hơi chúc
    như các quái khác; khung đủ cho cánh dựng cao, quạt chém ra trước và cú
    nhảy Thiên cẩu phi (đỉnh nhảy ~0,8 m)."""
    return camera(scene, -0.35, 1.65, 4.0, 3.7, ppm, yaw=-8, pitch=6)  # lunge mocap vươn xa hơn


def main():
    quick = "--quick" in sys.argv
    scene = reset_scene(samples=16 if quick else 64, world_hex="#C9C4C0", world_strength=0.7)
    m, rig, unweighted = build()
    fan(rig)
    tripo_kit.default_lights(scene)
    shadow_catcher()
    out = os.path.join(ROOT, "build", "blender", "tengu")
    os.makedirs(out, exist_ok=True)
    if "--dry" in sys.argv:  # dựng cảnh không render; TENGU_DEBUG = script soát chạy thêm
        if os.environ.get("TENGU_DEBUG"):
            exec(open(os.environ["TENGU_DEBUG"], encoding="utf-8").read())
        return
    if "--mocap-ready" in sys.argv:  # dáng chờ → art_src/mocap/ready (compose.py)
        import mocap_drive as md
        motion = TenguMotion(rig)
        origin, _ = motion.anchor()
        md.dump_ready(motion.minfo, motion.basis(), origin, "tengu_sutoku")
        return
    if "--review" in sys.argv:  # bộ soát cố định + kiểm tra tự động (review_kit), không lưu .blend
        from review_kit import review
        if "--strike" in sys.argv:
            TenguMotion(rig).pose(move="attack", phase=0.6)
        else:
            idle(rig)
        review(scene, m.body, rig, "tengu_boss", H / 1.75, tripo_kit.forward(), free=[r"^wing", r"^Fan"],
               important={"quạt lông": [r"^Fan"]}, embedded=[r"^FanHandle"],
               targets={"chân (khớp háng)/chiều cao": (0.44, 0.52)}, samples=16 if quick else 32)
        return
    if "--motion-review" in sys.argv:  # bộ soát chuyển động (tool/motion/motion_review.py), không render
        from motion_review import review_motion
        face_game(rig)
        motion = TenguMotion(rig)
        motion.facing = True
        review_motion(motion, m.body, rig, "tengu_boss", "tengu_sutoku", weapons=[r"^Fan"], grip=("hand_r", 0.14))
        return
    if "--video" in sys.argv:  # khung video từng đòn (tool/render/boss_video.py ghép mp4)
        face_game(rig)
        game_camera(scene, 150)
        motion = TenguMotion(rig)
        motion.facing = True
        from video_frames import video_frames
        a = sys.argv
        moves = a[a.index("--moves") + 1].split(",") if "--moves" in a else ("attack", "attack2")  # chỉ đòn đã sửa
        video_frames(scene, motion, out, moves=moves, quick="--quick" in a)
        return
    if "--still" in sys.argv:
        # Ảnh duyệt chính diện (như bản MPFB cũ) + dáng thử xương.
        idle(rig)
        camera(scene, 0.0, 1.1, 3.1, 2.4, 260, yaw=-8, pitch=6)
        render_to(scene, os.path.join(out, "still_full.png"))
        pb = rig.pose.bones["head"]
        head = rig.matrix_world @ pb.head.lerp(pb.tail, 0.5)
        camera(scene, head.x - 0.05, head.z, 0.7, 0.7, 900, yaw=-8, pitch=4)
        render_to(scene, os.path.join(out, "still_face.png"))
        for tag, yaw in (("test", -8), ("test_side", -60)):
            test_poses(rig)
            camera(scene, 0.0, 1.1, 3.1, 2.4, 260, yaw=yaw, pitch=6)
            render_to(scene, os.path.join(out, f"check_pose_{tag}.png"))
        # Tư thế khoá của từng đòn (biên đạo), góc sân khấu. TENGU_MOVE = một đòn.
        face_game(rig)
        game_camera(scene, 160)
        motion = TenguMotion(rig)
        motion.facing = True
        keys = [("attack", t) for t in (0.14, 0.36, 0.48, 0.52, 0.55, 0.58, 0.6, 0.72, 0.86)]
        keys += [("attack2", t) for t in (0.25, 0.36, 0.39, 0.5, 0.56, 0.585, 0.61, 0.635, 0.65, 0.7)]
        keys += [("write", t) for t in (0.15, 0.42, 0.55, 0.7, 0.92)]
        keys += [("defeat", 0.4), ("defeat", 1.0)]
        only = os.environ.get("TENGU_MOVE")
        for move, t in keys:
            if only and move != only.split("@")[0] or "@" in (only or "") and abs(t - float(only.split("@")[1])) > 1e-6:
                continue
            motion.pose(move=move, phase=t)
            bl = rig.pose.bones
            for s_ in "lr":  # gối nhô ra trước (+) hay choãi ngang: số đo cho POLE_ANGLE
                hip, knee, ank = (bl[f"thigh_{s_}"].head, bl[f"calf_{s_}"].head, bl[f"foot_{s_}"].head)
                off = knee - (hip + ank) / 2
                print(f"[tengu_knee] {move} {t} {s_}: trước {-off.y:.3f} ngang {off.x:.3f}")
                sh, el, wr = (bl[f"upperarm_{s_}"].head, bl[f"lowerarm_{s_}"].head, bl[f"hand_{s_}"].head)
                pole = rig.matrix_world.inverted() @ motion.ik[f"arm_{s_}"][1].location
                mid = (sh + wr) / 2
                print(f"[tengu_elbow] {s_}: khuỷu theo pole {(el - mid).normalized().dot((pole - mid).normalized()):.2f}")
            render_to(scene, os.path.join(out, "keys", f"{move}_{round(t * 1000):04d}.png"))
        if only:
            return
        face_game(rig, False)
        print(f"[tengu_boss] đỉnh không trọng số: {unweighted}")
        from boss_kit import save_blend
        save_blend("tengu_boss")
        return
    # Sprite: cổng soát chuyển động → kế hoạch khung (dày quanh mốc chạm) → nướng thành
    # khoá (art_src/blender/tengu_sutoku_anim.blend + track tư thế 2.5D) → xuất TỪ bản nướng.
    # Cử chỉ cơ chế: viết ấn nguyền (japan_sprite_boss.scriptedMove).
    from motion_review import gate
    gate("tengu_boss", "tengu_sutoku")
    from bake import bake, setups_from
    from sprite_kit import export_sprites
    from sprite_plan import plan
    scene.cycles.samples = 16 if quick else 64
    face_game(rig)
    cam = game_camera(scene, 3.0 * UNITS_PER_M)
    motion = TenguMotion(rig)
    motion.facing = True
    anims, phases = plan(motion, "tengu_sutoku", {"idle": 8, "attack": 20, "attack2": 20, "defeat": 6, "write": 10})
    extra = {"idlePeriod": 3.2, "phases": phases}
    frames = bake(rig, anims, "tengu_sutoku", cam, (0, 0, 0), UNITS_PER_M, weapons=[r"^Fan"], extra=extra)
    export_sprites(scene, cam, "tengu_sutoku", setups_from(frames), (0, 0, 0), UNITS_PER_M, extra=extra)


main()
