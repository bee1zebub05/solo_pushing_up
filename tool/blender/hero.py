# blender: user-prefs  (cần tiện ích MPFB — xem tool/blender/render.sh)
"""Nhân vật người chơi — người kế nhiệm Hercules (fantasy realism).

Thân người dựng bằng MPFB (MakeHuman cho Blender; mô hình xuất ra theo CC0),
trang phục Hy Lạp cổ: áo exomis vải lanh hở vai phải (vai gần máy quay), viền
xanh hoạ tiết ở gấu, thắt lưng da, băng đầu đỏ, dây sandal quấn cổ chân.

Tư thế giải đúng hình học như `HeroPose.plank` (lib/art/hero_pose.dart): mũi
chân (hoặc đầu gối) và bàn tay cố định trên sàn, thân thẳng xoay quanh điểm
tựa sao cho vai cách cổ tay đúng tầm với của góc khuỷu [elbow] (IK hai đoạn).

    bash tool/blender/render.sh hero --still               # nam
    bash tool/blender/render.sh hero --still --female      # nữ
    bash tool/blender/render.sh hero [--female]            # sprite tách lớp

Sprite TÁCH LỚP cho phép đổi ngoại hình như màn tạo nhân vật mà không render
mọi tổ hợp: `hero_<giới>_skin` (da render trắng trung tính, Flutter nhân màu
da đã chọn), `hero_<giới>_cloth` (áo, đai, sandal, mắt, bóng đổ — giữ màu),
`hero_<giới>_hair_<kiểu>` (tóc + lông mày render xám, nhân màu tóc). Lớp khác
chỉ "đục lỗ" (holdout): che khuất đúng nhưng không hiện trong ảnh.

Nhân vật quay mặt sang phải; tay/chân phải ở phía gần máy quay.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import (ARGS, ROOT, STILL, add_object, fur_material, glow_material,  # noqa: E402
                      parent_to_bone, render_to, reset_scene, skin_material, solid_scales_material, srgb,
                      with_fur)
from human_kit import (camera, group_center, make_human, raw_ellipsoid, rest_coords, ring_around,  # noqa: E402
                       shadow_catcher, shell_copy, store_point_attr, tapered_world, weights_by_group)


FEMALE = "--female" in ARGS
K = 1.0  # tỉ lệ người (1 = người thật ~1,75 m); quy đổi sang đơn vị sân khấu lúc ghép atlas
# Ảnh duyệt: màu thật. Sprite: trắng/xám trung tính để Flutter nhân màu.
SKIN = "#D9A27A" if STILL else "#F4ECE6"
HAIR = "#2A1A10" if STILL else "#CFCBC6"
HAIR_STYLES = ("curly", "buzz", "bun", "ponytail", "long")


# ---------------------------------------------------------------- thân người


def build_human(fat=0.35):
    return make_human(0.0 if FEMALE else 1.0, muscle=0.72, weight=0.35 + 0.5 * fat, height=0.55, scale=K)


def human_skin(name="Skin"):
    """Da người: tán xạ dưới da, độ nhám đổi theo vùng (nhiễu), lỗ chân lông
    li ti bằng bump, lớp mồ hôi bóng nhẹ; môi hồng hơn theo thuộc tính `lips`."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links.new
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    tc = N.new("ShaderNodeTexCoord")
    blot = N.new("ShaderNodeTexNoise")
    blot.inputs["Scale"].default_value = 9
    blot.inputs["Detail"].default_value = 4
    L(tc.outputs["Object"], blot.inputs["Vector"])
    tone = N.new("ShaderNodeMix")
    tone.data_type = "RGBA"
    tone.inputs[6].default_value = srgb(SKIN)
    tone.inputs[7].default_value = [c * 0.82 for c in srgb(SKIN)[:3]] + [1]
    k = N.new("ShaderNodeMapRange")
    k.inputs["From Min"].default_value = 0.35
    k.inputs["From Max"].default_value = 0.75
    k.inputs["To Max"].default_value = 0.55
    L(blot.outputs["Fac"], k.inputs["Value"])
    L(k.outputs[0], tone.inputs["Factor"])
    lips = N.new("ShaderNodeAttribute")
    lips.attribute_type = "GEOMETRY"
    lips.attribute_name = "lips"
    lm = N.new("ShaderNodeMix")
    lm.data_type = "RGBA"
    L(lips.outputs["Fac"], lm.inputs["Factor"])
    L(tone.outputs[2], lm.inputs[6])
    lm.inputs[7].default_value = srgb("#B0605A")
    L(lm.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Subsurface Weight"].default_value = 0.3
    bsdf.inputs["Subsurface Radius"].default_value = (1.0, 0.35, 0.2)
    bsdf.inputs["Subsurface Scale"].default_value = 0.012 * K
    rough = N.new("ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = 0.5
    rough.inputs["To Max"].default_value = 0.72
    L(blot.outputs["Fac"], rough.inputs["Value"])
    L(rough.outputs[0], bsdf.inputs["Roughness"])
    bsdf.inputs["Coat Weight"].default_value = 0.07  # mồ hôi
    bsdf.inputs["Coat Roughness"].default_value = 0.35
    pores = N.new("ShaderNodeTexNoise")
    pores.inputs["Scale"].default_value = 900 / K
    L(tc.outputs["Object"], pores.inputs["Vector"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.08
    L(pores.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def linen_material(name="Linen", hex_="#E9E1CF", trim="#2F5FA0"):
    """Vải lanh mộc: thớ dệt (sóng hai chiều), nếp nhăn mềm theo nhiễu, mặt
    vải nhám có ánh sheen; dải viền xanh hoạ tiết sóng ở gấu theo `hem` (m)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links.new
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    tc = N.new("ShaderNodeTexCoord")
    weave = N.new("ShaderNodeTexWave")
    weave.inputs["Scale"].default_value = 220 / K
    L(tc.outputs["Object"], weave.inputs["Vector"])
    fold = N.new("ShaderNodeTexNoise")
    fold.inputs["Scale"].default_value = 7 / K
    fold.inputs["Detail"].default_value = 3
    L(tc.outputs["Object"], fold.inputs["Vector"])
    h = N.new("ShaderNodeMath")
    h.operation = "MULTIPLY_ADD"
    L(fold.outputs["Fac"], h.inputs[0])
    h.inputs[1].default_value = 4.0
    L(weave.outputs["Fac"], h.inputs[2])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.004 * K
    L(h.outputs[0], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    # Vải bẩn dần về gấu + vệt bụi.
    dirt = N.new("ShaderNodeMix")
    dirt.data_type = "RGBA"
    L(fold.outputs["Fac"], dirt.inputs["Factor"])
    dirt.inputs[6].default_value = srgb(hex_)
    dirt.inputs[7].default_value = srgb("#B8A88C")
    # Viền: 0 < hem < 0,035 m (đơn vị người gốc) là dải xanh, có hoạ tiết sóng.
    hem = N.new("ShaderNodeAttribute")
    hem.attribute_type = "GEOMETRY"
    hem.attribute_name = "hem"
    band = N.new("ShaderNodeMapRange")
    band.inputs["From Min"].default_value = 0.036
    band.inputs["From Max"].default_value = 0.032
    L(hem.outputs["Fac"], band.inputs["Value"])
    meander = N.new("ShaderNodeTexWave")
    meander.wave_profile = "SAW"
    meander.inputs["Scale"].default_value = 18
    L(tc.outputs["Object"], meander.inputs["Vector"])
    stripe = N.new("ShaderNodeMapRange")
    stripe.inputs["From Min"].default_value = 0.5
    stripe.inputs["From Max"].default_value = 0.55
    L(meander.outputs["Fac"], stripe.inputs["Value"])
    trim_c = N.new("ShaderNodeMix")
    trim_c.data_type = "RGBA"
    L(stripe.outputs[0], trim_c.inputs["Factor"])
    trim_c.inputs[6].default_value = srgb(trim)
    trim_c.inputs[7].default_value = srgb("#C9A64A")
    col = N.new("ShaderNodeMix")
    col.data_type = "RGBA"
    L(band.outputs[0], col.inputs["Factor"])
    L(dirt.outputs[2], col.inputs[6])
    L(trim_c.outputs[2], col.inputs[7])
    L(col.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Sheen Weight"].default_value = 0.4
    bsdf.inputs["Sheen Tint"].default_value = (1, 1, 1, 1)
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def hair_mass_material():
    """Lõi khối tóc xoăn: sẫm, bóng mờ, vân xoắn nhỏ bằng bump Voronoi."""
    mat = solid_scales_material("HairMass", HAIR, "#0C0704", scale=260 / K, rough=0.55, metallic=0.0)
    return mat


def leather_material(name="Leather", hex_="#5A3620"):
    mat = skin_material(name, hex_, rough=0.55, noise_scale=60 / K)
    return mat


def cloth_material(name, hex_):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = srgb(hex_)
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Sheen Weight"].default_value = 0.5
    return mat


# ---------------------------------------------------------------- trang phục








def tunic_group(body, rig, co):
    """Nhóm đỉnh `tunic`: thân từ vai trái chéo xuống nách phải (exomis hở vai
    phải), váy từ hông tới giữa đùi (lấy lưới phụ `helper-skirt` của MPFB cho
    gấu váy liền hai chân). Nữ: che cả hai vai. Ghi `hem` = độ cao trên gấu."""
    w = weights_by_group(body)
    bl = rig.data.bones
    sh_l = bl["upperarm_l"].head_local
    arm_r = bl["upperarm_r"].tail_local
    thigh = bl["thigh_l"]
    hem_z = thigh.head_local.z + (thigh.tail_local.z - thigh.head_local.z) * 0.42
    top_l = sh_l.z + 0.12
    arm_z = arm_r.z + 0.06
    sx = bl["upperarm_r"].head_local.x  # âm (vai phải)
    slope = (top_l - arm_z) / (sh_l.x - sx)
    torso = ("pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r")
    sel, hem = [], []
    for i, p in enumerate(co):
        g = w[i]
        if g.get("HelperGeometry", 0) > 0.5 and g.get("helper-skirt", 0) < 0.5:
            sel.append(0.0); hem.append(1.0); continue
        if g.get("neck_01", 0) + g.get("head", 0) > 0.3 or p.z < hem_z:
            sel.append(0.0); hem.append(1.0); continue
        body_w = sum(g.get(n, 0) for n in torso)
        skirt = g.get("helper-skirt", 0) > 0.5
        leg = g.get("thigh_l", 0) + g.get("thigh_r", 0) > 0.5 and p.z > bl["thigh_l"].head_local.z - 0.06
        sleeve = g.get("upperarm_l", 0) > 0.4 and (p - sh_l).length < 0.09
        ok = body_w > 0.5 or skirt or leg or sleeve
        if ok and not FEMALE and p.z > arm_z + (p.x - sx) * slope:
            ok = False  # vai phải để trần
        if g.get("upperarm_r", 0) > 0.3 and not FEMALE:
            ok = False
        sel.append(1.0 if ok else 0.0)
        hem.append(p.z - hem_z)
    vg = body.vertex_groups.new(name="tunic")
    for i, s in enumerate(sel):
        if s:
            vg.add([i], 1.0, "REPLACE")
    store_point_attr(body, "hem", hem)
    return hem_z


def build(fat=0.35):
    """Thân + trang phục + tóc. Trả (thân, xương, {lớp: các object}) — lớp
    dùng cho sprite tách lớp (xem đầu file)."""
    body, rig = build_human(fat)
    body.data.materials.clear()
    body.data.materials.append(human_skin())
    co = rest_coords(body)
    w = weights_by_group(body)
    store_point_attr(body, "lips", [min(1.0, w[i].get("lips", 0)) for i in range(len(co))])
    bl = rig.data.bones

    # ---- áo exomis
    tunic_group(body, rig, co)
    linen = linen_material()
    shell_copy(body, "Tunic", "tunic", 0.012, 0.004, [linen])

    leather = leather_material()
    # ---- thắt lưng da quanh eo, khoá đồng phía trước
    waist_z = bl["spine_01"].head_local.z + 0.01
    ring_around(body, rig, co, "Belt", waist_z, "spine_01", leather, pad=0.02, r=0.018, flat=0.45,
                groups=("pelvis", "spine_01", "spine_02"))
    # ---- băng đầu đỏ ngang trán
    brow_z = bl["head"].head_local.z + (bl["head"].tail_local.z - bl["head"].head_local.z) * 0.62
    ring_around(body, rig, co, "Headband", brow_z, "head", cloth_material("Headband", "#A8261C"),
                pad=0.017, r=0.011, flat=0.5, groups=("head",))
    # ---- dây sandal quấn cổ chân + quai ngang mu bàn chân
    for s in ("l", "r"):
        calf = bl[f"calf_{s}"]
        for t in (0.82, 0.9):
            z = calf.head_local.z + (calf.tail_local.z - calf.head_local.z) * t
            ring_around(body, rig, co, f"Lace{s}", z, f"calf_{s}", leather, pad=0.004, r=0.006, flat=0.6,
                        side=s, groups=(f"calf_{s}", f"foot_{s}"))
        sole = bl[f"foot_{s}"].tail_local
        ring_around(body, rig, co, f"Strap{s}", sole.z + 0.035, f"foot_{s}", leather, pad=0.004, r=0.007,
                    flat=0.6, side=s, near=sole, groups=(f"foot_{s}", f"ball_{s}"))

    # ---- mắt: nhãn cầu + tròng nâu + đồng tử, gắn xương đầu
    sclera = skin_material("Sclera", "#EDE8E2", rough=0.15)
    iris = glow_material("Iris", "#2A160C", strength=0.0, base="#3A2214")
    for g in ("helper-l-eye", "helper-r-eye"):
        c = group_center(body, g, co)
        r = 0.0125 * K
        e = add_object("Eye", raw_ellipsoid("Eye", c, (r, r, r)), [sclera])
        parent_to_bone(e, rig, "head")
        ir = add_object("Iris", raw_ellipsoid("Iris", c + Vector((0, -r * 0.78, 0)), (r * 0.55, r * 0.3, r * 0.55)),
                        [iris])
        parent_to_bone(ir, rig, "head")
        # Lông mày: nét thon dày phía trong, mảnh dần ra đuôi.
        s = 1 if c.x > 0 else -1
        a = c + Vector((s * 0.004, -0.010, 0.019)) * K
        b = c + Vector((s * 0.016, -0.007, 0.022)) * K
        t = c + Vector((s * 0.026, -0.002, 0.016)) * K
        br = add_object("Brow", tapered_world("Brow", [(a, b, t, 0.0032 * K)], flat=2.2, taper=0.7),
                        [skin_material("BrowHair", HAIR, rough=0.6)])
        parent_to_bone(br, rig, "head")

    layers = {"skin": [body], "cloth": [o for o in bpy.data.objects
                                        if o.type in ("MESH", "CURVES") and o is not body
                                        and not o.name.startswith(("Brow", "Floor"))],
              "brows": [o for o in bpy.data.objects if o.name.startswith("Brow")], "hair": {}}
    styles = HAIR_STYLES if not STILL else ("ponytail" if FEMALE else "curly",)
    for style in styles:
        layers["hair"][style] = build_hair(body, rig, co, style)
    return body, rig, layers


def build_hair(body, rig, co, style):
    """Tóc kiểu [style] (HairStyle trong lib/art/hero_art.dart): khối tóc ôm
    da đầu + sợi thật. Sợi dài (đuôi ngựa, tóc dài) rủ theo trọng lực thật nên
    khi chống đẩy tóc buông xuống sàn."""
    if STILL:
        stops = [(0.0, "#5A3A24"), (0.5, HAIR), (1.0, "#120A06")]
    else:
        stops = [(0.0, "#F2EEEA"), (0.5, HAIR), (1.0, "#6A6662")]
    hair = fur_material("Hair_" + style, stops, sheen=0.08)
    out = []
    bl = rig.data.bones
    head_c = rig.matrix_world @ bl["head"].head_local.lerp(bl["head"].tail_local, 0.55)
    if style == "curly":
        # Khối tóc: vỏ phồng trên da đầu, gợn thành búi xoăn (dịch theo nhiễu
        # mây), rồi phủ sợi ngắn rối nằm sát theo khối.
        mass = shell_copy(body, "HairMass_curly", "scalp", 0.011, 0.0, [hair_mass_material()])
        tex = bpy.data.textures.new("Curls", "VORONOI")
        tex.noise_scale = 0.012
        clump = mass.modifiers.new("Curls", "DISPLACE")
        clump.texture = tex
        clump.texture_coords = "LOCAL"
        clump.strength = 0.007
        mass.modifiers.move(mass.modifiers.find("Curls"), 2)
        mass.add_rest_position_attribute = True
        out.append(mass)
        out.append(with_fur(mass, hair, density=45000 / K ** 2, length=(0.012 * K, 0.026 * K),
                            radius=0.0009 * K, comb=(0, 0, -0.3), lift=0.35, gravity=0.004 * K, jitter=1.2,
                            seed=7, resolution=5))
        return out
    if style == "buzz":
        mass = shell_copy(body, "HairMass_buzz", "scalp", 0.003, 0.0, [hair_mass_material()])
        mass.add_rest_position_attribute = True
        out.append(mass)
        out.append(with_fur(mass, hair, density=70000 / K ** 2, length=(0.004 * K, 0.008 * K),
                            radius=0.0006 * K, comb=(0, 0.3, 0), lift=0.6, gravity=0.0, jitter=0.4, seed=8,
                            resolution=3))
        return out
    # Tóc chải mượt ra sau, buộc lại (búi / đuôi ngựa) hoặc xoã (dài).
    mass = shell_copy(body, "HairMass_" + style, "scalp", 0.007, 0.0, [hair_mass_material()])
    mass.add_rest_position_attribute = True
    out.append(mass)
    out.append(with_fur(mass, hair, density=50000 / K ** 2, length=(0.014 * K, 0.026 * K), radius=0.0008 * K,
                        comb=(0, 1.0, -0.4), lift=0.05, gravity=0.002 * K, jitter=0.15, seed=9, resolution=5))
    if style == "long":
        # Sợi dài mọc ở nửa sau da đầu (không xoã che mặt), rủ theo trọng lực.
        front = [1.0 if (body.matrix_world @ c).y < head_c.y + 0.01 * K else 0.0 for c in co]
        store_point_attr(mass, "scar", front)
        out.append(with_fur(mass, hair, density=26000 / K ** 2, length=(0.2 * K, 0.3 * K), radius=0.0011 * K,
                            comb=(0, 0.6, -1.0), lift=0.2, gravity=0.09 * K, jitter=0.25, seed=10,
                            resolution=8))
        return out
    if style == "bun":
        at = head_c + Vector((0, 0.085, 0.055)) * K
        knot = add_object("Bun", raw_ellipsoid("Bun", at, (0.04 * K, 0.035 * K, 0.035 * K)),
                          [hair_mass_material()])
    else:  # ponytail
        at = head_c + Vector((0, 0.088, 0.02)) * K
        knot = add_object("Tie", raw_ellipsoid("Tie", at, (0.022 * K, 0.02 * K, 0.022 * K)),
                          [hair_mass_material()])
    parent_to_bone(knot, rig, "head")
    knot.add_rest_position_attribute = True
    out.append(knot)
    if style == "bun":
        out.append(with_fur(knot, hair, density=60000 / K ** 2, length=(0.01 * K, 0.02 * K), radius=0.0008 * K,
                            comb=(1, 0, 0), lift=0.1, gravity=0.0, jitter=0.6, seed=11, resolution=4))
    else:
        out.append(with_fur(knot, hair, density=90000 / K ** 2, length=(0.16 * K, 0.26 * K), radius=0.0012 * K,
                            comb=(0, 1.0, -0.6), lift=0.4, gravity=0.08 * K, jitter=0.2, seed=12,
                            resolution=8))
    return out


# ---------------------------------------------------------------- tư thế


class Poser:
    """Đặt dáng: xoay cả người (quay mặt sang phải + ngả theo thân), IK hai tay
    tới đích trên sàn, bàn tay úp phẳng, đầu ngẩng nhìn tới trước."""

    def __init__(self, rig):
        self.rig = rig
        bl = rig.data.bones
        self.a = (bl["upperarm_r"].tail_local - bl["upperarm_r"].head_local).length * K
        self.b = (bl["lowerarm_r"].tail_local - bl["lowerarm_r"].head_local).length * K
        self.ik = {}
        for s in ("l", "r"):
            t = bpy.data.objects.new(f"IK_{s}", None)
            p = bpy.data.objects.new(f"Pole_{s}", None)
            h = bpy.data.objects.new(f"Palm_{s}", None)
            for o in (t, p, h):
                bpy.context.scene.collection.objects.link(o)
            c = rig.pose.bones[f"lowerarm_{s}"].constraints.new("IK")
            c.target, c.pole_target, c.chain_count = t, p, 2
            c.pole_angle = math.radians(-90)
            cr = rig.pose.bones[f"hand_{s}"].constraints.new("COPY_ROTATION")
            cr.target = h
            self.ik[s] = (t, p, h, c, cr)

    def body_matrix(self, pitch, at=Vector()):
        """Quay mặt sang phải (+X) rồi ngả về trước [pitch] rad quanh trục Y."""
        return Matrix.Translation(at) @ Matrix.Rotation(pitch, 4, "Y") @ Matrix.Rotation(math.pi / 2, 4, "Z") \
            @ Matrix.Diagonal((K, K, K, 1))

    def world(self, bone, at=0.0):
        pb = self.rig.pose.bones[bone]
        return self.rig.matrix_world @ pb.head.lerp(pb.tail, at)

    def clear(self):
        for pb in self.rig.pose.bones:
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
        for s in ("l", "r"):
            self.ik[s][3].influence = 1.0
            self.ik[s][4].influence = 1.0

    def set_palm(self, s, fingers, palm_down):
        """Bàn tay [s]: ngón chỉ theo [fingers], lòng bàn tay úp theo [palm_down]."""
        rig = self.rig
        bl = rig.data.bones
        rest = rig.matrix_world @ bl[f"hand_{s}"].matrix_local
        d = (bl[f"middle_01_{s}"].head_local - bl[f"hand_{s}"].head_local)
        d = (rig.matrix_world.to_3x3() @ d).normalized()
        # Lòng bàn tay lúc nghỉ (dáng chữ A) quay vào trong thân.
        inward = rig.matrix_world.to_3x3() @ Vector((-1 if s == "l" else 1, 0, 0))
        n = (inward - d * inward.dot(d)).normalized()
        fr = Matrix((d, n, d.cross(n))).transposed()
        f = fingers.normalized()
        pd = (palm_down - f * palm_down.dot(f)).normalized()
        to = Matrix((f, pd, f.cross(pd))).transposed()
        q = to @ fr.transposed()
        h = self.ik[s][2]
        h.matrix_world = (q.to_4x4() @ Matrix(rest.to_3x3()).to_4x4())

    def plank(self, elbow_deg, knees=False, x0=0.0):
        rig = self.rig
        self.clear()
        bl = rig.data.bones
        if knees:
            # Cẳng chân gập ra sau, nhấc bàn chân khỏi sàn.
            for s in ("l", "r"):
                rig.pose.bones[f"calf_{s}"].rotation_euler.x = math.radians(72)
                rig.pose.bones[f"foot_{s}"].rotation_euler.x = math.radians(-35)
        else:
            for s in ("l", "r"):
                rig.pose.bones[f"ball_{s}"].rotation_euler.x = math.radians(-55)  # ngón chân gập trên sàn
        rig.pose.bones["neck_01"].rotation_euler.x = math.radians(-22)
        rig.pose.bones["head"].rotation_euler.x = math.radians(-18)

        def place(pitch):
            rig.matrix_world = self.body_matrix(pitch)
            bpy.context.view_layer.update()
            if knees:
                p = self.world("calf_r", 0.0) + Vector((0.0, 0, -0.055 * K))
            else:
                p = self.world("ball_r", 1.0)
            rig.matrix_world = self.body_matrix(pitch, Vector((x0 - p.x, 0, 0.012 * K - p.z)))
            bpy.context.view_layer.update()
            return self.world("upperarm_r", 0.0)

        # Tay thẳng: vai ngay trên cổ tay (cổ tay cao khỏi sàn một chút).
        wrist_z = 0.045 * K
        full = self.a + self.b
        lo, hi = math.radians(20), math.radians(89)
        for _ in range(40):
            mid = (lo + hi) / 2
            if place(mid).z - wrist_z > full:
                lo = mid
            else:
                hi = mid
        straight = place((lo + hi) / 2)
        wx = straight.x
        th = math.radians(min(max(elbow_deg, 55), 179))
        reach = math.sqrt(self.a ** 2 + self.b ** 2 - 2 * self.a * self.b * math.cos(th))
        lo2, hi2 = (lo + hi) / 2, math.radians(100)
        for _ in range(40):
            mid = (lo2 + hi2) / 2
            sh = place(mid)
            dist = math.hypot(sh.x - wx, sh.z - wrist_z)
            if dist > reach:
                lo2 = mid
            else:
                hi2 = mid
        place((lo2 + hi2) / 2)
        for s in ("l", "r"):
            sh = self.world(f"upperarm_{s}", 0.0)
            t, p, *_ = self.ik[s]
            out = 0.07 * K * (1 if s == "l" else -1)
            t.location = Vector((wx + 0.02 * K, sh.y + out, wrist_z))
            # Khuỷu chĩa về phía chân, hơi bung ra ngoài (khoảng 45°).
            p.location = sh + Vector((-0.5 * K, out * 3, 0.05 * K))
            self.set_palm(s, Vector((1, 0.15 * (1 if s == "l" else -1), 0)), Vector((0, 0, -1)))
        bpy.context.view_layer.update()

    def standing(self, x0=0.0, victory=0.0):
        rig = self.rig
        self.clear()
        rig.matrix_world = self.body_matrix(0.0)
        bpy.context.view_layer.update()
        p = self.world("ball_r", 1.0)
        rig.matrix_world = self.body_matrix(0.0, Vector((x0 - p.x - 0.12 * K, 0, -min(self.world("foot_r", 1.0).z, 0))))
        bpy.context.view_layer.update()
        for s in ("l", "r"):
            sh = self.world(f"upperarm_{s}", 0.0)
            t, p, *_ = self.ik[s]
            out = 0.06 * K * (1 if s == "l" else -1)
            reach = (self.a + self.b) * 0.97
            if s == "r" and victory:
                # Giơ nắm tay lên trời.
                t.location = sh + Vector((0.08 * K, out, reach * 0.95))
                p.location = sh + Vector((0.3 * K, out * 4, 0.2 * K))
                self.set_palm(s, Vector((0, 0, 1)), Vector((1, 0, 0)))
            else:
                t.location = sh + Vector((0.03 * K, out, -reach))
                p.location = sh + Vector((-0.4 * K, out, -0.2 * K))
                self.set_palm(s, Vector((0.05, 0, -1)), Vector((0, -1 if s == "l" else 1, 0)))
        bpy.context.view_layer.update()


# ---------------------------------------------------------------- cảnh


def lights(scene):
    """Nắng chiều Hy Lạp ấm từ trên–trước, trời xanh hắt, viền sáng phía sau."""
    from boss_kit import add_sun
    add_sun(scene, "Key", (0.45, 0.65, -0.62), 4.2, "#FFE2B8", angle=2.5)
    add_sun(scene, "Rim", (-0.7, -0.35, -0.3), 3.0, "#BFD8FF", angle=4)
    add_sun(scene, "Bounce", (0.1, 0.3, 0.9), 0.5, "#D8B888", angle=30)






def stage_units_per_m(rig):
    """Đơn vị sân khấu mỗi mét: cổ chân → vai dài bằng cẳng chân + đùi + thân
    của HeroBody (lib/art/hero_pose.dart: 42 + 44 + 62)."""
    bl = rig.data.bones
    ankle = rig.matrix_world @ bl["foot_r"].head_local
    shoulder = rig.matrix_world @ bl["upperarm_r"].head_local
    return 148.0 / (shoulder - ankle).length


def show_layer(layers, visible, hair_style=None, floor=None):
    """Chỉ lớp [visible] hiện; lớp khác đục lỗ (holdout); kiểu tóc khác ẩn hẳn."""
    hair = layers["hair"]
    for o in layers["skin"] + layers["cloth"] + layers["brows"] + [x for v in hair.values() for x in v]:
        o.hide_render = False
        o.is_holdout = o not in visible
    for style, objs in hair.items():
        if style != hair_style:
            for o in objs:
                o.hide_render = True
    if floor is not None:
        floor.hide_render = floor not in visible


def main():
    scene = reset_scene(samples=128, world_hex="#9DB6D2", world_strength=0.55, keep_prefs=True)
    body, rig, layers = build()
    poser = Poser(rig)
    lights(scene)
    floor = shadow_catcher()
    tag = "female" if FEMALE else "male"
    out = os.path.join(ROOT, "build", "blender", "hero")
    os.makedirs(out, exist_ok=True)
    if STILL:
        # Ảnh duyệt: khung rộng, độ phân giải cao.
        camera(scene, 0.75 * K, 0.55 * K, 2.3 * K, 1.25 * K, 520)
        for name, fn in (("plank_top", lambda: poser.plank(175)),
                         ("plank_bottom", lambda: poser.plank(78)),
                         ("knees_bottom", lambda: poser.plank(82, knees=True, x0=0.35 * K))):
            fn()
            render_to(scene, os.path.join(out, f"{tag}_{name}.png"))
        camera(scene, 0.4 * K, 0.95 * K, 1.25 * K, 2.0 * K, 420)
        for name, fn in (("stand", lambda: poser.standing(0.4 * K)),
                         ("victory", lambda: poser.standing(0.4 * K, victory=1))):
            fn()
            render_to(scene, os.path.join(out, f"{tag}_{name}.png"))
        from boss_kit import save_blend
        save_blend(f"hero_{tag}")
        return

    from sprite_kit import export_sprites
    upm = stage_units_per_m(rig)
    print(f"HERO units/m = {upm:.1f}")
    # Gốc toạ độ sprite = mũi chân trên sàn lúc chống đẩy, ứng với điểm
    # (40, 220) của sân khấu; chống gối đặt đầu gối, đứng đặt mũi chân như
    # HeroPose (đầu gối x = 76, mũi chân đứng x = 123).
    knee_x = (76 - 40) / upm
    stand_x = (123 - 40) / upm + 0.12 * K
    elbows = [178 - 108 * k / 8 for k in range(9)]  # 178° → 70°
    anims = {
        "plank": [lambda e=e: poser.plank(e) for e in elbows],
        "knees": [lambda e=e: poser.plank(e, knees=True, x0=knee_x) for e in elbows],
        "stand": [lambda: poser.standing(stand_x)],
        "victory": [lambda: poser.standing(stand_x, victory=1)],
    }
    cam = camera(scene, 0.9 * K, 0.95 * K, 2.6 * K, 2.1 * K, 3.0 * upm, yaw=-10, pitch=7)
    meta = {"elbowFrom": 178, "elbowTo": 70, "anchorX": 40}
    show_layer(layers, layers["skin"])
    export_sprites(scene, cam, f"hero_{tag}_skin", anims, Vector(), upm, extra=meta)
    show_layer(layers, layers["cloth"] + [floor], floor=floor)
    export_sprites(scene, cam, f"hero_{tag}_cloth", anims, Vector(), upm, extra=meta)
    scene.cycles.samples = 64
    for style, objs in layers["hair"].items():
        show_layer(layers, objs + layers["brows"], hair_style=style)
        export_sprites(scene, cam, f"hero_{tag}_hair_{style}", anims, Vector(), upm, extra=meta)
    from boss_kit import save_blend
    save_blend(f"hero_{tag}")


main()
