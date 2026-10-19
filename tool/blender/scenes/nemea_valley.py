"""Phông nền Thung lũng Nemea (Kỳ công 1, fantasy realism): bìa rừng ô liu
dưới nắng chiều, đền cẩm thạch trên đồi, núi xa xanh mờ, vách đá vôi có
hang sư tử bên phải. Dựng thật bằng 3D rồi render THEO TẦNG (trời, núi xa,
đồi giữa, cảnh gần, tiền cảnh) để sân khấu Flutter giữ parallax 2,5D và lớp
bụi Trì Trệ phủ từng tầng như bản vector (lib/art/nemea_scene.dart).

    bash tool/blender/render.sh nemea_valley --still   # một ảnh ghép, xem nhanh
    bash tool/blender/render.sh nemea_valley           # các tầng → assets/backdrops

Máy quay phối cảnh khớp sân khấu 400×260: mặt phẳng hành động (nơi nhân vật
và quái đứng) ở độ sâu y = 0, mặt đất tại dòng y = 220 của sân khấu, mỗi đơn
vị sân khấu ≈ 2 cm ở mặt phẳng đó. Ảnh rộng thêm MARGIN đơn vị mỗi bên cho
camera trôi. Toạ độ trong file này là mét Blender (x phải, y vào sâu, z lên).
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import paths  # noqa: E402,F401  (kits/, motion/, render/ — rules/dohoa/README.md)
from boss_kit import ROOT, STILL, add_object, fur_material, srgb, with_fur  # noqa: E402
from greek_kit import marble_material  # noqa: E402

STAGE_W, STAGE_H, GROUND_Y = 400, 260, 220
MARGIN = 24  # đơn vị sân khấu mỗi bên (camera trôi tối đa ~8 × parallax)
PX = 3.0  # điểm ảnh mỗi đơn vị sân khấu
CAM_D = 7.8  # khoảng cách máy quay tới mặt phẳng hành động
FOCAL = 35.0
UNIT = 36.0 / FOCAL * CAM_D / STAGE_W  # mét / đơn vị sân khấu ở y = 0
CAM_Z = (GROUND_Y - STAGE_H / 2) * UNIT  # mặt đất thấp hơn tâm ảnh 90 đơn vị

LAYERS = ("sky", "far", "mid", "near", "fg")


def stage_to_world(sx, sy, depth):
    """Điểm (sx, sy) trên sân khấu nhìn thấy ở độ sâu [depth] → (x, z) mét."""
    k = UNIT * (CAM_D + depth) / CAM_D
    return (sx - STAGE_W / 2) * k, CAM_Z - (sy - STAGE_H / 2) * k


# ---------------------------------------------------------------- tầng, vật liệu


def layer(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def put(obj, layer_name):
    for c in obj.users_collection:
        c.objects.unlink(obj)
    layer(layer_name).objects.link(obj)
    return obj


def _mat(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    return mat, nt, bsdf, out


HAZE = "#B4C2D2"

# Bảng màu "đồng cỏ tươi" (thử phong cách painted, rules/dohoa/phongcach.md):
# Mặc định dùng đồng cỏ tươi (14/10); style_test.py đặt LUSH = False cho bản
# "hiện tại" để so với bản đất khô cũ.
LUSH = True
DRY_PALETTE = {
    "ground": ("#B4966A", "#8C7050"), "ground_patch": "#7E7A3C", "pebble": "#D8CDB6",
    "grass": [(0.0, "#C8B870"), (0.5, "#9A9A50"), (1.0, "#5E6A34")],
    "olive_far": ("#7E9256", "#4A5A36"), "cypress": ("#3E5230", "#22301C"),
    "map_grass": ("#8E9A52", "#B8A866"), "map_dirt": "#A88C62",
}
LUSH_PALETTE = {
    "ground": ("#7A9A48", "#567A34"), "ground_patch": "#A89660", "pebble": "#C9C29A",
    "path": "#A48C68",
    "grass": [(0.0, "#D6E07A"), (0.5, "#8CB848"), (1.0, "#4E8030")],
    "olive_far": ("#8AB04E", "#46702E"), "cypress": ("#3E6A30", "#1E3E1C"),
    "map_grass": ("#6E9440", "#9CB458"), "map_dirt": "#A48C68",
}


def pal(key):
    return (LUSH_PALETTE if LUSH else DRY_PALETTE)[key]


def finish(mat, nt, bsdf, out, haze=1.0):
    """Phối cảnh không khí: càng xa càng hoà vào màu sương trời (theo khoảng
    cách tới máy quay), giữ alpha nguyên vẹn để tách tầng."""
    N, L = nt.nodes, nt.links.new
    if haze <= 0:
        L(bsdf.outputs[0], out.inputs["Surface"])
        return mat
    cam = N.new("ShaderNodeCameraData")
    mr = N.new("ShaderNodeMapRange")
    mr.interpolation_type = "SMOOTHSTEP"
    mr.inputs["From Min"].default_value = 18
    mr.inputs["From Max"].default_value = 900
    mr.inputs["To Max"].default_value = 0.92 * haze
    L(cam.outputs["View Distance"], mr.inputs["Value"])
    em = N.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = srgb(HAZE)
    em.inputs["Strength"].default_value = 1.0
    mix = N.new("ShaderNodeMixShader")
    L(mr.outputs[0], mix.inputs["Fac"])
    L(bsdf.outputs[0], mix.inputs[1])
    L(em.outputs[0], mix.inputs[2])
    L(mix.outputs[0], out.inputs["Surface"])
    return mat


def noise_color(nt, bsdf, a, b, scale, detail=6, lo=0.35, hi=0.65, coord="Object"):
    N, L = nt.nodes, nt.links.new
    tc = N.new("ShaderNodeTexCoord")
    tex = N.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = scale
    tex.inputs["Detail"].default_value = detail
    L(tc.outputs[coord], tex.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = lo
    mr.inputs["From Max"].default_value = hi
    L(tex.outputs["Fac"], mr.inputs["Value"])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L(mr.outputs[0], mix.inputs["Factor"])
    mix.inputs[6].default_value = srgb(a)
    mix.inputs[7].default_value = srgb(b)
    L(mix.outputs[2], bsdf.inputs["Base Color"])
    return tc, tex


def ground_material(name="Dirt", haze=1.0):
    """Đất khô sáng của Argolis: cát nâu vàng, sỏi vôi lốm đốm, vệt cỏ úa."""
    mat, nt, bsdf, out = _mat(name)
    N, L = nt.nodes, nt.links.new
    tc, _ = noise_color(nt, bsdf, *pal("ground"), 1.4, lo=0.4, hi=0.62)
    vor = N.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 26
    L(tc.outputs["Object"], vor.inputs["Vector"])
    peb = N.new("ShaderNodeMapRange")
    peb.inputs["From Min"].default_value = 0.18
    peb.inputs["From Max"].default_value = 0.05
    L(vor.outputs["Distance"], peb.inputs["Value"])
    grass = N.new("ShaderNodeTexNoise")
    grass.inputs["Scale"].default_value = 0.6
    L(tc.outputs["Object"], grass.inputs["Vector"])
    gm = N.new("ShaderNodeMapRange")
    gm.inputs["From Min"].default_value = 0.52
    gm.inputs["From Max"].default_value = 0.6
    gm.inputs["To Max"].default_value = 0.55
    L(grass.outputs["Fac"], gm.inputs["Value"])
    base = bsdf.inputs["Base Color"].links[0].from_socket
    g = N.new("ShaderNodeMix")
    g.data_type = "RGBA"
    L(gm.outputs[0], g.inputs["Factor"])
    L(base, g.inputs[6])
    g.inputs[7].default_value = srgb(pal("ground_patch"))
    p = N.new("ShaderNodeMix")
    p.data_type = "RGBA"
    L(peb.outputs[0], p.inputs["Factor"])
    L(g.outputs[2], p.inputs[6])
    p.inputs[7].default_value = srgb(pal("pebble"))
    color = p.outputs[2]
    if LUSH:
        # Lối đất trụi theo thuộc tính `scar` (lối đi trên dải hành động);
        # mặt không có thuộc tính này trả 0 → giữ cỏ.
        sc = N.new("ShaderNodeAttribute")
        sc.attribute_name = "scar"
        sm = N.new("ShaderNodeMapRange")
        sm.interpolation_type = "SMOOTHSTEP"
        sm.inputs["From Min"].default_value = 0.7
        sm.inputs["From Max"].default_value = 0.97
        L(sc.outputs["Fac"], sm.inputs["Value"])
        d = N.new("ShaderNodeMix")
        d.data_type = "RGBA"
        L(sm.outputs[0], d.inputs["Factor"])
        L(color, d.inputs[6])
        d.inputs[7].default_value = srgb(pal("path"))
        color = d.outputs[2]
    L(color, bsdf.inputs["Base Color"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.5
    bump.inputs["Distance"].default_value = 0.02
    L(peb.outputs[0], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return finish(mat, nt, bsdf, out, haze)


def rock_material(name="Limestone", base="#BCA684", dark="#7C6A52", haze=1.0, scale=1.2):
    """Đá vôi Peloponnese: vàng xám, vân phân tầng, hốc tối, rêu khô."""
    mat, nt, bsdf, out = _mat(name)
    N, L = nt.nodes, nt.links.new
    tc, tex = noise_color(nt, bsdf, base, dark, scale, detail=8, lo=0.42, hi=0.62)
    strata = N.new("ShaderNodeTexWave")
    strata.wave_type = "BANDS"
    strata.bands_direction = "Z"
    strata.inputs["Scale"].default_value = 1.6
    strata.inputs["Distortion"].default_value = 6
    strata.inputs["Detail"].default_value = 4
    L(tc.outputs["Object"], strata.inputs["Vector"])
    vor = N.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = scale * 3
    vor.feature = "DISTANCE_TO_EDGE"
    L(tc.outputs["Object"], vor.inputs["Vector"])
    crack = N.new("ShaderNodeMapRange")
    crack.inputs["From Min"].default_value = 0.0
    crack.inputs["From Max"].default_value = 0.012
    L(vor.outputs["Distance"], crack.inputs["Value"])
    h = N.new("ShaderNodeMath")
    h.operation = "MULTIPLY_ADD"
    L(strata.outputs["Fac"], h.inputs[0])
    h.inputs[1].default_value = 0.4
    cm = N.new("ShaderNodeMath")
    cm.operation = "MULTIPLY"
    cm.inputs[1].default_value = 0.0
    L(crack.outputs[0], cm.inputs[0])
    L(cm.outputs[0], h.inputs[2])
    h2 = N.new("ShaderNodeMath")
    h2.operation = "ADD"
    L(h.outputs[0], h2.inputs[0])
    L(tex.outputs["Fac"], h2.inputs[1])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.9
    bump.inputs["Distance"].default_value = 0.08
    L(h2.outputs[0], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    # Khe nứt tối (bụi bẩn đọng).
    base_col = bsdf.inputs["Base Color"].links[0].from_socket
    dk = N.new("ShaderNodeMix")
    dk.data_type = "RGBA"
    inv = N.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1
    inv.inputs[1].default_value = 0.0
    soft = N.new("ShaderNodeMath")
    soft.operation = "MULTIPLY"
    soft.inputs[1].default_value = 0.0  # lưới nứt đã bỏ: không tối thêm
    L(inv.outputs[0], soft.inputs[0])
    L(soft.outputs[0], dk.inputs["Factor"])
    L(base_col, dk.inputs[6])
    dk.inputs[7].default_value = srgb("#3A3026")
    L(dk.outputs[2], bsdf.inputs["Base Color"])
    # Vệt nước mưa chảy sẫm theo chiều dọc + đốm địa y vàng xám.
    st = N.new("ShaderNodeMapping")
    st.inputs["Scale"].default_value = (3.0 * scale, 3.0 * scale, 0.25 * scale)
    L(tc.outputs["Object"], st.inputs["Vector"])
    streak = N.new("ShaderNodeTexNoise")
    streak.inputs["Detail"].default_value = 3
    L(st.outputs[0], streak.inputs["Vector"])
    sm = N.new("ShaderNodeMapRange")
    sm.inputs["From Min"].default_value = 0.5
    sm.inputs["From Max"].default_value = 0.68
    sm.inputs["To Max"].default_value = 0.45
    L(streak.outputs["Fac"], sm.inputs["Value"])
    sc = N.new("ShaderNodeMix")
    sc.data_type = "RGBA"
    L(sm.outputs[0], sc.inputs["Factor"])
    L(bsdf.inputs["Base Color"].links[0].from_socket, sc.inputs[6])
    sc.inputs[7].default_value = srgb("#5E5244")
    lich = N.new("ShaderNodeTexVoronoi")
    lich.inputs["Scale"].default_value = 9 * scale
    L(tc.outputs["Object"], lich.inputs["Vector"])
    lm = N.new("ShaderNodeMapRange")
    lm.inputs["From Min"].default_value = 0.12
    lm.inputs["From Max"].default_value = 0.06
    lm.inputs["To Max"].default_value = 0.6
    L(lich.outputs["Distance"], lm.inputs["Value"])
    lc = N.new("ShaderNodeMix")
    lc.data_type = "RGBA"
    L(lm.outputs[0], lc.inputs["Factor"])
    L(sc.outputs[2], lc.inputs[6])
    lc.inputs[7].default_value = srgb("#B8B07A")
    L(lc.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    return finish(mat, nt, bsdf, out, haze)


def mountain_material(name="Mountain"):
    """Núi đá vôi xa: mảng sáng tối lớn theo nhiễu, sườn cây bụi sẫm, sương
    xanh dày (không chi tiết nhỏ — ở xa không thấy)."""
    mat, nt, bsdf, out = _mat(name)
    N, L = nt.nodes, nt.links.new
    tc, tex = noise_color(nt, bsdf, "#76828E", "#4C5862", 0.012, detail=6, lo=0.42, hi=0.6)
    nrm = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    L(nrm.outputs["Normal"], sep.inputs[0])
    flat = N.new("ShaderNodeMapRange")
    flat.inputs["From Min"].default_value = 0.75
    flat.inputs["From Max"].default_value = 0.95
    L(sep.outputs["Z"], flat.inputs["Value"])
    m = N.new("ShaderNodeMix")
    m.data_type = "RGBA"
    L(flat.outputs[0], m.inputs["Factor"])
    L(bsdf.inputs["Base Color"].links[0].from_socket, m.inputs[6])
    m.inputs[7].default_value = srgb("#56664E")
    L(m.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return finish(mat, nt, bsdf, out, 0.45)


def foliage_material(name, lit="#8A9E5A", dark="#4A5E34", haze=1.0, translucent=0.25):
    """Lá ô liu: mặt trên xanh xám, mặt dưới bạc; ánh xuyên lá."""
    mat, nt, bsdf, out = _mat(name)
    N, L = nt.nodes, nt.links.new
    rnd = N.new("ShaderNodeObjectInfo")
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L(rnd.outputs["Random"], mix.inputs["Factor"])
    mix.inputs[6].default_value = srgb(lit)
    mix.inputs[7].default_value = srgb(dark)
    # Lá thật (instance) lấy ngẫu nhiên theo từng lá; khối tán xa dùng nhiễu.
    tc, tex = noise_color(nt, bsdf, lit, dark, 6, lo=0.4, hi=0.6)
    m2 = N.new("ShaderNodeMix")
    m2.data_type = "RGBA"
    m2.inputs["Factor"].default_value = 0.5
    L(tex.outputs["Fac"], m2.inputs["Factor"])
    L(mix.outputs[2], m2.inputs[6])
    L(bsdf.inputs["Base Color"].links[0].from_socket, m2.inputs[7])
    L(m2.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = translucent
    mat.use_backface_culling = False
    return finish(mat, nt, bsdf, out, haze)


def bark_material(name="Bark", haze=1.0):
    mat, nt, bsdf, out = _mat(name)
    N, L = nt.nodes, nt.links.new
    tc, tex = noise_color(nt, bsdf, "#857868", "#4E4438", 14, detail=10, lo=0.42, hi=0.6)
    wave = N.new("ShaderNodeTexWave")
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 6
    wave.inputs["Distortion"].default_value = 14
    L(tc.outputs["Object"], wave.inputs["Vector"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.45
    bump.inputs["Distance"].default_value = 0.02
    L(wave.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.9
    return finish(mat, nt, bsdf, out, haze)


def flat_material(name, hex_, rough=0.9, haze=1.0, emission=0.0):
    mat, nt, bsdf, out = _mat(name)
    bsdf.inputs["Base Color"].default_value = srgb(hex_)
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = srgb(hex_)
        bsdf.inputs["Emission Strength"].default_value = emission
    return finish(mat, nt, bsdf, out, haze)


# ---------------------------------------------------------------- hình khối


def mesh_from(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def obj(name, me, mats, layer_name, smooth=True):
    o = add_object(name, me, mats, smooth_shade=smooth)
    return put(o, layer_name)


def blob(name, items, voxel, smooth_iter=4, rough=0.0, rough_scale=1.0, seed=0, ledges=0.0, boxes=()):
    """Gộp ellipsoid ((tâm), (rx, ry, rz)) mét và khối hộp [boxes] ((tâm),
    (dx, dy, dz), (xoay x, y, z độ)) thành bề mặt liền (voxel), rồi đẩy gồ
    ghề theo nhiễu [rough] (mét)."""
    from mathutils import Euler
    bm = bmesh.new()
    for c, r in items:
        g = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1)
        for v in g["verts"]:
            v.co = Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2])) + Vector(c)
    for c, size, rot in boxes:
        g = bmesh.ops.create_cube(bm, size=1)
        m = Euler([math.radians(a) for a in rot]).to_matrix()
        for v in g["verts"]:
            v.co = m @ Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(c)
    raw = mesh_from(name + "_raw", bm)
    tmp = bpy.data.objects.new(name + "_tmp", raw)
    bpy.context.scene.collection.objects.link(tmp)
    rm = tmp.modifiers.new("Remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = voxel
    sm = tmp.modifiers.new("Smooth", "SMOOTH")
    sm.iterations = smooth_iter
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.meshes.remove(raw)
    me.name = name
    if rough:
        off = Vector((seed * 7.1, seed * 3.3, seed * 1.7))
        for v in me.vertices:
            n = noise.fractal(v.co * rough_scale + off, 0.6, 2.2, 5)
            d = v.normal * n * rough
            if ledges:
                # Đá vôi xếp tầng: mỗi tầng nhô ra ở đáy, thụt vào ở đỉnh;
                # chỉ đẩy theo phương ngang (mặt vách đứng).
                # Tầng dày mỏng không đều, gờ lúc rõ lúc mất theo nhiễu.
                z = v.co.z * 1.3 + 0.9 * noise.noise(v.co * 0.35 + off)
                k = z % 1.0
                fade = max(0.0, noise.noise(v.co * 0.6 + off * 2) + 0.2)
                h = Vector((v.normal.x, v.normal.y, 0))
                if h.length > 0.3:
                    d += h.normalized() * (1 - k) ** 3 * ledges * fade
            v.co += d
    return me


def terrain(name, x0, x1, y0, y1, nx, ny, height):
    """Lưới mặt đất, độ cao z = height(x, y)."""
    bm = bmesh.new()
    verts = []
    for j in range(ny + 1):
        y = y0 + (y1 - y0) * j / ny
        row = []
        for i in range(nx + 1):
            x = x0 + (x1 - x0) * i / nx
            row.append(bm.verts.new((x, y, height(x, y))))
        verts.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
    return mesh_from(name, bm)


def tube(bm, pts, radii, sides=10):
    """Ống thon qua các điểm (mét) — thân, cành cây."""
    rings = []
    for k, (p, r) in enumerate(zip(pts, radii)):
        p = Vector(p)
        a = Vector(pts[min(k + 1, len(pts) - 1)]) - Vector(pts[max(k - 1, 0)])
        a.normalize()
        side = a.cross(Vector((0, 1, 0)))
        if side.length < 1e-3:
            side = a.cross(Vector((1, 0, 0)))
        side.normalize()
        up = side.cross(a).normalized()
        ring = []
        for s in range(sides):
            ang = 2 * math.pi * s / sides
            # Thân ô liu xoắn, sần: bán kính lồi lõm theo góc.
            rr = r * (1 + 0.18 * math.sin(ang * 3 + k * 0.9))
            ring.append(bm.verts.new(p + (side * math.cos(ang) + up * math.sin(ang)) * rr))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for s in range(sides):
            s2 = (s + 1) % sides
            bm.faces.new((a[s], a[s2], b[s2], b[s]))


def leaf_mesh():
    """Một lá ô liu: hình mác hẹp, hơi cong."""
    bm = bmesh.new()
    pts = [(0, 0), (0.012, 0.03), (0.01, 0.07), (0, 0.1), (-0.01, 0.07), (-0.012, 0.03)]
    vs = [bm.verts.new((x, 0.006 * math.sin(y * 30), y)) for x, y in pts]
    bm.faces.new(vs)
    me = mesh_from("Leaf", bm)
    o = bpy.data.objects.new("Leaf", me)
    bpy.context.scene.collection.objects.link(o)
    o.hide_render = True
    o.hide_viewport = True
    return o


def scatter_nodes(name, instance, density, scale, mat, keep_source=None, seed=0, align_normal=False,
                  selection_noise=None):
    """Geometry nodes: rải [instance] lên bề mặt object (lá trên tán, cây trên
    đồi), xoay ngẫu nhiên, phóng [scale] (min, max). [keep_source]: vật liệu
    cho chính lưới gốc (tán lõi tối chống lộ trời) — None thì bỏ lưới gốc.
    [selection_noise]: (tỉ lệ, ngưỡng) chỉ rải nơi nhiễu > ngưỡng (rừng
    thành đám)."""
    ng = bpy.data.node_groups.new(name, "GeometryNodeTree")
    ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    N, L = ng.nodes, ng.links.new
    gi = N.new("NodeGroupInput")
    go = N.new("NodeGroupOutput")
    dist = N.new("GeometryNodeDistributePointsOnFaces")
    dist.inputs["Density"].default_value = density
    dist.inputs["Seed"].default_value = seed
    L(gi.outputs[0], dist.inputs["Mesh"])
    if selection_noise:
        pos = N.new("GeometryNodeInputPosition")
        tex = N.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = selection_noise[0]
        L(pos.outputs[0], tex.inputs["Vector"])
        cmp_ = N.new("ShaderNodeMath")
        cmp_.operation = "GREATER_THAN"
        L(tex.outputs["Fac"], cmp_.inputs[0])
        cmp_.inputs[1].default_value = selection_noise[1]
        L(cmp_.outputs[0], dist.inputs["Selection"])
    info = N.new("GeometryNodeObjectInfo")
    info.inputs["Object"].default_value = instance
    if "As Instance" in info.inputs:
        info.inputs["As Instance"].default_value = True
    inst = N.new("GeometryNodeInstanceOnPoints")
    L(dist.outputs["Points"], inst.inputs["Points"])
    L(info.outputs["Geometry"], inst.inputs["Instance"])
    rot = N.new("FunctionNodeRandomValue")
    rot.data_type = "FLOAT_VECTOR"
    rot.inputs["Min"].default_value = (0, 0, 0)
    rot.inputs["Max"].default_value = (6.283, 6.283, 6.283) if not align_normal else (0.15, 0.15, 6.283)
    rot.inputs["Seed"].default_value = seed + 1
    L(rot.outputs[0], inst.inputs["Rotation"])
    sc = N.new("FunctionNodeRandomValue")
    sc.data_type = "FLOAT"
    lo, hi = [i for i in sc.inputs if i.type == "VALUE" and i.name in ("Min", "Max")][:2]
    lo.default_value, hi.default_value = scale
    sc.inputs["Seed"].default_value = seed + 2
    L(next(o for o in sc.outputs if o.type == "VALUE"), inst.inputs["Scale"])
    real = N.new("GeometryNodeRealizeInstances")
    L(inst.outputs[0], real.inputs["Geometry"])
    out = real.outputs[0]
    if mat is not None:
        sm = N.new("GeometryNodeSetMaterial")
        L(out, sm.inputs["Geometry"])
        sm.inputs["Material"].default_value = mat
        out = sm.outputs[0]
    if keep_source is not None:
        smat = N.new("GeometryNodeSetMaterial")
        L(gi.outputs[0], smat.inputs["Geometry"])
        smat.inputs["Material"].default_value = keep_source
        join = N.new("GeometryNodeJoinGeometry")
        L(out, join.inputs[0])
        L(smat.outputs[0], join.inputs[0])
        out = join.outputs[0]
    L(out, go.inputs[0])
    return ng


def scatter(o, ng):
    m = o.modifiers.new("Scatter", "NODES")
    m.node_group = ng
    return o


# ---------------------------------------------------------------- cây ô liu


def olive_tree(name, base, height, layer_name, leaf, mats, seed=0, leaf_density=900, spread=1.0):
    """Ô liu già: gốc phình, thân xoắn tách đôi, cành vươn ngang, tán thưa
    thành từng đám lá bạc (lá thật rải trên khối tán)."""
    rng = random.Random(seed)
    bark, foliage, inner = mats
    bx, by, bz = base
    bm = bmesh.new()
    r0 = height * 0.05
    # Hai nhánh thân xoắn vào nhau từ gốc.
    tips = []
    for k, lean in enumerate((-0.32, 0.26)):
        pts, rad = [], []
        for i in range(7):
            t = i / 6
            twist = math.sin(t * 3.0 + k * 1.7) * 0.18 * height * (0.4 + t)
            pts.append((bx + lean * height * t * spread + twist * 0.5 + (k - 0.5) * r0 * (1 - t),
                        by + twist * 0.3, bz + height * 0.55 * t))
            rad.append(r0 * (1.25 - 0.75 * t) * (1.4 if i == 0 else 1))
        tube(bm, pts, rad)
        tips.append(pts[-1])
    # Cành chính toả ra từ đỉnh thân.
    crowns = []
    for tip in tips:
        for b in range(3):
            ang = rng.uniform(-1.2, 1.2) + (0.0 if b == 0 else (-0.9 if b == 1 else 0.9))
            ln = height * rng.uniform(0.25, 0.42) * spread
            p0 = Vector(tip)
            p1 = p0 + Vector((math.sin(ang) * ln * 0.5, rng.uniform(-0.2, 0.2) * ln, ln * 0.45))
            p2 = p1 + Vector((math.sin(ang) * ln * 0.6, rng.uniform(-0.3, 0.3) * ln, ln * 0.25))
            tube(bm, [p0, p1, p2], [r0 * 0.55, r0 * 0.35, r0 * 0.15], sides=7)
            crowns.append(p2)
    wood = obj(name + "Trunk", mesh_from(name + "Trunk", bm), [bark], layer_name)
    # Tán: các đám lá quanh ngọn cành, không thành một khối tròn.
    items = []
    for c in crowns:
        for _ in range(4):
            off = Vector((rng.uniform(-1.6, 1.6), rng.uniform(-0.8, 0.8), rng.uniform(-0.6, 0.9))) * height * 0.16
            r = height * rng.uniform(0.07, 0.12)
            items.append((tuple(c + off), (r * 1.5, r * 1.2, r * 0.75)))
    canopy = blob(name + "Canopy", items, voxel=height * 0.015, smooth_iter=2, rough=height * 0.05,
                  rough_scale=4 / height, seed=seed)
    co = obj(name + "Canopy", canopy, [foliage], layer_name)
    scatter(co, scatter_nodes(name + "Leaves", leaf, leaf_density, (0.8, 1.3), foliage, keep_source=inner,
                              seed=seed))
    return wood, co


def far_olive(name, mats):
    """Cây ô liu nhỏ (đồi giữa, nhìn từ xa): thân ngắn + tán gồ ghề."""
    bark, foliage = mats
    bm = bmesh.new()
    tube(bm, [(0, 0, 0), (0.08, 0, 0.6), (0.02, 0, 1.2)], [0.2, 0.13, 0.09], sides=6)
    trunk = add_object(name + "Trunk", mesh_from(name + "Trunk", bm), [bark])
    canopy = blob(name + "Canopy", [((0, 0, 1.8), (1.7, 1.4, 0.8)), ((0.9, 0.2, 1.6), (1.1, 1.0, 0.7)),
                                     ((-0.8, -0.2, 1.7), (1.1, 1.0, 0.65)), ((0.2, 0.3, 2.3), (0.9, 0.8, 0.5))],
                  voxel=0.12, rough=0.28, rough_scale=1.4, seed=3)
    can = add_object(name + "Canopy", canopy, [foliage])
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    for o in (trunk, can):
        for c in o.users_collection:
            c.objects.unlink(o)
        col.objects.link(o)
    col.hide_render = True
    holder = bpy.data.objects.new(name, None)
    holder.instance_type = "COLLECTION"
    holder.instance_collection = col
    bpy.context.scene.collection.objects.link(holder)
    holder.hide_render = True
    # Gom thành một lưới để rải bằng geometry nodes.
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new(name + "Mesh")
    bm2 = bmesh.new()
    for o in (trunk, can):
        tmp = bmesh.new()
        tmp.from_mesh(o.evaluated_get(dg).data)
        tmp.to_mesh(me)
        bm2.from_mesh(me)
        tmp.free()
    bm2.to_mesh(me)
    bm2.free()
    me.materials.append(bark)
    me.materials.append(foliage)
    # Mặt thuộc tán (z > 1.5 m) dùng vật liệu lá.
    for p in me.polygons:
        p.material_index = 1 if p.center.z > 1.15 else 0
        p.use_smooth = True
    tree = bpy.data.objects.new(name + "Tree", me)
    bpy.context.scene.collection.objects.link(tree)
    tree.hide_render = True
    tree.hide_viewport = True
    return tree


def cypress(name, base, h, mat, layer_name, seed=0):
    x, y, z = base
    items = [((x, y, z + h * 0.45), (h * 0.11, h * 0.11, h * 0.45)),
             ((x, y, z + h * 0.8), (h * 0.07, h * 0.07, h * 0.22))]
    me = blob(name, items, voxel=h * 0.025, rough=h * 0.025, rough_scale=6 / h, seed=seed)
    return obj(name, me, [mat], layer_name)


# ---------------------------------------------------------------- đền


def temple(center, width, layer_name, marble, roof_mat, dark, roof=True):
    """Đền Doric nhỏ quay mặt về máy quay: nền 3 bậc, 6 cột có rãnh, đầu
    cột, xà, diềm, trán tường tam giác; một cột gãy (thung lũng hoang tàn)."""
    cx, cy, cz = center
    bm = bmesh.new()
    depth = width * 1.6
    step_h = width * 0.035

    def box(x0, x1, y0, y1, z0, z1):
        g = bmesh.ops.create_cube(bm, size=1)
        for v in g["verts"]:
            v.co = Vector(((x0 + x1) / 2 + v.co.x * (x1 - x0), (y0 + y1) / 2 + v.co.y * (y1 - y0),
                           (z0 + z1) / 2 + v.co.z * (z1 - z0)))

    for k in range(3):
        g = width * 0.04 * (2 - k)
        box(cx - width / 2 - g, cx + width / 2 + g, cy - g, cy + depth + g, cz + k * step_h, cz + (k + 1) * step_h)
    base_z = cz + 3 * step_h
    col_h = width * 0.42
    col_r = width * 0.045
    n = 6
    xs = [cx - width / 2 + col_r * 1.6 + (width - col_r * 3.2) * i / (n - 1) for i in range(n)]
    broken = 4
    for side_y in (cy + col_r * 1.6, cy + depth - col_r * 1.6):
        for i, x in enumerate(xs):
            h = col_h * (0.55 if (i == broken and side_y < cy + depth / 2) else 1.0)
            g = bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=col_r, radius2=col_r * 0.82,
                                      depth=h)
            for v in g["verts"]:
                # Rãnh dọc (flutes).
                ang = math.atan2(v.co.y, v.co.x)
                f = 1 - 0.06 * (0.5 + 0.5 * math.cos(ang * 20))
                v.co = Vector((x + v.co.x * f, side_y + v.co.y * f, base_z + h / 2 + v.co.z))
            if h == col_h:
                box(x - col_r * 1.25, x + col_r * 1.25, side_y - col_r * 1.25, side_y + col_r * 1.25,
                    base_z + col_h, base_z + col_h + col_r * 0.5)
    # Cột hai bên hông.
    for side_x in (xs[0], xs[-1]):
        for k in range(1, 5):
            y = cy + col_r * 1.6 + (depth - col_r * 3.2) * k / 5
            g = bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=col_r, radius2=col_r * 0.82,
                                      depth=col_h)
            for v in g["verts"]:
                v.co = Vector((side_x + v.co.x, y + v.co.y, base_z + col_h / 2 + v.co.z))
    top = base_z + col_h + col_r * 0.5
    ent = width * 0.14
    if roof:
        box(cx - width / 2, cx + width / 2, cy, cy + depth, top, top + ent * 0.45)  # xà
        box(cx - width / 2, cx + width / 2, cy, cy + depth, top + ent * 0.45, top + ent)  # diềm
        box(cx - width / 2 - 0.08 * width * 0.1, cx + width / 2 + 0.08 * width * 0.1, cy - 0.02 * width,
            cy + depth + 0.02 * width, top + ent, top + ent * 1.1)  # gờ mái
        # Lõi tối bên trong (naos) sau hàng cột.
        box(cx - width * 0.36, cx + width * 0.36, cy + depth * 0.2, cy + depth * 0.85, base_z, top)
    else:
        # Hoang tàn: xà chỉ còn trên hàng cột trước và một bên, tường naos đổ
        # còn nửa, nền lát đá lộ ra.
        bw = col_r * 1.4
        box(cx - width / 2, cx + width / 2, cy + col_r * 1.6 - bw, cy + col_r * 1.6 + bw, top, top + ent * 0.5)
        box(xs[0] - bw, xs[0] + bw, cy, cy + depth * 0.7, top, top + ent * 0.5)
        for x0, x1 in ((-0.36, -0.3), (0.3, 0.36)):
            box(cx + width * x0, cx + width * x1, cy + depth * 0.2, cy + depth * 0.85, base_z, base_z + col_h * 0.45)
    me = mesh_from("Temple", bm)
    t = obj("Temple", me, [marble], layer_name, smooth=False)
    if not roof:
        # Đền đổ mái (nhìn từ trên cao): chỉ còn hàng cột, xà, lõi tối.
        return t, None
    # Trán tường + mái dốc.
    bm = bmesh.new()
    pk = top + ent * 1.1
    peak = pk + width * 0.17
    for y0, y1 in ((cy - 0.02 * width, cy + depth + 0.02 * width),):
        a = [bm.verts.new((cx - width / 2, y0, pk)), bm.verts.new((cx + width / 2, y0, pk)),
             bm.verts.new((cx, y0, peak))]
        b = [bm.verts.new((cx - width / 2, y1, pk)), bm.verts.new((cx + width / 2, y1, pk)),
             bm.verts.new((cx, y1, peak))]
        bm.faces.new(a)
        bm.faces.new(list(reversed(b)))
        bm.faces.new((a[0], a[2], b[2], b[0]))
        bm.faces.new((a[2], a[1], b[1], b[2]))
        bm.faces.new((a[1], a[0], b[0], b[1]))
    roof = obj("Roof", mesh_from("Roof", bm), [roof_mat], layer_name, smooth=False)
    return t, roof


# ---------------------------------------------------------------- cảnh


def build():
    scene = bpy.context.scene
    dirt = ground_material()
    dirt_far = ground_material("DirtFar")
    rock = rock_material()
    rock_far = mountain_material()
    bark = bark_material()
    olive = foliage_material("Olive")
    olive_inner = flat_material("OliveInner", "#2E3A24", rough=1)
    olive_far = foliage_material("OliveFar", *pal("olive_far"), translucent=0.1)
    cypress_mat = foliage_material("Cypress", *pal("cypress"), translucent=0.05)
    marble = marble_material("TempleMarble", base="#EDE4D0", vein="#C2B8A6", glow_strength=0.0)
    roof_mat = flat_material("RoofTile", "#B4644A", rough=0.8)
    cave_dark = flat_material("CaveDark", "#0C0806", rough=1, haze=0)
    grass_mat = fur_material("Grass", pal("grass"))
    leaf = leaf_mesh()

    # ---- núi xa: dãy núi đá vôi Argolis, xanh mờ trong sương.
    def mountains(x, y):
        ridge = noise.ridged_multi_fractal(Vector((x * 0.004, y * 0.004, 0.3)), 0.9, 2.1, 5, 1.0, 2.0)
        base = 30 + 60 * math.exp(-((x + 220) / 320) ** 2) + 50 * math.exp(-((x - 320) / 280) ** 2)
        fade = min(1, max(0, (y - 420) / 160))
        return (base + ridge * 42) * fade - 4
    far = obj("Mountains", terrain("Mountains", -1600, 1600, 420, 1200, 260, 80, mountains), [rock_far], "far")
    far.data.polygons.foreach_set("use_smooth", [True] * len(far.data.polygons))

    # ---- đồi giữa: đồi thoải trồng ô liu, đồi đền ở giữa.
    temple_x, temple_z = stage_to_world(196, 118, 72)

    def hills(x, y):
        h = 2.5 + 3.5 * noise.fractal(Vector((x * 0.02, y * 0.02, 1.7)), 0.6, 2.0, 4)
        h += 5.0 * math.exp(-(((x - temple_x) / 24) ** 2 + ((y - 76) / 16) ** 2))
        h += 4 * max(0, (y - 120) / 80)
        near_fade = min(1, max(0, (y - 14) / 10))
        return h * near_fade - 0.2
    hm = obj("Hills", terrain("Hills", -160, 160, 12, 210, 160, 100, hills), [dirt_far], "mid")
    tree = far_olive("FarOlive", (bark, olive_far))
    scatter(hm, scatter_nodes("Grove", tree, 0.035, (0.7, 1.2), None, keep_source=dirt_far, seed=4,
                              align_normal=True, selection_noise=(0.04, 0.47)))
    temple_base = hills(temple_x, 72)
    temple((temple_x, 68, temple_base - 0.3), 12, "mid", marble, roof_mat, cave_dark)
    rng = random.Random(9)
    for k in range(14):
        x = rng.uniform(-60, 60)
        y = rng.uniform(26, 110)
        if abs(x - temple_x) < 12 and abs(y - 72) < 16:
            continue
        cypress(f"Cypress{k}", (x, y, hills(x, y) - 0.2), rng.uniform(6, 10), cypress_mat, "mid", seed=k)

    # ---- cảnh gần: mặt đất (lối đi trụi ở dải hành động), vách đá + hang
    # sau quái, cây ô liu già bên trái, cột đổ.
    def near_ground(x, y):
        bump = 0.12 * noise.fractal(Vector((x * 0.4, y * 0.4, 0.2)), 0.6, 2.0, 4)
        rise = 0.9 * max(0, (y - 6) / 10) ** 1.6
        flat = min(1, abs(y) / 1.6)  # dải hành động phẳng
        return bump * flat + rise
    gm = obj("Ground", terrain("Ground", -40, 40, -3, 16, 200, 60, near_ground), [dirt], "near")
    # Cỏ khô mọc ngoài lối đi (thuộc tính `scar` = trụi, xem fur_nodes).
    bare = []
    for v in gm.data.vertices:
        x, y = v.co.x, v.co.y
        path = math.exp(-(y / 1.3) ** 2)
        n = noise.fractal(Vector((x * 0.7, y * 0.7, 4.0)), 0.6, 2.0, 3)
        bare.append(min(1.0, path + max(0, 0.15 - n) * 3))
    attr = gm.data.attributes.new("scar", "FLOAT", "POINT")
    attr.data.foreach_set("value", bare)
    grass = with_fur(gm, grass_mat, density=1400, length=(0.05, 0.16), radius=0.0016, comb=(0.2, 0.1, 1.0),
                     lift=0.8, gravity=0.02, jitter=0.45, seed=2)
    put(grass, "near")

    # Vách đá vôi + hang sư tử sau lưng quái (sân khấu x ≈ 290–430): hai
    # trụ đá hai bên miệng hang, mái đá nhô trên đầu, vách sâu tối phía sau.
    mx, _ = stage_to_world(345, 0, 3.0)
    # Khối đá vôi góc cạnh xếp tầng (hộp xoay lệch), không phải khối tròn.
    cliff_boxes = [
        ((mx - 1.6, 3.4, 1.0), (1.3, 1.6, 2.2), (0, 4, 8)),  # trụ trái
        ((mx - 2.3, 4.1, 2.5), (2.0, 1.8, 1.7), (0, -6, -5)),
        ((mx + 1.55, 3.5, 1.15), (1.2, 1.8, 2.5), (0, -3, -6)),  # trụ phải
        ((mx + 3.0, 4.3, 1.7), (2.8, 2.6, 3.5), (0, 3, 10)),
        ((mx + 5.2, 5.0, 2.3), (3.0, 3.0, 4.8), (0, -2, -8)),
        ((mx + 0.1, 3.45, 2.95), (3.8, 1.8, 1.1), (0, 3, 2)),  # mái đá trên miệng hang
        ((mx + 0.5, 4.2, 3.95), (5.0, 2.6, 1.4), (0, -4, 6)),
        ((mx + 2.8, 4.9, 4.8), (4.2, 2.6, 1.6), (0, 5, -4)),
        ((mx, 5.4, 1.6), (2.8, 1.0, 3.4), (0, 0, 0)),  # vách trong cùng
    ]
    cliff = blob("Cliff", [], voxel=0.05, smooth_iter=2, rough=0.2, rough_scale=1.7, seed=5,
                 ledges=0.08, boxes=cliff_boxes)
    obj("Cliff", cliff, [rock], "near")
    inner = blob("CaveInner", [((mx, 4.3, 1.1), (1.25, 0.5, 1.3))], voxel=0.08)
    obj("CaveInner", inner, [cave_dark], "near")
    # Đá tảng lăn quanh chân vách.
    for k, (sx, d, r) in enumerate(((300, 1.4, 0.35), (410, 1.0, 0.5), (282, 2.6, 0.45), (395, 2.0, 0.3))):
        x, _ = stage_to_world(sx, 0, d)
        me = blob(f"Boulder{k}", [((x, d, r * 0.6), (r * 1.3, r, r))], voxel=r * 0.08, rough=r * 0.25,
                  rough_scale=2 / r, seed=20 + k)
        obj(f"Boulder{k}", me, [rock], "near")

    # Cây ô liu già bên trái (sau lưng nhân vật).
    ox, _ = stage_to_world(38, 0, 1.2)
    olive_tree("BigOlive", (ox, 1.2, 0), 4.0, "near", leaf, (bark, olive, olive_inner), seed=3, leaf_density=1300,
               spread=0.55)
    # Cột đổ: các khúc cột cẩm thạch nằm lăn lóc giữa sân khấu, hơi lùi sau.
    bm = bmesh.new()
    for k, (sx, d, ang, ln) in enumerate(((236, 2.4, 0.3, 0.7), (262, 2.8, -0.5, 0.55), (214, 3.2, 1.2, 0.5))):
        x, _ = stage_to_world(sx, 0, d)
        g = bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.24, radius2=0.24, depth=ln)
        for v in g["verts"]:
            a = math.atan2(v.co.y, v.co.x)
            f = 1 - 0.06 * (0.5 + 0.5 * math.cos(a * 20))
            p = Vector((v.co.x * f, v.co.y * f, v.co.z))
            p = Vector((p.z, p.y, p.x))  # nằm ngang
            c, s = math.cos(ang), math.sin(ang)
            v.co = Vector((x + p.x * c - p.y * s, d + p.x * s + p.y * c, 0.22 + p.z))
    obj("Ruins", mesh_from("Ruins", bm), [marble], "near", smooth=False)

    # ---- tiền cảnh: đá tối và cỏ cao ở hai góc dưới (đè lên nhân vật).
    for k, (sx, d, r) in enumerate(((-6, -1.9, 0.55), (414, -1.8, 0.5), (24, -2.0, 0.3))):
        x, _ = stage_to_world(sx, 0, d)
        me = blob(f"FgRock{k}", [((x, d, r * 0.3), (r * 1.4, r, r * 0.9))], voxel=r * 0.08, rough=r * 0.25,
                  rough_scale=2 / r, seed=40 + k)
        obj(f"FgRock{k}", me, [rock], "fg")
    fg_ground = terrain("FgGround", -6, 6, -2.4, -1.2, 60, 8, lambda x, y: -0.02)
    fgo = obj("FgGround", fg_ground, [dirt], "fg")
    vals = []
    for v in fgo.data.vertices:
        sx = v.co.x / (UNIT * (CAM_D + v.co.y) / CAM_D) + STAGE_W / 2
        edge = min(1, max(0, (abs(sx - 200) - 120) / 60))
        vals.append(1 - edge)
    attr = fgo.data.attributes.new("scar", "FLOAT", "POINT")
    attr.data.foreach_set("value", vals)
    fg_grass = with_fur(fgo, grass_mat, density=2600, length=(0.12, 0.32), radius=0.0024, comb=(0.2, 0.1, 1.0),
                        lift=0.8, gravity=0.04, jitter=0.5, seed=9)
    put(fg_grass, "fg")
    # Mặt đất tiền cảnh chỉ để mọc cỏ: không render (ẩn sau dải đất gần).
    fgo.hide_render = True
    return scene


def sky_world(scene):
    """Trời chiều Hy Lạp: xanh đậm trên đỉnh → vàng sương ở chân trời, sáng
    hơn phía mặt trời (trái)."""
    world = bpy.data.worlds.new("NemeaSky")
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links.new
    out = N.new("ShaderNodeOutputWorld")
    bg = N.new("ShaderNodeBackground")
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    L(tc.outputs["Generated"], sep.inputs[0])
    ramp = N.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, srgb("#E9DCC0")
    els[1].position, els[1].color = 0.45, srgb("#3E74BC")
    e = els.new(0.08)
    e.color = srgb("#C8D4DC")
    e = els.new(0.2)
    e.color = srgb("#8AB0D6")
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.0
    mr.inputs["From Max"].default_value = 1.0
    L(sep.outputs["Z"], mr.inputs["Value"])
    L(mr.outputs[0], ramp.inputs["Fac"])
    # Quầng nắng phía trái.
    glow = N.new("ShaderNodeVectorMath")
    glow.operation = "DOT_PRODUCT"
    L(tc.outputs["Generated"], glow.inputs[0])
    glow.inputs[1].default_value = Vector((-0.7, 0.55, 0.45)).normalized()
    pw = N.new("ShaderNodeMath")
    pw.operation = "POWER"
    clamp = N.new("ShaderNodeClamp")
    L(glow.outputs["Value"], clamp.inputs["Value"])
    L(clamp.outputs[0], pw.inputs[0])
    pw.inputs[1].default_value = 6
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "ADD"
    L(pw.outputs[0], mix.inputs["Factor"])
    L(ramp.outputs["Color"], mix.inputs[6])
    mix.inputs[7].default_value = srgb("#FFE2A8")
    L(mix.outputs[2], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    L(bg.outputs[0], out.inputs["Surface"])
    scene.world = world


def lights(scene):
    from boss_kit import add_sun
    # Cùng hướng nắng với quái/boss chương 1 (trên – trái – trước).
    add_sun(scene, "Sun", (0.55, 0.6, -0.6), 4.2, "#FFE0B4", angle=1.5)


def camera(scene):
    data = bpy.data.cameras.new("Cam")
    data.lens = FOCAL
    data.sensor_fit = "HORIZONTAL"
    data.sensor_width = 36.0 * (STAGE_W + 2 * MARGIN) / STAGE_W
    data.clip_start = 0.1
    data.clip_end = 3000
    cam = bpy.data.objects.new("Cam", data)
    scene.collection.objects.link(cam)
    cam.location = (0, -CAM_D, CAM_Z)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = cam
    scene.render.resolution_x = round((STAGE_W + 2 * MARGIN) * PX)
    scene.render.resolution_y = round(STAGE_H * PX)
    scene.render.resolution_percentage = 100
    return cam


def render_layer(scene, name, path):
    for ln in LAYERS[1:]:
        col = bpy.data.collections.get(ln)
        if col:
            col.hide_render = ln != name
    scene.render.film_transparent = name != "sky"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    from boss_kit import reset_scene, save_blend
    scene = reset_scene(samples=96)
    sky_world(scene)
    build()
    lights(scene)
    camera(scene)
    out = os.path.join(ROOT, "build", "blender", "backdrops")
    os.makedirs(out, exist_ok=True)
    if STILL:
        for ln in LAYERS[1:]:
            bpy.data.collections[ln].hide_render = False
        scene.render.film_transparent = False
        scene.render.filepath = os.path.join(out, "nemea_still.png")
        bpy.ops.render.render(write_still=True)
    else:
        for ln in LAYERS:
            render_layer(scene, ln, os.path.join(out, f"nemea_{ln}.png"))
    save_blend("nemea_valley")


if __name__ == "__main__":
    main()
