"""Phong cách "painted" (thử nghiệm, học cách làm đồ hoạ của các game chiến
thuật 3D kiểu Rise of Kingdoms): vẫn là 3D chiếu sáng mềm bằng Cycles (giữ
bóng đổ, AO) nhưng
  - màu tươi, bão hoà hơn; ánh sáng nắng vàng ấm, vùng tối ngả lạnh;
  - chất liệu mờ như sơn (bớt bóng loáng), bớt gồ ghề và nhiễu chi tiết nhỏ
    — hình đọc bằng khối lớn, không bằng chi tiết vụn;
  - lông/tóc thành từng lọn to thay vì sợi mảnh;
  - hiển thị màu AgX "Punchy" (tươi mà không cháy vùng sáng).

Gọi `install()` TRƯỚC khi dựng cảnh (lông), `apply(scene)` SAU khi dựng
cảnh và đặt đèn, trước khi render.
"""

import bpy

from boss_kit import srgb

# Mức chỉnh (một chỗ để thử nghiệm).
SATURATION = 1.15
VALUE = 1.0
MIN_ROUGHNESS = 0.62
SPECULAR_SCALE = 0.45
BUMP_SCALE = 0.2
MAX_NOISE_DETAIL = 2.0
FUR_RADIUS_SCALE = 2.4
FUR_DENSITY_SCALE = 0.3
KEY_SCALE = 1.1
KEY_TINT = "#FFE4BC"


# "Vẽ sẵn ánh sáng" như texture hand-painted: mặt hướng lên trời sáng ấm,
# mặt quay xuống tối ngả lạnh; mép lồi chạm sáng, khe lõm tối.
TOP_TINT = (1.12, 1.07, 0.97, 1.0)
BOTTOM_TINT = (0.72, 0.72, 0.86, 1.0)
EDGE_LIGHT = 0.35
EDGE_FROM, EDGE_TO = 0.5, 0.62


def _mix(nt, blend, fac, a, b):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = blend
    if isinstance(fac, float):
        m.inputs["Factor"].default_value = fac
    else:
        nt.links.new(fac, m.inputs["Factor"])
    for sock, v in ((m.inputs[6], a), (m.inputs[7], b)):
        if isinstance(v, tuple):
            sock.default_value = v
        else:
            nt.links.new(v, sock)
    return m.outputs[2]


def _map(nt, value, lo, hi):
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = lo
    mr.inputs["From Max"].default_value = hi
    nt.links.new(value, mr.inputs["Value"])
    return mr.outputs[0]


def _painted_light(nt, color):
    """[color] (socket) → màu đã "vẽ sáng" theo hướng mặt và độ lồi."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    up = _map(nt, sep.outputs["Z"], -1.0, 1.0)
    light = _mix(nt, "MIX", up, BOTTOM_TINT, TOP_TINT)
    color = _mix(nt, "MULTIPLY", 1.0, color, light)
    edge = _map(nt, geo.outputs["Pointiness"], EDGE_FROM, EDGE_TO)
    k = nt.nodes.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    nt.links.new(edge, k.inputs[0])
    k.inputs[1].default_value = EDGE_LIGHT
    return _mix(nt, "SCREEN", k.outputs[0], color, (1.0, 0.95, 0.85, 1.0))


def _saturate(nt, socket_from, socket_to, painted_light=False):
    hsv = nt.nodes.new("ShaderNodeHueSaturation")
    hsv.inputs["Saturation"].default_value = SATURATION
    hsv.inputs["Value"].default_value = VALUE
    nt.links.new(socket_from, hsv.inputs["Color"])
    out = hsv.outputs["Color"]
    if painted_light:
        out = _painted_light(nt, out)
    nt.links.new(out, socket_to)


def _boost(rgba):
    """Tăng bão hoà một màu hằng (khi ô màu không nối node)."""
    import colorsys
    r, g, b, a = rgba
    h, s, v = colorsys.rgb_to_hsv(max(r, 0), max(g, 0), max(b, 0))
    r, g, b = colorsys.hsv_to_rgb(h, min(1.0, s * SATURATION), v * VALUE)
    return (r, g, b, a)


def _paint_color_input(nt, sock, painted_light=False):
    if sock.is_linked:
        src = sock.links[0].from_socket
        nt.links.remove(sock.links[0])
        _saturate(nt, src, sock, painted_light)
    else:
        sock.default_value = _boost(tuple(sock.default_value))
        if painted_light:
            rgb = nt.nodes.new("ShaderNodeRGB")
            rgb.outputs[0].default_value = sock.default_value
            nt.links.new(_painted_light(nt, rgb.outputs[0]), sock)


def paint_material(mat):
    if not mat or not mat.use_nodes:
        return
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type == "BSDF_PRINCIPLED":
            _paint_color_input(nt, n.inputs["Base Color"], painted_light=True)
            r = n.inputs["Roughness"]
            if not r.is_linked:
                r.default_value = max(r.default_value, MIN_ROUGHNESS)
            for key in ("Specular IOR Level", "Coat Weight", "Sheen Weight"):
                if key in n.inputs and not n.inputs[key].is_linked:
                    n.inputs[key].default_value *= SPECULAR_SCALE
        elif n.type == "BSDF_HAIR_PRINCIPLED":
            _paint_color_input(nt, n.inputs["Color"])
            n.inputs["Roughness"].default_value = max(n.inputs["Roughness"].default_value, 0.5)
        elif n.type == "BUMP":
            n.inputs["Strength"].default_value *= BUMP_SCALE
        elif n.type == "TEX_NOISE":
            d = n.inputs["Detail"]
            if not d.is_linked:
                d.default_value = min(d.default_value, MAX_NOISE_DETAIL)


def install():
    """Gọi TRƯỚC khi dựng cảnh: mọi chỗ mọc lông (boss_kit.with_fur gọi
    fur_nodes) ra sợi to và thưa hơn — đọc thành từng lọn như vẽ."""
    import boss_kit
    if getattr(boss_kit, "_painted_fur", False):
        return
    original = boss_kit.fur_nodes

    def fur_nodes(name, source, mat, density, length, radius, *args, **kw):
        return original(name, source, mat, density * FUR_DENSITY_SCALE, length, radius * FUR_RADIUS_SCALE,
                        *args, **kw)

    boss_kit.fur_nodes = fur_nodes
    boss_kit._painted_fur = True


def warm_lights(scene):
    """Đèn chính (mạnh nhất) vàng ấm và mạnh hơn; trời hắt ngả xanh lạnh."""
    suns = [o for o in scene.objects if o.type == "LIGHT" and o.data.type == "SUN"]
    if suns:
        key = max(suns, key=lambda o: o.data.energy)
        key.data.energy *= KEY_SCALE
        key.data.color = srgb(KEY_TINT)[:3]
        key.data.angle = max(key.data.angle, 0.05)


def apply(scene):
    for mat in bpy.data.materials:
        paint_material(mat)
    warm_lights(scene)
    # AgX "Punchy": màu tươi mà vùng sáng không cháy (Standard cháy trắng/cam
    # khi đã tăng bão hoà, nhất là lông sư tử).
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
