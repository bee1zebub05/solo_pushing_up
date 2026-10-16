"""Thiên hoàng Sutoku hoá đại tengu (Kỳ công Heian) — model sinh bằng Tripo AI
(art_src/tripo/tengu_001/, thay hẳn bản dựng MPFB cũ 16/10/2026). Mặt đỏ mũi
dài, kimono xanh lá hoa tròn vàng, hakama lam, cánh đại bàng nâu; Tripo sinh
dáng chữ T, không xương → xương gắn ở đây (tripo_kit.build_rig), khớp đọc
trên ảnh lưới toạ độ cao 2 m. Cánh to ×1,25 và rũ xuống (dáng nền, mọi dáng).

    bash tool/blender/render.sh tengu_boss --still           # ảnh duyệt + dáng thử xương
    bash tool/blender/render.sh tengu_boss --review --quick  # bộ soát nhân vật
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Quaternion, Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import ROOT, render_to, reset_scene  # noqa: E402
from human_kit import camera, shadow_catcher  # noqa: E402
import tripo_kit  # noqa: E402

NAME = "tengu_001"
H = 2.0  # cao tới đỉnh búi tóc, như bản MPFB cũ (S = 1,15)
WING_SCALE = 1.25  # người dùng duyệt: cánh to hơn bản Tripo gốc
WING_DROOP = (14, 6, 10)
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
    return m, rig, unweighted


def rot(rig, bone, axis, deg):
    """Xoay [bone] [deg]° quanh trục THẾ GIỚI [axis] (dáng nghỉ) — khỏi đoán
    trục cục bộ của từng xương. Cộng dồn nếu gọi nhiều lần."""
    pb = rig.pose.bones[bone]
    pb.rotation_mode = "QUATERNION"
    local = (rig.matrix_world.to_3x3() @ pb.bone.matrix_local.to_3x3()).inverted() @ Vector(axis)
    pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion(local.normalized(), math.radians(deg))


def rest(rig):
    """Dáng nền: chữ T của Tripo, cánh phóng to và rũ xuống."""
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    for s, k in (("l", 1), ("r", -1)):
        rig.pose.bones[f"wing_01_{s}"].scale = (WING_SCALE,) * 3  # đốt con thừa hưởng
        for i, deg in enumerate(WING_DROOP):
            rot(rig, f"wing_0{i + 1}_{s}", Y, deg * k)  # +x quanh +Y = hạ xuống


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def idle(rig):
    """Dáng chờ trận: tay hạ xuống (bỏ chữ T), khuỷu hơi gập ra trước, gối hơi chùng."""
    rest(rig)
    for s, k in (("l", 1), ("r", -1)):
        rot(rig, f"upperarm_{s}", Y, 62 * k)       # +x quanh +Y = hạ xuống
        rot(rig, f"lowerarm_{s}", Z, -25 * k)      # cẳng tay gập ra trước (−Y)
        rot(rig, f"thigh_{s}", X, -6)              # đùi ra trước
        rot(rig, f"calf_{s}", X, 12)               # gối chùng
    bpy.context.view_layer.update()


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


def main():
    quick = "--quick" in sys.argv
    scene = reset_scene(samples=16 if quick else 64, world_hex="#C9C4C0", world_strength=0.7)
    m, rig, unweighted = build()
    tripo_kit.default_lights(scene)
    shadow_catcher()
    out = os.path.join(ROOT, "build", "blender", "tengu")
    os.makedirs(out, exist_ok=True)
    if "--review" in sys.argv:  # bộ soát cố định + kiểm tra tự động (review_kit), không lưu .blend
        from review_kit import review
        idle(rig)
        review(scene, m.body, rig, "tengu_boss", H / 1.75, tripo_kit.forward(), free=[r"^wing"],
               targets={"chân (khớp háng)/chiều cao": (0.44, 0.52)}, samples=16 if quick else 32)
        return
    # Ảnh duyệt (như bản MPFB cũ) + dáng thử xương.
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
    print(f"[tengu_boss] đỉnh không trọng số: {unweighted}")
    from boss_kit import save_blend
    save_blend("tengu_boss")

main()
