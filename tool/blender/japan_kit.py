"""Bộ chi tiết dùng chung cho boss hình người chương Nhật Bản (oni, tengu,
Susanoo, Tamamo): da nhuộm/xăm, sừng, chuỗi hạt, dây thừng shimenawa, quần
hakama, giáp tay, vuốt, lửa ma (onibi), chữ kanji, đứng ¾ quay về người chơi.

Toạ độ mét, cùng hệ MPFB (human_kit). Người MPFB nhìn về −Y; boss đứng bên
phải sân khấu nên quay mặt về −X (về phía người chơi) và chéo về máy quay.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

from boss_kit import add_object, glow_material, gold_material, parent_to_bone, skin_material, srgb
from human_kit import add_face_parts, make_human, raw_ellipsoid, raw_tube, tapered_world, weights_by_group

FONT_JP = r"C:\Windows\Fonts\YuGothB.ttc"  # có chữ Hán; dự phòng msgothic.ttc


# ---------------------------------------------------------------- vật liệu


def painted_skin(name, base, dark, tattoo=None, sss=0.15, rough=0.55, lips=None, cavity=None, tattoo_band=0.9,
                 tattoo_attr=None, tattoo_scale=4.5):
    """Da boss tô màu (đỏ oni, trắng ngà thần…): loang hai tông theo nhiễu,
    [tattoo] màu hoa văn xoáy (vân sóng méo) — để None nếu không xăm;
    [tattoo_band] 0,9 (nét dày) → 0,93 (nét mảnh, lộ khối cơ hơn).
    [tattoo_attr] tên thuộc tính điểm 0…1 giới hạn vùng xăm (ví dụ nửa ngực).
    [cavity] = (màu hõm, khoảng cách m, độ mạnh): tô đậm khe giữa các khối cơ
    bằng AO cục bộ, gờ cơ sáng lên — cho thớ cơ đọc rõ ở cỡ sprite."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links.new
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    tc = N.new("ShaderNodeTexCoord")
    blot = N.new("ShaderNodeTexNoise")
    blot.inputs["Scale"].default_value = 6
    blot.inputs["Detail"].default_value = 3
    L(tc.outputs["Object"], blot.inputs["Vector"])
    tone = N.new("ShaderNodeMix")
    tone.data_type = "RGBA"
    L(blot.outputs["Fac"], tone.inputs["Factor"])
    tone.inputs[6].default_value = srgb(base)
    tone.inputs[7].default_value = srgb(dark)
    color = tone.outputs[2]
    if tattoo:
        warp = N.new("ShaderNodeTexNoise")
        warp.inputs["Scale"].default_value = 3
        warp.inputs["Distortion"].default_value = 2.0
        L(tc.outputs["Object"], warp.inputs["Vector"])
        mix_v = N.new("ShaderNodeVectorMath")
        mix_v.operation = "ADD"
        L(tc.outputs["Object"], mix_v.inputs[0])
        sc = N.new("ShaderNodeVectorMath")
        sc.operation = "SCALE"
        L(warp.outputs["Color"], sc.inputs[0])
        sc.inputs["Scale"].default_value = 0.12
        L(sc.outputs[0], mix_v.inputs[1])
        wave = N.new("ShaderNodeTexWave")
        wave.wave_type = "RINGS"
        wave.inputs["Scale"].default_value = tattoo_scale
        wave.inputs["Distortion"].default_value = 11
        wave.inputs["Detail"].default_value = 2
        wave.inputs["Detail Scale"].default_value = 1.5
        L(mix_v.outputs[0], wave.inputs["Vector"])
        band = N.new("ShaderNodeMapRange")
        band.inputs["From Min"].default_value = tattoo_band
        band.inputs["From Max"].default_value = 0.94
        L(wave.outputs["Fac"], band.inputs["Value"])
        fac = band.outputs[0]
        if tattoo_attr:
            ta = N.new("ShaderNodeAttribute")
            ta.attribute_type = "GEOMETRY"
            ta.attribute_name = tattoo_attr
            mul = N.new("ShaderNodeMath")
            mul.operation = "MULTIPLY"
            L(fac, mul.inputs[0])
            L(ta.outputs["Fac"], mul.inputs[1])
            fac = mul.outputs[0]
        tm = N.new("ShaderNodeMix")
        tm.data_type = "RGBA"
        L(fac, tm.inputs["Factor"])
        L(color, tm.inputs[6])
        tm.inputs[7].default_value = srgb(tattoo)
        color = tm.outputs[2]
    if lips:
        # Môi tô son theo thuộc tính `lips` (store_point_attr từ nhóm đỉnh MPFB).
        la = N.new("ShaderNodeAttribute")
        la.attribute_type = "GEOMETRY"
        la.attribute_name = "lips"
        lm = N.new("ShaderNodeMix")
        lm.data_type = "RGBA"
        L(la.outputs["Fac"], lm.inputs["Factor"])
        L(color, lm.inputs[6])
        lm.inputs[7].default_value = srgb(lips)
        color = lm.outputs[2]
    if cavity:
        hue, dist, strength = cavity
        ao = N.new("ShaderNodeAmbientOcclusion")
        ao.only_local = True
        ao.samples = 16
        ao.inputs["Distance"].default_value = dist
        dark_k = N.new("ShaderNodeMapRange")  # AO 1 (lồi) → 0, AO thấp (khe) → 1
        dark_k.inputs["From Min"].default_value = 1.0
        dark_k.inputs["From Max"].default_value = 0.7
        dark_k.inputs["To Max"].default_value = strength
        L(ao.outputs["AO"], dark_k.inputs["Value"])
        cm = N.new("ShaderNodeMix")
        cm.data_type = "RGBA"
        L(dark_k.outputs[0], cm.inputs["Factor"])
        L(color, cm.inputs[6])
        cm.inputs[7].default_value = srgb(hue)
        color = cm.outputs[2]
    L(color, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Subsurface Weight"].default_value = sss
    bsdf.inputs["Subsurface Radius"].default_value = (1.0, 0.3, 0.2)
    bsdf.inputs["Subsurface Scale"].default_value = 0.015
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def silk_material(name, base, pattern=None, trim=None, sheen=0.6, rough=0.6):
    """Lụa / vải dày Nhật: ánh sheen, nếp mềm; [pattern] màu vân mây xoáy
    (kumo) in chìm; [trim] màu dải viền theo thuộc tính `hem` (0 ở gấu)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links.new
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    tc = N.new("ShaderNodeTexCoord")
    color = None
    base_rgb = srgb(base)
    if pattern:
        wave = N.new("ShaderNodeTexWave")
        wave.wave_type = "RINGS"
        wave.inputs["Scale"].default_value = 3.5
        wave.inputs["Distortion"].default_value = 14
        wave.inputs["Detail"].default_value = 2
        L(tc.outputs["Object"], wave.inputs["Vector"])
        band = N.new("ShaderNodeMapRange")
        band.inputs["From Min"].default_value = 0.9
        band.inputs["From Max"].default_value = 0.95
        L(wave.outputs["Fac"], band.inputs["Value"])
        pm = N.new("ShaderNodeMix")
        pm.data_type = "RGBA"
        L(band.outputs[0], pm.inputs["Factor"])
        pm.inputs[6].default_value = base_rgb
        pm.inputs[7].default_value = srgb(pattern)
        color = pm.outputs[2]
    if trim:
        hem = N.new("ShaderNodeAttribute")
        hem.attribute_type = "GEOMETRY"
        hem.attribute_name = "hem"
        tb = N.new("ShaderNodeMapRange")
        tb.inputs["From Min"].default_value = 0.07
        tb.inputs["From Max"].default_value = 0.06
        L(hem.outputs["Fac"], tb.inputs["Value"])
        tmix = N.new("ShaderNodeMix")
        tmix.data_type = "RGBA"
        L(tb.outputs[0], tmix.inputs["Factor"])
        if color is not None:
            L(color, tmix.inputs[6])
        else:
            tmix.inputs[6].default_value = base_rgb
        tmix.inputs[7].default_value = srgb(trim)
        color = tmix.outputs[2]
    if color is not None:
        L(color, bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = base_rgb
    fold = N.new("ShaderNodeTexNoise")
    fold.inputs["Scale"].default_value = 9
    L(tc.outputs["Object"], fold.inputs["Vector"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    L(fold.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Sheen Weight"].default_value = sheen
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def flame_material(name, core, edge, strength=6.0):
    """Lửa ma: phát sáng, lõi sáng ở giữa (theo pháp tuyến hướng máy quay),
    mờ dần ra rìa."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links.new
    out = N.new("ShaderNodeOutputMaterial")
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.3
    ramp = N.new("ShaderNodeValToRGB")
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.0, srgb(core)
    e[1].position, e[1].color = 1.0, srgb(edge)
    L(lw.outputs["Facing"], ramp.inputs[0])
    em = N.new("ShaderNodeEmission")
    L(ramp.outputs[0], em.inputs["Color"])
    em.inputs["Strength"].default_value = strength
    tr = N.new("ShaderNodeBsdfTransparent")
    alpha = N.new("ShaderNodeMath")
    alpha.operation = "SUBTRACT"
    alpha.inputs[0].default_value = 1.0
    L(lw.outputs["Facing"], alpha.inputs[1])
    mix = N.new("ShaderNodeMixShader")
    L(alpha.outputs[0], mix.inputs["Fac"])
    L(tr.outputs[0], mix.inputs[1])
    L(em.outputs[0], mix.inputs[2])
    L(mix.outputs[0], out.inputs["Surface"])
    return mat


# ---------------------------------------------------------------- thân


def boss_human(gender=1.0, muscle=1.0, weight=0.6, height=1.0, age=0.6, proportions=0.8, scale=1.0, details=None,
               face=True, eyebrows="eyebrow001"):
    """Người MPFB làm boss + mắt/lông mi/răng/lưỡi thật (gói CC0)."""
    body, rig = make_human(gender, muscle=muscle, weight=weight, height=height, age=age, proportions=proportions,
                           scale=scale, details=details)
    parts = add_face_parts(body, eyebrows=eyebrows) if face else {}
    return body, rig, parts


def bone_point(rig, name, at=0.0):
    b = rig.data.bones[name]
    return rig.matrix_world @ b.head_local.lerp(b.tail_local, at)


def head_frame(rig):
    """(tâm đầu, lên, trước, phải-của-nhân-vật) theo toạ độ thế giới lúc nghỉ."""
    m = rig.matrix_world.to_3x3()
    c = bone_point(rig, "head", 0.45)
    up = (m @ Vector((0, 0, 1))).normalized()
    fwd = (m @ Vector((0, -1, 0))).normalized()
    right = (m @ Vector((-1, 0, 0))).normalized()
    return c, up, fwd, right


# ---------------------------------------------------------------- phụ kiện


def curve_strand(points, radius, taper=0.9, sides=10):
    """Ống thon qua nhiều điểm (gốc → ngọn) — sừng, vuốt, tua."""
    n = len(points)
    radii = [(radius * (1 - taper * (i / (n - 1)) ** 1.2) + 0.0003,) * 2 for i in range(n)]
    return raw_tube("Strand", points, radii, sides=sides)


def horn(name, root, direction, length, radius, curl, mat, rig, bone="head", segments=10, ridges=True):
    """Sừng cong: mọc theo [direction], cong dần theo vectơ [curl]; có gờ vòng."""
    pts = []
    d = direction.normalized()
    p = root.copy()
    step = length / segments
    for i in range(segments + 1):
        pts.append(p.copy())
        d = (d + curl * (1.0 / segments)).normalized()
        p = p + d * step
    o = add_object(name, curve_strand(pts, radius, taper=0.95, sides=14), [mat])
    if ridges:
        # Gờ vòng như sừng thật: các khoanh mỏng dọc nửa gốc.
        rings = []
        for i in range(1, segments // 2 + 1):
            c = pts[i]
            t = (pts[i + 1] - pts[i - 1]).normalized()
            r = radius * (1 - 0.95 * (i / segments) ** 1.2) * 1.08
            a = t.orthogonal().normalized()
            b = t.cross(a)
            ring = [c + (a * math.cos(2 * math.pi * k / 16) + b * math.sin(2 * math.pi * k / 16)) * r
                    for k in range(16)]
            rings.append(add_object(f"{name}Ring", raw_tube(f"{name}Ring", ring, [(r * 0.08, r * 0.12)] * 16,
                                                            sides=6, closed=True), [mat]))
        for ro in rings:
            parent_to_bone(ro, rig, bone)
    parent_to_bone(o, rig, bone)
    return o


def beads(name, center, rx, ry, drop, n, r, mat, rig, bone, tilt=Vector((0, 0, 1)), big=None):
    """Chuỗi hạt quanh cổ: elip (rx, ry) quanh [center], võng xuống [drop]
    phía trước; [big] = {chỉ số: (bán kính, vật liệu)} cho hạt to/mặt dây."""
    objs = []
    for k in range(n):
        a = 2 * math.pi * k / n
        front = max(0.0, -math.sin(a))  # −y là phía trước
        p = center + Vector((rx * math.cos(a), ry * math.sin(a), -drop * front ** 1.5))
        rr, m = (big or {}).get(k, (r, mat))
        objs.append(add_object(f"{name}{k}", raw_ellipsoid(f"{name}{k}", p, (rr, rr, rr)), [m]))
    for o in objs:
        parent_to_bone(o, rig, bone)
    return objs


def twisted_rope(name, ring, r, mat, twists=26, strands=2):
    """Dây thừng xoắn (shimenawa): [strands] sợi quấn quanh đường vòng [ring]."""
    out = []
    n = len(ring)
    for s in range(strands):
        pts = []
        for i in range(n * 4):
            t = i / (n * 4)
            j = t * n
            a0 = ring[int(j) % n]
            a1 = ring[(int(j) + 1) % n]
            c = a0.lerp(a1, j - int(j))
            tan = (a1 - a0).normalized()
            nrm = tan.cross(Vector((0, 0, 1))).normalized()
            up = nrm.cross(tan).normalized()
            ang = 2 * math.pi * (twists * t + s / strands)
            pts.append(c + (nrm * math.cos(ang) + up * math.sin(ang)) * r * 0.55)
        out.append(add_object(f"{name}{s}", raw_tube(f"{name}{s}", pts, [(r * 0.62, r * 0.62)] * len(pts),
                                                     sides=10, closed=True), [mat]))
    return out


def ellipse_ring(center, rx, ry, n=64, tilt=0.0):
    return [center + Vector((rx * math.cos(2 * math.pi * k / n), ry * math.sin(2 * math.pi * k / n),
                             tilt * math.sin(2 * math.pi * k / n))) for k in range(n)]


def body_ring(body, co, z, groups, pad, band=0.012):
    """Tâm + bán kính elip của thân ở độ cao z (toạ độ nghỉ) — cho đai/vòng."""
    w = weights_by_group(body)
    pts = [p for i, p in enumerate(co) if abs(p.z - z) < band and w[i].get("HelperGeometry", 0) < 0.5
           and sum(w[i].get(g, 0) for g in groups) > 0.3]
    cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
    cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
    rx = max(abs(p.x - cx) for p in pts) + pad
    ry = max(abs(p.y - cy) for p in pts) + pad
    m = body.matrix_world
    return m @ Vector((cx, cy, z)), rx * m.to_scale().x, ry * m.to_scale().x


def kanji_plate(name, char, at, size, mat, rot=Matrix.Identity(3), depth=0.004):
    """Chữ Hán nổi (ví dụ 鬼 trên tạp dề oni)."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = char
    try:
        cu.font = bpy.data.fonts.load(FONT_JP, check_existing=True)
    except RuntimeError:
        cu.font = bpy.data.fonts.load(r"C:\Windows\Fonts\msgothic.ttc", check_existing=True)
    cu.size = size
    cu.extrude = depth
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.matrix_world = Matrix.Translation(at) @ rot.to_4x4()
    o.data.materials.append(mat)
    return o


def claws(rig, side, mat, length=0.03, radius=0.006, toes=False):
    """Móng vuốt đen ở đầu ngón tay (hoặc ngón chân)."""
    out = []
    names = (["thumb_03", "index_03", "middle_03", "ring_03", "pinky_03"] if not toes else ["ball"])
    for n in names:
        bn = f"{n}_{side}"
        if bn not in rig.data.bones:
            continue
        b = rig.data.bones[bn]
        tip = rig.matrix_world @ b.tail_local
        d = (rig.matrix_world.to_3x3() @ (b.tail_local - b.head_local)).normalized()
        if toes:
            for k in range(-2, 3):
                side_v = d.cross(Vector((0, 0, 1))).normalized()
                p0 = tip + side_v * k * 0.018 * rig.scale.x - Vector((0, 0, 0.01))
                pts = [p0, p0 + d * length * 0.6 - Vector((0, 0, length * 0.1)), p0 + d * length - Vector((0, 0, length * 0.35))]
                o = add_object(f"Claw{bn}{k}", curve_strand(pts, radius, taper=1.0, sides=8), [mat])
                parent_to_bone(o, rig, bn)
                out.append(o)
            continue
        pts = [tip - d * 0.004, tip + d * length * 0.6, tip + d * length - Vector((0, 0, length * 0.25))]
        o = add_object(f"Claw{bn}", curve_strand(pts, radius, taper=1.0, sides=8), [mat])
        parent_to_bone(o, rig, bn)
        out.append(o)
    return out


def flame(name, base, height, width, mat, lean=Vector((0, 0, 0)), tongues=3, seed=0):
    """Ngọn lửa ma (onibi): vài lưỡi lửa giọt nước xoắn lên, đầu nhọn cong."""
    import random
    rng = random.Random(seed)
    out = []
    for k in range(tongues):
        off = Vector((rng.uniform(-1, 1) * width * 0.4, rng.uniform(-1, 1) * width * 0.4, 0))
        h = height * rng.uniform(0.6, 1.0)
        pts = []
        for i in range(9):
            t = i / 8
            sway = math.sin(t * math.pi * 1.6 + k * 1.3) * width * 0.25 * t
            pts.append(base + off + lean * t * t + Vector((sway, 0, h * t)))
        radii = [(width * 0.5 * (math.sin(math.pi * min(1, t * 1.25)) ** 0.7) * (1 - t) ** 0.6 + 0.0005,) * 2
                 for t in [i / 8 for i in range(9)]]
        radii[0] = (width * 0.18,) * 2
        out.append(add_object(f"{name}{k}", raw_tube(f"{name}{k}", pts, radii, sides=12), [mat]))
    return out


def hakama(body, co, rig, name, mat, flare=0.11, top_pad=0.03):
    """Quần hakama ống rộng: vỏ ôm hông + hai ống chân, phồng dần xuống gấu
    (trọng số nhóm đỉnh điều khiển độ đẩy ra), dừng trên mắt cá."""
    w = weights_by_group(body)
    bl = rig.data.bones
    hip_z = bl["pelvis"].head_local.z + 0.04
    ankle_z = bl["foot_l"].head_local.z + 0.05
    span = hip_z - ankle_z
    keep = body.vertex_groups.new(name=f"{name}_keep")
    puff = body.vertex_groups.new(name=f"{name}_puff")
    hem = []
    legs = ("pelvis", "spine_01", "thigh_l", "thigh_r", "calf_l", "calf_r")
    for i, p in enumerate(co):
        g = w[i]
        ok = (sum(g.get(k, 0) for k in legs) > 0.5 and ankle_z < p.z < hip_z
              and (g.get("HelperGeometry", 0) < 0.5 or g.get("helper-skirt", 0) > 0.5))
        hem.append(max(0.0, p.z - ankle_z))
        if ok:
            keep.add([i], 1.0, "REPLACE")
            t = 1 - (p.z - ankle_z) / span  # 0 ở hông, 1 ở gấu
            puff.add([i], top_pad / flare + t ** 0.8, "REPLACE")
    from human_kit import store_point_attr
    store_point_attr(body, "hem", hem)
    o = body.copy()
    o.data = body.data.copy()
    o.name = name
    bpy.context.scene.collection.objects.link(o)
    for m in list(o.modifiers):
        if m.type != "ARMATURE":
            o.modifiers.remove(m)
    mask = o.modifiers.new("Keep", "MASK")
    mask.vertex_group = f"{name}_keep"
    mask.threshold = 0.5
    d = o.modifiers.new("Puff", "DISPLACE")
    d.direction = "NORMAL"
    d.mid_level = 0.0
    d.strength = flare
    d.vertex_group = f"{name}_puff"
    sm = o.modifiers.new("Soft", "SMOOTH")
    sm.factor = 0.8
    sm.iterations = 6
    s = o.modifiers.new("Thick", "SOLIDIFY")
    s.thickness = 0.006
    s.offset = 1.0
    sub = o.modifiers.new("Sub", "SUBSURF")
    sub.levels = sub.render_levels = 1
    o.data.materials.clear()
    o.data.materials.append(mat)
    return o


def limb_band(rig, bone, at0, at1, r0, r1, mat, name, sides=24):
    """Ống giáp/bao tay ôm đoạn xương [bone] từ [at0] tới [at1]."""
    a = bone_point(rig, bone, at0)
    b = bone_point(rig, bone, at1)
    pts = [a.lerp(b, t) for t in (0.0, 0.08, 0.5, 0.92, 1.0)]
    radii = [(r0 * 0.96,) * 2, (r0,) * 2, ((r0 + r1) / 2,) * 2, (r1,) * 2, (r1 * 0.96,) * 2]
    o = add_object(name, raw_tube(name, pts, radii, sides=sides), [mat])
    parent_to_bone(o, rig, bone)
    return o


# ---------------------------------------------------------------- dáng


class StandPoser:
    """Đứng ¾ quay về phía người chơi (−X) và máy quay; chân dạng rộng, IK
    hai tay tới đích cho trước (thế giới)."""

    def __init__(self, rig, facing_deg=-50, scale=1.0):
        self.rig = rig
        self.facing = math.radians(facing_deg)
        self.scale = scale
        bl = rig.data.bones
        self.a = (bl["upperarm_r"].tail_local - bl["upperarm_r"].head_local).length * scale
        self.b = (bl["lowerarm_r"].tail_local - bl["lowerarm_r"].head_local).length * scale
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
            self.ik[s] = (t, p, h, c)

    def frame(self):
        """(trước mặt, bên trái nhân vật, lên) — thế giới."""
        fwd = Vector((math.sin(self.facing), -math.cos(self.facing), 0))
        left = Vector((math.cos(self.facing), math.sin(self.facing), 0))
        return fwd, left, Vector((0, 0, 1))

    def world(self, bone, at=0.0):
        pb = self.rig.pose.bones[bone]
        return self.rig.matrix_world @ pb.head.lerp(pb.tail, at)

    def place(self, stance=0.0, crouch=0.0):
        """Đặt người: quay mặt, dạng chân [stance] rad, khuỵu gối [crouch] rad."""
        rig = self.rig
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0)
        for s, sg in (("l", 1), ("r", -1)):
            # Dạng chân quanh trục trước–sau của khung xương (Y), đổi sang hệ
            # cục bộ của xương đùi — trục Z cục bộ bị xoay lệch nên quay quanh
            # nó làm hai chân bắt chéo.
            loc = rig.data.bones[f"thigh_{s}"].matrix_local.to_3x3().inverted()
            spread = Matrix.Rotation(-sg * stance, 3, loc @ Vector((0, 1, 0)))
            rig.pose.bones[f"thigh_{s}"].rotation_euler = (spread @ Matrix.Rotation(crouch * 0.6, 3, "X")).to_euler()
            rig.pose.bones[f"calf_{s}"].rotation_euler.x = -crouch
            loc = rig.data.bones[f"foot_{s}"].matrix_local.to_3x3().inverted()
            rig.pose.bones[f"foot_{s}"].rotation_euler = (
                Matrix.Rotation(sg * stance, 3, loc @ Vector((0, 1, 0))) @ Matrix.Rotation(crouch * 0.4, 3, "X")
            ).to_euler()
        S = self.scale
        rig.matrix_world = Matrix.Rotation(self.facing, 4, "Z") @ Matrix.Diagonal((S, S, S, 1))
        bpy.context.view_layer.update()
        low = min(self.world("foot_l", 1.0).z, self.world("foot_r", 1.0).z, self.world("ball_l", 1.0).z,
                  self.world("ball_r", 1.0).z)
        rig.matrix_world = Matrix.Translation(Vector((0, 0, -low + 0.01 * S))) @ rig.matrix_world
        bpy.context.view_layer.update()

    def arm(self, s, target, pole):
        t, p, *_ = self.ik[s]
        t.location = target
        p.location = pole
        bpy.context.view_layer.update()

    def palm(self, s, fingers, palm_dir):
        """Xoay bàn tay [s]: ngón chỉ theo [fingers], lòng bàn tay quay về
        [palm_dir] (thế giới). Gọi sau place()."""
        rig = self.rig
        bl = rig.data.bones
        m3 = rig.matrix_world.to_3x3().normalized()
        rest = rig.matrix_world @ bl[f"hand_{s}"].matrix_local
        d = (m3 @ (bl[f"middle_01_{s}"].head_local - bl[f"hand_{s}"].head_local)).normalized()
        # Dáng chữ A lúc nghỉ: lòng bàn tay quay vào trong thân.
        inward = m3 @ Vector((-1 if s == "l" else 1, 0, 0))
        n = (inward - d * inward.dot(d)).normalized()
        fr = Matrix((d, n, d.cross(n))).transposed()
        f = fingers.normalized()
        pd = (palm_dir - f * palm_dir.dot(f)).normalized()
        to = Matrix((f, pd, f.cross(pd))).transposed()
        h = self.ik[s][2]
        h.matrix_world = (to @ fr.transposed()).to_4x4() @ Matrix(rest.to_3x3().normalized()).to_4x4()
        pb = rig.pose.bones[f"hand_{s}"]
        if not any(c.type == "COPY_ROTATION" for c in pb.constraints):
            pb.constraints.new("COPY_ROTATION").target = h
        bpy.context.view_layer.update()


def fist(rig, s, curl=1.0):
    """Nắm bàn tay [s] quanh cán (chuỳ, kiếm)."""
    for f in ("index", "middle", "ring", "pinky"):
        for j, ang in (("01", 60), ("02", 85), ("03", 55)):
            pb = rig.pose.bones.get(f"{f}_{j}_{s}")
            if pb:
                pb.rotation_euler.x = math.radians(ang * curl)
    for j, ang in (("02", 25), ("03", 35)):
        pb = rig.pose.bones.get(f"thumb_{j}_{s}")
        if pb:
            pb.rotation_euler.x = math.radians(ang * curl)
    bpy.context.view_layer.update()


def inflate(body, co, center, radii, amount, name="Inflate", front_only=True):
    """Đắp thêm khối (bụng phệ, ngực…) bằng shape key: đẩy đỉnh ra theo pháp
    tuyến, mạnh nhất ở [center] (toạ độ nghỉ cục bộ), tắt dần theo elip
    [radii]. [front_only]: chỉ mặt trước (pháp tuyến hướng −Y)."""
    if body.data.shape_keys is None:
        body.shape_key_add(name="Basis")
    key = body.shape_key_add(name=name, from_mix=False)
    normals = [v.normal.copy() for v in body.data.vertices]
    w = weights_by_group(body)
    for i, p in enumerate(co):
        if w[i].get("HelperGeometry", 0) > 0.5:
            continue
        d = Vector(((p.x - center.x) / radii[0], (p.y - center.y) / radii[1], (p.z - center.z) / radii[2]))
        f = math.exp(-d.length_squared * 2.0)
        if f < 0.01:
            continue
        n = normals[i]
        if front_only:
            f *= max(0.0, -n.y) ** 0.5 if n.y < 0 else 0.15
        key.data[i].co = key.data[i].co + n * amount * f
    key.value = 1.0
    return key


def belly_ball(body, co, center, rx, ry, rz_top, rz_bot, tuck_z, name="BellyBall", soft=0.18, top_flat=0.3):
    """Bụng bia tròn kiểu Gragas (shape key): chiếu đỉnh thân nằm trong khối
    elip ra mặt elip theo tia từ tâm — mặt cầu tròn đều, không nhọn như đẩy
    theo pháp tuyến. Nửa trên cao [rz_top] hoà vào ngực, nửa dưới [rz_bot]
    nặng và trễ; dưới [tuck_z] tắt hẳn nên mép dưới có nếp gấp chờm qua đai.
    [top_flat] làm nửa trên nông dần để bụng thoải vào ngực. Lưng không bị
    đẩy. Toạ độ nghỉ cục bộ, người nhìn về −Y."""
    if body.data.shape_keys is None:
        body.shape_key_add(name="Basis")
    key = body.shape_key_add(name=name, from_mix=False)
    w = weights_by_group(body)
    torso = ("pelvis", "spine_01", "spine_02", "spine_03")

    def smooth(a, b, x):
        t = min(1.0, max(0.0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)

    for i, p in enumerate(co):
        g = w[i]
        tw = smooth(0.15, 0.7, sum(g.get(k, 0) for k in torso))  # hông lẫn trọng số tay: mờ dần
        if g.get("HelperGeometry", 0) > 0.5 or tw <= 0:
            continue
        d = p - center
        up = max(0.0, d.z / rz_top)
        q = Vector((d.x / rx, d.y / (ry * (1 - top_flat * min(1.0, up))), d.z / (rz_top if d.z > 0 else rz_bot)))
        r = q.length
        if r < 1e-6 or r > 1.0 + soft:
            continue
        # Hợp mềm (smooth max) giữa thân và mặt elip: không có gờ ở mép trên.
        r_new = 0.5 * (r + 1.0 + math.sqrt((r - 1.0) ** 2 + soft * soft))
        front = smooth(-0.7, 0.2, -q.y / r)  # sau lưng → 0
        f = tw * front * smooth(tuck_z - 0.025, tuck_z + 0.015, p.z)
        if f <= 0:
            continue
        key.data[i].co = key.data[i].co + d * ((r_new / r - 1.0) * f)
    key.value = 1.0
    return key


def muscle_bulge(body, co, rig, bone, lobes, name, min_w=0.35):
    """Bắp cơ dọc xương [bone] (shape key): mỗi lobe (u0, wu, góc0°, rộng°,
    biên độ m) — u theo chiều dài xương (0 gốc → 1 ngọn), góc quanh trục
    (0 = trước mặt −Y, 90 = phía ngoài thân, 180 = sau lưng); biên độ âm là
    rãnh phân cơ. Chỉ đỉnh thuộc nhóm [bone] (trọng số ≥ [min_w]), đẩy theo
    pháp tuyến, nhân trọng số nên không lan sang thân."""
    if body.data.shape_keys is None:
        body.shape_key_add(name="Basis")
    key = body.shape_key_add(name=name, from_mix=False)
    b = rig.data.bones[bone]
    h, t = b.head_local, b.tail_local
    L = (t - h).length
    a = (t - h).normalized()
    front = Vector((0, -1, 0))
    f = (front - a * front.dot(a)).normalized()
    out = Vector((1 if h.x >= 0 else -1, 0, 0))
    lat = a.cross(f)
    if lat.dot(out) < 0:
        lat = -lat
    w = weights_by_group(body)
    normals = [v.normal.copy() for v in body.data.vertices]
    for i, p in enumerate(co):
        g = w[i]
        wb = g.get(bone, 0)
        if wb < min_w or g.get("HelperGeometry", 0) > 0.5:
            continue
        d = p - h
        u = d.dot(a) / L
        r = d - a * d.dot(a)
        ang = math.degrees(math.atan2(r.dot(lat), r.dot(f)))
        disp = 0.0
        for u0, wu, a0, wa, amp in lobes:
            da = (ang - a0 + 180) % 360 - 180
            disp += amp * math.exp(-((u - u0) / wu) ** 2 * 2) * math.exp(-(da / wa) ** 2 * 2)
        if disp:
            key.data[i].co = key.data[i].co + normals[i] * disp * min(1.0, wb * 1.4)
    key.value = 1.0
    return key


def hero_muscles(body, co, rig, k=1.0):
    """Đắp khối cơ cho thớ cơ đọc rõ ở cỡ sprite (target MPFB làm cơ tròn mềm):
    ngực có gờ dưới sắc + rãnh giữa, cơ thang, và bắp dọc xương tay (vai,
    bắp tay trước/sau, cẳng tay) kèm rãnh phân cơ. Toạ độ nghỉ cục bộ; người
    nhìn về −Y, trái +X. [k] nhân mọi biên độ (oni 1, thần mảnh hơn ~0,7)."""
    bl = rig.data.bones

    def front_y(x, z, r=0.03):
        ys = [p.y for p in co if abs(p.x - x) < r and abs(p.z - z) < r]
        return min(ys) if ys else 0.0

    zc = bl["spine_03"].head_local.z + 0.06  # tầm ngực
    for sx in (-1, 1):
        x = 0.09 * sx
        inflate(body, co, Vector((x, front_y(x, zc), zc)), (0.1, 0.1, 0.08), 0.07 * k, name=f"Pec{sx}",
                front_only=False)
        inflate(body, co, Vector((x * 1.05, front_y(x, zc - 0.085), zc - 0.085)), (0.11, 0.1, 0.018), -0.018 * k,
                name=f"PecFold{sx}", front_only=False)
        nk = bl["neck_01"].head_local
        inflate(body, co, Vector((0.08 * sx, nk.y + 0.03, nk.z - 0.02)), (0.07, 0.07, 0.05), 0.035 * k,
                name=f"Trap{sx}", front_only=False)
        s_ = "l" if sx > 0 else "r"
        # (u0, độ rộng u, góc°, độ rộng góc°, biên độ m)
        muscle_bulge(body, co, rig, f"upperarm_{s_}", [
            (0.12, 0.16, 70, 110, 0.035 * k),   # cơ delta trùm vai
            (0.3, 0.05, 40, 60, -0.012 * k),    # rãnh delta – bắp tay
            (0.58, 0.2, 0, 55, 0.04 * k),       # bắp tay trước (nhị đầu)
            (0.5, 0.25, 180, 60, 0.032 * k),    # bắp tay sau (tam đầu)
            (0.55, 0.3, 90, 14, -0.012 * k),    # rãnh giữa trước/sau phía ngoài
            (0.55, 0.3, -90, 14, -0.008 * k),
        ], f"Arm{s_}")
        muscle_bulge(body, co, rig, f"lowerarm_{s_}", [
            (0.22, 0.18, 45, 50, 0.03 * k),     # cơ cánh tay quay
            (0.25, 0.2, -60, 50, 0.022 * k),    # nhóm gấp cổ tay
            (0.3, 0.3, -5, 10, -0.008 * k),     # rãnh giữa hai nhóm
        ], f"Forearm{s_}")
    inflate(body, co, Vector((0, front_y(0, zc), zc)), (0.016, 0.1, 0.11), -0.025 * k, name="Sternum",
            front_only=False)


def flat_band(name, pts, outs, width, thick, widths=None):
    """Dải vải dẹt dọc [pts]: rộng [width] theo mặt thân, dày [thick] theo
    hướng ra ngoài [outs] — không xoắn như ống dẹt khi đi gần thẳng đứng.
    [widths] hệ số rộng từng điểm (thuôn đầu dải)."""
    verts, faces = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        tan = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        o = outs[i] - tan * outs[i].dot(tan)
        o.normalize()
        w = o.cross(tan).normalized()
        for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            verts.append(p + w * a * width * (widths[i] if widths else 1.0) + o * b * thick)
    for i in range(n - 1):
        for k in range(4):
            k2 = (k + 1) % 4
            faces.append((i * 4 + k, i * 4 + k2, (i + 1) * 4 + k2, (i + 1) * 4 + k))
    faces += [(3, 2, 1, 0), tuple((n - 1) * 4 + k for k in range(4))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    return mesh


def kamon_material(name, base, crest, scale=10.0, sheen=0.5, rough=0.6, trim=None, size=1.0):
    """Vải in hoa văn tròn (kamon / hoa cúc tròn) rải đều: ô Voronoi, mỗi ô
    một vòng tròn [crest] có cánh hoa (sóng quanh tâm)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links.new
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    tc = N.new("ShaderNodeTexCoord")
    vor = N.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = scale
    vor.inputs["Randomness"].default_value = 0.35
    L(tc.outputs["Object"], vor.inputs["Vector"])
    # Vòng ngoài + nhuỵ: dải khoảng cách tới tâm ô.
    ring = N.new("ShaderNodeMapRange")
    ring.interpolation_type = "SMOOTHSTEP"
    ring.inputs["From Min"].default_value = 0.2 * size
    ring.inputs["From Max"].default_value = 0.17 * size
    L(vor.outputs["Distance"], ring.inputs["Value"])
    hole = N.new("ShaderNodeMapRange")
    hole.interpolation_type = "SMOOTHSTEP"
    hole.inputs["From Min"].default_value = 0.08 * size
    hole.inputs["From Max"].default_value = 0.11 * size
    L(vor.outputs["Distance"], hole.inputs["Value"])
    core = N.new("ShaderNodeMapRange")
    core.inputs["From Min"].default_value = 0.035 * size
    core.inputs["From Max"].default_value = 0.025 * size
    L(vor.outputs["Distance"], core.inputs["Value"])
    m1 = N.new("ShaderNodeMath")
    m1.operation = "MULTIPLY"
    L(ring.outputs[0], m1.inputs[0])
    L(hole.outputs[0], m1.inputs[1])
    m2 = N.new("ShaderNodeMath")
    m2.operation = "MAXIMUM"
    L(m1.outputs[0], m2.inputs[0])
    L(core.outputs[0], m2.inputs[1])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L(m2.outputs[0], mix.inputs["Factor"])
    mix.inputs[6].default_value = srgb(base)
    mix.inputs[7].default_value = srgb(crest)
    color = mix.outputs[2]
    if trim:
        hem = N.new("ShaderNodeAttribute")
        hem.attribute_type = "GEOMETRY"
        hem.attribute_name = "hem"
        tb = N.new("ShaderNodeMapRange")
        tb.inputs["From Min"].default_value = 0.06
        tb.inputs["From Max"].default_value = 0.05
        L(hem.outputs["Fac"], tb.inputs["Value"])
        tm = N.new("ShaderNodeMix")
        tm.data_type = "RGBA"
        L(tb.outputs[0], tm.inputs["Factor"])
        L(color, tm.inputs[6])
        tm.inputs[7].default_value = srgb(trim)
        color = tm.outputs[2]
    L(color, bsdf.inputs["Base Color"])
    fold = N.new("ShaderNodeTexNoise")
    fold.inputs["Scale"].default_value = 8
    L(tc.outputs["Object"], fold.inputs["Vector"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.2
    L(fold.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Sheen Weight"].default_value = sheen
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def garment(body, rig, co, name, groups, mat, offset, z_min=None, z_max=None, extra=None, flare=None,
            thickness=0.005, smooth=4):
    """Áo ôm thân: vỏ của các đỉnh thuộc [groups] (tổng trọng số > 0,5) trong
    khoảng cao [z_min, z_max] (toạ độ nghỉ). [flare] = (nhóm, hàm(p) → 0–1):
    phồng thêm theo trọng số (tay áo rộng, vạt áo xoè). [extra](i, p, g) → bool
    để lọc thêm."""
    w = weights_by_group(body)
    keep = body.vertex_groups.new(name=f"{name}_keep")
    puff = body.vertex_groups.new(name=f"{name}_puff") if flare else None
    for i, p in enumerate(co):
        g = w[i]
        if g.get("HelperGeometry", 0) > 0.5:
            continue
        if sum(g.get(k, 0) for k in groups) < 0.5:
            continue
        if z_min is not None and p.z < z_min or z_max is not None and p.z > z_max:
            continue
        if extra and not extra(i, p, g):
            continue
        keep.add([i], 1.0, "REPLACE")
        if flare:
            puff.add([i], max(0.0, min(1.0, flare[1](p, g))), "REPLACE")
    o = body.copy()
    o.data = body.data.copy()
    o.name = name
    bpy.context.scene.collection.objects.link(o)
    for m in list(o.modifiers):
        if m.type != "ARMATURE":
            o.modifiers.remove(m)
    mask = o.modifiers.new("Keep", "MASK")
    mask.vertex_group = f"{name}_keep"
    mask.threshold = 0.5
    d = o.modifiers.new("Out", "DISPLACE")
    d.direction = "NORMAL"
    d.mid_level = 0.0
    d.strength = offset
    if flare:
        d2 = o.modifiers.new("Flare", "DISPLACE")
        d2.direction = "NORMAL"
        d2.mid_level = 0.0
        d2.strength = flare[0]
        d2.vertex_group = f"{name}_puff"
    if smooth:
        sm = o.modifiers.new("Soft", "SMOOTH")
        sm.factor = 0.8
        sm.iterations = smooth
    s = o.modifiers.new("Thick", "SOLIDIFY")
    s.thickness = thickness
    s.offset = 1.0
    sub = o.modifiers.new("Sub", "SUBSURF")
    sub.levels = sub.render_levels = 1
    o.data.materials.clear()
    o.data.materials.append(mat)
    return o


def sleeve_bag(rig, side, mat, length=0.32, width=0.24, name="Sleeve"):
    """Tay áo kimono rộng (tamoto): túi vải rủ dưới cẳng tay, gắn xương cẳng
    tay — phần đặc trưng nhất của áo Nhật nhìn từ xa."""
    a = bone_point(rig, f"upperarm_{side}", 0.55)
    b = bone_point(rig, f"lowerarm_{side}", 0.95)
    axis = (b - a)
    n = 14
    bm = bmesh.new()
    rows = []
    down = Vector((0, 0, -1))
    for r in range(n + 1):
        t = r / n
        c = a.lerp(b, t)
        # Miệng tay áo phồng tròn ở cổ tay, túi rủ sâu nhất giữa cẳng tay.
        drop = length * (math.sin(math.pi * min(1.0, t * 1.05)) ** 0.6) * (0.4 + 0.6 * t)
        ring = []
        side_v = axis.cross(down).normalized()
        for k in range(12):
            ang = 2 * math.pi * k / 12
            off = side_v * math.cos(ang) * width * 0.5 * (0.55 + 0.45 * t) + down * (0.5 - 0.5 * math.sin(ang)) * (drop + 0.06)
            ring.append(bm.verts.new(c + off - down * 0.03))
        rows.append(ring)
    for r in range(n):
        for k in range(12):
            k2 = (k + 1) % 12
            bm.faces.new((rows[r][k], rows[r][k2], rows[r + 1][k2], rows[r + 1][k]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    o = add_object(f"{name}{side}", mesh, [mat])
    sol = o.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.006
    sub = o.modifiers.new("Sub", "SUBSURF")
    sub.levels = sub.render_levels = 1
    parent_to_bone(o, rig, f"lowerarm_{side}")
    return o


def feather_fan(name, grip, direction, face, mats, n=15, length=0.3, scale=1.0):
    """Quạt lông vũ (hauchiwa): cán sơn đen đầu vàng, các lông xoè quạt."""
    from bird_kit import blade
    feather, handle, gold = mats
    d = direction.normalized()
    f = face.normalized()
    side = d.cross(f).normalized()
    top = grip + d * 0.14 * scale
    out = [add_object(f"{name}Handle", raw_tube(f"{name}Handle", [grip - d * 0.05 * scale, grip, top],
                                                [(0.012 * scale,) * 2, (0.011 * scale,) * 2,
                                                 (0.016 * scale,) * 2], sides=10), [handle])]
    out.append(add_object(f"{name}Cap", raw_ellipsoid(f"{name}Cap", top, (0.022 * scale,) * 3), [gold]))
    for k in range(n):
        a = math.radians(-80 + 160 * k / (n - 1))
        dd = d * math.cos(a) + side * math.sin(a)
        # Hai lớp lông so le, gần như tròn như quạt hauchiwa.
        out.append(blade(f"{name}F{k}", top + f * 0.004 * scale * (k % 2), dd, f,
                         length * scale * (0.9 + 0.1 * math.cos(a)), 0.07 * scale, feather, curve=0.03,
                         tone=0.25 + 0.5 * (k % 2)))
    return out


def blob(name, items, mats, voxel=0.012, smooth_iter=5):
    """Gộp nhiều ellipsoid (tâm, (rx, ry, rz), [ma trận xoay 3×3]) — MÉT — thành
    một bề mặt liền (remesh voxel + làm mượt): thân thú, đầu, mõm."""
    bm = bmesh.new()
    for it in items:
        c, r = Vector(it[0]), it[1]
        rot = it[2] if len(it) > 2 else Matrix.Identity(3)
        geom = bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=16, radius=1)
        for v in geom["verts"]:
            v.co = rot @ Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2])) + c
    raw = bpy.data.meshes.new(name + "_raw")
    bm.to_mesh(raw)
    bm.free()
    tmp = bpy.data.objects.new(name + "_tmp", raw)
    bpy.context.scene.collection.objects.link(tmp)
    rm = tmp.modifiers.new("Remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = voxel
    sm = tmp.modifiers.new("Smooth", "SMOOTH")
    sm.iterations = smooth_iter
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.meshes.remove(raw)
    mesh.name = name
    return add_object(name, mesh, mats)


def capsule_items(a, b, r0, r1, n=6):
    """Chuỗi ellipsoid dọc đoạn a→b (chân thú…) cho blob()."""
    a, b = Vector(a), Vector(b)
    out = []
    for i in range(n):
        t = i / (n - 1)
        r = r0 + (r1 - r0) * t
        out.append((a.lerp(b, t), (r, r, r)))
    return out


def bezier_pts(p0, p1, p2, p3, n):
    out = []
    for i in range(n):
        t = i / (n - 1)
        u = 1 - t
        out.append(p0 * u ** 3 + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t ** 3)
    return out
