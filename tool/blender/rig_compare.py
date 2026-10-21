"""So sánh gắn xương: CÙNG một model Tripo, hai bộ xương — bộ mình tự gắn
(tripo_kit.build_rig + add_fingers, như tengu_boss.py) và bộ Tripo Studio tự
rig (Auto Rig, xuất kèm xương) — chạy cùng một bộ dáng thử, chụp cùng góc,
có texture và đất sét (bỏ texture, lộ chỗ lưới méo). Ảnh cho người dùng so
bằng mắt (baocao_chuong2.html, mục so sánh gắn xương).

    bash tool/blender/render.sh rig_compare ours           # tengu_001, xương tự gắn
    bash tool/blender/render.sh rig_compare tripo <tên>    # art_src/tripo/<tên>/ có xương Tripo

Dáng xoay theo trục THẾ GIỚI ở dáng nền chữ T (như tengu_boss.rot) trên tên
xương MPFB — tripo_kit.load đổi tên xương Tripo sang MPFB nên hai bộ nhận
cùng lệnh. Xương ngón: mọi hậu duệ của hand_* (tên ngón hai bộ khác nhau).
Ra build/blender/rig_compare/<nguồn>/<dáng>_{tex,clay}.png.
"""

import math
import os
import sys
import types

import bpy
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paths  # noqa: E402,F401
from boss_kit import ROOT, render_to, reset_scene, skin_material  # noqa: E402
from human_kit import camera, shadow_catcher  # noqa: E402
import tripo_kit  # noqa: E402

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
H = 2.0  # như tengu_boss.H — hai nguồn cùng cỡ, cùng khung máy quay


def tengu_ours():
    """Dựng tengu_001 như tengu_boss.build() (xương tự gắn + ngón), không chạy main()."""
    p = os.path.join(HERE, "characters", "tengu_boss.py")
    mod = types.ModuleType("tengu_boss_cmp")
    mod.__file__ = p
    src = open(p, encoding="utf-8").read().replace("\nmain()\n", "\n")
    exec(compile(src, p, "exec"), mod.__dict__)
    m, rig, _ = mod.build()
    return m, rig


def tripo_rigged(name):
    m = tripo_kit.load(name)
    if not m.rig:
        raise SystemExit(f"{name}: model không có xương — gửi bản Tripo đã Auto Rig")
    tripo_kit.normalize(m, height=H)
    miss = tripo_kit.can_review(m)
    if miss:
        print(f"[rig_compare] {name}: thiếu xương MPFB {miss} — dáng dùng xương đó bị bỏ qua")
    return m, m.rig


def reset(rig):
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)


def rot(rig, bone, axis, deg):
    """Xoay [bone] quanh trục thế giới [axis] (khung dáng nền), cộng dồn; thiếu xương thì bỏ."""
    pb = rig.pose.bones.get(bone)
    if pb is None:
        return
    local = pb.bone.matrix_local.to_3x3().inverted() @ (rig.matrix_world.to_3x3().inverted() @ Vector(axis))
    pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion(local.normalized(), math.radians(deg))


def drop_pelvis(rig, dz):
    pb = rig.pose.bones.get("pelvis")
    if pb:
        pb.location = pb.bone.matrix_local.to_3x3().inverted() @ Vector((0, 0, dz))


def fingers(rig, side):
    hand = rig.pose.bones.get(f"hand_{side}")
    return [] if hand is None else [c.name for c in hand.children_recursive]


# Dáng thử (k = 1 bên trái / +x, −1 bên phải). Dấu theo tengu_boss: tay
# trái quanh +Y dương = hạ; đùi quanh X âm = đưa tới; khuỷu trái quanh Z âm = gập tới.
def arms_down(rig, deg=62):
    for s, k in (("l", 1), ("r", -1)):
        rot(rig, f"upperarm_{s}", Y, deg * k)


def p_rest(rig):
    arms_down(rig)


def p_overhead(rig):
    for s, k in (("l", 1), ("r", -1)):
        rot(rig, f"clavicle_{s}", Y, -15 * k)
        rot(rig, f"upperarm_{s}", Y, -65 * k)


def p_elbow(rig):
    for s, k in (("l", 1), ("r", -1)):
        rot(rig, f"upperarm_{s}", Y, 35 * k)
        rot(rig, f"upperarm_{s}", Z, -35 * k)
        rot(rig, f"lowerarm_{s}", Z, -115 * k)


def p_squat(rig, knee=55):
    arms_down(rig, 45)
    for s in "lr":
        rot(rig, f"thigh_{s}", X, -knee)
        rot(rig, f"calf_{s}", X, 2 * knee)
        rot(rig, f"foot_{s}", X, -knee)
    drop_pelvis(rig, -0.87 * (1 - math.cos(math.radians(knee))))


def p_lunge(rig):
    arms_down(rig, 50)
    rot(rig, "thigh_l", X, -65)
    rot(rig, "calf_l", X, 70)
    rot(rig, "foot_l", X, -10)
    rot(rig, "thigh_r", X, 30)
    rot(rig, "calf_r", X, 35)
    rot(rig, "foot_r", X, -20)
    drop_pelvis(rig, -0.12)


def p_twist(rig):
    arms_down(rig, 55)
    for b in ("spine_01", "spine_02", "spine_03"):
        rot(rig, b, Z, 10)


def p_fist(rig):
    """Chữ T, mọi đốt ngón gập 55° xuống (lòng bàn tay úp)."""
    for s, k in (("l", 1), ("r", -1)):
        for b in fingers(rig, s):
            rot(rig, b, Y, 55 * k)


POSES = [
    ("1_ha_tay", "Đứng, hạ tay", p_rest, "full"),
    ("2_gio_tay", "Giơ hai tay qua đầu", p_overhead, "full"),
    ("3_gap_khuyu", "Gập khuỷu 115°", p_elbow, "upper"),
    ("4_khuyu_goi", "Khuỵu gối 55°", p_squat, "full"),
    ("5_buoc_dai", "Bước dài", p_lunge, "full"),
    ("6_van_than", "Vặn thân 30°", p_twist, "full"),
    ("7_nam_tay", "Nắm tay", p_fist, "hand"),
]


def frame(scene, rig, kind, yaw):
    if kind == "full":
        return camera(scene, 0.0, 1.05, 3.1, 2.4, 170, yaw=yaw, pitch=6)
    if kind == "upper":
        return camera(scene, 0.0, 1.45, 2.4, 1.3, 260, yaw=yaw, pitch=6)
    hand = rig.matrix_world @ rig.pose.bones["hand_l"].tail
    return camera(scene, hand.x, hand.z, 0.55, 0.4, 900, yaw=-20, pitch=35)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    src = args[0] if args else "ours"
    scene = reset_scene(samples=24, world_hex="#C9C4C0", world_strength=0.7)
    if src == "ours":
        m, rig = tengu_ours()
        tag = "ours"
    else:
        name = args[1] if len(args) > 1 else "tengu_rig"
        m, rig = tripo_rigged(name)
        tag = f"tripo_{name}"
    tripo_kit.default_lights(scene)
    shadow_catcher()
    out = os.path.join(ROOT, "build", "blender", "rig_compare", tag)
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "bones.txt"), "w", encoding="utf-8") as f:
        f.write(f"{len(rig.data.bones)} xương\n" + "\n".join(b.name for b in rig.data.bones) + "\n")
    clay = skin_material("Clay", "#B8B2AA", rough=0.7)
    vl = scene.view_layers[0]
    for key, label, fn, kind in POSES:
        reset(rig)
        fn(rig)
        bpy.context.view_layer.update()
        frame(scene, rig, kind, -25)
        for mode in ("tex", "clay"):
            vl.material_override = clay if mode == "clay" else None
            render_to(scene, os.path.join(out, f"{key}_{mode}.png"))
        print(f"[rig_compare] {tag} {label}")
    vl.material_override = None


main()
