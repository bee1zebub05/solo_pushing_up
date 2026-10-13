"""Đồ Hy Lạp cổ dùng chung cho quái chương 1 (fantasy realism): vật liệu cẩm
thạch / đồng / đất sét, mũ Corinth, khiên aspis, giáo dory, giáp ngực, ống
đồng che cẳng chân, váy giáp pteruges. Toạ độ mét; `co` = toạ độ nghỉ cục bộ
của thân MPFB (human_kit.rest_coords)."""

import math

import bpy
from mathutils import Vector

from boss_kit import add_object, parent_to_bone, srgb, fur_material, with_fur
from human_kit import (group_center, raw_ellipsoid, raw_tube, shell_copy, tapered_world,
                       weights_by_group)


# ---------------------------------------------------------------- vật liệu


def _principled(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return mat, nt, bsdf


def _cracks(nt, scale, width, mask_scale, mask_lo):
    """0–1: đường nứt mảnh (cạnh Voronoi bị nhiễu uốn), chỉ ở vùng mặt nạ nhiễu."""
    N, L = nt.nodes, nt.links.new
    tc = N.new("ShaderNodeTexCoord")
    warp = N.new("ShaderNodeTexNoise")
    warp.inputs["Scale"].default_value = scale * 0.6
    L(tc.outputs["Object"], warp.inputs["Vector"])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "VECTOR"
    mix.inputs["Factor"].default_value = 0.25
    L(tc.outputs["Object"], mix.inputs[4])
    L(warp.outputs["Color"], mix.inputs[5])
    vor = N.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = scale
    L(mix.outputs[1], vor.inputs["Vector"])
    line = N.new("ShaderNodeMapRange")
    line.inputs["From Min"].default_value = width
    line.inputs["From Max"].default_value = 0.0
    L(vor.outputs["Distance"], line.inputs["Value"])
    m = N.new("ShaderNodeTexNoise")
    m.inputs["Scale"].default_value = mask_scale
    L(tc.outputs["Object"], m.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = mask_lo
    mr.inputs["From Max"].default_value = mask_lo + 0.06
    L(m.outputs["Fac"], mr.inputs["Value"])
    mul = N.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    L(line.outputs[0], mul.inputs[0])
    L(mr.outputs[0], mul.inputs[1])
    return mul.outputs[0]


def _crevice(nt, distance=0.03):
    """0–1: độ khuất (AO) — 1 ở khe, nách, rãnh."""
    N, L = nt.nodes, nt.links.new
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = distance
    inv = N.new("ShaderNodeMapRange")
    inv.inputs["From Min"].default_value = 0.85
    inv.inputs["From Max"].default_value = 0.35
    L(ao.outputs["AO"], inv.inputs["Value"])
    return inv.outputs[0]


def marble_material(name="Marble", base="#E8E4DB", vein="#B4AEA6", glow="#9A5CFF", moss="#4E6A2E",
                    glow_strength=4.0):
    """Cẩm thạch phong hoá: vân xám uốn lượn, mặt hơi trong (SSS), bẩn đọng
    trong khe, rêu mọc ở khe hướng lên, đường nứt rỉ ánh tím Trì Trệ."""
    mat, nt, bsdf = _principled(name)
    N, L = nt.nodes, nt.links.new
    tc = N.new("ShaderNodeTexCoord")
    wave = N.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = 3.5
    wave.inputs["Distortion"].default_value = 22
    wave.inputs["Detail"].default_value = 8
    wave.inputs["Detail Roughness"].default_value = 0.7
    L(tc.outputs["Object"], wave.inputs["Vector"])
    vmask = N.new("ShaderNodeMapRange")
    vmask.inputs["From Min"].default_value = 0.95
    vmask.inputs["From Max"].default_value = 0.995
    vmask.inputs["To Max"].default_value = 0.7
    L(wave.outputs["Fac"], vmask.inputs["Value"])
    col = N.new("ShaderNodeMix")
    col.data_type = "RGBA"
    L(vmask.outputs[0], col.inputs["Factor"])
    col.inputs[6].default_value = srgb(base)
    col.inputs[7].default_value = srgb(vein)
    crev = _crevice(nt)
    dirt = N.new("ShaderNodeMix")
    dirt.data_type = "RGBA"
    L(crev, dirt.inputs["Factor"])
    L(col.outputs[2], dirt.inputs[6])
    dirt.inputs[7].default_value = srgb("#6A6256")
    # Rêu: khe + mặt hướng lên + nhiễu loang.
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    L(geo.outputs["Normal"], sep.inputs[0])
    upm = N.new("ShaderNodeMapRange")
    upm.inputs["From Min"].default_value = 0.2
    upm.inputs["From Max"].default_value = 0.8
    L(sep.outputs[2], upm.inputs["Value"])
    blot = N.new("ShaderNodeTexNoise")
    blot.inputs["Scale"].default_value = 6
    L(tc.outputs["Object"], blot.inputs["Vector"])
    bm = N.new("ShaderNodeMapRange")
    bm.inputs["From Min"].default_value = 0.5
    bm.inputs["From Max"].default_value = 0.62
    L(blot.outputs["Fac"], bm.inputs["Value"])
    m1 = N.new("ShaderNodeMath")
    m1.operation = "MULTIPLY"
    L(upm.outputs[0], m1.inputs[0])
    L(bm.outputs[0], m1.inputs[1])
    m2 = N.new("ShaderNodeMath")
    m2.operation = "MAXIMUM"
    L(m1.outputs[0], m2.inputs[0])
    m3 = N.new("ShaderNodeMath")
    m3.operation = "MULTIPLY"
    L(crev, m3.inputs[0])
    L(bm.outputs[0], m3.inputs[1])
    L(m3.outputs[0], m2.inputs[1])
    mossy = N.new("ShaderNodeMix")
    mossy.data_type = "RGBA"
    L(m2.outputs[0], mossy.inputs["Factor"])
    L(dirt.outputs[2], mossy.inputs[6])
    mossy.inputs[7].default_value = srgb(moss)
    crack = _cracks(nt, scale=7, width=0.02, mask_scale=3.0, mask_lo=0.6)
    dark = N.new("ShaderNodeMix")
    dark.data_type = "RGBA"
    L(crack, dark.inputs["Factor"])
    L(mossy.outputs[2], dark.inputs[6])
    dark.inputs[7].default_value = srgb("#1A1424")
    L(dark.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Emission Color"].default_value = srgb(glow)
    em = N.new("ShaderNodeMath")
    em.operation = "MULTIPLY"
    em.inputs[1].default_value = glow_strength
    L(crack, em.inputs[0])
    L(em.outputs[0], bsdf.inputs["Emission Strength"])
    bsdf.inputs["Subsurface Weight"].default_value = 0.15
    bsdf.inputs["Subsurface Radius"].default_value = (0.4, 0.4, 0.35)
    bsdf.inputs["Subsurface Scale"].default_value = 0.01
    rough = N.new("ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = 0.32
    rough.inputs["To Max"].default_value = 0.7
    L(m2.outputs[0], rough.inputs["Value"])
    L(rough.outputs[0], bsdf.inputs["Roughness"])
    # Bề mặt đá: rỗ li ti + nứt lõm.
    pits = N.new("ShaderNodeTexNoise")
    pits.inputs["Scale"].default_value = 160
    pits.inputs["Detail"].default_value = 8
    L(tc.outputs["Object"], pits.inputs["Vector"])
    h = N.new("ShaderNodeMath")
    h.operation = "SUBTRACT"
    L(pits.outputs["Fac"], h.inputs[0])
    L(crack, h.inputs[1])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.004
    L(h.outputs[0], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    return mat


def bronze_material(name="Bronze", base="#A27A4C", patina="#3F8E78", rough=0.34, polish=1.0):
    """Đồng thau: kim loại ánh vàng nâu, xước mảnh, gỉ xanh đọng ở khe/mép."""
    mat, nt, bsdf = _principled(name)
    N, L = nt.nodes, nt.links.new
    tc = N.new("ShaderNodeTexCoord")
    crev = _crevice(nt, 0.04)
    blot = N.new("ShaderNodeTexNoise")
    blot.inputs["Scale"].default_value = 14
    blot.inputs["Detail"].default_value = 6
    L(tc.outputs["Object"], blot.inputs["Vector"])
    pm = N.new("ShaderNodeMath")
    pm.operation = "MULTIPLY_ADD"
    L(blot.outputs["Fac"], pm.inputs[0])
    pm.inputs[1].default_value = 0.9 * (2 - polish)
    L(crev, pm.inputs[2])
    pmr = N.new("ShaderNodeMapRange")
    pmr.inputs["From Min"].default_value = 0.75
    pmr.inputs["From Max"].default_value = 1.0
    L(pm.outputs[0], pmr.inputs["Value"])
    col = N.new("ShaderNodeMix")
    col.data_type = "RGBA"
    L(pmr.outputs[0], col.inputs["Factor"])
    col.inputs[6].default_value = srgb(base)
    col.inputs[7].default_value = srgb(patina)
    L(col.outputs[2], bsdf.inputs["Base Color"])
    met = N.new("ShaderNodeMapRange")
    met.inputs["To Min"].default_value = 1.0
    met.inputs["To Max"].default_value = 0.1
    L(pmr.outputs[0], met.inputs["Value"])
    L(met.outputs[0], bsdf.inputs["Metallic"])
    scratch = N.new("ShaderNodeTexWave")
    scratch.inputs["Scale"].default_value = 60
    scratch.inputs["Distortion"].default_value = 30
    L(tc.outputs["Object"], scratch.inputs["Vector"])
    rr = N.new("ShaderNodeMapRange")
    rr.inputs["To Min"].default_value = rough * 0.7
    rr.inputs["To Max"].default_value = rough * 1.5 + 0.1
    L(scratch.outputs["Fac"], rr.inputs["Value"])
    rmax = N.new("ShaderNodeMath")
    rmax.operation = "MAXIMUM"
    L(rr.outputs[0], rmax.inputs[0])
    L(pmr.outputs[0], rmax.inputs[1])
    L(rmax.outputs[0], bsdf.inputs["Roughness"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.12
    L(blot.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    return mat


def clay_material(name="Clay", base="#6E4A30", glow="#FF6A1E", glow_strength=6.0):
    """Đất sét khô nứt nẻ (người mọc từ răng rồng gieo xuống đất): mảng nứt
    sâu rỉ ánh lửa, bụi đất bám, đốm ẩm sẫm."""
    mat, nt, bsdf = _principled(name)
    N, L = nt.nodes, nt.links.new
    tc = N.new("ShaderNodeTexCoord")
    blot = N.new("ShaderNodeTexNoise")
    blot.inputs["Scale"].default_value = 9
    blot.inputs["Detail"].default_value = 6
    L(tc.outputs["Object"], blot.inputs["Vector"])
    col = N.new("ShaderNodeMix")
    col.data_type = "RGBA"
    L(blot.outputs["Fac"], col.inputs["Factor"])
    col.inputs[6].default_value = srgb(base)
    col.inputs[7].default_value = srgb("#9A7A5A")
    crack = _cracks(nt, scale=11, width=0.035, mask_scale=2.5, mask_lo=0.38)
    dark = N.new("ShaderNodeMix")
    dark.data_type = "RGBA"
    L(crack, dark.inputs["Factor"])
    L(col.outputs[2], dark.inputs[6])
    dark.inputs[7].default_value = srgb("#1A0C06")
    L(dark.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Emission Color"].default_value = srgb(glow)
    em = N.new("ShaderNodeMath")
    em.operation = "MULTIPLY"
    em.inputs[1].default_value = glow_strength
    L(crack, em.inputs[0])
    L(em.outputs[0], bsdf.inputs["Emission Strength"])
    bsdf.inputs["Roughness"].default_value = 0.88
    pits = N.new("ShaderNodeTexNoise")
    pits.inputs["Scale"].default_value = 120
    pits.inputs["Detail"].default_value = 8
    L(tc.outputs["Object"], pits.inputs["Vector"])
    h = N.new("ShaderNodeMath")
    h.operation = "SUBTRACT"
    L(pits.outputs["Fac"], h.inputs[0])
    hk = N.new("ShaderNodeMath")
    hk.operation = "MULTIPLY"
    hk.inputs[1].default_value = 1.5
    L(crack, hk.inputs[0])
    L(hk.outputs[0], h.inputs[1])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.45
    bump.inputs["Distance"].default_value = 0.006
    L(h.outputs[0], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    return mat


def wood_material(name="Wood", hex_="#5A3A22"):
    mat, nt, bsdf = _principled(name)
    N, L = nt.nodes, nt.links.new
    tc = N.new("ShaderNodeTexCoord")
    grain = N.new("ShaderNodeTexWave")
    grain.wave_type = "RINGS"
    grain.inputs["Scale"].default_value = 3
    grain.inputs["Distortion"].default_value = 8
    L(tc.outputs["Object"], grain.inputs["Vector"])
    col = N.new("ShaderNodeMix")
    col.data_type = "RGBA"
    L(grain.outputs["Fac"], col.inputs["Factor"])
    col.inputs[6].default_value = srgb(hex_)
    col.inputs[7].default_value = [c * 0.6 for c in srgb(hex_)[:3]] + [1]
    L(col.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    return mat


# ---------------------------------------------------------------- áo giáp theo thân


def make_group(body, name, pick):
    """Nhóm đỉnh [name] = các đỉnh mà pick(chỉ_số, trọng_số_theo_nhóm) đúng."""
    w = weights_by_group(body)
    vg = body.vertex_groups.new(name=name)
    for i in range(len(w)):
        if w[i].get("HelperGeometry", 0) < 0.5 and pick(i, w[i]):
            vg.add([i], 1.0, "REPLACE")
    return vg


def corinthian_helmet(body, rig, co, mat, offset=0.014):
    """Mũ Corinth: vỏ ôm kín đầu (che má, gáy), chừa khe chữ T — hai khe
    mắt hạnh nhân, sống mũi che, khe dọc ở miệng/cằm."""
    le = group_center(body, "helper-l-eye", co)
    re_ = group_center(body, "helper-r-eye", co)
    inv = body.matrix_world.inverted()
    le, re_ = inv @ le, inv @ re_
    ez, ey, ex = (le.z + re_.z) / 2, (le.y + re_.y) / 2, abs(le.x - re_.x) / 2

    def pick(i, g):
        p = co[i]
        if g.get("head", 0) + g.get("neck_01", 0) * 0.6 < 0.5:
            return False
        front = p.y < ey + 0.012
        if front and abs(p.z - ez) < 0.016 and 0.011 < abs(p.x) < ex + 0.03:
            return False  # khe mắt
        if front and abs(p.x) < 0.017 and p.z < ez - 0.032:
            return False  # khe miệng
        return True

    make_group(body, "helmet", pick)
    return shell_copy(body, "Helmet", "helmet", offset + 0.006, 0.006, [mat], smooth=25)


def helmet_crest(body, rig, co, mat, hair_mat=None, height=0.06, width=0.012):
    """Mào chạy dọc đỉnh mũ từ trán ra gáy (vòng cung trong mặt phẳng giữa).
    [hair_mat]: mọc lông ngựa thật trên mào (bản đồng); không có thì mào tạc."""
    bl = rig.data.bones
    head = bl["head"]
    top = head.tail_local.z + 0.035
    cy = head.head_local.y + 0.01
    ry = 0.12
    pts, rad = [], []
    for k in range(25):
        a = math.pi * (0.1 + 0.85 * k / 24)  # trước → sau
        y = cy - math.cos(a) * ry
        z = top - 0.11 + math.sin(a) * 0.11
        pts.append(body.matrix_world @ Vector((0, y, z + height * 0.5)))
        t = k / 24
        rad.append((width * (1 - 0.3 * t), height * (0.5 + 0.5 * math.sin(math.pi * min(1, t * 1.3)))))
    s = body.matrix_world.to_scale().x
    o = add_object("Crest", raw_tube("Crest", pts, [(a * s, b * s) for a, b in rad], sides=14), [mat])
    parent_to_bone(o, rig, "head")
    if hair_mat:
        o.add_rest_position_attribute = True
        with_fur(o, hair_mat, density=26000 / s ** 2, length=(0.07 * s, 0.13 * s), radius=0.0012 * s,
                 comb=(0, 1.0, -0.4), lift=0.5, gravity=0.04 * s, jitter=0.25, seed=13)
    return o


def cuirass(body, rig, co, mat, offset=0.022):
    """Giáp ngực đúc ("cuirass cơ bắp") ôm thân từ hông tới cổ, hở tay."""
    bl = rig.data.bones
    zlo = bl["pelvis"].head_local.z + 0.03
    torso = ("spine_01", "spine_02", "spine_03", "pelvis", "clavicle_l", "clavicle_r")

    def pick(i, g):
        if co[i].z < zlo:
            return False
        if g.get("upperarm_l", 0) + g.get("upperarm_r", 0) > 0.35:
            return False
        if g.get("neck_01", 0) + g.get("head", 0) > 0.25:
            return False
        return sum(g.get(n, 0) for n in torso) > 0.5

    make_group(body, "cuirass", pick)
    return shell_copy(body, "Cuirass", "cuirass", offset, 0.008, [mat], smooth=6)


def greaves(body, rig, co, mat, offset=0.012):
    bl = rig.data.bones

    def pick(i, g):
        p = co[i]
        for s in ("l", "r"):
            c = bl[f"calf_{s}"]
            if g.get(f"calf_{s}", 0) > 0.5 and c.tail_local.z + 0.06 < p.z < c.head_local.z + 0.03:
                return True
        return False

    make_group(body, "greaves", pick)
    return shell_copy(body, "Greaves", "greaves", offset, 0.004, [mat], smooth=4)


def pteruges(body, rig, co, mat, count=16, length=0.2):
    """Váy giáp: các dải da/vải dày rủ quanh hông dưới mép giáp ngực."""
    bl = rig.data.bones
    z = bl["pelvis"].head_local.z + 0.04
    pts = [p for i, p in enumerate(co) if abs(p.z - z) < 0.01]
    w = weights_by_group(body)
    pts = [co[i] for i in range(len(co)) if abs(co[i].z - z) < 0.01
           and w[i].get("HelperGeometry", 0) < 0.5 and w[i].get("hand_l", 0) + w[i].get("hand_r", 0)
           + w[i].get("lowerarm_l", 0) + w[i].get("lowerarm_r", 0) < 0.2]
    cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
    cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
    rx = (max(p.x for p in pts) - min(p.x for p in pts)) / 2 + 0.035
    ry = (max(p.y for p in pts) - min(p.y for p in pts)) / 2 + 0.035
    strands = []
    M = body.matrix_world
    for k in range(count):
        a = 2 * math.pi * (k + 0.5) / count
        d = Vector((math.cos(a), math.sin(a), 0))
        top = Vector((cx + rx * d.x, cy + ry * d.y, z))
        bot = top + d * 0.05 + Vector((0, 0, -length))
        strands.append((M @ top, M @ (top + (bot - top) * 0.5 + d * 0.01), M @ bot, 0.03 * M.to_scale().x))
    o = add_object("Pteruges", tapered_world("Pteruges", strands, sides=6, flat=3.2, taper=0.05), [mat])
    parent_to_bone(o, rig, "pelvis")
    return o


# ---------------------------------------------------------------- vũ khí (dựng dọc trục +Z cục bộ)


def aspis(name, mat, rim_mat=None, radius=0.46, depth=0.1, emblem_mat=None):
    """Khiên tròn lõm (aspis/hoplon): mặt khum, vành dày; mặt ngoài hướng +Z
    cục bộ, tâm tại gốc. [emblem_mat]: hoạ tiết nổi (vòng xoáy) ở giữa."""
    import bmesh
    bm = bmesh.new()
    rings, sectors = 18, 64
    grid = []
    for i in range(rings + 1):
        rho = radius * i / rings
        row = []
        for k in range(sectors):
            a = 2 * math.pi * k / sectors
            row.append(bm.verts.new((rho * math.cos(a), rho * math.sin(a), depth * (1 - (rho / radius) ** 2))))
        grid.append(row)
    for i in range(rings):
        for k in range(sectors):
            k2 = (k + 1) % sectors
            bm.faces.new((grid[i][k], grid[i][k2], grid[i + 1][k2], grid[i + 1][k]))
    bmesh.ops.remove_doubles(bm, verts=grid[0], dist=1e-6)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    o = add_object(name, mesh, [mat])
    sol = o.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.02
    sub = o.modifiers.new("Smooth", "SUBSURF")
    sub.levels = sub.render_levels = 1
    parts = [o]
    rim = [Vector((radius * math.cos(2 * math.pi * k / 64), radius * math.sin(2 * math.pi * k / 64), -0.005))
           for k in range(64)]
    r = add_object(name + "Rim", raw_tube(name + "Rim", rim, [0.022] * 64, sides=12, closed=True),
                   [rim_mat or mat])
    parts.append(r)
    if emblem_mat:
        # Vòng xoáy ba nhánh (triskelion) nổi giữa khiên + núm tâm.
        strands = []
        for b in range(3):
            pts = []
            for i in range(16):
                t = i / 15
                a = 2 * math.pi * b / 3 + t * 2.6
                rho = 0.05 + 0.24 * t
                pts.append(Vector((rho * math.cos(a), rho * math.sin(a), depth * (1 - (rho / radius) ** 2) + 0.012)))
            strands.append(add_object(name + "Swirl", raw_tube(name + "Swirl", pts,
                                                                [0.022 * (1 - 0.7 * i / 15) for i in range(16)],
                                                                sides=10), [emblem_mat]))
        boss = add_object(name + "Boss", raw_ellipsoid(name + "Boss", Vector((0, 0, depth + 0.004)),
                                                         (0.06, 0.06, 0.035)), [emblem_mat])
        parts += strands + [boss]
    return parts


def dory(name, shaft_mat, head_mat, length=2.5, grip=0.9):
    """Giáo dory: cán gỗ, mũi đồng hình lá có gân giữa, chuôi nhọn (sauroter).
    Dựng dọc +Z cục bộ, gốc ở chỗ cầm (cách đuôi [grip] m)."""
    z0, z1 = -grip, length - grip
    shaft = add_object(name, tapered_world(name, [(Vector((0, 0, z0)), Vector((0, 0, (z0 + z1) / 2)),
                                                   Vector((0, 0, z1 - 0.2)), 0.018)], taper=0.25, sides=10),
                       [shaft_mat])
    leaf = []
    for k in (-1, 1):
        leaf.append((Vector((0, 0, z1 - 0.24)), Vector((0.05 * k, 0, z1 - 0.12)), Vector((0, 0, z1 + 0.05)), 0.012))
    blade = add_object(name + "Blade", tapered_world(name + "Blade", [(Vector((0, 0, z1 - 0.24)),
                                                                       Vector((0, 0, z1 - 0.08)),
                                                                       Vector((0, 0, z1 + 0.08)), 0.022)],
                                                     sides=8, flat=2.2, taper=0.75), [head_mat])
    rib = add_object(name + "Rib", tapered_world(name + "Rib", [(Vector((0, 0, z1 - 0.28)), Vector((0, 0, z1 - 0.1)),
                                                                 Vector((0, 0, z1 + 0.04)), 0.012)], taper=0.9),
                     [head_mat])
    butt = add_object(name + "Butt", tapered_world(name + "Butt", [(Vector((0, 0, z0 + 0.14)), Vector((0, 0, z0 + 0.05)),
                                                                   Vector((0, 0, z0 - 0.1)), 0.02)], taper=1.2),
                      [head_mat])
    return [shaft, blade, rib, butt]


def holder(name, parts):
    """Empty làm gốc cho một món cầm tay (giáo, khiên)."""
    h = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(h)
    for p in parts:
        p.parent = h
    return h


def make_fist(rig, s, curl=1.0):
    """Nắm bàn tay [s] (cầm cán giáo / quai khiên)."""
    for f in ("index", "middle", "ring", "pinky"):
        for j, ang in (("01", 55), ("02", 80), ("03", 55)):
            pb = rig.pose.bones.get(f"{f}_{j}_{s}")
            if pb:
                pb.rotation_euler.x = math.radians(ang * curl)
    for j, ang in (("02", 25), ("03", 30)):
        pb = rig.pose.bones.get(f"thumb_{j}_{s}")
        if pb:
            pb.rotation_euler.x = math.radians(ang * curl)
