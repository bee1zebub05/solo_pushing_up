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

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import paths  # noqa: E402,F401  (kits/, motion/, render/ — rules/dohoa/README.md)
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


def neck_points(base, head, d, lift=1.0, wave=0.0):
    """4 điểm điều khiển cổ: gốc → vồng lên → gần đầu → đầu. [wave] uốn cổ
    thành chữ S (lệch vuông góc ngược chiều ở hai điểm giữa), các cổ quấn
    lẫn nhau như tranh tham khảo."""
    bx, by = base
    hx, hy = head[0], head[1]
    L = math.hypot(hx - bx, hy - by) or 1
    nx, ny = -(hy - by) / L, (hx - bx) / L
    w = wave * L * 0.22
    p1 = (bx + (hx - bx) * 0.3 + nx * w, by + (hy - by) * 0.45 - 10 * lift + ny * w, d * 0.6)
    p2 = (bx + (hx - bx) * 0.7 - nx * w, by + (hy - by) * 0.85 - 6 * lift - ny * w, d * 0.9)
    return [(bx, by, d * 0.3), p1, p2, (hx, hy, d)]


def wave_of(i):
    return (0.9, -0.7, 0.6, -1.0, 0.8, -0.6, 1.0, -0.8)[i]


HEAD_K = 1.1  # đầu rắn thon, to hơn cổ vừa đủ đọc từ xa


def head_parts(i, mats, rig, parts):
    """Đầu rắn i theo tranh tham khảo (rắn tám đầu dưới trăng lưỡi liềm): sọ
    hình nêm dẹt, mõm tròn, gờ mày che mắt vàng con ngươi dọc, môi và hàm
    dưới trắng ngà, nanh dài, lưỡi chẻ hồng. Không sừng, không gai.
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
        (W(-5, 0.4), R(9, 4.6, 6.6)),  # gáy rộng (cơ hàm)
        (W(-14, 0.8), R(9, 3.8, 5.6), 3),
        (W(-22, 1.6), R(5, 3.0, 4.0), 5),  # mõm tròn
        (W(-12, -2.8, -4.0), R(5, 1.5, 2.4), -6),  # gờ mày
        (W(-12, -2.8, 4.0), R(5, 1.5, 2.4), -6),
        (W(2, 1), R(5, 4.4, 5.2)),  # nối vào cổ
    ], voxel=0.008, smooth_iter=5)
    parts.append(add_object(f"Head{i}", head, [mats["head"]], f"head{i}"))
    lip = ellipsoids_mesh(f"Lip{i}", [(W(-14, 3.0), R(10, 1.3, 5.4), 4), (W(-22, 3.2), R(4.2, 1.2, 3.4), 5)],
                          voxel=0.008, smooth_iter=3)
    parts.append(add_object(f"Lip{i}", lip, [mats["lip"]], f"head{i}"))
    jaw = ellipsoids_mesh(f"Jaw{i}", [(W(-13, 5.0), R(11, 1.6, 5.0), 4), (W(-3, 4.4), R(5.5, 2.6, 5.4))],
                          voxel=0.008, smooth_iter=4)
    parts.append(add_object(f"Jaw{i}", jaw, [mats["lip"]], f"jaw{i}"))
    # Lòng miệng hồng: vòm trên theo sọ, nền lưỡi theo hàm — há ra là thấy.
    parts.append(add_object(f"Mouth{i}", uv_ellipsoid(f"Mouth{i}", W(-14, 3.9), R(10, 1.4, 4.4)), [mats["mouth"]],
                            f"head{i}"))
    parts.append(add_object(f"Gullet{i}", uv_ellipsoid(f"Gullet{i}", W(-13, 4.1), R(10, 1.3, 4.2)), [mats["mouth"]],
                            f"jaw{i}"))
    for s in (-1, 1):
        # Mắt tròn to vàng, viền trắng ngà, con ngươi đen tròn (như tranh).
        parts.append(add_object(f"EyeRing{i}", uv_ellipsoid(f"EyeRing{i}", W(-13.5, -1.4, 4.2 * s), R(3.0, 2.8, 1.4)),
                                [mats["lip"]], f"head{i}"))
        parts.append(add_object(f"Eye{i}", uv_ellipsoid(f"Eye{i}", W(-13.5, -1.4, 4.9 * s), R(2.4, 2.3, 1.2)),
                                [mats["eye"]], f"head{i}"))
        parts.append(add_object(f"Pupil{i}", uv_ellipsoid(f"Pupil{i}", W(-14.0, -1.4, 5.85 * s), R(0.9, 0.9, 0.5)),
                                [mats["pupil"]], f"head{i}"))
        parts.append(add_object(f"Nostril{i}", uv_ellipsoid(f"Nostril{i}", W(-25.5, 0.6, 1.8 * s), R(0.7, 0.5, 0.5)),
                                [mats["pupil"]], f"head{i}"))
    # Hai nanh dài cong ở mõm trên, hàng răng nhỏ dọc hàm.
    fangs = [(W(-21.5, 3.4, 2.4 * s), W(-22, 6.2, 2.5 * s), W(-20.5, 8.6, 2.3 * s), 0.8 * K) for s in (-1, 1)]
    fangs += [(W(-17.5 + k * 3.0, 3.6, 3.3 * s), W(-17.5 + k * 3.0, 4.6, 3.3 * s), W(-18 + k * 3.0, 5.5, 3.2 * s), 0.38 * K)
              for k in range(4) for s in (-1, 1)]
    parts.append(add_object(f"Teeth{i}", tapered_tubes(f"Teeth{i}", fangs, 5, 3, taper=1.1), [mats["tooth"]],
                            f"head{i}"))
    tongue = [(W(-18, 4.6, 0), W(-27, 5.6, 0), W(-33, 7.5, s * 1.8), 0.6 * K) for s in (-1, 1)]
    parts.append(add_object(f"Tongue{i}", tapered_tubes(f"Tongue{i}", tongue, 6, 4, taper=0.9), [mats["tongue"]],
                            f"jaw{i}"))


def build():
    mats = {
        # Theo tranh tham khảo: lưng xanh xám bạc, bụng vảy hồng phấn, mắt vàng.
        "neck": scales_material("Hide", back="#9AA890", belly="#E3A69E", edge="#2E3A2E",
                                scale_uv=(7, 7), plates=22, belly_band=0.2, metallic=0.05, rough=0.5,
                                bump_strength=0.8),
        "body": scales_material("BodyHide", back="#8E9C84", belly="#DE9C94", edge="#2A3428",
                                scale_uv=(4, 9), plates=10, belly_band=0.2, metallic=0.05, rough=0.5,
                                bump_strength=0.8),
        "head": solid_scales_material("HeadScales", "#A8B69E", "#56644E", scale=14, metallic=0.05),
        "lip": skin_material("Lip", "#E6E4D6", rough=0.5, noise_scale=30),
        "tooth": skin_material("Tooth", "#F4EEDC", rough=0.3),
        "mouth": skin_material("Mouth", "#B8545C", rough=0.35, sss=0.3),
        "tongue": skin_material("Tongue", "#E07A88", rough=0.3, sss=0.4),
        "eye": glow_material("Eye", "#F2CC40", strength=1.6, base="#E8C030"),
        "pupil": skin_material("Pupil", "#0A0806", rough=0.1),
        "gold": glow_material("GoldLeaf", "#FFD860", strength=2.5, base="#F0C040"),
        "flesh": skin_material("Flesh", "#9A1E22", rough=0.35, sss=0.5),
        "bone": skin_material("Bone", "#E8DCC0", rough=0.5),
    }

    bones = {}
    rests = []
    for i in range(HEADS):
        hx, hy, d = head_rest(i)
        pts = neck_points(BASE, (hx, hy), d, wave=wave_of(i))
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
    # ---- 8 cổ + đầu; mỗi cổ có bản "đã chém" (gốc cụt, mặt cắt đỏ, đốt sống)
    for i in range(HEADS):
        pts = rests[i]
        neck_mesh, _ = tube_mesh(f"Neck{i}", pts, lambda t: 7.5 - 2.5 * t, sides=22, samples_per_seg=8,
                                 dorsal=(0.3, -1, 0))
        neck = add_object(f"Neck{i}", neck_mesh, [mats["neck"]])
        rig.skin(neck, [f"n{i}_{k}" for k in range(3)])
        parts.append(neck)
        head_parts(i, mats, rig, parts)
        # Gốc cụt: nửa dưới cổ + nắp thịt đỏ, vành da, đốt sống trắng.
        cut = lerp(pts[1], pts[2], 0.4)
        stub_mesh, _ = tube_mesh(f"Stump{i}", [pts[0], pts[1], cut], lambda t: 7.5 - 1.6 * t, sides=22,
                                 samples_per_seg=6, dorsal=(0.3, -1, 0))
        stub = add_object(f"Stump{i}", stub_mesh, [mats["neck"]])
        rig.skin(stub, [f"n{i}_0", f"n{i}_1"])
        # Mặt cắt: đĩa dẹt vuông góc với hướng cổ tại chỗ chém.
        dx, dy = pts[2][0] - pts[1][0], pts[2][1] - pts[1][1]
        cut_ang = math.degrees(math.atan2(dy, dx))
        cap = add_object(f"Cut{i}", ellipsoids_mesh(f"Cut{i}", [(cut, (1.4, 6.6, 6.6), cut_ang)], voxel=0.008, smooth_iter=2),
                         [mats["flesh"]], f"n{i}_1")
        tip = (cut[0] + dx * 0.04, cut[1] + dy * 0.04, cut[2])
        bone_ = add_object(f"Vert{i}", ellipsoids_mesh(f"Vert{i}", [(tip, (1.4, 2.8, 2.8), cut_ang)], voxel=0.006, smooth_iter=2),
                           [mats["bone"]], f"n{i}_1")
        parts += [stub, cap, bone_]
    for p in parts:
        if any(g.name in rig.bones for g in p.vertex_groups) or p.vertex_groups:
            rig.bind(p)

    # Vảy vàng lá lấp lánh quanh các cổ (như vàng rắc trên tranh).
    rng = np.random.default_rng(8)
    for k in range(22):
        x, y, z = rng.uniform(-140, 40), rng.uniform(-160, -40), rng.uniform(10, 40)
        r = rng.uniform(1.0, 1.8)
        add_object(f"Gold{k}", uv_ellipsoid(f"Gold{k}", (x, y, z), (r, r * 0.7, r * 0.3), segments=8, rings=5),
                   [mats["gold"]])

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
        for name in ("Neck", "Head", "Lip", "Jaw", "Mouth", "Gullet", "EyeRing", "Eye", "Pupil", "Nostril", "Teeth",
                     "Tongue"):
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
        tilt = math.sin(ph + 1) * 5 + (-6, 14, -22, 8, -30, 18, -12, 24)[i]  # mỗi đầu ngoảnh một kiểu
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
        pts = neck_points(BASE, head, d, lift=1 + 2 * fall, wave=wave_of(i) * (1 - fall))
        for k in range(3):
            rig.set(f"n{i}_{k}", pts[k], pts[k + 1])
        ang = math.radians(tilt + 25 * fall)
        K = HEAD_K
        tip = rot2((head[0] - 26 * K, head[1] + 4 * K, d), (head[0], head[1]), ang)
        rig.set(f"head{i}", (head[0], head[1], d), (tip[0], tip[1], d))
        gape = (0.15, 0.9, 0.2, 1.0, 0.1, 0.7, 0.25, 0.85)[i]  # vài đầu há rộng nhe nanh như tranh
        opened = (max(0.4 * windup, strike) if i == current else gape + 0.08 * math.sin(ph)) + 0.25 * fall
        j0 = rot2((head[0] - 2 * K, head[1] + 5 * K, d), (head[0], head[1]), ang)
        j1 = rot2((head[0] - 28 * K, head[1] + 9 * K, d), (head[0], head[1]), ang)
        j1 = rot2(j1, j0, math.radians(-40 * opened))
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
