"""Bản hoạt hình (2.5D) của quái Tripo: cùng mô hình, cùng xương, cùng biên
đạo với bản 3D, chỉ đổi cách tô — màu phẳng gom mảng, đổ bóng hai nấc, viền
đen quanh bóng hình. Xuất atlas `<tên>_toon`; chế độ 2.5D của game dùng atlas
này thay bản vẽ vector cũ (lib/art/sprite_atlas.dart, rules/dohoa.md mục 12).

    bash tool/blender/render.sh boar_tripo --toon --still
    bash tool/blender/render.sh boar_tripo --toon

Cycles không có Shader to RGB, Toon BSDF lại cắt mặt khuất về gần đen: tự
tính N·L với một hướng sáng cố định, chia nấc cứng bằng ColorRamp, tô bằng
phát sáng (sáng tối không phụ thuộc đèn; bóng đổ trên đất vẫn theo đèn thật). Viền = vỏ lật
ngược (Solidify sau Armature, đẩy ra ngoài, lật pháp tuyến): phần vỏ chắn
trước thân (sau khi lật thành quay lưng) trong suốt, phần lòi ra quanh bóng
hình tô đen thành nét viền.
"""

import sys

import bpy
import numpy as np

TOON = "--toon" in sys.argv

# Hướng tới đèn chính (trên – trái – trước máy quay, ngược hướng tia "Key"
# của các script quái) và các nấc sáng: (vị trí trên thang 0–1 của N·L, độ sáng).
LIGHT = (-0.55, -0.6, 0.6)
BANDS = ((0.0, 0.66), (0.42, 0.86), (0.58, 1.0), (0.86, 1.12))


def flat_image(img, block=16, colors=8, blur=2, iters=10):
    """Bản phẳng của ảnh màu [img]: thu nhỏ theo ô [block]² và làm mờ (xoá vân
    lông, vết ảnh chụp), gom về [colors] màu (k-means) — mảng màu phẳng như
    tranh vẽ. Trả về ảnh NHỎ: nút texture nội suy mượt nên mép giữa hai mảng
    mềm, không vỡ ô vuông. Mép đảo UV lem nhẹ, ở cỡ sprite không thấy."""
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    bw, bh = w // block, h // block
    small = px[: bh * block, : bw * block].reshape(bh, block, bw, block, 4).mean(axis=(1, 3))
    for _ in range(blur):
        pad = np.pad(small, ((1, 1), (1, 1), (0, 0)), mode="edge")
        small = sum(pad[dy:dy + bh, dx:dx + bw] for dy in range(3) for dx in range(3)) / 9
    flat = small[..., :3].reshape(-1, 3)
    rng = np.random.default_rng(3)
    centers = flat[rng.choice(len(flat), colors, replace=False)].copy()
    for _ in range(iters):
        label = ((flat[:, None, :] - centers[None]) ** 2).sum(-1).argmin(1)
        for k in range(colors):
            sel = flat[label == k]
            if len(sel):
                centers[k] = sel.mean(0)
    out = np.ones((bh, bw, 4), dtype=np.float32)
    out[..., :3] = centers[label].reshape(bh, bw, 3)
    flat_img = bpy.data.images.new(img.name + "_flat", bw, bh, alpha=True)
    flat_img.colorspace_settings.name = img.colorspace_settings.name
    flat_img.pixels.foreach_set(out.ravel())
    flat_img.pack()
    return flat_img


def _base_color(nt):
    """Ổ cắm đang cấp màu nền cho Principled (ảnh texture qua Mix), hoặc None."""
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return None, None
    sock = bsdf.inputs["Base Color"]
    if sock.links:
        return sock.links[0].from_socket, bsdf
    return None, bsdf


def toon_material(mat, sat=1.0, strength=1.7, block=16, colors=8):
    """Đổi vật liệu [mat] sang tô hoạt hình, giữ ảnh màu gốc."""
    nt = mat.node_tree
    for tex in [n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image]:
        tex.image = flat_image(tex.image, block, colors)
        tex.interpolation = "Linear"
    src, bsdf = _base_color(nt)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    if src is None:
        col = nt.nodes.new("ShaderNodeRGB")
        col.outputs[0].default_value = bsdf.inputs["Base Color"].default_value if bsdf else (0.6, 0.6, 0.6, 1)
        src = col.outputs[0]
    hsv = nt.nodes.new("ShaderNodeHueSaturation")
    hsv.inputs["Saturation"].default_value = sat
    nt.links.new(src, hsv.inputs["Color"])
    # Sáng tối theo góc pháp tuyến – hướng sáng, chia nấc cứng (cel).
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = LIGHT
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    span = nt.nodes.new("ShaderNodeMapRange")
    span.inputs["From Min"].default_value = -1
    span.inputs["From Max"].default_value = 1
    nt.links.new(dot.outputs["Value"], span.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    for k, (pos, v) in enumerate(BANDS):
        e = els[k] if k < len(els) else els.new(pos)
        e.position = pos
        e.color = (v, v, v, 1)
    nt.links.new(span.outputs["Result"], ramp.inputs["Fac"])
    shade = nt.nodes.new("ShaderNodeMix")
    shade.data_type = "RGBA"
    shade.blend_type = "MULTIPLY"
    shade.inputs["Factor"].default_value = 1
    nt.links.new(hsv.outputs["Color"], shade.inputs["A"])
    nt.links.new(ramp.outputs["Color"], shade.inputs["B"])
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Strength"].default_value = strength
    nt.links.new(shade.outputs["Result"], emit.inputs["Color"])
    nt.links.new(emit.outputs[0], out.inputs["Surface"])


def outline_material(color=(0.05, 0.035, 0.03, 1)):
    mat = bpy.data.materials.new("ToonOutline")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    ink = nt.nodes.new("ShaderNodeEmission")
    ink.inputs["Color"].default_value = color
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
    # Pháp tuyến vỏ đã lật: phần vỏ chắn trước thân là "quay lưng" → trong
    # suốt; phần lòi ra quanh bóng hình quay mặt về máy quay → mực.
    nt.links.new(ink.outputs[0], mix.inputs[1])
    nt.links.new(clear.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def toonify(scene, width=0.015, smooth=0, block=16, colors=8, skip=()):
    """Tô hoạt hình mọi lưới trong cảnh (trừ mặt hứng bóng và [skip]); viền
    dày [width] × cỡ lớn nhất của vật. Gọi SAU khi dựng và gắn xương."""
    ink = outline_material()
    done = set()
    for obj in list(bpy.data.objects):
        if obj.type != "MESH" or obj.is_shadow_catcher or obj.name in skip:
            continue
        for mat in obj.data.materials:
            if mat and mat.use_nodes and mat.name not in done:
                toon_material(mat, block=block, colors=colors)
                done.add(mat.name)
        if not obj.data.materials:
            continue
        # Làm mượt khối (sau Armature): xoá thớ lông/vân tạc vào lưới — mặt
        # gồ ghề cho vạch sáng tối lởm chởm, không ra mảng phẳng.
        if smooth:
            sm = obj.modifiers.new("ToonSmooth", "LAPLACIANSMOOTH")
            sm.iterations = smooth
            sm.lambda_factor = 0.6
            sm.lambda_border = 0.0
        obj.data.materials.append(ink)
        mod = obj.modifiers.new("ToonOutline", "SOLIDIFY")
        mod.thickness = -width * max(obj.dimensions)
        mod.offset = 1.0
        mod.use_flip_normals = True
        mod.use_rim = False
        mod.material_offset = len(obj.data.materials) - 1
