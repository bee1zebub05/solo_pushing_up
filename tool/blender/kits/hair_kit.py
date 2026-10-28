"""Tóc, râu, bờm dựng theo LỌN cho nhân vật hình người (boss chương Nhật…).

Mỗi lọn là một đường dẫn (guide) do script đặt tay — tỉa được dáng từng lọn
như tranh vẽ. Hai cách hiện:

- `strand_locks`: Curves object; bộ node tóc chính thức của Blender
  (datafiles/assets/nodes/procedural_hair_node_assets.blend — Duplicate,
  Clump, Frizz, Curl, Set Hair Curve Profile) nhân mỗi guide thành chùm sợi
  gom về ngọn. Đẹp ở cận cảnh, render bằng Cycles (sợi trên object Curves —
  sợi geometry nodes trên object lưới KHÔNG render, xem rules/dohoa/dunghinh.md).
- `ribbon_locks`: lọn khối (dải dẹt thon) như tượng tạc — đọc rõ ở cỡ sprite
  nhỏ, hợp phong cách painted (rules/dohoa/phongcach.md).

Toạ độ tính bằng mét (cùng hệ với human_kit / MPFB).
"""

import math
import os

import bpy
from mathutils import Vector

from boss_kit import add_object, srgb
from human_kit import tapered_world

HAIR_ASSETS = os.path.join(os.path.dirname(bpy.app.binary_path), f"{bpy.app.version[0]}.{bpy.app.version[1]}",
                           "datafiles", "assets", "nodes", "procedural_hair_node_assets.blend")


def hair_group(name):
    """Nạp một node group tóc của Blender (một lần)."""
    ng = bpy.data.node_groups.get(name)
    if ng:
        return ng
    with bpy.data.libraries.load(HAIR_ASSETS, link=False) as (src, dst):
        dst.node_groups = [name]
    return bpy.data.node_groups[name]


def bezier(p0, p1, p2, p3, n):
    """n điểm trên Bézier bậc ba."""
    out = []
    for i in range(n):
        t = i / (n - 1)
        u = 1 - t
        out.append(p0 * u ** 3 + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t ** 3)
    return out


def guide_curves(name, guides, radius=0.004):
    """Object Curves từ danh sách đường (mỗi đường: list Vector, gốc → ngọn)."""
    cv = bpy.data.hair_curves.new(name)
    cv.add_curves([len(g) for g in guides])
    flat = [c for g in guides for p in g for c in p]
    cv.position_data.foreach_set("vector", flat)
    rad = cv.attributes.get("radius") or cv.attributes.new("radius", "FLOAT", "POINT")
    vals = []
    for g in guides:
        n = len(g)
        vals += [radius * (1 - 0.85 * (i / (n - 1)) ** 1.4) for i in range(n)]
    rad.data.foreach_set("value", vals)
    obj = bpy.data.objects.new(name, cv)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _node(nt, group_name, **inputs):
    n = nt.nodes.new("GeometryNodeGroup")
    n.node_tree = hair_group(group_name)
    for k, v in inputs.items():
        if k in n.inputs:
            n.inputs[k].default_value = v
    return n


def strand_locks(name, guides, mat, per_lock=40, spread=0.012, clump=0.85, frizz=0.002, curl=0.0,
                 root_radius=0.0012, seed=0):
    """Mỗi guide → [per_lock] sợi rải quanh gốc trong bán kính [spread], gom
    về ngọn ([clump] 0–1), xù nhẹ ([frizz] mét), xoăn ([curl] mét bán kính)."""
    obj = guide_curves(name, guides)
    mod = obj.modifiers.new("Hair", "NODES")
    nt = bpy.data.node_groups.new(f"{name}Hair", "GeometryNodeTree")
    nt.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    nt.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    gi = nt.nodes.new("NodeGroupInput")
    go = nt.nodes.new("NodeGroupOutput")
    L = nt.links.new
    # Giữ guide làm "chỉ số chùm" để Clump gom sợi con về đúng guide của nó.
    dup = _node(nt, "Duplicate Hair Curves", Amount=per_lock, Radius=spread, Seed=seed)
    L(gi.outputs[0], dup.inputs[0])
    cur = dup.outputs[0]
    if clump > 0:
        cl = _node(nt, "Clump Hair Curves", Factor=clump, Shape=0.4, Seed=seed)
        # Guide = chính các guide gốc (đầu vào).
        if "Guide Curves" in cl.inputs:
            L(gi.outputs[0], cl.inputs["Guide Curves"])
        L(cur, cl.inputs[0])
        cur = cl.outputs[0]
    if curl > 0:
        cu = _node(nt, "Curl Hair Curves", Radius=curl, Frequency=6.0, Seed=seed)
        L(cur, cu.inputs[0])
        cur = cu.outputs[0]
    if frizz > 0:
        fr = _node(nt, "Frizz Hair Curves", Distance=frizz, Seed=seed)
        L(cur, fr.inputs[0])
        cur = fr.outputs[0]
    prof = _node(nt, "Set Hair Curve Profile", Radius=root_radius)
    L(cur, prof.inputs[0])
    sm = nt.nodes.new("GeometryNodeSetMaterial")
    sm.inputs["Material"].default_value = mat
    L(prof.outputs[0], sm.inputs[0])
    L(sm.outputs[0], go.inputs[0])
    mod.node_group = nt
    obj.data.materials.append(mat)
    return obj


def ribbon_locks(name, locks, mat, flat=2.6, taper=1.0, sides=8, steps=10):
    """Lọn khối dẹt: mỗi lọn (gốc, uốn, ngọn, bán kính gốc) — mét."""
    return add_object(name, tapered_world(name, locks, sides=sides, steps=steps, flat=flat, taper=taper), [mat])


def hair_material(name, root, mid, tip, sheen=0.08, rough=0.35):
    """Principled Hair theo màu gốc → ngọn (melanin bỏ qua, dùng màu trực tiếp)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    hair = nt.nodes.new("ShaderNodeBsdfHairPrincipled")
    hair.parametrization = "COLOR"
    info = nt.nodes.new("ShaderNodeHairInfo")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, srgb(root)
    els[1].position, els[1].color = 1.0, srgb(tip)
    m = els.new(0.5)
    m.color = srgb(mid)
    nt.links.new(info.outputs["Intercept"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], hair.inputs["Color"])
    hair.inputs["Roughness"].default_value = rough
    if "Coat" in hair.inputs:
        hair.inputs["Coat"].default_value = sheen
    nt.links.new(hair.outputs[0], out.inputs["Surface"])
    return mat


def combed_material(name, dark, light, scale=4.0, rough=0.45):
    """Mảng tóc chải bết sát da đầu (vỏ scalp): sọc mảnh chạy trước → sau
    (dọc trục Y vật thể), méo nhẹ theo nhiễu, có bump — đọc thành tóc dày,
    không thành mũ trơn dưới lớp sợi."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links.new
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    tc = N.new("ShaderNodeTexCoord")
    wave = N.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "X"
    wave.inputs["Scale"].default_value = scale
    wave.inputs["Distortion"].default_value = 2.5
    wave.inputs["Detail"].default_value = 3
    L(tc.outputs["Object"], wave.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.25, srgb(dark)
    e[1].position, e[1].color = 0.85, srgb(light)
    L(wave.outputs["Fac"], ramp.inputs[0])
    L(ramp.outputs[0], bsdf.inputs["Base Color"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.5
    L(wave.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = rough
    if "Anisotropic" in bsdf.inputs:
        bsdf.inputs["Anisotropic"].default_value = 0.6
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def fan(center, normal, up, n, length, spread_deg, droop, radius):
    """Một nhúm lọn xoè quạt từ [center] theo hướng [normal], cong xuống theo
    trọng lực [droop] — tiện cho bờm, mái, tóc tung bay."""
    side = normal.cross(up).normalized()
    out = []
    for k in range(n):
        a = math.radians(-spread_deg / 2 + spread_deg * k / max(1, n - 1))
        d = (normal * math.cos(a) + side * math.sin(a)).normalized()
        a0 = center
        a1 = center + d * length * 0.5 + up * length * 0.15
        a2 = center + d * length - up * droop
        out.append((a0, a1, a2, radius))
    return out
