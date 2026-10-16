# blender: user-prefs  (cần tiện ích MPFB — xem tool/blender/render.sh)
"""Harpy chương 1 (fantasy realism): mình chim mặt người, "kẻ cướp" lượn
quanh đền chờ người lơ là. Đầu và vai người già gầy (da tái xám, mắt đỏ
rực, tóc bạc dài bay rối), từ ngực trở xuống là thân chim lông xám tím xếp
ngói, cổ áo lông xù hai lớp, cánh thay tay (bird_kit), chân chim vảy sừng
với móng quắp đen; đuôi lông rách tả tơi.

    bash tool/blender/render.sh harpy --still
    bash tool/blender/render.sh harpy            # hoạt hình + atlas

Quay mặt sang trái. Ra đòn (= sà xuống quắp vàng) theo `AttackPose`: lấy đà
ngả ra sau giương cánh, co móng; ra đòn chúi tới, móng vươn ra trước.
Gốc toạ độ: mặt đất ngay dưới thân (Harpy lơ lửng).
"""

import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import (ROOT, STILL, add_object, add_sun, attack_pose, ellipsoids_mesh, fur_material,  # noqa: E402
                      glow_material, parent_to_bone, render_to, reset_scene, save_blend, skin_material, srgb,
                      with_fur)
from bird_kit import E, Wing, blade, feather_material, flap_cycle, plumage  # noqa: E402
from greek_kit import make_group  # noqa: E402
from human_kit import (camera, group_center, make_human, raw_ellipsoid, raw_tube, rest_coords,  # noqa: E402
                       shell_copy, store_point_attr, weights_by_group)
from sprite_kit import export_sprites  # noqa: E402

K = 0.92
HOVER = 0.62  # độ cao lơ lửng của gốc khung xương (m)
# Đơn vị sân khấu cho 1 m: Harpy (cả cánh) cao ~120 như bản vector (×1,5).
UNITS_PER_M = 62
FRONT = Vector((-1, 0, 0))
UP = Vector((0, 0, 1))

ARM_GROUPS = ("upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky")
LEG_GROUPS = ("thigh", "calf", "foot", "ball")


def build():
    body, rig = make_human(0.0, muscle=0.3, weight=0.2, height=0.45, age=0.85, scale=K,
                           race={"asian": 0.1, "caucasian": 0.8, "african": 0.1})
    rig.rotation_euler = (0, 0, -math.pi / 2)
    bpy.context.view_layer.update()
    co = rest_coords(body)
    skin = skin_material("HagSkin", "#A89C90", rough=0.6, sss=0.25, noise_scale=40)
    body.data.materials.clear()
    body.data.materials.append(skin)

    # Bỏ tay và chân người: cánh thay tay, thân chim + chân chim thay chân.
    def cut(i, g):
        arm = sum(v for k, v in g.items() if k.split("_")[0] in ARM_GROUPS)
        leg = sum(v for k, v in g.items() if k.split("_")[0] in LEG_GROUPS)
        return arm > 0.5 or leg > 0.35

    make_group(body, "cut", cut)
    mask = body.modifiers.new("Cut", "MASK")
    mask.vertex_group = "cut"
    mask.invert_vertex_group = True
    body.modifiers.move(body.modifiers.find("Cut"), body.modifiers.find("Smooth"))

    def world_bone(name, at=0.0):
        b = rig.data.bones[name]
        return rig.matrix_world @ b.head_local.lerp(b.tail_local, at)

    dark = feather_material("HarpyPlumage", "#1E1824", "#7C6C80", sheen="#B8A8C8", metallic=0.25, rough=0.45)
    wing_mat = feather_material("HarpyWing", "#18121C", "#6A5874", sheen="#A898B8", metallic=0.3, rough=0.42)
    talon = skin_material("Talon", "#14100E", rough=0.25)
    scaly = skin_material("Shank", "#5E5048", rough=0.5, noise_scale=220)

    # Thân chim từ ngực tới hông: khối liền phủ lông xếp ngói, ngọn chĩa xuống.
    pel = world_bone("pelvis")
    sp2 = world_bone("spine_03")
    to_m = lambda v: (v.x, v.y, v.z)  # noqa: E731
    fb = ellipsoids_mesh("FeatherBody", [
        E(to_m(sp2 + Vector((-0.01, 0, 0.05))), (0.13 * K, 0.13 * K, 0.12 * K)),
        E(to_m(sp2 + Vector((0.0, 0, -0.04))), (0.15 * K, 0.135 * K, 0.15 * K)),
        E(to_m((sp2 + pel) / 2), (0.15 * K, 0.135 * K, 0.17 * K)),
        E(to_m(pel + Vector((0.02, 0, -0.04))), (0.16 * K, 0.13 * K, 0.14 * K)),
        E(to_m(pel + Vector((0.14, 0, -0.08))), (0.12 * K, 0.08 * K, 0.08 * K), -20),
    ], voxel=0.012, smooth_iter=6)
    feather_body = add_object("FeatherBody", fb, [dark])
    store_point_attr(feather_body, "feather_t", [0.2] * len(fb.vertices))
    plum = plumage("FeatherCoat", feather_body, dark, density=0.016, length=(0.07, 0.1), width=0.02,
                   small_front=-99, flow=(0.35, 0, -1), seed=11)
    for o in (feather_body, plum):
        parent_to_bone(o, rig, "spine_01")

    # Cổ áo lông xù hai lớp quanh chân cổ.
    neck = world_bone("neck_01")
    ruff_mesh = ellipsoids_mesh("Ruff", [E(to_m(neck + Vector((0.01, 0, -0.03))),
                                          (0.13 * K, 0.08 * K, 0.13 * K))], voxel=0.01, smooth_iter=4)
    ruff = add_object("Ruff", ruff_mesh, [dark])
    store_point_attr(ruff, "feather_t", [0.6] * len(ruff_mesh.vertices))
    ruff_f = plumage("RuffCoat", ruff, dark, density=0.011, length=(0.1, 0.15), width=0.022, small_front=-99,
                     flow=(0.4, 0, -1), seed=5)
    for o in (ruff, ruff_f):
        parent_to_bone(o, rig, "spine_03")

    # Đuôi rách tả tơi: lông dài so le, vài chiếc gãy ngắn.
    tail_root = pel + Vector((0.2 * K, 0, -0.1 * K))
    for i in range(7):
        yy = (i - 3) * 0.02
        L = (0.36 - abs(i - 3) * 0.03 - (0.12 if i in (1, 5) else 0)) * K
        d = Vector((0.6, yy * 3, -1.0 + 0.08 * i))
        t = blade(f"Tail{i}", tail_root + Vector((0, yy, 0)), d, (0, -0.8, 0.4), L, 0.03 * K, wing_mat,
                  curve=0.08, tone=0.4 + 0.1 * (i % 3))
        parent_to_bone(t, rig, "pelvis")

    # Chân chim: đùi lông, cẳng vảy sừng, bốn ngón móng quắp (tư thế đổi ở pose()).
    legs = []
    for s, side in ((-1, "l"), (1, "r")):
        hip = pel + Vector((0.0, s * 0.08 * K, -0.1 * K))
        pivot = bpy.data.objects.new(f"Leg_{side}", None)
        bpy.context.scene.collection.objects.link(pivot)
        pivot.location = hip
        knee = Vector((-0.05, 0, -0.18)) * K
        ankle = Vector((0.02, 0, -0.38)) * K
        thigh = add_object("Thigh", raw_tube("Thigh", [Vector(), knee], [0.06 * K, 0.035 * K], sides=16), [dark])
        shank = add_object("Shank", raw_tube("Shank", [knee, ankle], [0.022 * K, 0.017 * K], sides=12), [scaly])
        parts = [thigh, shank]
        for k, (dx, dy) in enumerate(((1, 0), (0.8, -0.45), (0.8, 0.45), (-0.7, 0))):
            d = Vector((-dx, dy * s, 0)).normalized()
            t1 = ankle + (d * 0.07 + Vector((0, 0, -0.02))) * K
            t2 = t1 + (d * 0.03 + Vector((0, 0, -0.045))) * K
            parts.append(add_object("Toe", raw_tube("Toe", [ankle, t1], [0.012 * K, 0.009 * K], sides=10), [scaly]))
            parts.append(add_object("Claw", raw_tube("Claw", [t1, t2], [0.009 * K, 0.0008], sides=10), [talon]))
        for o in parts:
            o.parent = pivot
        parent_to_bone(pivot, rig, "pelvis")
        legs.append(pivot)

    # Cánh thay tay, mọc từ vai.
    wings = []
    for side, far in (("l", False), ("r", True)):
        sh = world_bone(f"upperarm_{side}")
        w = Wing(f"Wing{side}", sh, wing_mat, dark, far=far, span=(0.3, 0.42, 0.3), scale=1.55,
                 seed=3 if far else 8, primaries=11, secondaries=13)
        for part in w.parts:
            store_point_attr(part, "feather_t", [0.5] * len(part.data.vertices))
        parent_to_bone(w.joints[0], rig, "spine_03")
        wings.append(w)

    # Mắt đỏ rực.
    glow = glow_material("HarpyEye", "#FF3020", strength=10)
    for g in ("helper-l-eye", "helper-r-eye"):
        c = group_center(body, g, co)
        e = add_object("Eye", raw_ellipsoid("Eye", c, (0.0095 * K,) * 3), [glow])
        parent_to_bone(e, rig, "head")

    # Tóc bạc dài bay rối ra sau.
    hair = fur_material("HagHair", [(0.0, "#C8C2B8"), (0.5, "#7E7870"), (1.0, "#2E2A28")], sheen=0.05)
    scalp = shell_copy(body, "Scalp", "scalp", 0.012, 0.0, [skin_material("ScalpBase", "#5A5650", rough=0.7)])
    scalp.add_rest_position_attribute = True
    with_fur(scalp, hair, density=90000 / K ** 2, length=(0.2 * K, 0.4 * K), radius=0.0013 * K,
             comb=(2.4, 0, -1.2), lift=0.25, gravity=0.14 * K, jitter=0.35, seed=21, resolution=10)
    return body, rig, wings, legs


class Poser:
    def __init__(self, rig, wings, legs):
        self.rig, self.wings, self.legs = rig, wings, legs

    def pose(self, phase=0.0, attack=-1.0):
        rig = self.rig
        windup, strike, recover = attack_pose(attack)
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0)
        lift, fold = flap_cycle(phase % 1.0)
        bob = -0.04 * math.sin(2 * math.pi * phase)
        # Thân ngả tới như chim lượn; lấy đà ngửa ra sau, ra đòn chúi tới.
        lean = math.radians(32 - 28 * windup + 30 * strike + 6 * recover)
        rig.pose.bones["spine_01"].rotation_euler.x = lean * 0.4
        rig.pose.bones["spine_02"].rotation_euler.x = lean * 0.35
        rig.pose.bones["spine_03"].rotation_euler.x = lean * 0.25
        # Đầu luôn nhìn về phía người chơi, ra đòn thì ngẩng hơn (gầm rít).
        rig.pose.bones["neck_01"].rotation_euler.x = -lean * 0.7 - math.radians(10 * strike)
        rig.pose.bones["head"].rotation_euler.x = -lean * 0.3
        rig.location = Vector((0.15 * windup - 0.35 * strike, 0, HOVER + bob + 0.1 * windup - 0.12 * strike))
        flap = lift * (1 - windup) * (1 - strike) + math.radians(75) * windup + math.radians(20) * strike
        fold = fold * (1 - windup) * (1 - strike) + 0.25 * windup + 0.3 * strike
        sweep = -math.radians(25) * strike + math.radians(10) * windup
        for w in self.wings:
            w.pose(flap, fold, sweep)
        # Chân: co sát bụng khi lượn/lấy đà, vươn tới trước quắp khi ra đòn.
        reach = strike
        for leg in self.legs:
            leg.rotation_euler = Euler((0, math.radians(-25 + 20 * windup - 75 * reach), 0), "XYZ")
        bpy.context.view_layer.update()


def lights(scene):
    add_sun(scene, "Key", (0.55, 0.6, -0.6), 4.5, "#FFE0B4", angle=2.5)
    add_sun(scene, "Rim", (0.7, -0.4, -0.35), 3.5, "#C8D8FF", angle=4)
    add_sun(scene, "Bounce", (-0.1, 0.3, 0.9), 0.6, "#C8A880", angle=30)


def main():
    scene = reset_scene(samples=96, world_hex="#9DB6D2", world_strength=0.5, keep_prefs=True)
    body, rig, wings, legs = build()
    poser = Poser(rig, wings, legs)
    lights(scene)
    out = os.path.join(ROOT, "build", "blender", "greek")
    os.makedirs(out, exist_ok=True)
    if STILL:
        camera(scene, 0.1, 1.75, 2.5, 2.5, 300, yaw=-18, pitch=8)
        shots = [("glide", dict(phase=0.0)), ("down", dict(phase=0.3)), ("windup", dict(attack=0.45)),
                 ("strike", dict(attack=0.6))]
        for name, kw in shots:
            poser.pose(**kw)
            render_to(scene, os.path.join(out, f"harpy_{name}.png"))
        poser.pose()
        save_blend("harpy")
        return
    scene.cycles.samples = 64
    cam = camera(scene, 0.1, 1.75, 2.5, 2.5, 190, yaw=-18, pitch=8)
    anims = {
        "idle": [lambda k=k: poser.pose(phase=k / 10) for k in range(10)],
        "attack": [lambda k=k: poser.pose(attack=k / 7) for k in range(8)],
    }
    export_sprites(scene, cam, "harpy", anims, (0, 0, 0), UNITS_PER_M, extra={"idlePeriod": 0.9})


main()
