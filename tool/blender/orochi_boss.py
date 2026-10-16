"""Kỳ công 5 — Yamata no Orochi (fantasy realism), cảm hứng từ tranh đã hết
bản quyền: Tsukioka Yoshitoshi "Susanoo no Mikoto slays Yamata no Orochi in
Izumo" (1887), tranh bộ ba khoảng 1870 (Commons: YamataNoOrochi.jpg), Torii
Kiyomasu II (1748, CC0) — đầu rồng-rắn xanh sẫm, lưỡi đỏ, giữa sóng dữ. Chi
tiết theo Kojiki: mắt đỏ như quả anh đào mùa đông, bụng đỏ rỉ máu, rêu và
cây bách, tuyết tùng mọc trên lưng.

    bash tool/blender/render.sh orochi_boss --still
    bash tool/blender/render.sh orochi_boss

Gốc toạ độ: điểm (330, 220) của sân khấu. Đầu 0 thấp và gần người chơi nhất,
bị chém trước (như lib/art/bosses/orochi_boss.dart).
"""

import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403

HEADS = 8
BASE = (0, -26)  # gốc các cổ trên đỉnh thân (đơn vị vẽ, so với gốc)
FRAME_X = (-178, 130)
FRAME_Y = (-178, 18)


def neck_layout(i):
    """Hướng, độ dài cổ, chiều sâu của đầu i (cùng bố cục bản vector)."""
    a = math.pi * (1.05 + 0.62 * i / (HEADS - 1))
    length = 92 + (i % 3) * 14
    depth = -22 + i * 6.5
    return a, length, depth


def head_rest(i):
    a, length, d = neck_layout(i)
    return (BASE[0] + math.cos(a) * length, BASE[1] + math.sin(a) * length * 0.9, d)


def neck_points(base, head, d, lift=1.0):
    """4 điểm điều khiển cổ: gốc → vồng lên → gần đầu → đầu."""
    bx, by = base
    hx, hy = head[0], head[1]
    p1 = (bx + (hx - bx) * 0.3, by + (hy - by) * 0.45 - 10 * lift, d * 0.6)
    p2 = (bx + (hx - bx) * 0.7, by + (hy - by) * 0.85 - 6 * lift, d * 0.9)
    return [(bx, by, d * 0.3), p1, p2, (hx, hy, d)]


HEAD_K = 1.6  # đầu to hơn hẳn cổ (đọc được từ xa, như tranh ukiyo-e)


def head_parts(i, mats, rig, parts):
    """Đầu rồng-rắn i: sọ, mõm, gờ mày, mào gai, sừng, mắt đỏ, hàm, lưỡi chẻ.
    Dựng theo hệ toạ độ đầu (gáy ở gốc, mõm hướng −x) rồi đặt vào chỗ."""
    hx, hy, d = head_rest(i)
    ang = math.radians(8)  # mõm hơi chúi xuống
    K = HEAD_K

    def W(x, y, dd=0.0):
        q = rot2((x * K, y * K, 0), (0, 0), ang)
        return (hx + q[0], hy + q[1], d + dd * K)

    def R(*r):
        return tuple(v * K for v in r)

    head = ellipsoids_mesh(f"Head{i}", [
        (W(-6, 0), R(10, 7.5, 8.5)),
        (W(-19, 1.5), R(11, 5, 6.5), 4),
        (W(-27, 2.5), R(5, 4, 5.5), 6),  # chóp mõm vuông
        (W(-12, -5.5, -4), R(6, 2.4, 2.8), -8),
        (W(-12, -5.5, 4), R(6, 2.4, 2.8), -8),
        (W(-4, 3, -6), R(6, 5, 3)),  # gò má
        (W(-4, 3, 6), R(6, 5, 3)),
        (W(1, 2), R(7, 7, 7)),
    ], voxel=0.01, smooth_iter=4)
    parts.append(add_object(f"Head{i}", head, [mats["head"]], f"head{i}"))
    jaw = ellipsoids_mesh(f"Jaw{i}", [(W(-15, 6.5), R(13, 2.8, 5.5), 4), (W(-4, 5), R(6, 4, 6))], voxel=0.01, smooth_iter=4)
    parts.append(add_object(f"Jaw{i}", jaw, [mats["head"]], f"jaw{i}"))
    parts.append(add_object(f"Mouth{i}", uv_ellipsoid(f"Mouth{i}", W(-16, 4.5), R(11, 2.5, 4.5)), [mats["mouth"]], f"head{i}"))
    horns = []
    for s in (-1, 1):
        horns.append((W(-8, -6, 4 * s), W(2, -13, 6 * s), W(12, -12, 8 * s), 1.8 * K))
        horns.append((W(-4, 3, 6 * s), W(4, 6, 8 * s), W(10, 10, 9 * s), 1.0 * K))  # râu cằm
        horns.append((W(-2, 1, 7 * s), W(6, 0, 10 * s), W(12, 3, 12 * s), 0.8 * K))  # vây má
    # Mào gai dọc đỉnh đầu ra sau gáy.
    for k in range(4):
        x = -10 + k * 4.5
        horns.append((W(x, -6.5), W(x + 2, -10 - k * 0.5), W(x + 5, -11 - k * 0.6), (1.2 - k * 0.15) * K))
    parts.append(add_object(f"Horns{i}", tapered_tubes(f"Horns{i}", horns, 7, 6, taper=1.0), [mats["horn"]], f"head{i}"))
    for s in (-1, 1):
        parts.append(add_object(f"Eye{i}", uv_ellipsoid(f"Eye{i}", W(-14, -2.5, 6 * s), R(2.6, 1.8, 1.2)), [mats["eye"]], f"head{i}"))
    teeth = [(W(-26 + k * 3.5, 4.5, 3.2 * s), W(-26 + k * 3.5, 6.5, 3.2 * s), W(-27 + k * 3.5, 8.5, 3 * s), 0.9 * K)
             for k in range(4) for s in (-1, 1)]
    parts.append(add_object(f"Teeth{i}", tapered_tubes(f"Teeth{i}", teeth, 5, 3, taper=1.1), [mats["tooth"]], f"head{i}"))
    tongue = [(W(-24, 6, 0), W(-32, 7, 0), W(-38, 9, s * 1.5), 1.0 * K) for s in (-1, 1)]
    parts.append(add_object(f"Tongue{i}", tapered_tubes(f"Tongue{i}", tongue, 6, 4, taper=0.9), [mats["tongue"]], f"jaw{i}"))


def build():
    mats = {
        # Xanh ngọc bích sẫm ánh kim (rồng xanh tranh ukiyo-e), bụng đỏ thẫm (Kojiki).
        "neck": scales_material("Hide", back="#1C6A5A", belly="#A3202A", edge="#03110D",
                                scale_uv=(9, 9), plates=20, belly_band=0.14, metallic=0.35, bump_strength=0.9),
        "body": scales_material("BodyHide", back="#1C6A5A", belly="#A3202A", edge="#03110D",
                                scale_uv=(5, 14), plates=10, belly_band=0.16, metallic=0.35, bump_strength=0.9),
        "head": solid_scales_material("HeadScales", "#1E705E", "#03110D", scale=26, metallic=0.35),
        "horn": skin_material("Horn", "#D8C79A", rough=0.4, noise_scale=40),
        "tooth": skin_material("Tooth", "#EFE6CF", rough=0.35),
        "mouth": skin_material("Mouth", "#4A0A10", rough=0.35, sss=0.3),
        "tongue": skin_material("Tongue", "#C0202A", rough=0.3, sss=0.4),
        "eye": glow_material("Eye", "#FF3020", strength=7, base="#600000"),
        "flesh": skin_material("Flesh", "#9A1E22", rough=0.35, sss=0.5),
        "bone": skin_material("Bone", "#E8DCC0", rough=0.5),
    }

    bones = {}
    rests = []
    for i in range(HEADS):
        hx, hy, d = head_rest(i)
        pts = neck_points(BASE, (hx, hy), d)
        rests.append(pts)
        for k in range(3):
            bones[f"n{i}_{k}"] = (pts[k], pts[k + 1])
        bones[f"head{i}"] = ((hx, hy, d), (hx - 26 * HEAD_K, hy + 4 * HEAD_K, d))
        bones[f"jaw{i}"] = ((hx - 2 * HEAD_K, hy + 5 * HEAD_K, d), (hx - 28 * HEAD_K, hy + 9 * HEAD_K, d))
    rig = Rig("OrochiRig", bones)

    parts = []
    # ---- thân: ba vòng thân rắn khổng lồ cuộn chồng, đuôi thòi ra bên phải
    coil = []
    turns = 2.2
    n = 44
    for k in range(n + 1):
        th = turns * 2 * math.pi * k / n + 0.4
        r = 70 - 26 * k / n
        coil.append((14 + math.cos(th) * r, -12 - 58 * k / n - 6 * math.sin(th), math.sin(th) * r * 0.6))
    tail = [(120, -4, -20), (100, -6, -36)]
    body_mesh, body_curve = tube_mesh("Body", tail + coil, lambda t: 4 + 18 * smooth(min(1, t * 3)) - 4 * t,
                                      sides=36, samples_per_seg=6, dorsal=(0, -1, 0), flatten=0.95)
    body = add_object("Body", body_mesh, [mats["body"]])
    parts.append(body)
    # Bách / tuyết tùng nhỏ mọc trên lưng (cây nón nhiều tầng).
    rng = np.random.default_rng(5)
    tree_mat = skin_material("Cedar", "#1F3318", rough=0.8, noise_scale=60)
    trunk_mat = skin_material("Trunk", "#3A2A1C", rough=0.9)
    trees, trunks = [], []
    for k in range(14):
        j = int(rng.integers(len(body_curve) // 3, len(body_curve) - 2))
        c = body_curve[j]
        h = rng.uniform(16, 30)
        top = (c[0] + rng.uniform(-3, 3), c[1] - 15 - h, c[2])
        trunks.append(((c[0], c[1] - 14, c[2]), (c[0], c[1] - 14 - h * 0.3, c[2]), top, 1.4))
        for tier in range(4):
            y0 = c[1] - 18 - h * tier * 0.22
            w = (4 - tier) * 2.6
            trees.append(((c[0], y0, c[2]), (c[0], y0 - h * 0.2, c[2]), (top[0], y0 - h * 0.42, top[2]), w))
    parts.append(add_object("Trees", tapered_tubes("Trees", trees, 9, 4, taper=1.0), [tree_mat]))
    parts.append(add_object("Trunks", tapered_tubes("Trunks", trunks, 6, 3, taper=0.6), [trunk_mat]))

    # ---- 8 cổ + đầu; mỗi cổ có bản "đã chém" (gốc cụt, mặt cắt đỏ, đốt sống)
    for i in range(HEADS):
        pts = rests[i]
        neck_mesh, _ = tube_mesh(f"Neck{i}", pts, lambda t: 10 - 3.5 * t, sides=22, samples_per_seg=8,
                                 dorsal=(0.3, -1, 0))
        neck = add_object(f"Neck{i}", neck_mesh, [mats["neck"]])
        rig.skin(neck, [f"n{i}_{k}" for k in range(3)])
        parts.append(neck)
        # Hàng gai nhỏ dọc sống cổ.
        nc = catmull(pts, 8)
        fins = []
        for j in range(3, len(nc) - 3, 2):
            tan = (nc[j + 1] - nc[j - 1]).normalized()
            up = Vector((0.3, -1, 0))
            up = (up - tan * up.dot(tan)).normalized()
            r = 10 - 3.5 * j / len(nc)
            b0 = nc[j] + up * r * 0.85
            fins.append((tuple(b0), tuple(b0 + up * 2.5 - tan * 1.5), tuple(b0 + up * 4.5 - tan * 4), 1.4))
        fo = add_object(f"Fins{i}", tapered_tubes(f"Fins{i}", fins, 5, 3, flat=0.6, taper=1.0), [mats["horn"]])
        rig.skin(fo, [f"n{i}_{k}" for k in range(3)])
        parts.append(fo)
        head_parts(i, mats, rig, parts)
        # Gốc cụt: nửa dưới cổ + nắp thịt đỏ, vành da, đốt sống trắng.
        cut = lerp(pts[1], pts[2], 0.4)
        stub_mesh, _ = tube_mesh(f"Stump{i}", [pts[0], pts[1], cut], lambda t: 10 - 2.2 * t, sides=22,
                                 samples_per_seg=6, dorsal=(0.3, -1, 0))
        stub = add_object(f"Stump{i}", stub_mesh, [mats["neck"]])
        rig.skin(stub, [f"n{i}_0", f"n{i}_1"])
        # Mặt cắt: đĩa dẹt vuông góc với hướng cổ tại chỗ chém.
        dx, dy = pts[2][0] - pts[1][0], pts[2][1] - pts[1][1]
        cut_ang = math.degrees(math.atan2(dy, dx))
        cap = add_object(f"Cut{i}", ellipsoids_mesh(f"Cut{i}", [(cut, (1.6, 8.4, 8.4), cut_ang)], voxel=0.008, smooth_iter=2),
                         [mats["flesh"]], f"n{i}_1")
        tip = (cut[0] + dx * 0.04, cut[1] + dy * 0.04, cut[2])
        bone_ = add_object(f"Vert{i}", ellipsoids_mesh(f"Vert{i}", [(tip, (1.4, 2.8, 2.8), cut_ang)], voxel=0.006, smooth_iter=2),
                           [mats["bone"]], f"n{i}_1")
        parts += [stub, cap, bone_]
    for p in parts:
        if any(g.name in rig.bones for g in p.vertex_groups) or p.vertex_groups:
            rig.bind(p)

    # Vò rượu sake sơn đỏ (Susanoo bày 8 vò để Orochi say) phía trước thân.
    lacquer = skin_material("Lacquer", "#8E1A14", rough=0.25)
    rim = skin_material("Rope", "#C8B07A", rough=0.8)
    for k, (x, d) in enumerate([(-100, -34), (-76, -48), (70, -54)]):
        vat, _ = tube_mesh(f"Vat{k}", [(x, 0, d), (x, -10, d), (x, -20, d)], lambda t: 10 + 1.8 * math.sin(math.pi * t),
                           sides=32, samples_per_seg=6, dorsal=(1, 0, 0))
        add_object(f"Vat{k}", vat, [lacquer])
        for yy in (-4, -16):
            add_object(f"VatRope{k}", uv_ellipsoid(f"VatRope{k}", (x, yy, d), (11.6, 0.9, 11.6)), [rim])
        add_object(f"Sake{k}", uv_ellipsoid(f"Sake{k}", (x, -19.4, d), (9.4, 0.5, 9.4)), [water_material("Sake", "#E8D8B0")])
    return rig


def set_severed(count, defeated=False):
    """Đầu < count đã bị chém: ẩn cổ + đầu, hiện gốc cụt."""
    for i in range(HEADS):
        cut = i < count or defeated
        for name in ("Neck", "Fins", "Head", "Jaw", "Mouth", "Horns", "Eye", "Teeth", "Tongue"):
            for o in bpy.data.objects:
                if o.name == f"{name}{i}" or o.name.startswith(f"{name}{i}."):
                    o.hide_render = cut
        for name in ("Stump", "Cut", "Vert"):
            bpy.data.objects[f"{name}{i}"].hide_render = not cut


def pose(rig, t=0.0, attack=-1.0, defeat=0.0, current=0):
    """Mỗi đầu lắc lư lệch pha; đầu [current] (đang bị chém) ra đòn 3 pha,
    các đầu khác ngóc theo; gục thì các cổ đổ rạp."""
    rig.rest()
    windup, strike, recover = attack_pose(attack)
    fall = smooth(defeat)
    for i in range(HEADS):
        hx, hy, d = head_rest(i)
        ph = t * 2 * math.pi + i * 0.9
        dx = math.sin(ph) * 4
        dy = math.cos(ph * 0.8) * 3
        tilt = math.sin(ph + 1) * 5
        if i == current:
            dx += 16 * windup - 32 * strike - 6 * recover
            dy += -14 * windup + 20 * strike
            tilt += -16 * windup + 18 * strike
        else:
            dx += 5 * windup
            dy += -5 * windup
        # Gục: các cổ đổ rạp qua vòng thân trước, đầu nằm trên đất phía trước.
        ground = (hx * 0.9 - 30 + 8 * i, -8 - 3 * (i % 2))
        head = (hx + dx + (ground[0] - hx - dx) * fall, hy + dy + (ground[1] - hy - dy) * fall)
        d = d - 50 * fall
        pts = neck_points(BASE, head, d, lift=1 + 2 * fall)
        for k in range(3):
            rig.set(f"n{i}_{k}", pts[k], pts[k + 1])
        ang = math.radians(tilt + 25 * fall)
        K = HEAD_K
        tip = rot2((head[0] - 26 * K, head[1] + 4 * K, d), (head[0], head[1]), ang)
        rig.set(f"head{i}", (head[0], head[1], d), (tip[0], tip[1], d))
        opened = (max(0.4 * windup, strike) if i == current else 0.1 + 0.08 * math.sin(ph)) + 0.25 * fall
        j0 = rot2((head[0] - 2 * K, head[1] + 5 * K, d), (head[0], head[1]), ang)
        j1 = rot2((head[0] - 28 * K, head[1] + 9 * K, d), (head[0], head[1]), ang)
        j1 = rot2(j1, j0, math.radians(-32 * opened))
        rig.set(f"jaw{i}", (j0[0], j0[1], d), (j1[0], j1[1], d))


def lights(scene):
    # Hoàng hôn đỏ cam sau lưng (tranh Yoshitoshi), ánh trăng lạnh phía trước.
    add_sun(scene, "Key", (0.7, 0.55, -0.5), 4.5, "#DCE4FF")
    add_sun(scene, "Sunset", (-0.7, -0.8, -0.2), 6.0, "#FF7A3A", angle=2)
    add_point(scene, "EyeGlow", (-40, -80, -40), 60, "#FF4020", radius=1.5)


def main():
    scene = reset_scene(samples=64, world_hex="#4A3A5A", world_strength=0.4)
    rig = build()
    lights(scene)
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=1.8)
    anchor, ppu = anchor_info(scene, cam)
    print(f"OROCHI anchor={tuple(round(c, 1) for c in anchor)} ppu={ppu:.3f}")
    out = os.path.join(ROOT, "build", "blender", "orochi")
    if STILL:
        def still(sev, **kw):
            def run():
                set_severed(sev)
                pose(rig, current=sev, **kw)
            return run
        render_stills(scene, out, [
            ("idle", still(0, t=0)),
            ("windup", still(0, t=0.25, attack=0.45)),
            ("strike", still(0, t=0.25, attack=0.6)),
            ("cut3", still(3, t=0.5)),
            ("defeat", still(0, t=0.25, defeat=1)),
        ])
        set_severed(0)
        pose(rig, 0)
        save_blend("orochi")
        return
    # Bản đầy đủ: lớp thân + từng cổ (xem lib/art/sprite_sheet.dart) — làm ở bước tích hợp.
    raise SystemExit("Chưa có chế độ render atlas cho Orochi: chạy với --still")


main()
