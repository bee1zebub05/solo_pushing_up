# blender: user-prefs  (cần tiện ích MPFB — xem tool/blender/render.sh)
"""Kỳ công 12 — Thuỷ Tinh (fantasy realism). Thân người nam trưởng thành vạm
vỡ dựng bằng MPFB (MakeHuman cho Blender; mô hình xuất ra theo CC0), rồi
thêm chi tiết thủy thần Việt theo tranh thờ "Tản Viên Sơn Thánh" (sách Nhất
thành khả cách chân kinh, public domain): mũ miện ngọc lửa có hoa và cánh
cuộn, râu dài, đai ngọc, gậy. Da đồng ướt, hình xăm sóng nước phát sáng, tóc
râu đen ánh xanh, dải nước xoáy quanh người; đứng ngập tới đùi trong lũ.

    bash tool/blender/render.sh thuy_tinh_boss --still
    bash tool/blender/render.sh thuy_tinh_boss

Gốc toạ độ: điểm (330, 220) của sân khấu = mặt nước lũ (chỗ thân bị cắt).
"""

import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403

from bl_ext.blender_org.mpfb.services.humanservice import HumanService  # noqa: E402
from bl_ext.blender_org.mpfb.services.targetservice import TargetService  # noqa: E402

FRAME_X = (-130, 90)
FRAME_Y = (-196, 12)
SCALE = 2.0  # người khổng lồ ~4,3 m
CUT = 0.82  # độ cao (m, người gốc) chỗ mặt nước cắt ngang đùi
FACING = math.radians(-62)  # quay mặt về phía người chơi (trái), hơi hướng máy quay


def facing_axes():
    """(hướng mặt, lên, bên trái nhân vật) theo toạ độ thế giới."""
    fwd = Vector((math.cos(FACING - math.pi / 2), math.sin(FACING - math.pi / 2), 0))
    up = Vector((0, 0, 1))
    return fwd, up, fwd.cross(up).normalized()


def build_human():
    macro = TargetService.get_default_macro_info_dict()
    macro.update(gender=1.0, age=0.62, muscle=1.0, weight=0.68, height=0.8, proportions=1.0)
    macro["race"] = {"asian": 0.6, "caucasian": 0.1, "african": 0.3}
    body = HumanService.create_human(macro_detail_dict=macro)
    rig = HumanService.add_builtin_rig(body, "game_engine")
    rig.scale = (SCALE, SCALE, SCALE)
    rig.rotation_euler = (0, 0, FACING)
    rig.location = (0, 0, -CUT * SCALE)
    sub = body.modifiers.new("Smooth", "SUBSURF")
    sub.levels = sub.render_levels = 1
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
    bpy.context.view_layer.update()
    return body, rig


def group_center(obj, name):
    """Tâm thế giới của một nhóm đỉnh trên lưới đã áp shape key (dáng thật)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    mesh = ev.to_mesh()
    gi = obj.vertex_groups[name].index
    pts = [obj.matrix_world @ mesh.vertices[v.index].co for v in obj.data.vertices
           if any(g.group == gi and g.weight > 0.5 for g in v.groups) and v.index < len(mesh.vertices)]
    ev.to_mesh_clear()
    return sum(pts, Vector()) / len(pts)


def human_skin_material():
    """Da đồng ướt (SSS, lớp phủ bóng) + hình xăm sóng nước phát sáng theo
    thuộc tính `tattoo` (tay, vai, ngực)."""
    mat = bpy.data.materials.new("Skin")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links.new
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = srgb("#7A4E34")
    bsdf.inputs["Subsurface Weight"].default_value = 0.25
    bsdf.inputs["Subsurface Radius"].default_value = (0.9, 0.35, 0.2)
    bsdf.inputs["Roughness"].default_value = 0.42
    bsdf.inputs["Coat Weight"].default_value = 0.55  # da ướt
    bsdf.inputs["Coat Roughness"].default_value = 0.08
    # Vân sóng: Wave texture uốn bằng nhiễu theo toạ độ object.
    tc = N.new("ShaderNodeTexCoord")
    wave = N.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "DIAGONAL"
    wave.inputs["Scale"].default_value = 5.0
    wave.inputs["Distortion"].default_value = 14
    wave.inputs["Detail"].default_value = 4
    wave.inputs["Detail Scale"].default_value = 2.5
    L(tc.outputs["Object"], wave.inputs["Vector"])
    band = N.new("ShaderNodeMapRange")
    band.inputs["From Min"].default_value = 0.93
    band.inputs["From Max"].default_value = 0.96
    L(wave.outputs["Fac"], band.inputs["Value"])
    attr = N.new("ShaderNodeAttribute")
    attr.attribute_type = "GEOMETRY"
    attr.attribute_name = "tattoo"
    mul = N.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    L(band.outputs[0], mul.inputs[0])
    L(attr.outputs["Fac"], mul.inputs[1])
    bsdf.inputs["Emission Color"].default_value = srgb("#12A8D8")
    k = N.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.inputs[1].default_value = 1.6
    L(mul.outputs[0], k.inputs[0])
    L(k.outputs[0], bsdf.inputs["Emission Strength"])
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def paint_tattoo(body):
    """Thuộc tính `tattoo` 0–1: tay, vai, ngực (theo trọng số xương)."""
    mesh = body.data
    want = {"upperarm_l": 1, "lowerarm_l": 1, "upperarm_r": 1, "lowerarm_r": 1,
            "clavicle_l": 0.8, "clavicle_r": 0.8, "spine_03": 0.6}
    idx = {body.vertex_groups[n].index: w for n, w in want.items() if n in body.vertex_groups}
    vals = [0.0] * len(mesh.vertices)
    for v in mesh.vertices:
        vals[v.index] = min(1.0, sum(g.weight * idx[g.group] for g in v.groups if g.group in idx))
    a = mesh.attributes.new("tattoo", "FLOAT", "POINT")
    a.data.foreach_set("value", vals)


def bone_world(rig, name, at=0.0):
    """Điểm trên xương (0 = gốc, 1 = ngọn) theo toạ độ thế giới lúc nghỉ."""
    b = rig.data.bones[name]
    return rig.matrix_world @ (b.head_local.lerp(b.tail_local, at))


# ---------------------------------------------------------------- hình khối theo mét (toạ độ thế giới)


def raw_ellipsoid(name, center, radii, rot_z=0.0, segments=24, rings=14):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1)
    R = Matrix.Rotation(rot_z, 3, "Z")
    for v in bm.verts:
        v.co = R @ Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + center
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    return mesh


def tapered_world(name, strands, sides=8, steps=8, flat=1.0, taper=0.8):
    """Như tapered_tubes nhưng điểm và bán kính tính bằng mét (thế giới)."""
    verts, faces = [], []
    for a, b, c, r in strands:
        base = len(verts)
        for i in range(steps + 1):
            t = i / steps
            pt = a * (1 - t) ** 2 + b * 2 * t * (1 - t) + c * t * t
            tan = ((b - a) * 2 * (1 - t) + (c - b) * 2 * t).normalized()
            sd = tan.cross(Vector((0, 0, 1)))
            if sd.length < 1e-4:
                sd = tan.cross(Vector((1, 0, 0)))
            sd.normalize()
            u = sd.cross(tan).normalized()
            rad = r * (1 - t) ** taper + 0.002
            for k in range(sides):
                ang = 2 * math.pi * k / sides
                verts.append(pt + (sd * math.cos(ang) * flat + u * math.sin(ang) / flat) * rad)
        for i in range(steps):
            for k in range(sides):
                k2 = (k + 1) % sides
                o = base + i * sides
                faces.append((o + k, o + k2, o + sides + k2, o + sides + k))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    return mesh


def raw_tube(name, pts, radii, sides=24):
    """Ống qua các điểm (mét) với bán kính tại từng điểm."""
    verts, faces = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        tan = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        sd = tan.cross(Vector((0, 0, 1)))
        if sd.length < 1e-4:
            sd = tan.cross(Vector((1, 0, 0)))
        sd.normalize()
        u = sd.cross(tan).normalized()
        for k in range(sides):
            a = 2 * math.pi * k / sides
            verts.append(p + (sd * math.cos(a) + u * math.sin(a)) * radii[i])
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append((i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    return mesh


def attach(name, mesh, mats, rig, bone=None):
    """Gắn lưới vào xương [bone] của [rig]; không có bone thì [rig] là object cha thường."""
    o = add_object(name, mesh, mats)
    if bone:
        parent_to_bone(o, rig, bone)
    else:
        o.parent = rig
        o.matrix_parent_inverse = rig.matrix_world.inverted()
    return o


# ---------------------------------------------------------------- dựng


def build():
    body, rig = build_human()
    body.data.materials.clear()
    body.data.materials.append(human_skin_material())
    paint_tattoo(body)

    gold = gold_material("Gold", "#E2B04A", rough=0.25)
    jade = skin_material("Jade", "#2E8A6A", rough=0.15, sss=0.3)
    pearl = skin_material("Pearl", "#F2ECE2", rough=0.12)
    eye = glow_material("Eye", "#BFF8FF", strength=6)
    orb = glow_material("Orb", "#9FF6FF", strength=12)
    water = water_material("Swirl", "#3A9EC0", emission=0.25, rough=0.05)
    armor = solid_scales_material("Armor", "#1E5E66", "#061A1C", scale=40, metallic=0.6)
    hair_mat = fur_material("WetHair", [(0.0, "#16262A"), (0.5, "#0A1214"), (1.0, "#040607")], sheen=0.05)
    dark = skin_material("HairRoot", "#0A1418", rough=0.35)

    fwd, up, side = facing_axes()
    head_top = bone_world(rig, "head", 1.0)
    head_base = bone_world(rig, "head", 0.0)
    hc = head_base.lerp(head_top, 0.45)  # tâm sọ
    hr = (head_top - head_base).length * 0.55  # bán kính đầu (m)

    # ---- mắt thần sáng lạnh
    for g in ("helper-l-eye", "helper-r-eye"):
        c = group_center(body, g) + fwd * 0.012 * SCALE
        attach("Eye", raw_ellipsoid("Eye", c, (0.016 * SCALE,) * 3), [eye], rig, "head")

    # ---- tóc dài ướt chảy ra sau, râu dài, ria rủ (sợi thật mọc trên vỏ ẩn)
    scalp = attach("Scalp", raw_ellipsoid("Scalp", hc - fwd * hr * 0.15 + up * hr * 0.1, (hr * 0.98, hr * 1.02, hr),
                                          rot_z=FACING), [dark], rig, "head")
    with_fur(scalp, hair_mat, density=900, length=(0.28 * SCALE, 0.5 * SCALE), radius=0.0035 * SCALE,
             comb=tuple(-fwd * 1.0 - up * 0.9), lift=0.35, gravity=0.18 * SCALE, jitter=0.15, seed=21)
    chin = hc + fwd * hr * 0.55 - up * hr * 0.75
    beard = attach("BeardRoot", raw_ellipsoid("BeardRoot", chin, (hr * 0.5, hr * 0.42, hr * 0.38), rot_z=FACING),
                   [dark], rig, "head")
    with_fur(beard, hair_mat, density=4000, length=(0.35 * SCALE, 0.6 * SCALE), radius=0.0035 * SCALE,
             comb=tuple(-up * 1.0 + fwd * 0.15), lift=0.3, gravity=0.2 * SCALE, jitter=0.2, seed=22)
    for s in (-1, 1):  # ria dài rủ hai bên miệng
        tip = hc + fwd * hr * 0.75 - up * hr * 0.35 + side * s * hr * 0.25
        attach("Mustache", tapered_world("Mustache", [(tip, tip + side * s * hr * 0.3 - up * hr * 0.1,
                                                      tip + side * s * hr * 0.45 - up * hr * 0.9, 0.02 * SCALE)]),
               [dark], rig, "head")

    # ---- mũ miện vàng kiểu Việt: vành, ngọc lửa, hoa ngọc, cánh cuộn
    crown_c = head_top - up * hr * 0.35
    attach("CrownBand", raw_ellipsoid("CrownBand", crown_c, (hr * 0.95, hr * 0.95, hr * 0.32)), [gold], rig, "head")
    attach("CrownTop", raw_ellipsoid("CrownTop", crown_c + up * hr * 0.35, (hr * 0.72, hr * 0.72, hr * 0.38)), [gold], rig, "head")
    flame = crown_c + up * hr * 0.7 + fwd * hr * 0.3
    attach("CrownFlame", tapered_world("CrownFlame", [(flame, flame + up * hr * 0.4 - fwd * hr * 0.1,
                                                      flame + up * hr * 0.85, 0.06 * SCALE)], taper=1.4), [gold], rig, "head")
    attach("CrownPearl", raw_ellipsoid("CrownPearl", flame + up * hr * 0.25 + fwd * hr * 0.05, (hr * 0.17,) * 3), [orb], rig, "head")
    for s in (-1, 1):
        flower = crown_c + fwd * hr * 0.8 + side * s * hr * 0.5 + up * hr * 0.15
        attach("CrownJade", raw_ellipsoid("CrownJade", flower, (hr * 0.14,) * 3), [jade], rig, "head")
        base = crown_c - fwd * hr * 0.4 + side * s * hr * 0.85
        attach("CrownWing", tapered_world("CrownWing", [(base, base + side * s * hr * 0.6 + up * hr * 0.1,
                                                        base + side * s * hr * 0.9 + up * hr * 0.45, 0.045 * SCALE)],
                                          flat=2.4, taper=0.4), [gold], rig, "head")

    # ---- đai ngọc + váy giáp vảy quanh hông (chìm dần xuống nước)
    pelvis = bone_world(rig, "pelvis", 0.3)
    waist = bone_world(rig, "spine_01", 0.2)
    r_hip = 0.2 * SCALE
    skirt = raw_tube("Skirt", [waist + up * 0.02, pelvis - up * 0.15 * SCALE, pelvis - up * 0.42 * SCALE],
                     [r_hip * 0.95, r_hip * 1.1, r_hip * 1.25])
    attach("Skirt", skirt, [armor], rig, "pelvis")
    attach("Belt", raw_ellipsoid("Belt", waist + up * 0.02, (r_hip * 1.02, r_hip * 1.02, 0.035 * SCALE)), [gold], rig, "spine_01")
    attach("BeltJade", raw_ellipsoid("BeltJade", waist + up * 0.02 + fwd * r_hip, (0.06 * SCALE, 0.02 * SCALE, 0.05 * SCALE),
                                     rot_z=FACING), [jade], rig, "spine_01")

    # ---- chuỗi ngọc trai trên ngực
    neck = bone_world(rig, "neck_01", 0.0)
    for k in range(17):
        t = k / 16
        a = math.pi * (0.15 + 0.7 * t)
        p = neck - up * (0.06 + 0.16 * math.sin(math.pi * t)) * SCALE \
            + fwd * (0.06 + 0.08 * math.sin(math.pi * t)) * SCALE + side * math.cos(a) * 0.15 * SCALE
        attach("Pearl", raw_ellipsoid("Pearl", p, (0.018 * SCALE,) * 3), [pearl], rig, "spine_03")

    # ---- vòng tay vàng
    for s in ("l", "r"):
        c = bone_world(rig, f"lowerarm_{s}", 0.75)
        attach("Bracer", raw_ellipsoid("Bracer", c, (0.06 * SCALE,) * 3), [gold], rig, f"lowerarm_{s}")

    # ---- gậy thần đầu ngọc trong tay phải (phía xa máy quay)
    hand_s = bone_world(rig, "hand_l", 0.5)
    holder = bpy.data.objects.new("StaffHolder", None)
    bpy.context.scene.collection.objects.link(holder)
    holder.location = hand_s
    bpy.context.view_layer.update()
    bottom = hand_s - up * 0.95 * SCALE
    top = bottom + up * 2.25 * SCALE
    attach("Staff", tapered_world("Staff", [(bottom, (bottom + top) / 2, top, 0.035 * SCALE)], taper=0.2),
           [skin_material("StaffWood", "#3A2416", rough=0.5)], holder)
    claws = []
    for a in np.linspace(0, 2 * math.pi, 6)[:-1]:
        d = Vector((math.cos(a), math.sin(a), 0))
        claws.append((top - up * 0.05 * SCALE, top + d * 0.12 * SCALE + up * 0.1 * SCALE,
                      top + d * 0.04 * SCALE + up * 0.26 * SCALE, 0.02 * SCALE))
    attach("StaffClaws", tapered_world("StaffClaws", claws, taper=1.0), [gold], holder)
    attach("StaffOrb", raw_ellipsoid("StaffOrb", top + up * 0.14 * SCALE, (0.1 * SCALE,) * 3), [orb], holder)

    # ---- dải nước xoáy quanh thân (thủy thần điều khiển dòng lũ)
    base = bone_world(rig, "pelvis", 0.0)
    for k in range(2):
        pts, rads = [], []
        for i in range(40):
            t = i / 39
            a = 2 * math.pi * (1.1 * t + k / 2)
            r = (0.5 - 0.1 * t) * SCALE
            pts.append(base + Vector((math.cos(a) * r, math.sin(a) * r * 0.8, (t * 0.45 - 0.35) * SCALE)))
            rads.append(0.03 * SCALE * math.sin(math.pi * t) + 0.004)
        attach(f"Swirl{k}", raw_tube(f"Swirl{k}", pts, rads, sides=10), [water], rig, "pelvis")

    # Mặt nước cắt ngang đùi (holdout): phần dưới nước không lộ ra sprite.
    ground = add_object("WaterCut", raw_ellipsoid("WaterCut", Vector((0, 0, -0.6)), (20, 20, 0.6)), [])
    ground.is_holdout = True
    return body, rig


# ---------------------------------------------------------------- tư thế (IK tay)


def setup_ik(rig):
    """Đích IK cho hai bàn tay (empty) + đích cực cho khuỷu."""
    targets = {}
    for s in ("l", "r"):
        t = bpy.data.objects.new(f"IK_{s}", None)
        p = bpy.data.objects.new(f"Pole_{s}", None)
        bpy.context.scene.collection.objects.link(t)
        bpy.context.scene.collection.objects.link(p)
        c = rig.pose.bones[f"lowerarm_{s}"].constraints.new("IK")
        c.target = t
        c.pole_target = p
        c.chain_count = 2
        c.pole_angle = math.radians(-90)
        targets[s] = (t, p)
    return targets


def pose(rig, ik, t=0.0, attack=-1.0, defeat=0.0):
    """Thở; lấy đà giơ tay trái (gần máy quay) gọi sóng, ra đòn đẩy tay về
    phía người chơi; gục thì chìm xuống và ngả ra sau."""
    windup, strike, recover = attack_pose(attack)
    fall = smooth(defeat)
    sway = math.sin(t * 2 * math.pi)
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
    rig.location = (0, 0, -CUT * SCALE - 1.4 * fall * SCALE)
    lean = -0.12 * windup + 0.22 * strike - 0.25 * fall + 0.02 * sway
    rig.pose.bones["spine_02"].rotation_euler.x = lean
    rig.pose.bones["spine_03"].rotation_euler.x = lean * 0.6
    rig.pose.bones["head"].rotation_euler.x = 0.12 - 0.1 * windup + 0.1 * strike + 0.3 * fall
    bpy.context.view_layer.update()
    fwd, up, side = facing_axes()
    # Tay phải nhân vật ở phía người chơi: gọi sóng; tay trái cầm gậy.
    sh_l = rig.matrix_world @ rig.pose.bones["upperarm_r"].head
    sh_r = rig.matrix_world @ rig.pose.bones["upperarm_l"].head
    side = -side
    L = 0.62 * SCALE  # tầm với cánh tay
    # Tay trái: chỉ xuống về phía người chơi → giơ cao gọi sóng → đẩy thẳng tới.
    rest_l = sh_l + fwd * 0.35 * L - up * 0.75 * L + side * 0.1 * L
    raised = sh_l + up * 0.9 * L + fwd * 0.2 * L + side * 0.25 * L
    thrust = sh_l + fwd * 0.97 * L + up * 0.05 * L
    hand_l = rest_l.lerp(raised, windup).lerp(thrust, strike) - up * 0.4 * L * fall + up * 0.03 * L * sway
    ik["r"][0].location = hand_l
    ik["r"][1].location = sh_l - fwd * 0.6 * L - up * 0.4 * L + side * 0.3 * L
    # Tay phải (cầm gậy): khuỷu gập, bàn tay trước hông.
    out = (sh_r - sh_l).normalized()  # từ vai gọi sóng sang vai cầm gậy: ra xa thân
    ik["l"][0].location = sh_r + out * 0.45 * L + fwd * 0.15 * L - up * 0.62 * L
    ik["l"][1].location = sh_r - fwd * 0.6 * L - up * 0.3 * L + out * 0.6 * L
    bpy.context.view_layer.update()
    holder = bpy.data.objects["StaffHolder"]
    hand = rig.matrix_world @ rig.pose.bones["hand_l"].head
    holder.location = hand
    holder.rotation_euler = (0, 0, 0)
    holder.rotation_mode = "AXIS_ANGLE"
    holder.rotation_axis_angle = (lean * 0.6, side.x, side.y, side.z)
    bpy.context.view_layer.update()


def lights(scene):
    add_sun(scene, "Key", (0.75, 0.5, -0.55), 4.0, "#E6F0FF", angle=1.5)
    add_sun(scene, "Storm", (-0.6, -0.9, -0.3), 6.0, "#A88CFF", angle=1.5)
    add_point(scene, "Under", (-20, -20, -60), 200, "#5FD8FF", radius=1.0)


def main():
    scene = reset_scene(samples=96, world_hex="#3A4E62", world_strength=0.35, keep_prefs=True)
    body, rig = build()
    ik = setup_ik(rig)
    lights(scene)
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=2.0)
    anchor, ppu = anchor_info(scene, cam)
    print(f"THUYTINH anchor={tuple(round(c, 1) for c in anchor)} ppu={ppu:.3f}")
    out = os.path.join(ROOT, "build", "blender", "thuy_tinh")
    if STILL:
        render_stills(scene, out, [
            ("idle", lambda: pose(rig, ik, 0)),
            ("windup", lambda: pose(rig, ik, 0.25, attack=0.48)),
            ("strike", lambda: pose(rig, ik, 0.25, attack=0.62)),
            ("defeat", lambda: pose(rig, ik, 0.25, defeat=0.6)),
        ])
        pose(rig, ik, 0)
        save_blend("thuy_tinh")
        return
    raise SystemExit("Chưa có chế độ atlas cho Thuỷ Tinh bản người: chạy với --still")


main()
