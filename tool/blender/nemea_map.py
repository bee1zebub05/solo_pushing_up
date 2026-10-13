"""Bản đồ Thung lũng Nemea (màn chọn màn Kỳ công 1) dựng 3D như một sa bàn
nhìn chéo từ trên: đồng cỏ vàng xanh, sông uốn qua thung lũng có cầu đá, rừng
ô liu, đồi đền cẩm thạch, vách đá vôi có hang sư tử ở góc trên phải. Dùng
chung vật liệu và cây/đền/đá với phông trận (nemea_valley.py) để chương 1
liền một phong cách.

    bash tool/blender/render.sh nemea_map     # → assets/backdrops/nemea_map.webp

Toạ độ bản đồ 400×300 (lib/art/nemea_map_art.dart) quy về mặt đất bằng tia
từ máy quay trực giao nghiêng: điểm (mx, my) trên ảnh ↔ điểm mặt đất mà tia
đi qua. Flutter vẽ đường mòn và 10 điểm màn đè lên ảnh này, nên cây được
rải TRÁNH đường mòn theo toạ độ ảnh.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import ROOT, add_object, add_sun, reset_scene, save_blend, srgb  # noqa: E402
from greek_kit import marble_material  # noqa: E402
import nemea_valley as nv  # noqa: E402

MAP_W, MAP_H = 400, 300
PX = 3.0
WIDTH_M = 40.0  # bề ngang bản đồ, mét
TILT = math.radians(40)  # 0 = nhìn thẳng xuống

NODES = [(48, 262), (104, 240), (84, 196), (140, 170), (204, 188), (250, 228), (304, 200), (276, 148), (318, 104),
         (352, 62)]
TEMPLE = (196, 128)
CAVE = (356, 50)
BRIDGE = (232, 210)

CAM_H = 60.0
_right = Vector((1, 0, 0))
_up = Vector((0, math.cos(TILT), math.sin(TILT)))
_fwd = Vector((0, math.sin(TILT), -math.cos(TILT)))
_cam_pos = Vector((0, 0, 0)) - _fwd * CAM_H
HEIGHT_M = WIDTH_M * MAP_H / MAP_W


def ground_at(mx, my, h=0.0):
    """Điểm có độ cao [h] nằm trên tia của điểm (mx, my) trên ảnh bản đồ."""
    o = _cam_pos + _right * (mx / MAP_W - 0.5) * WIDTH_M + _up * (0.5 - my / MAP_H) * HEIGHT_M
    t = (o.z - h) / -_fwd.z
    return o + _fwd * t


def bezier(p0, p1, p2, p3, n=24):
    out = []
    for k in range(n + 1):
        t = k / n
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t * t
        d = t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


# Sông theo cùng đường cong với bản vector (_river trong nemea_map_art.dart).
_bank_a = bezier((0, 150), (60, 140), (120, 220), (190, 216)) + bezier((190, 216), (250, 212), (260, 260), (300, 300))
_bank_b = bezier((0, 136), (70, 128), (126, 206), (190, 202)) + bezier((190, 202), (270, 200), (284, 250), (326, 300))
RIVER = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in zip(_bank_a, _bank_b)]


def _seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / (dx * dx + dy * dy + 1e-9)))
    return math.hypot(p[0] - ax - dx * t, p[1] - ay - dy * t)


def dist_to(poly, p):
    return min(_seg_dist(p, a, b) for a, b in zip(poly, poly[1:]))


def path_poly():
    """Đường mòn như _path() của Flutter (bézier bậc hai qua trung điểm lệch)."""
    pts = [NODES[0]]
    for a, b in zip(NODES, NODES[1:]):
        mid = ((a[0] + b[0]) / 2 + (b[1] - a[1]) * 0.25, (a[1] + b[1]) / 2 + (a[0] - b[0]) * 0.25)
        for k in range(1, 9):
            t = k / 8
            pts.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * mid[0] + t * t * b[0],
                        (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * mid[1] + t * t * b[1]))
    return pts


PATH = path_poly()


def to_map(p):
    """Điểm thế giới → toạ độ bản đồ (đường chiếu song song theo _fwd)."""
    d = Vector(p) - _cam_pos
    return ((d.dot(_right) / WIDTH_M + 0.5) * MAP_W, (0.5 - d.dot(_up) / HEIGHT_M) * MAP_H)


# ---------------------------------------------------------------- địa hình


HILLS = [((70, 90), 9.0, 2.6), ((200, 110), 10.0, 3.2), ((150, 262), 7.0, 1.2), ((30, 40), 12.0, 3.0)]


def height(x, y):
    p = to_map((x, y, 0))
    h = 0.35 * noise.fractal(Vector((x * 0.12, y * 0.12, 0.5)), 0.6, 2.0, 4)
    for (mx, my), r, hh in HILLS:
        c = ground_at(mx, my)
        h += hh * math.exp(-((x - c.x) ** 2 + (y - c.y) ** 2) / (r * r))
    # Cao nguyên đá vôi góc trên phải (hang sư tử).
    c = ground_at(*CAVE)
    k = max(0.0, 1 - math.hypot((x - c.x) / 13, (y - c.y - 4) / 11))
    h += 6.5 * min(1.0, k * 2.2)
    # Lòng sông.
    d = dist_to(RIVER, p)
    if d < 14:
        h -= 0.9 * (1 - (d / 14) ** 2)
    return h


def grass_material():
    """Đồng cỏ cuối hè Argolis: xanh ô liu xen vàng rơm, lốm đốm đất."""
    mat, nt, bsdf, out = nv._mat("MapGrass")
    N, L = nt.nodes, nt.links.new
    tc, tex = nv.noise_color(nt, bsdf, "#8E9A52", "#B8A866", 0.18, detail=6, lo=0.4, hi=0.62)
    dirt = N.new("ShaderNodeTexNoise")
    dirt.inputs["Scale"].default_value = 1.6
    L(tc.outputs["Object"], dirt.inputs["Vector"])
    dm = N.new("ShaderNodeMapRange")
    dm.inputs["From Min"].default_value = 0.58
    dm.inputs["From Max"].default_value = 0.68
    dm.inputs["To Max"].default_value = 0.7
    L(dirt.outputs["Fac"], dm.inputs["Value"])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L(dm.outputs[0], mix.inputs["Factor"])
    L(bsdf.inputs["Base Color"].links[0].from_socket, mix.inputs[6])
    mix.inputs[7].default_value = srgb("#A88C62")
    # Đá lộ ra ở sườn dốc.
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    L(geo.outputs["Normal"], sep.inputs[0])
    steep = N.new("ShaderNodeMapRange")
    steep.inputs["From Min"].default_value = 0.8
    steep.inputs["From Max"].default_value = 0.6
    L(sep.outputs["Z"], steep.inputs["Value"])
    rock = N.new("ShaderNodeMix")
    rock.data_type = "RGBA"
    L(steep.outputs[0], rock.inputs["Factor"])
    L(mix.outputs[2], rock.inputs[6])
    rock.inputs[7].default_value = srgb("#BCA684")
    L(rock.outputs[2], bsdf.inputs["Base Color"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.3
    L(tex.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.95
    return nv.finish(mat, nt, bsdf, out, 0)


def water_material():
    mat, nt, bsdf, out = nv._mat("River")
    bsdf.inputs["Base Color"].default_value = srgb("#3C7898")
    bsdf.inputs["Roughness"].default_value = 0.06
    bsdf.inputs["Coat Weight"].default_value = 0.5
    N, L = nt.nodes, nt.links.new
    tc = N.new("ShaderNodeTexCoord")
    wave = N.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = 0.8
    wave.inputs["Distortion"].default_value = 6
    L(tc.outputs["Object"], wave.inputs["Vector"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.15
    L(wave.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    return nv.finish(mat, nt, bsdf, out, 0)


def build():
    grass = grass_material()
    rock = nv.rock_material("MapRock", haze=0)
    bark = nv.bark_material("MapBark", haze=0)
    olive = nv.foliage_material("MapOlive", lit="#8A9E5A", dark="#4E6236", haze=0, translucent=0.1)
    cyp = nv.foliage_material("MapCypress", lit="#3E5230", dark="#22301C", haze=0, translucent=0.05)
    marble = marble_material("MapMarble", base="#EDE4D0", vein="#C2B8A6", glow_strength=0.0)
    roof = nv.flat_material("MapRoof", "#B4644A", rough=0.8, haze=0)
    dark = nv.flat_material("MapCave", "#0C0806", rough=1, haze=0)

    # Địa hình phủ hết khung (mở rộng ra ngoài để mép không lộ).
    c0 = ground_at(-20, -20)
    c1 = ground_at(MAP_W + 20, MAP_H + 20)
    terr = nv.terrain("MapGround", c0.x, c1.x, c1.y, c0.y, 240, 200, height)
    t = add_object("MapGround", terr, [grass])

    # Mặt nước sông: dải lưới theo đường tâm, rộng theo hai bờ.
    bm = bmesh.new()
    rows = []
    for a, b in zip(_bank_a, _bank_b):
        pa = ground_at(*a)
        pb = ground_at(*b)
        rows.append((bm.verts.new((pa.x, pa.y, -0.42)), bm.verts.new((pb.x, pb.y, -0.42))))
    for (a0, b0), (a1, b1) in zip(rows, rows[1:]):
        bm.faces.new((a0, b0, b1, a1))
    add_object("River", nv.mesh_from("River", bm), [water_material()])

    # Cầu đá vòm qua sông chỗ đường mòn cắt ngang.
    c = ground_at(*BRIDGE)
    bm = bmesh.new()
    g = bmesh.ops.create_cube(bm, size=1)
    for v in g["verts"]:
        v.co = Vector((c.x + v.co.x * 1.6, c.y + v.co.y * 3.2, 0.15 + v.co.z * 0.35))
    add_object("Bridge", nv.mesh_from("Bridge", bm), [marble])

    # Đền trên đồi giữa.
    tc = ground_at(*TEMPLE)
    nv.temple((tc.x, tc.y - 1.0, height(tc.x, tc.y) - 0.15), 3.2, "map", marble, roof, dark)

    # Vách đá + miệng hang sư tử quay về phía máy quay (−Y).
    cc = ground_at(*CAVE)
    base = height(cc.x, cc.y)
    boxes = [
        ((cc.x - 2.6, cc.y + 1.5, base + 0.6), (3.0, 3.4, 3.2), (0, 3, 8)),
        ((cc.x + 2.6, cc.y + 1.8, base + 0.7), (3.0, 3.6, 3.6), (0, -4, -6)),
        ((cc.x, cc.y + 2.6, base + 2.2), (6.0, 3.0, 1.6), (0, 2, 3)),
        ((cc.x + 5.0, cc.y + 4.0, base + 1.0), (4.0, 5.0, 4.0), (0, 0, 10)),
    ]
    cliff = nv.blob("MapCliff", [], voxel=0.12, smooth_iter=2, rough=0.3, rough_scale=0.9, seed=5, ledges=0.15,
                    boxes=boxes)
    add_object("MapCliff", cliff, [rock])
    add_object("MapCaveMouth", nv.blob("MapCaveMouth", [((cc.x, cc.y + 0.6, base + 0.6), (1.1, 0.4, 1.0))],
                                       voxel=0.08), [dark])

    # Rừng ô liu + bách: rải ngẫu nhiên, tránh đường mòn, sông, điểm màn, đền, hang.
    tree = nv.far_olive("MapOliveTree", (bark, olive))
    rng = random.Random(4)
    placed = 0
    groves = [((30, 210), 40), ((170, 280), 34), ((140, 60), 46), ((60, 110), 30), ((250, 120), 26),
              ((380, 160), 30), ((300, 260), 24)]
    for (gx, gy), r in groves:
        for _ in range(int(r * 1.3)):
            mx = gx + rng.gauss(0, r * 0.5)
            my = gy + rng.gauss(0, r * 0.4)
            if not (4 < mx < MAP_W - 4 and 4 < my < MAP_H - 2):
                continue
            if dist_to(PATH, (mx, my)) < 13 or dist_to(RIVER, (mx, my)) < 12:
                continue
            if math.hypot(mx - TEMPLE[0], my - TEMPLE[1]) < 26 or math.hypot(mx - CAVE[0], my - CAVE[1]) < 34:
                continue
            g = ground_at(mx, my)
            z = height(g.x, g.y)
            o = tree.copy()
            o.hide_render = False
            o.hide_viewport = False
            bpy.context.scene.collection.objects.link(o)
            s = rng.uniform(0.32, 0.45)
            o.location = (g.x, g.y, z - 0.05)
            o.scale = (s, s, s)
            o.rotation_euler = (0, 0, rng.uniform(0, 6.28))
            placed += 1
    for k in range(10):
        mx, my = rng.uniform(20, 380), rng.uniform(20, 280)
        if dist_to(PATH, (mx, my)) < 14 or dist_to(RIVER, (mx, my)) < 12 or math.hypot(mx - CAVE[0], my - CAVE[1]) < 40:
            continue
        g = ground_at(mx, my)
        nv.cypress(f"MapCypress{k}", (g.x, g.y, height(g.x, g.y) - 0.1), rng.uniform(2.6, 3.6), cyp, "map", seed=k)
    print(f"MAP trees={placed}")


def main():
    scene = reset_scene(samples=128)
    nv.sky_world(scene)
    build()
    add_sun(scene, "Sun", (0.55, 0.6, -0.6), 4.0, "#FFE0B4", angle=2.0)
    data = bpy.data.cameras.new("MapCam")
    data.type = "ORTHO"
    data.ortho_scale = WIDTH_M
    data.clip_end = 400
    cam = bpy.data.objects.new("MapCam", data)
    scene.collection.objects.link(cam)
    cam.location = _cam_pos
    cam.rotation_euler = (TILT, 0, 0)
    scene.camera = cam
    scene.render.resolution_x = round(MAP_W * PX)
    scene.render.resolution_y = round(MAP_H * PX)
    scene.render.film_transparent = False
    out = os.path.join(ROOT, "build", "blender", "backdrops")
    os.makedirs(out, exist_ok=True)
    scene.render.filepath = os.path.join(out, "nemea_map.png")
    bpy.ops.render.render(write_still=True)
    save_blend("nemea_map")


main()
