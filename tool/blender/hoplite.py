# blender: user-prefs  (cần tiện ích MPFB — xem tool/blender/render.sh)
"""Chiến binh hoplite chương 1 (fantasy realism), hai biến thể:

- Lính đá (mặc định): tượng chiến binh cẩm thạch bị Trì Trệ làm sống dậy —
  vân đá, rêu đọng khe, đường nứt rỉ ánh tím; mũ Corinth, giáp ngực, khiên,
  giáo đều tạc cùng khối đá.
- Spartoi (`--spartoi`): "người gieo" mọc từ răng rồng (Cadmus, Jason) — thân
  đất sét nứt nẻ rỉ lửa, giáp đồng có gỉ xanh, mào lông ngựa đỏ, mắt lửa;
  trồi lên từ đất (`rise`).

    bash tool/blender/render.sh hoplite --still
    bash tool/blender/render.sh hoplite --still --spartoi

Quay mặt sang trái (về phía người chơi). Tay trái (gần máy quay) cầm khiên,
tay phải cầm giáo giương ngang vai (thế đâm từ trên xuống của hoplite).
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import (ARGS, ROOT, STILL, add_object, add_sun, attack_pose, fur_material,  # noqa: E402
                      glow_material, parent_to_bone, render_to, reset_scene, save_blend, smooth)
from greek_kit import (aspis, bronze_material, clay_material, corinthian_helmet, cuirass, dory,  # noqa: E402
                       greaves, helmet_crest, holder, make_fist, marble_material, pteruges, wood_material)
from human_kit import (arm_ik, camera, group_center, make_human, raw_ellipsoid, rest_coords,  # noqa: E402
                       shadow_catcher)

SPARTOI = "--spartoi" in ARGS
K = 1.12 if not SPARTOI else 1.05
FRONT = Vector((-1, 0, 0))
UP = Vector((0, 0, 1))
NEAR = Vector((0, -1, 0))


def build():
    body, rig = make_human(1.0, muscle=0.95, weight=0.55, height=0.7, age=0.45, scale=K,
                           race={"asian": 0.2, "caucasian": 0.7, "african": 0.1})
    rig.rotation_euler = (0, 0, -math.pi / 2)  # quay mặt sang trái
    bpy.context.view_layer.update()
    co = rest_coords(body)
    if SPARTOI:
        skin = clay_material("Clay")
        metal = bronze_material("Bronze", polish=0.8)
        trim = bronze_material("BronzeDark", base="#7A5228", rough=0.45, polish=0.4)
        strap = clay_material("Strap", base="#3A2414", glow_strength=0.0)
    else:
        skin = marble_material("Marble")
        metal = marble_material("MarbleArmor", base="#DCD6CA", glow_strength=3.0)
        trim = metal
        strap = metal
    body.data.materials.clear()
    body.data.materials.append(skin)

    corinthian_helmet(body, rig, co, metal)
    if SPARTOI:
        horse = fur_material("Horsehair", [(0.0, "#C0301C"), (0.6, "#8A1A10"), (1.0, "#3A0806")], sheen=0.1)
        helmet_crest(body, rig, co, trim, hair_mat=horse, height=0.05)
    else:
        helmet_crest(body, rig, co, metal, height=0.075, width=0.016)
    cuirass(body, rig, co, metal)
    greaves(body, rig, co, metal)
    pteruges(body, rig, co, strap)

    # Mắt: lửa (Spartoi) hoặc ánh tím Trì Trệ (lính đá) sau khe mũ.
    glow = glow_material("EyeGlow", "#FF8A2A" if SPARTOI else "#B07CFF", strength=14)
    for g in ("helper-l-eye", "helper-r-eye"):
        c = group_center(body, g, co)
        e = add_object("Eye", raw_ellipsoid("Eye", c, (0.012 * K,) * 3), [glow])
        parent_to_bone(e, rig, "head")

    spear = holder("Spear", dory("Dory", wood_material() if SPARTOI else metal, metal))
    shield = holder("Shield", aspis("Aspis", metal, rim_mat=trim, emblem_mat=trim))
    if SPARTOI:
        # Đất vụn quanh chỗ trồi lên + mặt đất che phần thân còn dưới đất.
        ground = add_object("Earth", raw_ellipsoid("Earth", Vector((0, 0, -3)), (30, 30, 3)), [])
        ground.is_holdout = True
    return body, rig, spear, shield


class Poser:
    def __init__(self, rig, spear, shield):
        self.rig, self.spear, self.shield = rig, spear, shield
        self.ik = arm_ik(rig)

    def world(self, bone, at=0.0):
        pb = self.rig.pose.bones[bone]
        return self.rig.matrix_world @ pb.head.lerp(pb.tail, at)

    def pose(self, t=0.0, attack=-1.0, rise=1.0, defeat=0.0):
        rig = self.rig
        windup, strike, recover = attack_pose(attack)
        breath = math.sin(t * 2 * math.pi)
        fall = smooth(defeat)
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0)
        # Thế đứng hoplite: chân trái bước trước, gối hơi chùng.
        rig.pose.bones["thigh_l"].rotation_euler.x = math.radians(-14)
        rig.pose.bones["thigh_r"].rotation_euler.x = math.radians(12)
        rig.pose.bones["calf_l"].rotation_euler.x = math.radians(10)
        rig.pose.bones["calf_r"].rotation_euler.x = math.radians(8)
        lean = math.radians(6 - 10 * windup + 14 * strike + 3 * breath * 0.3 + 30 * fall)
        rig.pose.bones["spine_02"].rotation_euler.x = lean * 0.6
        rig.pose.bones["spine_03"].rotation_euler.x = lean * 0.4
        rig.pose.bones["neck_01"].rotation_euler.x = -lean * 0.6
        make_fist(rig, "l")
        make_fist(rig, "r")
        sink = (1 - rise) * 1.9 * K + 0.3 * K * fall
        rig.location = (0, 0, -sink)
        bpy.context.view_layer.update()

        sh_l = self.world("upperarm_l")  # gần máy quay: khiên
        sh_r = self.world("upperarm_r")  # xa: giáo
        arm = 0.6 * K
        tl, pl, *_ = self.ik["l"]
        tl.location = sh_l + FRONT * arm * (0.5 + 0.15 * strike) - UP * arm * 0.45 + NEAR * 0.1 * K
        pl.location = sh_l - UP * arm + NEAR * 0.6 * K
        tr, pr, *_ = self.ik["r"]
        idle_h = sh_r + UP * arm * 0.12 - FRONT * arm * 0.25
        back_h = sh_r + UP * arm * 0.3 - FRONT * arm * 0.6
        thrust = sh_r + FRONT * arm * 0.92 + UP * arm * 0.05
        hand = idle_h.lerp(back_h, windup).lerp(thrust, strike) - UP * arm * 0.6 * fall
        tr.location = hand + UP * 0.01 * K * breath
        pr.location = sh_r - UP * arm * 0.3 - FRONT * arm + Vector((0, 0.5 * K, 0))
        bpy.context.view_layer.update()

        # Giáo nằm trong nắm tay phải, chĩa tới trước hơi chúc xuống.
        g = self.world("hand_r", 0.6)
        tip = FRONT + UP * (-0.12 + 0.1 * windup - 0.05 * strike) - UP * 1.2 * fall
        self.spear.matrix_world = Matrix.Translation(g) @ tip.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        # Khiên đeo trên cẳng tay trái, mặt quay ra máy quay và tới trước.
        f = self.world("lowerarm_l", 0.55)
        n = (NEAR * 0.55 + FRONT * 1.0).normalized()
        self.shield.matrix_world = Matrix.Translation(f + n * 0.07 * K) @ n.to_track_quat("Z", "X").to_matrix().to_4x4() \
            @ Matrix.Diagonal((K, K, K, 1))
        bpy.context.view_layer.update()


def lights(scene):
    add_sun(scene, "Key", (0.55, 0.6, -0.6), 4.0, "#FFE0B4", angle=2.5)
    add_sun(scene, "Rim", (0.7, -0.4, -0.35), 3.5, "#C8D8FF", angle=4)
    add_sun(scene, "Bounce", (-0.1, 0.3, 0.9), 0.5, "#C8A880", angle=30)


def main():
    scene = reset_scene(samples=128, world_hex="#9DB6D2", world_strength=0.5, keep_prefs=True)
    body, rig, spear, shield = build()
    poser = Poser(rig, spear, shield)
    lights(scene)
    shadow_catcher()
    tag = "spartoi" if SPARTOI else "stone"
    out = os.path.join(ROOT, "build", "blender", "greek")
    os.makedirs(out, exist_ok=True)
    if STILL:
        camera(scene, -0.45 * K, 1.0 * K, 3.0 * K, 2.3 * K, 300)
        shots = [("idle", dict(t=0)), ("windup", dict(t=0.2, attack=0.45)), ("strike", dict(t=0.2, attack=0.6))]
        if SPARTOI:
            shots.append(("rise", dict(t=0, rise=0.55)))
        for name, kw in shots:
            poser.pose(**kw)
            render_to(scene, os.path.join(out, f"{tag}_{name}.png"))
        poser.pose()
        save_blend(f"{tag}_soldier")
        return
    raise SystemExit("Chưa có chế độ atlas: chạy với --still")


main()
