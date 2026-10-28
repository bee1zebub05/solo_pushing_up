"""Hydra non chương 1 (fantasy realism, mini-boss 1.8): rắn nước đầm lầy
Lerna còn non — ba cổ rắn vươn từ khối thân cuộn trên vũng bùn đen, vảy xanh
rêu ánh dầu, bụng vàng đục, mắt vàng rực đồng tử khe, nanh cong, lưỡi chẻ đỏ.
"Chém một, mọc hai": đầu nào bị chém còn lại gốc cụt đỏ.

    bash tool/blender/render.sh hydra --still
    bash tool/blender/render.sh hydra          # hoạt hình + atlas

Toạ độ theo đơn vị vẽ của bản vector (paintYoungHydra, sân khấu ×1,25): gốc
ở mặt đất giữa vòng thân, đầu quay sang trái. Atlas có ba biến thể theo số
đầu còn sống (`idle_h1..3`, `attack_h1..3`); đầu 0 (gần người chơi nhất)
ra đòn.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import paths  # noqa: E402,F401  (kits/, motion/, render/ — rules/dohoa/README.md)
from boss_kit import *  # noqa: E402,F401,F403
from sprite_kit import export_sprites  # noqa: E402

STAGE_SCALE = 1.25
HEADS = 3
# Gốc từng cổ rải trên đỉnh vòng thân (không mọc chung một chỗ).
BASES = [(-24, -40), (-6, -46), (12, -40)]
HEAD_REST = [(-74, -118, -18), (-38, -152, 2), (6, -130, 20)]
HEAD_K = 1.25
FRAME_X = (-150, 90)
FRAME_Y = (-190, 14)


def neck_points(base, head, d, lift=1.0):
    bx, by = base
    hx, hy = head[0], head[1]
    p1 = (bx + (hx - bx) * 0.15 + 6, by + (hy - by) * 0.4 - 4 * lift, d * 0.5)
    p2 = (bx + (hx - bx) * 0.6 + 8, by + (hy - by) * 0.8 - 8 * lift, d * 0.85)
    return [(bx, by, d * 0.3), p1, p2, (hx, hy, d)]


def head_parts(i, mats, parts):
    """Đầu rắn i: sọ dẹt hình thoi, gờ mày nhô, má bạnh (tuyến nọc), mõm tù,
    mắt vàng khe dọc, hàm dưới tách rời, nanh, lưỡi chẻ."""
    hx, hy, d = HEAD_REST[i]
    ang = math.radians(6)
    K = HEAD_K

    def W(x, y, dd=0.0):
        q = rot2((x * K, y * K, 0), (0, 0), ang)
        return (hx + q[0], hy + q[1], d + dd * K)

    def R(*r):
        return tuple(v * K for v in r)

    head = ellipsoids_mesh(f"Head{i}", [
        (W(-6, 0), R(10, 6.5, 9)),
        (W(-17, 1), R(10, 4.6, 6.8), 4),
        (W(-25, 2), R(4.5, 3.6, 5), 6),
        (W(-12, -4.8, -4.5), R(6, 2.2, 2.6), -10),
        (W(-12, -4.8, 4.5), R(6, 2.2, 2.6), -10),
        (W(-1, 2.5, -7), R(7, 5, 3.4)),  # má bạnh
        (W(-1, 2.5, 7), R(7, 5, 3.4)),
        (W(4, 1), R(6, 6, 6.5)),
    ], voxel=0.009, smooth_iter=4)
    parts.append(add_object(f"Head{i}", head, [mats["head"]], f"head{i}"))
    jaw = ellipsoids_mesh(f"Jaw{i}", [(W(-14, 5.5), R(12, 2.4, 5.6), 4), (W(-2, 4.5), R(6, 3.5, 6.4))],
                          voxel=0.009, smooth_iter=4)
    parts.append(add_object(f"Jaw{i}", jaw, [mats["head"]], f"jaw{i}"))
    parts.append(add_object(f"Mouth{i}", uv_ellipsoid(f"Mouth{i}", W(-14, 4), R(10, 2.2, 4.4)), [mats["mouth"]],
                            f"head{i}"))
    for s in (-1, 1):
        parts.append(add_object(f"Eye{i}", uv_ellipsoid(f"Eye{i}", W(-13, -2.2, 5.6 * s), R(2.6, 2.0, 1.3)),
                                [mats["eye"]], f"head{i}"))
        parts.append(add_object(f"Pupil{i}", uv_ellipsoid(f"Pupil{i}", W(-14.2, -2.2, 6.6 * s), R(0.5, 1.7, 0.4)),
                                [mats["pupil"]], f"head{i}"))
    fangs = [(W(-22, 3.6, 2.8 * s), W(-22.5, 6.5, 2.8 * s), W(-21.5, 9, 2.6 * s), 1.0 * K) for s in (-1, 1)]
    fangs += [(W(-14 + k * 3, 4, 3.8 * s), W(-14 + k * 3, 5.5, 3.8 * s), W(-14.5 + k * 3, 6.6, 3.7 * s), 0.5 * K)
              for k in range(3) for s in (-1, 1)]
    parts.append(add_object(f"Fangs{i}", tapered_tubes(f"Fangs{i}", fangs, 6, 4, taper=1.1), [mats["tooth"]],
                            f"head{i}"))
    tongue = [(W(-22, 5, 0), W(-30, 6, 0), W(-36, 8, s * 1.6), 0.8 * K) for s in (-1, 1)]
    parts.append(add_object(f"Tongue{i}", tapered_tubes(f"Tongue{i}", tongue, 6, 4, taper=0.9), [mats["tongue"]],
                            f"jaw{i}"))
    # Vài gai sừng nhỏ sau gáy (Hydra còn non, mào chưa mọc hết).
    spikes = [(W(-2 + k * 4, -5.5), W(k * 4 + 1, -8.5), W(k * 4 + 4, -9.5), (1.0 - k * 0.2) * K) for k in range(3)]
    parts.append(add_object(f"Spikes{i}", tapered_tubes(f"Spikes{i}", spikes, 6, 4, taper=1.0), [mats["horn"]],
                            f"head{i}"))


def build():
    mats = {
        "neck": scales_material("NeckHide", back="#2C4A22", belly="#B8A456", edge="#0A1408",
                                scale_uv=(9, 9), plates=20, belly_band=0.14, metallic=0.25, bump_strength=0.9),
        "body": scales_material("BodyHide", back="#2C4A22", belly="#B8A456", edge="#0A1408",
                                scale_uv=(5, 14), plates=10, belly_band=0.16, metallic=0.25, bump_strength=0.9),
        "head": solid_scales_material("HeadScales", "#30522A", "#0A1408", scale=30, metallic=0.25),
        "horn": skin_material("Horn", "#BFB08A", rough=0.4, noise_scale=40),
        "tooth": skin_material("Tooth", "#EFE6CF", rough=0.35),
        "mouth": skin_material("Mouth", "#5A1218", rough=0.35, sss=0.3),
        "tongue": skin_material("Tongue", "#C0202A", rough=0.3, sss=0.4),
        "eye": glow_material("Eye", "#FFC020", strength=3, base="#C08000"),
        "pupil": skin_material("Pupil", "#050302", rough=0.1),
        "flesh": skin_material("Flesh", "#9A1E22", rough=0.35, sss=0.5),
        "bone": skin_material("Bone", "#E8DCC0", rough=0.5),
        "mud": water_material("Mud", "#1A1A10", rough=0.15),
    }
    bones = {}
    rests = []
    for i in range(HEADS):
        hx, hy, d = HEAD_REST[i]
        pts = neck_points(BASES[i], (hx, hy), d)
        rests.append(pts)
        for k in range(3):
            bones[f"n{i}_{k}"] = (pts[k], pts[k + 1])
        bones[f"head{i}"] = ((hx, hy, d), (hx - 26 * HEAD_K, hy + 3 * HEAD_K, d))
        bones[f"jaw{i}"] = ((hx - 2 * HEAD_K, hy + 4.5 * HEAD_K, d), (hx - 26 * HEAD_K, hy + 8 * HEAD_K, d))
    rig = Rig("HydraRig", bones)

    parts = []
    # ---- thân: hai vòng cuộn trên vũng bùn, đuôi thòi ra phải rồi chìm.
    coil = []
    n = 36
    for k in range(n + 1):
        th = 1.8 * 2 * math.pi * k / n + 0.6
        r = 44 - 16 * k / n
        coil.append((-2 + math.cos(th) * r, -9 - 30 * k / n - 4 * math.sin(th), math.sin(th) * r * 0.6))
    tail = [(78, 4, -14), (64, -3, -26)]
    body_mesh, _ = tube_mesh("Body", tail + coil, lambda t: 3 + 13 * smooth(min(1, t * 3)) - 2 * t,
                             sides=32, samples_per_seg=6, dorsal=(0, -1, 0), flatten=0.92)
    parts.append(add_object("Body", body_mesh, [mats["body"]]))
    # Vũng bùn đen bóng dưới thân (chìm xuống mặt đất).
    add_object("Mud", uv_ellipsoid("Mud", (-4, 1.5, 0), (66, 2.4, 34)), [mats["mud"]])

    for i in range(HEADS):
        pts = rests[i]
        neck_mesh, _ = tube_mesh(f"Neck{i}", pts, lambda t: 8.5 - 3.2 * t, sides=22, samples_per_seg=8,
                                 dorsal=(0.3, -1, 0))
        neck = add_object(f"Neck{i}", neck_mesh, [mats["neck"]])
        rig.skin(neck, [f"n{i}_{k}" for k in range(3)])
        parts.append(neck)
        head_parts(i, mats, parts)
        # Gốc cụt (đầu đã bị chém): nửa dưới cổ + mặt cắt đỏ + đốt sống.
        cut = lerp(pts[1], pts[2], 0.3)
        stub_mesh, _ = tube_mesh(f"Stump{i}", [pts[0], pts[1], cut], lambda t: 8.5 - 2 * t, sides=22,
                                 samples_per_seg=6, dorsal=(0.3, -1, 0))
        stub = add_object(f"Stump{i}", stub_mesh, [mats["neck"]])
        rig.skin(stub, [f"n{i}_0", f"n{i}_1"])
        dx, dy = pts[2][0] - pts[1][0], pts[2][1] - pts[1][1]
        cut_ang = math.degrees(math.atan2(dy, dx))
        cap = add_object(f"Cut{i}", ellipsoids_mesh(f"Cut{i}", [(cut, (1.4, 7.2, 7.2), cut_ang)], voxel=0.008,
                                                    smooth_iter=2), [mats["flesh"]], f"n{i}_1")
        tip = (cut[0] + dx * 0.04, cut[1] + dy * 0.04, cut[2])
        vert = add_object(f"Vert{i}", ellipsoids_mesh(f"Vert{i}", [(tip, (1.2, 2.4, 2.4), cut_ang)], voxel=0.006,
                                                      smooth_iter=2), [mats["bone"]], f"n{i}_1")
        parts += [stub, cap, vert]
    for p in parts:
        if p.vertex_groups:
            rig.bind(p)
    return rig


def set_alive(alive):
    """Đầu i < HEADS − alive đã bị chém (đầu gần người chơi mất trước)."""
    for i in range(HEADS):
        cut = i < HEADS - alive
        for o in bpy.data.objects:
            base = o.name.split(".")[0]
            if base in (f"{n}{i}" for n in ("Neck", "Head", "Jaw", "Mouth", "Eye", "Pupil", "Fangs", "Tongue",
                                            "Spikes")):
                o.hide_render = cut
            if base in (f"{n}{i}" for n in ("Stump", "Cut", "Vert")):
                o.hide_render = not cut


def pose(rig, t=0.0, attack=-1.0, alive=HEADS):
    """Cổ lắc lư lệch pha; đầu sống gần người chơi nhất ra đòn (lấy đà ngóc
    lên, ra đòn mổ xuống tới trước), các đầu khác rít theo."""
    rig.rest()
    windup, strike, recover = attack_pose(attack)
    current = HEADS - alive
    for i in range(HEADS):
        hx, hy, d = HEAD_REST[i]
        ph = t * 2 * math.pi + i * 1.7
        dx = math.sin(ph) * 3.5
        dy = math.cos(ph) * 3
        tilt = math.sin(ph + 1) * 6
        if i == current:
            dx += 14 * windup - 34 * strike - 6 * recover
            dy += -12 * windup + 34 * strike
            tilt += -18 * windup + 22 * strike
        else:
            dx += 4 * windup
            dy += -4 * windup
        head = (hx + dx, hy + dy)
        pts = neck_points(BASES[i], head, d)
        for k in range(3):
            rig.set(f"n{i}_{k}", pts[k], pts[k + 1])
        ang = math.radians(tilt)
        K = HEAD_K
        tip = rot2((head[0] - 26 * K, head[1] + 3 * K, d), head, ang)
        rig.set(f"head{i}", (head[0], head[1], d), (tip[0], tip[1], d))
        opened = max(0.5 * windup, strike) if i == current else 0.15 + 0.12 * math.sin(ph * 1.3)
        j0 = rot2((head[0] - 2 * K, head[1] + 4.5 * K, d), head, ang)
        j1 = rot2((head[0] - 26 * K, head[1] + 8 * K, d), head, ang)
        j1 = rot2(j1, j0, math.radians(-38 * opened))
        rig.set(f"jaw{i}", (j0[0], j0[1], d), (j1[0], j1[1], d))


def lights(scene):
    add_sun(scene, "Key", (0.55, 0.6, -0.6), 4.5, "#FFE0B4", angle=2.5)
    add_sun(scene, "Rim", (0.7, -0.4, -0.35), 4.0, "#B8FFC8", angle=4)
    add_sun(scene, "Bounce", (-0.1, 0.3, 0.9), 0.6, "#A8C080", angle=30)


def main():
    scene = reset_scene(samples=64, world_hex="#9DB6D2", world_strength=0.5)
    rig = build()
    lights(scene)
    out = os.path.join(ROOT, "build", "blender", "greek")
    os.makedirs(out, exist_ok=True)
    if STILL:
        setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=3.4, yaw=-14, pitch=6)
        for name, alive, kw in (("idle", 3, dict(t=0)), ("windup", 3, dict(t=0.2, attack=0.4)),
                                ("strike", 3, dict(t=0.2, attack=0.58)), ("cut1", 2, dict(t=0.5))):
            set_alive(alive)
            pose(rig, alive=alive, **kw)
            render_to(scene, os.path.join(out, f"hydra_{name}.png"))
        set_alive(3)
        pose(rig)
        save_blend("young_hydra")
        return
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=2.9, yaw=-14, pitch=6)
    anims = {}
    for alive in (1, 2, 3):
        def run(alive=alive, **kw):
            set_alive(alive)
            pose(rig, alive=alive, **kw)
        anims[f"idle_h{alive}"] = [lambda k=k, run=run: run(t=k / 4) for k in range(4)]
        anims[f"attack_h{alive}"] = [lambda k=k, run=run: run(t=0.2, attack=k / 5) for k in range(6)]
    export_sprites(scene, cam, "young_hydra", anims, P(0, 0), 50 * STAGE_SCALE, extra={"idlePeriod": 2.8})


main()
