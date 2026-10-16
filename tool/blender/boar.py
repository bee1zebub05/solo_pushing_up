"""Lợn rừng Erymanthus chương 1 (fantasy realism, màn tinh anh 1.5): con lợn
rừng khổng lồ Hercules từng bắt sống, húc đổ từng hàng ô liu. U vai gồ cao
với bờm lông gáy dựng như hàng gai, lông thô đen nâu, cặp nanh ngà cong vểnh
lên, mõm đĩa ướt, mắt nhỏ đỏ ngầu; bốn chân ngắn chắc, móng guốc đen.

    bash tool/blender/render.sh boar --still
    bash tool/blender/render.sh boar           # hoạt hình + atlas

Toạ độ theo đơn vị vẽ của bản vector (paintErymanthianBoar, sân khấu phóng
×1,25): gốc ở mặt đất giữa thân, mặt quay sang trái. Ra đòn theo
`AttackPose`: lấy đà = lùi, cúi đầu, cào chân trước; ra đòn = lao húc, hất
nanh lên. Màn 1.5 dùng nửa đầu chuỗi ra đòn làm "lấy đà" theo `charge`.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403
from sprite_kit import export_sprites  # noqa: E402

STAGE_SCALE = 1.25  # bản vector vẽ ×1,25 trên sân khấu
NEAR, FAR = -15, 15

LEGS = {
    "fl_n": [(-36, -40, NEAR), (-38, -22, NEAR), (-40, -8, NEAR), (-42, 0, NEAR)],
    "fl_f": [(-26, -40, FAR), (-28, -22, FAR), (-30, -8, FAR), (-32, 0, FAR)],
    "bl_n": [(40, -42, NEAR), (48, -24, NEAR), (42, -9, NEAR), (44, 0, NEAR)],
    "bl_f": [(50, -42, FAR), (58, -24, FAR), (52, -9, FAR), (54, 0, FAR)],
}
TAIL = [(62, -56, 0), (68, -50, 0), (70, -42, 0), (69, -35, 0)]
BONES = {
    "body": ((58, -50, 0), (-30, -54, 0)),
    "chest": ((-30, -54, 0), (-42, -34, 0)),
    "neck": ((-34, -56, 0), (-56, -48, 0)),
    "head": ((-56, -48, 0), (-100, -26, 0)),
}
for _leg, _j in LEGS.items():
    BONES[_leg + "_1"] = (_j[0], _j[1])
    BONES[_leg + "_2"] = (_j[1], _j[2])
    BONES[_leg + "_3"] = (_j[2], _j[3])
BONES.update(chain_bones("tail_", TAIL))


def same_side(bone, p):
    if "_n_" in bone and p.y > 0.05:
        return False
    if "_f_" in bone and p.y < -0.05:
        return False
    return True


def build():
    hide = skin_material("BoarHide", "#2A1C14", rough=0.8, noise_scale=30)
    snout_mat = skin_material("Snout", "#3A2622", rough=0.25, sss=0.2)
    nostril = skin_material("Nostril", "#0A0605", rough=0.4)
    tusk_mat = skin_material("Tusk", "#E8DCC0", rough=0.3, noise_scale=60)
    hoof_mat = skin_material("Hoof", "#120C0A", rough=0.35)
    eye_mat = glow_material("BoarEye", "#FF2A10", strength=4, base="#3A0602")
    coat = fur_material("BoarCoat", [(0.0, "#4A3626"), (0.35, "#241810"), (1.0, "#080504")], sheen=-0.05)
    bristle = fur_material("Bristle", [(0.0, "#5A4636"), (0.4, "#1A120C"), (1.0, "#050302")])

    rig = Rig("BoarRig", BONES)
    parts = []

    # ---- thân: u vai đồ sộ dồn về trước, hông hẹp hơn (dáng lợn rừng).
    els = [
        ball(-26, -50, 0, 30, sx=1.15, sy=1.15, sz=0.82),
        ball(-24, -66, 0, 20, sx=1.5, sy=0.75, sz=0.7),  # u vai
        ball(12, -48, 0, 30, sx=1.5, sy=0.95, sz=0.74),
        ball(12, -32, 0, 18, sx=1.8, sy=0.55, sz=0.66),  # bụng
        ball(44, -48, 0, 25, sx=1.0, sy=1.0, sz=0.76),  # mông
        ball(-40, -36, 0, 20, sx=0.9, sy=1.0, sz=0.78),  # ức
    ]
    for leg, j in LEGS.items():
        front = leg.startswith("f")
        r1, r2, r3 = (12, 6.5, 4.8) if front else (14, 6.5, 4.8)
        els.append(ball(*j[0], r1 + 6, sx=1, sy=1.2, sz=0.6))
        els.append(capsule(j[0], j[1], r1))
        els.append(capsule(j[1], j[2], r2))
        els.append(capsule(j[2], lerp(j[2], j[3], 0.6), r3))
    for a, b in zip(TAIL, TAIL[1:]):
        els.append(capsule(a, b, 3.2, stiff=2.5))
    body = add_object("BoarBody", subdivided(metaball_mesh("BoarBody", els)), [hide])
    rig.skin(body, [n for n in BONES if n not in ("head",)], near_filter=same_side)
    with_fur(body, coat, density=30000, length=(0.035, 0.06), radius=0.0032,
             comb=(1.2, 0, -0.8), lift=0.12, gravity=0.01, jitter=0.15, seed=1)
    parts.append(body)

    # ---- đầu: sọ hình nêm dài, mõm thuôn tới đĩa mõm, má bạnh, tai nhọn.
    head = ellipsoids_mesh("BoarHead", [
        ((-58, -48), (19, 17, 14)),
        ((-70, -40), (17, 12, 12), 18),
        ((-84, -33), (15, 8.5, 9), 24),
        ((-96, -27), (8, 6.5, 7), 24),
        ((-62, -36, -10), (11, 9, 5)), ((-62, -36, 10), (11, 9, 5)),  # má bạnh
        ((-54, -64, -9), (4, 9, 3), -30), ((-54, -64, 9), (4, 9, 3), -30),  # tai nhọn
        ((-70, -51, -7), (7, 2.8, 3), -20), ((-70, -51, 7), (7, 2.8, 3), -20),  # gờ mày
    ], voxel=0.012)
    h = add_object("BoarHead", subdivided(head), [hide], "head")
    with_fur(h, coat, density=26000, length=(0.02, 0.04), radius=0.0026,
             comb=(1.2, 0, -0.3), lift=0.15, gravity=0.004, jitter=0.15, seed=2)
    parts.append(h)
    disc = ellipsoids_mesh("Snout", [((-103, -24), (2.6, 6.2, 6.8), 24)], voxel=0.006, smooth_iter=2)
    parts.append(add_object("Snout", disc, [snout_mat], "head"))
    for d in (-2.5, 2.5):
        parts.append(add_object("Nostril", uv_ellipsoid("Nostril", (-105.4, -24, d), (0.8, 1.6, 1.0), 12, 8),
                                [nostril], "head"))
    # Nanh ngà: mọc từ mép mõm, cong vểnh lên và ra sau, nanh dưới mài sắc.
    tusks = []
    for d in (-6.5, 6.5):
        tusks.append(((-88, -26, d), (-100, -34, d * 1.3), (-92, -52, d * 1.5), 3.6))
        tusks.append(((-84, -27, d * 0.9), (-90, -32, d * 1.05), (-88, -39, d * 1.1), 1.8))
    parts.append(add_object("Tusks", tapered_tubes("Tusks", tusks, 10, 8, taper=1.0), [tusk_mat], "head"))
    for d in (-8.5, 8.5):
        parts.append(add_object("Eye", uv_ellipsoid("Eye", (-72, -48, d * 1.05), (2.2, 1.7, 1.3), 14, 10),
                                [eye_mat], "head"))

    # ---- bờm gáy: dải gai lông dựng dọc sống lưng từ gáy tới hông.
    crest = ellipsoids_mesh("Crest", [((-50, -66), (10, 4, 4), -20), ((-30, -76), (16, 4, 4), -5),
                                      ((-8, -74), (16, 4, 4), 5), ((14, -66), (16, 4, 4), 12),
                                      ((34, -62), (12, 3, 3), 8)], voxel=0.01)
    cr = add_object("Crest", crest, [hide])
    rig.skin(cr, ["body", "chest", "neck"])
    with_fur(cr, bristle, density=14000, length=(0.12, 0.26), radius=0.007,
             comb=(0.5, 0, 1.2), lift=1.4, gravity=0.01, jitter=0.12, seed=4)
    parts.append(cr)

    # ---- móng guốc chẻ đôi + móng huyền.
    for leg, j in LEGS.items():
        px, py, pd = j[3]
        hoof = ellipsoids_mesh(leg + "Hoof", [((px - 3, -3, pd - 2.2), (4, 3.4, 2.4), -10),
                                               ((px - 3, -3, pd + 2.2), (4, 3.4, 2.4), -10),
                                               ((px + 3, -8, pd), (2, 2, 3))], voxel=0.006, smooth_iter=2)
        parts.append(add_object(leg + "Hoof", hoof, [hoof_mat], leg + "_3"))

    tx, ty, _ = TAIL[-1]
    tt = add_object("TailTip", ellipsoids_mesh("TailTip", [((tx, ty, 0), (2.5, 4, 2.5))]), [hide],
                    f"tail_{len(TAIL) - 2}")
    with_fur(tt, bristle, density=26000, length=(0.06, 0.12), radius=0.003,
             comb=(0.1, 0, -1.0), lift=0.3, gravity=0.02, jitter=0.3, seed=5)
    parts.append(tt)

    for p in parts:
        rig.bind(p)
    return rig


def pose(rig, t=0.0, attack=-1.0):
    rig.rest()
    breath = math.sin(t * 2 * math.pi) * 0.5 + 0.5
    windup, strike, recover = attack_pose(attack)
    shift = 12 * windup - 34 * strike
    drop = 3 * windup - breath * 1.0
    tilt = math.radians(-5 * windup + 3 * strike)  # lấy đà: hạ vai, chổng mông

    def body_pt(p):
        q = rot2(p, (10, -50), tilt)
        return (q[0] + shift, q[1] + drop, p[2])

    rig.set("body", body_pt(BONES["body"][0]), body_pt(BONES["body"][1]))
    rig.set("chest", body_pt(BONES["chest"][0]), body_pt(BONES["chest"][1]))
    # Đầu: cúi gằm khi lấy đà, hất nanh lên khi húc; khịt mũi nhẹ lúc đứng.
    hb = BONES["head"]
    head_rot = math.radians(14 * windup - 30 * strike + 10 * recover + 2 * math.sin(t * 4 * math.pi))
    h0 = body_pt(hb[0])
    h0 = (h0[0] - 4 * strike, h0[1] + 6 * windup - 4 * strike, 0)
    rig.set("neck", body_pt(BONES["neck"][0]), h0)
    rig.set("head", h0, rot2((h0[0] + hb[1][0] - hb[0][0], h0[1] + hb[1][1] - hb[0][1], 0), h0, head_rot))

    # Chân: chân trước gần cào đất lúc lấy đà; ra đòn chân trước vươn, chân sau đạp.
    scrape = math.sin(windup * math.pi * 3) * windup
    for leg, j in LEGS.items():
        hip = body_pt(j[0])
        paw = list(j[3])
        front = leg.startswith("f")
        if leg == "fl_n":
            paw[0] += 10 * scrape - 14 * strike
            paw[1] -= 6 * max(0.0, scrape) + 10 * strike
        elif front:
            paw[0] -= 8 * strike
        else:
            paw[0] += 4 * windup + 10 * strike
        paw[0] += shift * (0.0 if not front else 0.2)
        ankle = (paw[0] + (j[2][0] - j[3][0]), paw[1] + (j[2][1] - j[3][1]), j[3][2])
        l1 = math.dist(j[1][:2], j[0][:2])
        l2 = math.dist(j[2][:2], j[1][:2])
        knee = two_bone(hip, ankle, l1, l2, -1 if front else 1)
        knee = (knee[0], knee[1], j[0][2])
        rig.set(leg + "_1", (hip[0], hip[1], j[0][2]), knee)
        rig.set(leg + "_2", knee, ankle)
        rig.set(leg + "_3", ankle, tuple(paw))

    prev = body_pt(TAIL[0])
    ang = 0.0
    for i in range(len(TAIL) - 1):
        a, b = TAIL[i], TAIL[i + 1]
        ang += math.radians(14 * math.sin(t * 6 * math.pi + i) + 20 * windup)
        dx, dy = b[0] - a[0], b[1] - a[1]
        c, s = math.cos(ang), math.sin(ang)
        nxt = (prev[0] + dx * c - dy * s, prev[1] + dx * s + dy * c, 0)
        rig.set(f"tail_{i}", prev, nxt)
        prev = nxt


FRAME_X = (-155, 95)
FRAME_Y = (-115, 14)


def lights(scene):
    add_sun(scene, "Key", (0.55, 0.6, -0.6), 5.0, "#FFE0B4", angle=2.5)
    add_sun(scene, "Rim", (0.7, -0.4, -0.35), 4.0, "#FFC890", angle=4)
    add_sun(scene, "Bounce", (-0.1, 0.3, 0.9), 0.6, "#C8A880", angle=30)


def shadow_floor():
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=8)
    mesh = bpy.data.meshes.new("Floor")
    bm.to_mesh(mesh)
    bm.free()
    floor = add_object("Floor", mesh, [], smooth_shade=False)
    floor.is_shadow_catcher = True


def main():
    scene = reset_scene(samples=64, world_hex="#9DB6D2", world_strength=0.5)
    rig = build()
    lights(scene)
    shadow_floor()
    out = os.path.join(ROOT, "build", "blender", "greek")
    os.makedirs(out, exist_ok=True)
    if STILL:
        setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=4.0, yaw=-14, pitch=6)
        for name, kw in (("idle", dict(t=0)), ("windup", dict(t=0.2, attack=0.4)),
                         ("strike", dict(t=0.2, attack=0.58))):
            pose(rig, **kw)
            render_to(scene, os.path.join(out, f"boar_{name}.png"))
        pose(rig, 0)
        save_blend("erymanthian_boar")
        return
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=3.4, yaw=-14, pitch=6)
    anims = {
        "idle": [lambda k=k: pose(rig, k / 6) for k in range(6)],
        "attack": [lambda k=k: pose(rig, 0.2, attack=k / 9) for k in range(10)],
    }
    export_sprites(scene, cam, "erymanthian_boar", anims, P(0, 0), 50 * STAGE_SCALE, extra={"idlePeriod": 2.2})


main()
