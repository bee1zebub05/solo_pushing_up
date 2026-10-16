"""Chim Stymphalia chương 1 (fantasy realism): chim ăn thịt người của hồ
Stymphalia, mỏ đồng, móng đồng, lông đồng sắc như dao (bắn lông như mũi tên).
Đầu chim săn mồi: sọ thuôn, gờ mày dữ che mắt hổ phách, mào lông đỏ vuốt
ngược; thân phủ lông xếp ngói ánh kim, ức vảy đồng sáng; đuôi sáu lông dao.

    bash tool/blender/render.sh stymphalia --still

Quay mặt sang trái (về phía người chơi). Ra đòn theo `AttackPose`: lấy đà =
ngóc lên, lùi lại, giương cánh cao; ra đòn = cụp cánh lao xuống mổ, mỏ há.
Toạ độ mét, gốc ở tâm thân chim; cánh gần máy quay sải theo −Y.
"""

import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import (ROOT, STILL, _nodes, add_object, add_point, add_sun, attack_pose, ellipsoids_mesh,  # noqa: E402
                      glow_material, render_to, reset_scene, save_blend, smooth, srgb)
from bird_kit import E, Wing, blade, feather_material, flap_cycle, plumage  # noqa: E402
from greek_kit import bronze_material  # noqa: E402
from sprite_kit import export_sprites  # noqa: E402
from human_kit import camera, raw_ellipsoid, raw_tube, store_point_attr  # noqa: E402

# Đơn vị sân khấu cho 1 m: thân chim (mỏ → đuôi ~1,1 m) dài cỡ bản vector.
UNITS_PER_M = 32
# ---------------------------------------------------------------- vật liệu


def eye_material():
    mat = bpy.data.materials.new("Eye")
    nt, out = _nodes(mat)
    N, L = nt.nodes, nt.links.new
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    # Tròng hổ phách sáng dần ra viền, đồng tử đen giữa (theo toạ độ object).
    tc = N.new("ShaderNodeTexCoord")
    grad = N.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    L(tc.outputs["Object"], grad.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, srgb("#E89A1A")
    els[1].position, els[1].color = 0.62, srgb("#FFD24A")
    p = els.new(0.66)
    p.color = srgb("#0A0604")
    q = els.new(1.0)
    q.color = srgb("#0A0604")
    L(grad.outputs["Fac"], ramp.inputs["Fac"])
    L(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.05
    bsdf.inputs["Coat Weight"].default_value = 1.0
    bsdf.inputs["Emission Color"].default_value = srgb("#FFB020")
    bsdf.inputs["Emission Strength"].default_value = 0.6
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


# ---------------------------------------------------------------- dựng chim


class Bird:
    def __init__(self):
        dark = feather_material("Plumage", "#160E0A", "#8E5C2C", sheen="#E0A050", metallic=0.75)
        wing_mat = feather_material("WingFeather", "#24180F", "#A8743C", sheen="#F0C27A", metallic=0.8)
        crest_mat = feather_material("Crest", "#5A0C08", "#C8301E", sheen="#FF7A50", metallic=0.15, rough=0.45)
        bronze = bronze_material("BeakBronze", base="#B0813F", polish=1.4, rough=0.22)
        talon = bronze_material("Talon", base="#8A6230", polish=1.2, rough=0.3)
        skin = bpy.data.materials.new("Cere")
        nt, out = _nodes(skin)
        b = nt.nodes.new("ShaderNodeBsdfPrincipled")
        b.inputs["Base Color"].default_value = srgb("#3A2A22")
        b.inputs["Roughness"].default_value = 0.6
        nt.links.new(b.outputs[0], out.inputs["Surface"])

        self.root = bpy.data.objects.new("Bird", None)
        bpy.context.scene.collection.objects.link(self.root)
        objs = []

        # Thân: ức nở, lưng thuôn về đuôi, cổ cong, đầu chim săn mồi có gờ mày.
        body_mesh = ellipsoids_mesh("Body", [
            E((0.02, 0, 0.0), (0.19, 0.095, 0.1)),
            E((-0.12, 0, -0.015), (0.12, 0.1, 0.11)),
            E((0.2, 0, 0.015), (0.11, 0.06, 0.05), -8),
            E((-0.23, 0, 0.05), (0.08, 0.06, 0.065), 30),
            E((-0.3, 0, 0.1), (0.07, 0.05, 0.055), -6),
            E((-0.34, 0, 0.115), (0.045, 0.034, 0.035)),
            # Gờ mày nhô hai bên che mắt.
            E((-0.335, -0.03, 0.128), (0.03, 0.014, 0.012), -12),
            E((-0.335, 0.03, 0.128), (0.03, 0.014, 0.012), -12),
        ], voxel=0.007, smooth_iter=4)
        body = add_object("Body", body_mesh, [dark])
        store_point_attr(body, "feather_t", [0.15] * len(body_mesh.vertices))
        objs.append(body)
        objs.append(plumage("Plumage", body, dark, avoid=[Vector((-0.343, s, 0.113)) for s in (-0.036, 0.036)]))

        # Mắt hổ phách dưới gờ mày, mắt gần máy quay rõ nhất.
        em = eye_material()
        for s in (-1, 1):
            e = add_object("Eye", raw_ellipsoid("Eye", Vector((-0.343, s * 0.036, 0.113)), (0.016, 0.008, 0.015)),
                           [em])
            objs.append(e)

        # Mỏ đồng hai hàm: hàm trên móc chóp, hàm dưới há khi mổ.
        up_pts = [Vector((-0.365, 0, 0.122)), Vector((-0.41, 0, 0.12)), Vector((-0.45, 0, 0.11)),
                  Vector((-0.485, 0, 0.09)), Vector((-0.5, 0, 0.068)), Vector((-0.497, 0, 0.055))]
        upper = add_object("BeakUpper", raw_tube("BeakUpper", up_pts,
                                                 [(0.028, 0.026), (0.022, 0.02), (0.016, 0.015),
                                                  (0.01, 0.01), (0.006, 0.006), (0.002, 0.002)], sides=20), [bronze])
        lo_pts = [Vector((-0.365, 0, 0.098)), Vector((-0.41, 0, 0.094)), Vector((-0.45, 0, 0.088)),
                  Vector((-0.478, 0, 0.08))]
        self.lower = add_object("BeakLower", raw_tube("BeakLower", lo_pts,
                                                      [(0.02, 0.012), (0.015, 0.009), (0.009, 0.006),
                                                       (0.002, 0.002)], sides=16), [bronze])
        cere = add_object("Cere", raw_ellipsoid("Cere", Vector((-0.372, 0, 0.122)), (0.02, 0.03, 0.018)), [skin])
        jaw = bpy.data.objects.new("JawPivot", None)
        bpy.context.scene.collection.objects.link(jaw)
        jaw.location = Vector((-0.365, 0, 0.098))
        self.lower.parent = jaw
        self.lower.matrix_parent_inverse = Matrix.Translation(-jaw.location)
        self.jaw = jaw
        objs += [upper, cere, jaw]

        # Mào đỏ: bốn lông vuốt ngược ra sau–lên.
        for i in range(5):
            base = Vector((-0.34 + i * 0.022, 0, 0.16 - i * 0.004))
            d = Vector((1, 0, 0.55 - i * 0.08))
            objs.append(blade(f"Crest{i}", base, d, (0, -1, 0.3), 0.11 + i * 0.018, 0.019, crest_mat, curve=0.12,
                              tone=0.3 + 0.15 * (i % 2)))

        # Đuôi: sáu lông dao đồng xoè hình quạt, gốc phủ lông bao.
        for i in range(6):
            a = math.radians(-18 + i * 7)
            yy = (i - 2.5) * 0.012
            d = Vector((math.cos(a), yy * 3, math.sin(a) * 0.6 - 0.08))
            objs.append(blade(f"Tail{i}", (0.25, yy, 0.015), d, (0, -0.8, 1), 0.36 - abs(i - 2.5) * 0.025, 0.026,
                              wing_mat, curve=0.05, tone=0.55 + 0.1 * (i % 2)))

        # Chân quắp ra sau dưới bụng, móng đồng cong.
        self.feet = []
        for s in (-1, 1):
            hip = Vector((0.04, s * 0.045, -0.07))
            knee = Vector((0.12, s * 0.05, -0.13))
            ankle = Vector((0.2, s * 0.045, -0.12))
            leg = add_object("Leg", raw_tube("Leg", [hip, knee, ankle], [0.03, 0.016, 0.012], sides=14), [skin])
            objs.append(leg)
            for k, (dx, dy) in enumerate(((1, 0), (0.7, -0.5), (0.7, 0.5), (-0.6, 0))):
                toe0 = ankle
                toe1 = ankle + Vector((0.045 * dx, s * 0.02 * dy, -0.02))
                toe2 = toe1 + Vector((0.015 * dx, s * 0.01 * dy, -0.03))
                objs.append(add_object("Talon", raw_tube("Talon", [toe0, toe1, toe2],
                                                         [0.007, 0.005, 0.0008], sides=10), [talon]))

        # Cánh: vai trên lưng hai bên.
        self.wings = [Wing("WingN", (-0.05, -0.07, 0.07), wing_mat, dark, far=False, scale=1.05, seed=2),
                      Wing("WingF", (-0.05, 0.07, 0.07), wing_mat, dark, far=True, scale=1.05, seed=5)]
        for wpart in self.wings:
            for part in wpart.parts:
                store_point_attr(part, "feather_t", [0.55] * len(part.data.vertices))
        for o in objs + [w.joints[0] for w in self.wings]:
            if o.parent is None:
                o.parent = self.root

    def pose(self, phase=0.0, attack=-1.0, defeat=0.0):
        windup, strike, recover = attack_pose(attack)
        lift, fold = flap_cycle(phase % 1.0)
        # Ra đòn: cánh giương nửa chừng quét ra sau (thế bổ nhào), chúi mũi xuống.
        dive = strike
        flap = lift * (1 - windup) * (1 - dive) * (1 - 0.6 * defeat) + math.radians(70) * windup * (1 - dive) \
            + math.radians(35) * dive - math.radians(40) * defeat
        fold = fold * (1 - windup) * (1 - dive) + 0.3 * windup + 0.35 * dive
        sweep = math.radians(38) * dive
        for w in self.wings:
            w.pose(flap, fold, sweep)
        bob = -0.03 * math.sin(2 * math.pi * phase)
        pitch = math.radians(22 * windup - 30 * dive + 8 * recover - 70 * defeat)
        self.root.rotation_euler = Euler((math.radians(-25) * defeat, pitch, 0), "XYZ")
        self.root.location = Vector((0.18 * windup - 0.5 * dive, 0, bob + 0.08 * windup - 0.3 * dive - 0.25 * defeat))
        gape = 0.15 * windup + 0.45 * dive
        self.jaw.rotation_euler = Euler((0, -gape, 0), "XYZ")
        bpy.context.view_layer.update()


def lights(scene):
    add_sun(scene, "Key", (0.55, 0.6, -0.6), 5.0, "#FFE0B4", angle=2.5)
    add_sun(scene, "Rim", (0.7, -0.4, -0.35), 3.5, "#C8D8FF", angle=4)
    add_sun(scene, "Bounce", (-0.1, 0.3, 0.9), 0.6, "#C8A880", angle=30)


def main():
    scene = reset_scene(samples=96, world_hex="#9DB6D2", world_strength=0.5)
    bird = Bird()
    lights(scene)
    out = os.path.join(ROOT, "build", "blender", "greek")
    os.makedirs(out, exist_ok=True)
    if STILL:
        camera(scene, 0.05, 0.22, 2.1, 1.95, 360, yaw=-22, pitch=14)
        shots = [("glide", dict(phase=0.0)), ("down", dict(phase=0.3)), ("up", dict(phase=0.75)),
                 ("windup", dict(phase=0.0, attack=0.45)), ("strike", dict(phase=0.0, attack=0.6)),
                 ("defeat", dict(phase=0.5, defeat=1.0))]
        for name, kw in shots:
            bird.pose(**kw)
            render_to(scene, os.path.join(out, f"bird_{name}.png"))
        bird.pose()
        save_blend("stymphalian_bird")
        return
    # Hoạt hình: 12 pha đập cánh (lặp), 8 khung ra đòn theo tiến độ, 3 khung gục.
    scene.cycles.samples = 64
    cam = camera(scene, 0.05, 0.22, 2.1, 1.95, 130, yaw=-22, pitch=14)
    flap = [lambda k=k: bird.pose(phase=k / 12) for k in range(12)]
    attack = [lambda k=k: bird.pose(phase=0.0, attack=k / 7) for k in range(8)]
    defeat = [lambda k=k: bird.pose(phase=0.5, defeat=(k + 1) / 3) for k in range(3)]
    export_sprites(scene, cam, "stymphalian_bird", {"idle": flap, "attack": attack, "defeat": defeat},
                   (0, 0, 0), UNITS_PER_M, extra={"idlePeriod": 0.7})


main()
