"""Bộ công cụ chung dựng boss bằng Blender (fantasy realism) rồi render thành
sprite cho sân khấu Flutter. Mỗi boss một script (`fafnir_boss.py`…) import
file này; chạy bằng `bash tool/blender/render.sh <tên> [--still]`.

Quy ước toạ độ: viết theo đơn vị sân khấu 400×260 của game (x sang phải, y
hướng XUỐNG), gốc tại điểm neo của boss (thường là chân boss trên mặt đất),
d = chiều sâu (âm = gần máy quay). Mỗi 50 đơn vị = 1 m trong Blender.
"""

import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
STILL = "--still" in ARGS

S = 1 / 50  # đơn vị vẽ → mét


def P(x, y, d=0.0):
    """Đơn vị vẽ (x phải, y xuống, d chiều sâu) → toạ độ Blender."""
    return Vector((x * S, d * S, -y * S))


def srgb(hex_):
    """'#C99140' → màu tuyến tính (node Blender làm việc ở không gian tuyến tính)."""
    h = hex_.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i : i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def smooth(t):
    x = min(max(t, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def attack_pose(phase):
    """Port AttackPose.at (lib/art/motion.dart): (lấy đà, ra đòn, thu về)."""
    if phase < 0 or phase > 1:
        return 0.0, 0.0, 0.0
    if phase < 0.5:
        t = phase / 0.5
        return 1 - (1 - t) * (1 - t), 0.0, 0.0
    if phase < 0.65:
        t = (phase - 0.5) / 0.15
        return 1 - t, math.sin(t * math.pi / 2), 0.0
    t = (phase - 0.65) / 0.35
    return 0.0, 1 - t, math.sin(t * math.pi)


# ---------------------------------------------------------------- cảnh, Cycles


def reset_scene(samples=64, world_hex="#5A6A8C", world_strength=0.45, glass_alpha=False, keep_prefs=False):
    """Cảnh trống + Cycles GPU. [keep_prefs]: giữ tiện ích của người dùng (MPFB)."""
    if keep_prefs:
        bpy.ops.wm.read_homefile(use_empty=True)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    # BLENDER_CPU=1: nhường GPU (4 GB) cho việc khác — Cycles GPU chạy cùng lúc
    # huấn luyện torch (tool/motion/mocap/model.py) thì cả hai lỗi truy cập bộ nhớ CUDA.
    for kind in (() if os.environ.get("BLENDER_CPU") == "1" else ("OPTIX", "CUDA")):
        try:
            prefs.compute_device_type = kind
        except TypeError:
            continue
        prefs.get_devices()
        gpus = [d for d in prefs.devices if d.type == kind]
        if gpus:
            for d in prefs.devices:
                d.use = d.type == kind
            scene.cycles.device = "GPU"
            break
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    # Nước/kính trong suốt thật trên nền trong (sprite đặt lên phông game).
    scene.cycles.film_transparent_glass = glass_alpha
    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = srgb(world_hex)
    bg.inputs[1].default_value = world_strength
    scene.world = world
    return scene


# ---------------------------------------------------------------- vật liệu


def _nodes(mat):
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    return nt, nt.nodes.new("ShaderNodeOutputMaterial")


def skin_material(name, hex_, rough=0.75, sss=0.0, metallic=0.0, noise_scale=18, scar=None):
    """Da / sừng / răng: Principled, có vân nhiễu cho đỡ phẳng. [scar]: màu
    sẹo, tô theo thuộc tính `scar` của lưới (xem paint_scars) và gồ lên."""
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = noise_scale
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs[6].default_value = srgb(hex_)
    mix.inputs[7].default_value = [c * 0.6 for c in srgb(hex_)[:3]] + [1]
    k = nt.nodes.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.inputs[1].default_value = 0.5
    nt.links.new(noise.outputs["Fac"], k.inputs[0])
    nt.links.new(k.outputs[0], mix.inputs["Factor"])
    color = mix.outputs[2]
    if scar:
        attr = nt.nodes.new("ShaderNodeAttribute")
        attr.attribute_type = "GEOMETRY"
        attr.attribute_name = "scar"
        sm = nt.nodes.new("ShaderNodeMix")
        sm.data_type = "RGBA"
        nt.links.new(attr.outputs["Fac"], sm.inputs["Factor"])
        nt.links.new(color, sm.inputs[6])
        sm.inputs[7].default_value = srgb(scar)
        color = sm.outputs[2]
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.8
        bump.inputs["Distance"].default_value = 0.01
        nt.links.new(attr.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs[0], bsdf.inputs["Normal"])
    nt.links.new(color, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    if sss:
        bsdf.inputs["Subsurface Weight"].default_value = sss
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def glow_material(name, hex_, strength=3.0, base="#000000"):
    """Mắt / lõi phát sáng (sinh vật thần thoại), bề mặt bóng."""
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = srgb(base)
    bsdf.inputs["Roughness"].default_value = 0.05
    bsdf.inputs["Coat Weight"].default_value = 1.0
    bsdf.inputs["Emission Color"].default_value = srgb(hex_)
    bsdf.inputs["Emission Strength"].default_value = strength
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def gold_material(name="Gold", hex_="#F2C25A", rough=0.28):
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = srgb(hex_)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = rough
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def water_material(name="Water", hex_="#4FB0C8", emission=0.0, rough=0.04):
    """Nước trong (truyền sáng, khúc xạ), hơi xanh; [emission] cho ánh thần."""
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = srgb(hex_)
    bsdf.inputs["Transmission Weight"].default_value = 1.0
    bsdf.inputs["IOR"].default_value = 1.33
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = srgb(hex_)
        bsdf.inputs["Emission Strength"].default_value = emission
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def scales_material(name, back, belly, edge, scale_uv=(26, 9), plates=40, rough=0.45,
                    metallic=0.15, belly_band=0.17, frost=None, bump_strength=0.35):
    """Vảy rồng/rắn trên lưới có UV (u dọc thân theo mét, v quanh thân, v=0
    sống lưng, v=0,5 bụng — xem tube_mesh): vảy lưng là ô Voronoi vồng lên,
    rãnh tối giữa các vảy; bụng là các tấm ngang. [frost]: màu sương giá phủ
    phía sống lưng (Fafnir)."""
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    N, L = nt.nodes, nt.links.new
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    uv = N.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    sep = N.new("ShaderNodeSeparateXYZ")
    L(uv.outputs[0], sep.inputs[0])

    # Vảy lưng: Voronoi trên (u, v) kéo giãn theo số vảy.
    mapping = N.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (scale_uv[0], scale_uv[1], 1)
    L(uv.outputs[0], mapping.inputs["Vector"])
    vor = N.new("ShaderNodeTexVoronoi")
    vor.voronoi_dimensions = "2D"
    vor.feature = "F1"
    L(mapping.outputs[0], vor.inputs["Vector"])
    edge_v = N.new("ShaderNodeTexVoronoi")
    edge_v.voronoi_dimensions = "2D"
    edge_v.feature = "DISTANCE_TO_EDGE"
    L(mapping.outputs[0], edge_v.inputs["Vector"])
    groove = N.new("ShaderNodeMapRange")
    groove.inputs["From Min"].default_value = 0.0
    groove.inputs["From Max"].default_value = 0.12
    L(edge_v.outputs["Distance"], groove.inputs["Value"])  # 0 ở rãnh, 1 trong vảy

    # Tấm bụng: dải ngang theo u.
    pl = N.new("ShaderNodeMath")
    pl.operation = "MULTIPLY"
    pl.inputs[1].default_value = plates
    L(sep.outputs[0], pl.inputs[0])
    fr = N.new("ShaderNodeMath")
    fr.operation = "FRACT"
    L(pl.outputs[0], fr.inputs[0])
    plate_h = N.new("ShaderNodeMapRange")
    plate_h.inputs["From Min"].default_value = 0.0
    plate_h.inputs["From Max"].default_value = 0.15
    L(fr.outputs[0], plate_h.inputs["Value"])

    # Mặt nạ bụng theo v (gần 0,5).
    dv = N.new("ShaderNodeMath")
    dv.operation = "SUBTRACT"
    dv.inputs[1].default_value = 0.5
    L(sep.outputs[1], dv.inputs[0])
    adv = N.new("ShaderNodeMath")
    adv.operation = "ABSOLUTE"
    L(dv.outputs[0], adv.inputs[0])
    bmask = N.new("ShaderNodeMapRange")
    bmask.inputs["From Min"].default_value = belly_band + 0.03
    bmask.inputs["From Max"].default_value = belly_band
    L(adv.outputs[0], bmask.inputs["Value"])

    height = N.new("ShaderNodeMix")
    height.data_type = "FLOAT"
    L(bmask.outputs[0], height.inputs["Factor"])
    L(groove.outputs[0], height.inputs[2])
    L(plate_h.outputs[0], height.inputs[3])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = bump_strength
    bump.inputs["Distance"].default_value = 0.02
    L(height.outputs[0], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])

    # Màu: lưng (mỗi vảy lệch màu chút) – rãnh tối – bụng.
    # Mỗi vảy sáng/tối lệch nhau một chút (xám, không lẫn màu RGB ngẫu nhiên).
    cell = N.new("ShaderNodeRGBToBW")
    L(vor.outputs["Color"], cell.inputs[0])
    cell_k = N.new("ShaderNodeMath")
    cell_k.operation = "MULTIPLY"
    cell_k.inputs[1].default_value = 0.45
    L(cell.outputs[0], cell_k.inputs[0])
    back_c = N.new("ShaderNodeMix")
    back_c.data_type = "RGBA"
    L(cell_k.outputs[0], back_c.inputs["Factor"])
    back_c.inputs[6].default_value = srgb(back)
    back_c.inputs[7].default_value = [c * 0.55 for c in srgb(back)[:3]] + [1]
    grooved = N.new("ShaderNodeMix")
    grooved.data_type = "RGBA"
    L(groove.outputs[0], grooved.inputs["Factor"])
    grooved.inputs[6].default_value = srgb(edge)
    L(back_c.outputs[2], grooved.inputs[7])
    col = N.new("ShaderNodeMix")
    col.data_type = "RGBA"
    L(bmask.outputs[0], col.inputs["Factor"])
    L(grooved.outputs[2], col.inputs[6])
    belly_c = N.new("ShaderNodeMix")
    belly_c.data_type = "RGBA"
    L(plate_h.outputs[0], belly_c.inputs["Factor"])
    belly_c.inputs[6].default_value = [c * 0.55 for c in srgb(belly)[:3]] + [1]
    belly_c.inputs[7].default_value = srgb(belly)
    L(belly_c.outputs[2], col.inputs[7])
    final = col.outputs[2]
    if frost:
        # Sương giá đóng ở phía sống lưng (v gần 0 hoặc 1).
        fm = N.new("ShaderNodeMapRange")
        fm.inputs["From Min"].default_value = 0.30
        fm.inputs["From Max"].default_value = 0.48
        L(adv.outputs[0], fm.inputs["Value"])
        noise = N.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 30
        mul = N.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        L(fm.outputs[0], mul.inputs[0])
        L(noise.outputs["Fac"], mul.inputs[1])
        st = N.new("ShaderNodeMapRange")
        st.inputs["From Min"].default_value = 0.25
        st.inputs["From Max"].default_value = 0.45
        L(mul.outputs[0], st.inputs["Value"])
        fz = N.new("ShaderNodeMix")
        fz.data_type = "RGBA"
        L(st.outputs[0], fz.inputs["Factor"])
        L(final, fz.inputs[6])
        fz.inputs[7].default_value = srgb(frost)
        final = fz.outputs[2]
    L(final, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Coat Weight"].default_value = 0.3
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def solid_scales_material(name, hex_, edge, scale=60, rough=0.45, metallic=0.15):
    """Vảy nhỏ cho lưới không có UV (đầu rồng): Voronoi 3D theo toạ độ object."""
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    N, L = nt.nodes, nt.links.new
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    tc = N.new("ShaderNodeTexCoord")
    vor = N.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = scale
    L(tc.outputs["Object"], vor.inputs["Vector"])
    groove = N.new("ShaderNodeMapRange")
    groove.inputs["From Max"].default_value = 0.1
    L(vor.outputs["Distance"], groove.inputs["Value"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.45
    bump.inputs["Distance"].default_value = 0.01
    L(groove.outputs[0], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L(groove.outputs[0], mix.inputs["Factor"])
    mix.inputs[6].default_value = srgb(edge)
    mix.inputs[7].default_value = srgb(hex_)
    L(mix.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Coat Weight"].default_value = 0.3
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def fur_material(name, stops, sheen=0.0):
    """Lông thật (Principled Hair, tô màu trực tiếp). Màu chọn theo `fur_t`
    (0 = sáng, 1 = tối) qua dải [stops], cộng chút ngẫu nhiên từng sợi."""
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    hair = nt.nodes.new("ShaderNodeBsdfHairPrincipled")
    hair.parametrization = "COLOR"
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_type = "GEOMETRY"
    attr.attribute_name = "fur_t"
    info = nt.nodes.new("ShaderNodeHairInfo")
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "MULTIPLY_ADD"
    nt.links.new(info.outputs["Random"], add.inputs[0])
    add.inputs[1].default_value = 0.22
    nt.links.new(attr.outputs["Fac"], add.inputs[2])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    while len(els) < len(stops):
        els.new(0.5)
    for el, (pos, col) in zip(els, stops):
        el.position = pos
        el.color = srgb(col)
    nt.links.new(add.outputs[0], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], hair.inputs["Color"])
    for key, val in (("Roughness", 0.32 - sheen * 0.3), ("Radial Roughness", 0.5), ("Coat", max(0.0, 0.1 + sheen)),
                     ("Random Roughness", 0.3)):
        if key in hair.inputs:
            hair.inputs[key].default_value = val
    nt.links.new(hair.outputs[0], out.inputs["Surface"])
    return mat


# ---------------------------------------------------------------- lông / sợi (geometry nodes)


def fur_nodes(name, source, mat, density, length, radius, comb, lift, gravity, jitter=0.25,
              seed=0, dark_from=None, resolution=5):
    """Cây geometry nodes mọc sợi (lông, tóc nước, rêu) trên lưới [source] đã
    biến dạng theo xương. Sợi nằm trên object Curves riêng (Blender 5.2 không
    render sợi do modifier của object lưới sinh ra), đọc [source] qua Object
    Info. Điểm mọc rải trên dáng NGHỈ (rest_position) rồi lấy vị trí/pháp
    tuyến tương ứng trên dáng biến dạng: sợi không nhảy chỗ giữa các khung.
    `fur_t` (độ tối 0–1): theo pháp tuyến (mặt dưới sáng) hoặc theo x nghỉ
    ([dark_from] = (x0, x1) mét)."""
    ng = bpy.data.node_groups.new(name, "GeometryNodeTree")
    ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    N = ng.nodes
    L = ng.links.new
    N.new("NodeGroupInput")
    go = N.new("NodeGroupOutput")

    def node(kind, **props):
        n = N.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def vmath(op, a, b=None, scale=None):
        n = node("ShaderNodeVectorMath", operation=op)
        L(a, n.inputs[0])
        if b is not None:
            if isinstance(b, (tuple, list)):
                n.inputs[1].default_value = b
            else:
                L(b, n.inputs[1])
        if scale is not None:
            n.inputs["Scale"].default_value = scale
        return n.outputs[0]

    pos = node("GeometryNodeInputPosition").outputs[0]
    nrm = node("GeometryNodeInputNormal").outputs[0]

    def store(geom, attr_name, value, data_type="FLOAT_VECTOR"):
        n = node("GeometryNodeStoreNamedAttribute", data_type=data_type, domain="POINT")
        n.inputs["Name"].default_value = attr_name
        L(geom, n.inputs["Geometry"])
        L(value, n.inputs["Value"])
        return n.outputs[0]

    src = node("GeometryNodeObjectInfo", transform_space="RELATIVE")
    src.inputs["Object"].default_value = source
    g = store(src.outputs["Geometry"], "def_pos", pos)
    g = store(g, "def_n", nrm)
    rest = node("GeometryNodeInputNamedAttribute", data_type="FLOAT_VECTOR")
    rest.inputs["Name"].default_value = "rest_position"
    setp = node("GeometryNodeSetPosition")
    L(g, setp.inputs["Geometry"])
    L(rest.outputs[0], setp.inputs["Position"])
    rest_mesh = setp.outputs[0]
    dist = node("GeometryNodeDistributePointsOnFaces")
    L(rest_mesh, dist.inputs["Mesh"])
    dist.inputs["Density"].default_value = density
    dist.inputs["Seed"].default_value = seed
    # Không mọc ở vệt sẹo (thuộc tính `scar`, thiếu thì coi như 0).
    bald = node("GeometryNodeInputNamedAttribute", data_type="FLOAT")
    bald.inputs["Name"].default_value = "scar"
    keep = node("ShaderNodeMath", operation="LESS_THAN")
    L(bald.outputs[0], keep.inputs[0])
    keep.inputs[1].default_value = 0.35
    L(keep.outputs[0], dist.inputs["Selection"])

    def sample(attr_name):
        a = node("GeometryNodeInputNamedAttribute", data_type="FLOAT_VECTOR")
        a.inputs["Name"].default_value = attr_name
        sm = node("GeometryNodeSampleNearestSurface", data_type="FLOAT_VECTOR")
        L(rest_mesh, sm.inputs["Mesh"])
        L(a.outputs[0], sm.inputs["Value"])
        L(pos, sm.inputs["Sample Position"])
        return sm.outputs["Value"]

    def_pos = sample("def_pos")
    def_n = sample("def_n")
    sep = node("ShaderNodeSeparateXYZ")
    mr = node("ShaderNodeMapRange")
    if dark_from:
        L(pos, sep.inputs[0])
        mr.inputs["From Min"].default_value = dark_from[0]
        mr.inputs["From Max"].default_value = dark_from[1]
        L(sep.outputs[0], mr.inputs["Value"])
    else:
        L(def_n, sep.inputs[0])
        mr.inputs["From Min"].default_value = -0.45
        mr.inputs["From Max"].default_value = 0.6
        L(sep.outputs[2], mr.inputs["Value"])
    pts = store(dist.outputs["Points"], "fur_t", mr.outputs[0], "FLOAT")
    mv = node("GeometryNodeSetPosition")
    L(pts, mv.inputs["Geometry"])
    L(def_pos, mv.inputs["Position"])

    rnd = node("FunctionNodeRandomValue", data_type="FLOAT_VECTOR")
    rnd.inputs["Min"].default_value = (-1, -1, -1)
    rnd.inputs["Max"].default_value = (1, 1, 1)
    rnd.inputs["Seed"].default_value = seed + 3
    d = vmath("SCALE", def_n, scale=lift)
    d = vmath("ADD", d, tuple(comb))
    d = vmath("ADD", d, vmath("SCALE", rnd.outputs[0], scale=jitter))
    d = vmath("NORMALIZE", d)
    align = node("FunctionNodeAlignRotationToVector", axis="Z")
    L(d, align.inputs["Vector"])
    line = node("GeometryNodeCurvePrimitiveLine")
    line.inputs["End"].default_value = (0, 0, 1)
    res = node("GeometryNodeResampleCurve")
    L(line.outputs[0], res.inputs["Curve"])
    res.inputs["Count"].default_value = resolution
    rlen = node("FunctionNodeRandomValue", data_type="FLOAT")
    lo, hi = [i for i in rlen.inputs if i.type == "VALUE" and i.name in ("Min", "Max")][:2]
    lo.default_value, hi.default_value = length
    rlen.inputs["Seed"].default_value = seed + 5
    inst = node("GeometryNodeInstanceOnPoints")
    L(mv.outputs[0], inst.inputs["Points"])
    L(res.outputs[0], inst.inputs["Instance"])
    L(align.outputs[0], inst.inputs["Rotation"])
    L(next(o for o in rlen.outputs if o.type == "VALUE"), inst.inputs["Scale"])
    real = node("GeometryNodeRealizeInstances")
    L(inst.outputs[0], real.inputs["Geometry"])
    par = node("GeometryNodeSplineParameter")
    sq = node("ShaderNodeMath", operation="POWER")
    L(par.outputs["Factor"], sq.inputs[0])
    sq.inputs[1].default_value = 2
    off = node("ShaderNodeVectorMath", operation="SCALE")
    off.inputs[0].default_value = (0, 0, -gravity)
    L(sq.outputs[0], off.inputs["Scale"])
    droop = node("GeometryNodeSetPosition")
    L(real.outputs[0], droop.inputs["Geometry"])
    L(off.outputs[0], droop.inputs["Offset"])
    rad = node("ShaderNodeMath", operation="MULTIPLY_ADD")
    L(par.outputs["Factor"], rad.inputs[0])
    rad.inputs[1].default_value = -radius * 0.85
    rad.inputs[2].default_value = radius
    srad = node("GeometryNodeSetCurveRadius")
    L(droop.outputs[0], srad.inputs["Curve"])
    L(rad.outputs[0], srad.inputs["Radius"])
    smat = node("GeometryNodeSetMaterial")
    L(srad.outputs[0], smat.inputs["Geometry"])
    smat.inputs["Material"].default_value = mat
    L(smat.outputs[0], go.inputs[0])
    return ng


def with_fur(obj, mat, **kw):
    """Mọc sợi cho [obj]: object Curves riêng tên `<obj>Fur` (xem fur_nodes)."""
    obj.add_rest_position_attribute = True
    data = bpy.data.hair_curves.new(obj.name + "Fur")
    data.materials.append(mat)
    fur = bpy.data.objects.new(obj.name + "Fur", data)
    bpy.context.scene.collection.objects.link(fur)
    gn = fur.modifiers.new("Fur", "NODES")
    gn.node_group = fur_nodes(obj.name + "Fur", obj, mat, **kw)
    return fur


# ---------------------------------------------------------------- hình khối


def parent_to_bone(obj, arm, bone):
    """Gắn [obj] cứng vào xương [bone] của armature [arm], giữ nguyên vị trí lúc nghỉ."""
    b = arm.data.bones[bone]
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    tail = arm.matrix_world @ b.matrix_local @ Matrix.Translation((0, b.length, 0))
    obj.matrix_parent_inverse = tail.inverted()


def add_object(name, mesh, mats, group=None, smooth_shade=True):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for m in mats:
        mesh.materials.append(m)
    if smooth_shade:
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    if group:
        vg = obj.vertex_groups.new(name=group)
        vg.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    return obj


def paint_scars(obj, strokes, side=-1):
    """Ghi thuộc tính `scar` (0–1) lên lưới: các nét sẹo [strokes] =
    [(danh sách điểm (x, y) đơn vị vẽ, bề rộng)], chỉ ở mặt phía [side]
    (−1 = phía gần máy quay) và mặt đang quay ra phía đó."""
    mesh = obj.data
    vals = [0.0] * len(mesh.vertices)
    segs = []
    for pts, width in strokes:
        for a, b in zip(pts, pts[1:]):
            segs.append((Vector((a[0] * S, -a[1] * S)), Vector((b[0] * S, -b[1] * S)), width * S))
    for v in mesh.vertices:
        if v.co.y * side <= 0 or v.normal.y * side < 0.15:
            continue
        p = Vector((v.co.x, v.co.z))
        best = 0.0
        for a, b, w in segs:
            ab = b - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
            d = (p - (a + ab * t)).length
            # Sẹo thon hai đầu như vết vuốt.
            ww = w * (0.35 + 0.65 * math.sin(math.pi * t))
            if d < ww:
                best = max(best, 1 - smooth(d / ww))
        vals[v.index] = best
    attr = mesh.attributes.new("scar", "FLOAT", "POINT")
    attr.data.foreach_set("value", vals)


def subdivided(mesh, levels=1):
    """Chia mịn lưới (subdivision surface) — cho vệt sẹo và cơ mịn hơn."""
    tmp = bpy.data.objects.new("_subd", mesh)
    bpy.context.scene.collection.objects.link(tmp)
    m = tmp.modifiers.new("Subd", "SUBSURF")
    m.levels = m.render_levels = levels
    dg = bpy.context.evaluated_depsgraph_get()
    out = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    out.name = mesh.name
    bpy.data.meshes.remove(mesh)
    return out


def metaball_mesh(name, elements, resolution=0.03):
    """Khối hữu cơ liền mạch từ các metaball rồi đổi thành lưới."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = 0.6
    tmp = bpy.data.objects.new(name + "_mb", mb)
    bpy.context.scene.collection.objects.link(tmp)
    for kind, co, radius, size, rot, stiff in elements:
        el = mb.elements.new(type=kind)
        el.co = co
        el.radius = radius
        el.stiffness = stiff
        if size is not None:
            el.size_x, el.size_y, el.size_z = size
        if rot is not None:
            el.rotation = rot
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.metaballs.remove(mb)
    mesh.name = name
    return mesh


def ball(x, y, d, r, sx=1, sy=1, sz=1, stiff=2.0):
    """Metaball ellipsoid theo đơn vị vẽ: bán kính r, kéo giãn sx (ngang), sy (cao), sz (sâu)."""
    return ("ELLIPSOID", P(x, y, d), r * S, (sx, sz, sy), None, stiff)


def capsule(a, b, r, stiff=2.0):
    """Metaball khúc tròn dài từ a tới b (x, y, d đơn vị vẽ), bán kính r."""
    pa, pb = P(*a), P(*b)
    v = pb - pa
    q = Vector((1, 0, 0)).rotation_difference(v.normalized())
    return ("CAPSULE", (pa + pb) / 2, r * S, (v.length / 2, 1, 1), q, stiff)


def uv_ellipsoid(name, center, radii, segments=24, rings=14):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1)
    rx, ry, rz = radii
    for v in bm.verts:
        v.co = Vector((v.co.x * rx * S, v.co.y * rz * S, v.co.z * ry * S)) + P(*center)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def ellipsoids_mesh(name, items, voxel=0.018, smooth_iter=6):
    """Gộp nhiều ellipsoid ((tâm), (rx, ry cao, rz sâu)) thành một bề mặt liền
    (remesh voxel + làm mượt) — đầu, hàm: không lộ mối nối. Phần tử thứ 3
    tuỳ chọn là góc xoay (độ) trong mặt phẳng nhìn ngang."""
    bm = bmesh.new()
    for item in items:
        center, (rx, ry, rz) = item[0], item[1]
        rot = math.radians(item[2]) if len(item) > 2 else 0.0
        geom = bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=16, radius=1)
        c, s = math.cos(rot), math.sin(rot)
        for v in geom["verts"]:
            x, y, z = v.co.x * rx * S, v.co.y * rz * S, v.co.z * ry * S
            # Quay trong mặt phẳng XZ (y vẽ hướng xuống ⇒ góc dương = xoay xuôi chiều kim đồng hồ trên màn hình).
            v.co = Vector((x * c + z * s, y, -x * s + z * c)) + P(*center)
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
    out = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.meshes.remove(raw)
    out.name = name
    return out


def catmull(points, samples_per_seg=8):
    """Đường cong Catmull-Rom đi qua mọi điểm (đơn vị vẽ)."""
    pts = [Vector(p) for p in points]
    pts = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(samples_per_seg):
            t = k / samples_per_seg
            t2, t3 = t * t, t * t * t
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-2])
    return out


def tube_mesh(name, spine, radius, sides=28, samples_per_seg=8, dorsal=(0.35, 0, -1), flatten=1.0):
    """Thân rắn/rồng: ống quét dọc [spine] (điểm đơn vị vẽ), bán kính theo
    hàm radius(t) với t 0→1 từ đầu tới cuối đường. UV: u = chiều dài (mét),
    v quanh thân, v=0 ở sống lưng (hướng [dorsal], toạ độ vẽ: y âm = lên),
    v=0,5 ở bụng. [flatten] < 1 dẹt thân theo chiều lưng–bụng (rắn)."""
    curve = catmull(spine, samples_per_seg)
    pts = [P(*p) for p in curve]
    ref = P(*dorsal)
    ref.normalize()
    lengths = [0.0]
    for a, b in zip(pts, pts[1:]):
        lengths.append(lengths[-1] + (b - a).length)
    total = lengths[-1]
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    rings = []
    for i, p in enumerate(pts):
        tan = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        up = (ref - tan * ref.dot(tan))
        if up.length < 1e-4:
            up = Vector((0, 1, 0)) - tan * tan.y
        up.normalize()
        side = tan.cross(up).normalized()
        r = radius(lengths[i] / total) * S
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            ring.append(bm.verts.new(p + (up * math.cos(a) * flatten + side * math.sin(a)) * r))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            f = bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
            for loop, (ii, kk) in zip(f.loops, ((i, k), (i, k + 1), (i + 1, k + 1), (i + 1, k))):
                loop[uv_layer].uv = (lengths[ii], kk / sides)
    # Nắp hai đầu.
    for ring in (rings[0], rings[-1]):
        bm.faces.new(ring if ring is rings[-1] else list(reversed(ring)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return mesh, curve


def tapered_tubes(name, strands, sides=7, steps=7, flat=1.0, taper=0.8):
    """Nhiều sừng/răng/gai gộp một lưới: mỗi cái là ống thon dần dọc Bézier
    bậc hai (gốc, điểm uốn, ngọn — đơn vị vẽ), bán kính gốc r."""
    verts, faces = [], []
    for p0, p1, p2, r in strands:
        a, b, c = P(*p0), P(*p1), P(*p2)
        base = len(verts)
        for i in range(steps + 1):
            t = i / steps
            pt = a * (1 - t) ** 2 + b * 2 * t * (1 - t) + c * t * t
            tan = ((b - a) * 2 * (1 - t) + (c - b) * 2 * t).normalized()
            side = tan.cross(Vector((0, 1, 0)))
            if side.length < 1e-4:
                side = tan.cross(Vector((1, 0, 0)))
            side.normalize()
            up = side.cross(tan).normalized()
            rad = r * S * (1 - t) ** taper + 0.001
            for k in range(sides):
                ang = 2 * math.pi * k / sides
                verts.append(pt + (side * math.cos(ang) * flat + up * math.sin(ang) / flat) * rad)
        for i in range(steps):
            for k in range(sides):
                k2 = (k + 1) % sides
                o = base + i * sides
                faces.append((o + k, o + k2, o + sides + k2, o + sides + k))
        faces.append(tuple(base + k for k in reversed(range(sides))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    return mesh


# ---------------------------------------------------------------- khung xương


class Rig:
    """Khung xương phẳng: mọi xương độc lập (không cha–con), đặt thẳng bằng
    toạ độ đầu–ngọn mỗi khung (set). Trọng số theo khoảng cách tới đoạn xương."""

    def __init__(self, name, bones):
        self.bones = dict(bones)  # tên → (gốc, ngọn) đơn vị vẽ
        data = bpy.data.armatures.new(name)
        self.arm = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(self.arm)
        bpy.context.view_layer.objects.active = self.arm
        bpy.ops.object.mode_set(mode="EDIT")
        for n, (a, b) in self.bones.items():
            eb = data.edit_bones.new(n)
            eb.head = P(*a)
            eb.tail = P(*b)
            eb.align_roll(Vector((0, 1, 0)))
        bpy.ops.object.mode_set(mode="OBJECT")
        self.arm.show_in_front = True
        for pb in self.arm.pose.bones:
            pb.rotation_mode = "QUATERNION"

    def skin(self, obj, bones=None, near_filter=None):
        """Trọng số 2 xương gần nhất. [near_filter](tên_xương, toạ_độ) → False
        để loại cặp không hợp lệ (ví dụ chân gần/xa)."""
        names = bones or list(self.bones)
        segs = {n: (P(*self.bones[n][0]), P(*self.bones[n][1])) for n in names}
        groups = {n: obj.vertex_groups.new(name=n) for n in names}
        for v in obj.data.vertices:
            p = v.co
            ds = []
            for n, (a, b) in segs.items():
                if near_filter and not near_filter(n, p):
                    continue
                ab = b - a
                t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
                ds.append(((p - (a + ab * t)).length, n))
            ds.sort()
            best = ds[:2]
            w = [1 / max(d, 0.02) ** 4 for d, _ in best]
            tot = sum(w)
            for (d, n), wi in zip(best, w):
                groups[n].add([v.index], wi / tot, "REPLACE")

    def bind(self, obj):
        mod = obj.modifiers.new("Rig", "ARMATURE")
        mod.object = self.arm
        obj.modifiers.move(obj.modifiers.find("Rig"), 0)

    def rest(self):
        for pb in self.arm.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)

    def set(self, name, a, b):
        """Đặt xương nằm từ a tới b (đơn vị vẽ)."""
        pb = self.arm.pose.bones[name]
        pa, pt = P(*a), P(*b)
        y = (pt - pa).normalized()
        z = Vector((0, 1, 0))
        z = (z - y * y.dot(z)).normalized()
        x = y.cross(z).normalized()
        m = Matrix((x, y, z)).transposed().to_4x4()
        m.translation = pa
        pb.matrix = m
        bpy.context.view_layer.update()

    def keyframe(self, frame):
        for pb in self.arm.pose.bones:
            pb.keyframe_insert("location", frame=frame)
            pb.keyframe_insert("rotation_quaternion", frame=frame)


def chain_bones(prefix, points):
    """Chuỗi xương nối các điểm liên tiếp (cổ, thân rắn, đuôi)."""
    return {f"{prefix}{i}": (points[i], points[i + 1]) for i in range(len(points) - 1)}


def two_bone(root, target, l1, l2, bend):
    """IK 2 đoạn trong mặt phẳng nhìn ngang; bend=±1 chọn phía khớp giữa lồi."""
    r = Vector(root[:2])
    t = Vector(target[:2])
    d = max(1e-3, min((t - r).length, l1 + l2 - 1e-3))
    a = math.acos(max(-1, min(1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    base = math.atan2(t.y - r.y, t.x - r.x)
    ang = base + a * bend
    mid = r + Vector((math.cos(ang), math.sin(ang))) * l1
    return (mid.x, mid.y)


def rot2(p, pivot, ang):
    c, s = math.cos(ang), math.sin(ang)
    dx, dy = p[0] - pivot[0], p[1] - pivot[1]
    return (pivot[0] + dx * c - dy * s, pivot[1] + dx * s + dy * c, p[2] if len(p) > 2 else 0)


# ---------------------------------------------------------------- máy quay, đèn


def setup_camera(scene, frame_x, frame_y, px_per_unit=1.8, yaw=-12, pitch=6):
    """Máy quay trực giao nhìn ngang khung [frame_x]×[frame_y] (đơn vị vẽ)."""
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    w = frame_x[1] - frame_x[0]
    h = frame_y[1] - frame_y[0]
    cam_data.ortho_scale = max(w, h) * S
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    center = P((frame_x[0] + frame_x[1]) / 2, (frame_y[0] + frame_y[1]) / 2)
    cam.rotation_euler = (math.radians(90 - pitch), 0, math.radians(yaw))
    fwd = cam.rotation_euler.to_matrix() @ Vector((0, 0, -1))
    cam.location = center - fwd * 30
    cam_data.clip_end = 100
    scene.camera = cam
    scene.render.resolution_x = round(w * px_per_unit)
    scene.render.resolution_y = round(h * px_per_unit)
    scene.render.resolution_percentage = 100
    return cam


def add_sun(scene, name, direction, energy, color, angle=3):
    """Đèn mặt trời chiếu theo [direction] (toạ độ Blender: từ đèn về vật)."""
    data = bpy.data.lights.new(name, "SUN")
    data.energy = energy
    data.color = srgb(color)[:3]
    data.angle = math.radians(angle)
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()
    return obj


def add_point(scene, name, at, energy, color, radius=0.2):
    data = bpy.data.lights.new(name, "POINT")
    data.energy = energy
    data.color = srgb(color)[:3]
    data.shadow_soft_size = radius
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = P(*at)
    return obj


def anchor_info(scene, cam):
    """Gốc toạ độ vẽ trên ảnh (điểm ảnh) và số điểm ảnh mỗi đơn vị vẽ."""
    bpy.context.view_layer.update()
    rx, ry = scene.render.resolution_x, scene.render.resolution_y

    def px(p):
        v = world_to_camera_view(scene, cam, p)
        return Vector((v.x * rx, (1 - v.y) * ry))

    o = px(P(0, 0))
    ux = (px(P(100, 0)) - o).length / 100
    uy = (px(P(0, -100)) - o).length / 100
    return o, (ux + uy) / 2


# ---------------------------------------------------------------- render + atlas


def render_to(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def render_stills(scene, out_dir, stills):
    """[stills]: [(tên, hàm đặt dáng)] → build/blender/<boss>/still_<tên>.png."""
    os.makedirs(out_dir, exist_ok=True)
    for tag, setup in stills:
        setup()
        render_to(scene, os.path.join(out_dir, f"still_{tag}.png"))


def render_anims(scene, out_dir, anims, keyframe=None):
    """[anims]: {tên: [hàm đặt dáng cho từng khung]} → {tên: [đường dẫn]}.
    [keyframe](số khung timeline) ghi lại dáng vào file .blend."""
    os.makedirs(out_dir, exist_ok=True)
    files = {}
    frame = 1
    for name, setups in anims.items():
        files[name] = []
        for k, setup in enumerate(setups):
            setup()
            if keyframe:
                keyframe(frame)
            frame += 1
            files[name].append(render_to(scene, os.path.join(out_dir, f"{name}_{k:02d}.png")))
        frame += 10
    return files


def pack_atlas(files, anchor, ppu, out_png, out_json, width=2048):
    """Cắt sát từng khung theo alpha, xếp hàng (shelf) vào một ảnh, ghi vị trí
    khung so với gốc toạ độ vẽ (đơn vị vẽ)."""
    frames = []
    for name, paths in files.items():
        for path in paths:
            img = bpy.data.images.load(path)
            w, h = img.size
            px = np.empty(w * h * 4, dtype=np.float32)
            img.pixels.foreach_get(px)
            px = px.reshape(h, w, 4)[::-1]
            bpy.data.images.remove(img)
            ys, xs = np.nonzero(px[:, :, 3] > 0.004)
            if len(xs) == 0:
                xs, ys = np.array([0]), np.array([0])
            x0, x1 = max(xs.min() - 1, 0), min(xs.max() + 2, w)
            y0, y1 = max(ys.min() - 1, 0), min(ys.max() + 2, h)
            frames.append((name, px[y0:y1, x0:x1], x0, y0))
    pad = 2
    x = y = shelf = 0
    places = []
    for _, crop, _, _ in frames:
        h, w = crop.shape[:2]
        if x + w > width:
            x, y, shelf = 0, y + shelf + pad, 0
        places.append((x, y))
        x += w + pad
        shelf = max(shelf, h)
    height = y + shelf
    atlas = np.zeros((height, width, 4), dtype=np.float32)
    meta = {"unitsPerPixel": round(1 / ppu, 5), "anims": {}}
    for (name, crop, x0, y0), (ax, ay) in zip(frames, places):
        h, w = crop.shape[:2]
        atlas[ay : ay + h, ax : ax + w] = crop
        meta["anims"].setdefault(name, []).append({
            "x": int(ax), "y": int(ay), "w": int(w), "h": int(h),
            "dx": round((x0 - anchor.x) / ppu, 2),
            "dy": round((y0 - anchor.y) / ppu, 2),
        })
    img = bpy.data.images.new("atlas", width, height, alpha=True)
    img.pixels.foreach_set(atlas[::-1].astype(np.float32).ravel())
    img.filepath_raw = out_png
    img.file_format = "PNG"
    img.save()
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1)
    return width, height


def save_blend(name):
    """Lưu cảnh ra art_src/blender/<name>.blend. Blender ghi `<file>@` rồi đổi
    tên — trên Windows với file lớn (oni ~110 MB) file vừa ghi bị khoá tạm
    (quét virus) nên Blender báo "Cannot change old file" và sót `@`, kể cả
    khi lưu ra tên mới tinh. Vì vậy: lưu ra file tạm, Blender lỗi thì tự đổi
    tên `@` (thử lại tới khi hết khoá) rồi thay file đích; không giữ `.blend1`."""
    import time
    path = os.path.join(ROOT, "art_src", "blender", f"{name}.blend")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = os.path.join(os.path.dirname(path), f"{name}.saving.blend")
    for stale in (tmp, tmp + "@", path + "@"):
        if os.path.exists(stale):
            os.remove(stale)
    try:
        bpy.ops.wm.save_as_mainfile(filepath=tmp, compress=True, copy=True)
    except RuntimeError:
        if not os.path.exists(tmp + "@"):
            raise
        src = tmp + "@"  # Blender đã ghi đủ, chỉ vấp bước đổi tên
    else:
        src = tmp
    for attempt in range(20):
        try:
            os.replace(src, path)
            return path
        except PermissionError:
            time.sleep(0.5 * (attempt + 1))
    print(f"save_blend: không thay được {path} (file đang mở?) — bản mới để ở {src}")
    return src
