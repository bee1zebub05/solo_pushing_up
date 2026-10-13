"""Kỳ công 1 — Sư tử Nemea (fantasy realism): mãnh thú thần thoại da vàng
không vũ khí nào xuyên thủng, thớ cơ cuồn cuộn, mình đầy sẹo của những kẻ
từng thử giết nó, ánh mắt hổ phách sắc lẹm. Lông thật (hair curves), sẹo
trụi lông, render thành sprite cho sân khấu Flutter.

    bash tool/blender/render.sh lion_nemea --still    # vài khung xem nhanh
    bash tool/blender/render.sh lion_nemea            # hoạt hình + atlas

Toạ độ theo đơn vị vẽ của bản vector (lib/art/lion_art.dart): gốc ở mặt đất
giữa thân, mặt quay sang trái; sân khấu đặt tại (lionX, stageGroundY) và
phóng lionScale. Tư thế dùng cùng công thức với paintLion() để sprite khớp
nhịp đòn (attackPhase, defeat).
"""

import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403

HEAD = (-74, -104)
NEAR, FAR = -24, 24  # chiều sâu chân gần / xa máy quay
K = 1.18  # đầu to hơn tỉ lệ thật một chút cho dễ đọc từ xa (như bản vector)

# Khớp nghỉ (rest) của chân: vai/hông → khuỷu/gối → cổ chân → bàn.
LEGS = {
    "fl_n": [(-46, -82, NEAR), (-46, -46, NEAR), (-54, -16, NEAR), (-62, -2, NEAR)],
    "fl_f": [(-30, -86, FAR), (-30, -48, FAR), (-38, -16, FAR), (-46, -2, FAR)],
    "bl_n": [(76, -86, NEAR), (60, -54, NEAR), (86, -32, NEAR), (78, -2, NEAR)],
    "bl_f": [(64, -88, FAR), (48, -56, FAR), (74, -32, FAR), (66, -2, FAR)],
}
TAIL = [(96, -98, 0), (114, -84, 0), (130, -88, 0), (140, -106, 0), (144, -128, 0), (146, -148, 0)]

BONES = {
    "body": ((96, -88, 0), (-40, -86, 0)),
    "chest": ((-40, -86, 0), (-52, -60, 0)),
    "neck": ((-38, -96, 0), (-60, -104, 0)),
    "head": ((-60, -104, 0), (-100, -98, 0)),
    "jaw": ((-62, -88, 0), (-98, -82, 0)),
}
for _leg, _j in LEGS.items():
    BONES[_leg + "_1"] = (_j[0], _j[1])
    BONES[_leg + "_2"] = (_j[1], _j[2])
    BONES[_leg + "_3"] = (_j[2], _j[3])
BONES.update(chain_bones("tail_", TAIL))


def H(dx, dy, d=0.0):
    """Toạ độ quanh tâm đầu, phóng K."""
    return (HEAD[0] + dx * K, HEAD[1] + dy * K, d * K)


def R(*r):
    return tuple(v * K for v in r)


def same_side(bone, p):
    """Chân gần/xa chỉ nhận vertex cùng phía chiều sâu (chân không dính nhau)."""
    if "_n_" in bone and p.y > 0.05:
        return False
    if "_f_" in bone and p.y < -0.05:
        return False
    return True


# Sẹo: vết vuốt, vết giáo của những kẻ từng thử giết nó (phía gần máy quay).
BODY_SCARS = [
    ([(6, -108), (14, -92), (26, -72)], 4.0),  # ba vết vuốt chéo ở hông
    ([(17, -110), (25, -94), (37, -74)], 4.0),
    ([(28, -111), (36, -96), (48, -77)], 3.6),
    ([(-44, -116), (-34, -100), (-22, -90)], 3.4),  # vai
    ([(-58, -78), (-52, -58)], 3.0),  # cẳng chân trước
    ([(56, -108), (70, -99), (86, -93)], 3.4),  # mông
    ([(42, -72), (56, -66)], 2.6),
]
HEAD_SCARS = [
    ([H(-27, -24)[:2], H(-21, -9)[:2], H(-15, 9)[:2]], 2.8),  # vết rạch dọc xuyên mắt
    ([H(-44, -3)[:2], H(-34, 4)[:2]], 2.0),  # mõm
    ([H(-6, -18)[:2], H(5, -6)[:2]], 2.0),  # trán
]


def build():
    hide = skin_material("Hide", "#6E4420", scar="#A0625A")
    nose_mat = skin_material("Nose", "#20120E", rough=0.35)
    mouth_mat = skin_material("Mouth", "#3E0A0E", rough=0.4, sss=0.3)
    gum_mat = skin_material("Gum", "#1C0E0C", rough=0.4)
    tongue_mat = skin_material("Tongue", "#9A2A30", rough=0.35, sss=0.4)
    fang_mat = skin_material("Fang", "#EDE2C2", rough=0.28)
    claw_mat = skin_material("Claw", "#CFC2A6", rough=0.3)
    eye_mat = glow_material("Eye", "#FF6A00", strength=1.1, base="#E85400")
    pupil_mat = skin_material("Pupil", "#050302", rough=0.1)
    rim_mat = skin_material("EyeRim", "#120A06", rough=0.5)

    # Lông vàng sẫm ánh kim (da thần thoại), bụng sáng → lưng sẫm; bờm vàng gần
    # mặt → nâu đen phía sau; chùm đuôi đen.
    coat = fur_material("Coat", [(0.0, "#E8C27E"), (0.35, "#C98E3E"), (0.75, "#9A6224"), (1.0, "#5E3814")], sheen=-0.1)
    mane = fur_material("ManeFur", [(0.0, "#C8822E"), (0.3, "#8A3E14"), (0.6, "#4A1C0A"), (1.0, "#160805")])
    tuft = fur_material("TuftFur", [(0.0, "#2A140A"), (1.0, "#0C0604")])

    rig = Rig("LionRig", BONES)
    parts = []

    # ---- thân + chân + đuôi: một khối metaball; các bó cơ cứng (stiffness cao)
    # để thớ cơ tách rõ dưới lớp lông ngắn.
    els = [
        ball(-40, -86, 0, 42, sx=1.15, sy=1.1, sz=0.8),  # ngực, vai
        ball(-30, -110, 0, 22, sx=1.5, sy=0.7, sz=0.9),  # u vai
        ball(12, -84, 0, 36, sx=1.7, sy=0.92, sz=0.72),  # thân giữa
        ball(14, -64, 0, 24, sx=1.8, sy=0.55, sz=0.66),  # bụng thóp
        ball(66, -86, 0, 40, sx=1.05, sy=1.05, sz=0.82),  # mông, đùi sau
        ball(-52, -64, 0, 26, sx=0.85, sy=1.0, sz=0.75),  # ức
    ]
    for sd in (NEAR, FAR):
        s = 1 if sd > 0 else -1
        els += [
            ball(-36, -112, 15 * s, 14, sx=1.4, sy=0.8, sz=0.6, stiff=3.5),  # bả vai
            ball(-50, -92, 17 * s, 13, sx=0.9, sy=1.2, sz=0.6, stiff=3.5),  # cơ delta
            ball(-36, -72, 18 * s, 12, sx=0.9, sy=1.3, sz=0.6, stiff=3.5),  # tam đầu
            ball(70, -94, 18 * s, 18, sx=1.1, sy=1.0, sz=0.6, stiff=3.5),  # mông
            ball(56, -70, 19 * s, 14, sx=0.9, sy=1.2, sz=0.6, stiff=3.5),  # đùi trước
            ball(90, -72, 18 * s, 13, sx=0.9, sy=1.2, sz=0.6, stiff=3.5),  # khoeo
        ]
    for leg, j in LEGS.items():
        front = leg.startswith("f")
        r1, r2, r3 = (22, 17, 13) if front else (26, 15, 11)
        els.append(ball(*j[0], r1 + 10, sx=1, sy=1.25, sz=0.6))
        els.append(capsule(j[0], j[1], r1))
        els.append(capsule(j[1], j[2], r2))
        els.append(capsule(j[2], lerp(j[2], j[3], 0.7), r3))  # cổ chân (bàn dựng riêng)
        if front:  # cơ cẳng tay cuồn cuộn, khuỷu nhô
            els.append(ball(*lerp(j[1], j[2], 0.3), 15, sx=0.9, sy=1.25, sz=0.8, stiff=3.5))
            els.append(ball(j[1][0] + 8, j[1][1] + 2, j[1][2], 8, stiff=3.5))
        else:  # bắp chân, gót xương nhô
            els.append(ball(*lerp(j[1], j[2], 0.3), 13, sx=1.0, sy=1.1, sz=0.8, stiff=3.5))
            els.append(ball(j[2][0] + 4, j[2][1] - 2, j[2][2], 6, stiff=4))
    for a, b in zip(TAIL, TAIL[1:]):
        els.append(capsule(a, b, 7.5 if a == TAIL[0] else 6, stiff=2.5))
    body = add_object("LionBody", subdivided(metaball_mesh("LionBody", els)), [hide])
    paint_scars(body, BODY_SCARS)
    rig.skin(body, [n for n in BONES if n != "jaw"], near_filter=same_side)
    # Lông thân ngắn (cơ lộ ra), chải ra sau và xuống.
    with_fur(body, coat, density=30000, length=(0.035, 0.06), radius=0.0034,
             comb=(0.9, 0, -0.6), lift=0.25, gravity=0.004, jitter=0.18, seed=1)
    parts.append(body)

    # ---- đầu: sọ, gò má, mõm vuông, gờ mày nặng xếch xuống, nếp nhăn mũi
    # (gầm gừ), tai cụp ra sau.
    head = ellipsoids_mesh("Head", [
        (H(-2, -2), R(25, 21, 20)),
        (H(-14, 6, -7), R(17, 13, 13)), (H(-14, 6, 7), R(17, 13, 13)),
        (H(-32, 4), R(19, 12, 14)), (H(-42, 8), R(10, 10, 13)),
        (H(-38, 13, -7), R(9, 6.5, 5)), (H(-38, 13, 7), R(9, 6.5, 5)),  # đệm ria
        (H(-18, -12.5, -7), R(14, 5.2, 7), 18), (H(-18, -12.5, 7), R(14, 5.2, 7), 18),
        (H(-32, -4), R(13, 4, 6), -8),
        (H(-27, -6.5), R(1.4, 1.6, 6.5)), (H(-31, -5.8), R(1.4, 1.6, 6.5)), (H(-35, -5), R(1.4, 1.5, 6)),
        (H(-35, 11, -8), R(8, 6, 4.5)), (H(-35, 11, 8), R(8, 6, 4.5)),
        (H(8, -19, -13), R(8, 6, 4), 35), (H(8, -19, 13), R(8, 6, 4), 35),
    ], voxel=0.014)
    head = subdivided(head)
    h = add_object("Head", head, [hide], "head")
    paint_scars(h, HEAD_SCARS)
    with_fur(h, coat, density=24000, length=(0.02, 0.035), radius=0.0026,
             comb=(1.0, 0, 0.1), lift=0.45, gravity=0.0, jitter=0.22, seed=2)
    parts.append(h)
    jaw = ellipsoids_mesh("Jaw", [(H(-24, 22), R(16, 6, 12)), (H(-12, 20), R(12, 7, 12))])
    jo = add_object("Jaw", jaw, [hide], "jaw")
    with_fur(jo, coat, density=24000, length=(0.02, 0.035), radius=0.0026,
             comb=(0.6, 0, -1.0), lift=0.4, gravity=0.0, jitter=0.22, seed=3)
    parts.append(jo)
    # Mũi da dẹt rộng hình tam giác, phủ đầu mõm (không phải hòn bi).
    nose = ellipsoids_mesh("Nose", [(H(-50, 0), R(4.5, 6, 10), -20), (H(-48, 6), R(3.6, 3.4, 6), -25)],
                           voxel=0.006, smooth_iter=2)
    parts.append(add_object("Nose", nose, [nose_mat], "head"))
    parts.append(add_object("MouthIn", uv_ellipsoid("MouthIn", H(-28, 16), R(15, 6.5, 10)), [mouth_mat], "head"))
    parts.append(add_object("Gum", uv_ellipsoid("Gum", H(-30, 13.5), R(14, 2.4, 10.5)), [gum_mat], "head"))
    parts.append(add_object("Tongue", uv_ellipsoid("Tongue", H(-26, 20), R(11, 3, 7)), [tongue_mat], "jaw"))
    # Nanh dài cong, răng cửa nhỏ.
    fangs_up, fangs_lo = [], []
    for d in (-7.5, 7.5):
        fangs_up.append((H(-38, 12, d), H(-38.5, 19, d), H(-37, 26, d * 0.95), 2.8 * K))
        fangs_lo.append((H(-33, 21, d * 0.9), H(-33.5, 16, d * 0.9), H(-35, 11, d * 0.85), 2.3 * K))
        for k in range(3):
            dd = d * 0.35 * (k - 1)
            fangs_up.append((H(-41 + k * 0.6, 12.5, dd), H(-41, 14.5, dd), H(-41, 16, dd), 0.9 * K))
        fangs_up.append((H(-26, 13, d), H(-26, 16, d), H(-26.5, 18.5, d), 1.6 * K))
    parts.append(add_object("FangsUp", tapered_tubes("FangsUp", fangs_up, 8, 6, taper=1.15), [fang_mat], "head"))
    parts.append(add_object("FangsLo", tapered_tubes("FangsLo", fangs_lo, 8, 6, taper=1.15), [fang_mat], "jaw"))
    # Mắt: hạnh nhân hẹp xếch, viền đen, mí trên sụp (lườm), đồng tử khe, ánh
    # hổ phách cam đỏ sáng nhẹ (không loá trắng).
    for d in (-16.5, 14.5):
        side = 1 if d < 0 else -1
        parts.append(add_object("EyeRim", ellipsoids_mesh("EyeRim", [(H(-21, -7.5, d), R(7.2, 3.4, 2.8), 16)], voxel=0.006, smooth_iter=2), [rim_mat], "head"))
        parts.append(add_object("Eye", ellipsoids_mesh("Eye", [(H(-22, -7.5, d - 0.7 * side), R(5.8, 2.4, 2.6), 16)], voxel=0.005, smooth_iter=2), [eye_mat], "head"))
        parts.append(add_object("Pupil", uv_ellipsoid("Pupil", H(-24.2, -7.6, d - 2.2 * side), R(0.8, 2.2, 1.0), 12, 8), [pupil_mat], "head"))
        parts.append(add_object("Lid", ellipsoids_mesh("Lid", [(H(-21, -10.4, d - 0.9 * side), R(7.4, 2.2, 3.2), 20)], voxel=0.006, smooth_iter=2), [rim_mat], "head"))

    # ---- bàn chân: đệm gan bàn, 4 ngón tách rời, móng vuốt cong sắc
    for leg, j in LEGS.items():
        px, py, pd = j[3]
        toes, claws = [], []
        for k, dd in enumerate((-9, -3.2, 3.2, 9)):
            tx = px - 8 + (2.5 if abs(dd) > 5 else 0)
            toes.append(((tx, -5, pd + dd), (5.6, 5, 4.2)))
            claws.append(((tx - 4.5, -6, pd + dd), (tx - 9.5, -4.5, pd + dd * 1.05),
                          (tx - 11, 0.5, pd + dd * 1.08), 2.0))
        paw = ellipsoids_mesh(leg + "Paw", [((px + 3, -8, pd), (13, 8, 11))] + toes, voxel=0.012)
        po = add_object(leg + "Paw", paw, [hide], leg + "_3")
        with_fur(po, coat, density=20000, length=(0.015, 0.028), radius=0.0026,
                 comb=(1.0, 0, 0.3), lift=0.4, gravity=0.0, jitter=0.2, seed=11)
        parts.append(po)
        parts.append(add_object(leg + "Claws", tapered_tubes(leg + "Claws", claws, 8, 7, taper=1.1),
                                [claw_mat], leg + "_3"))

    # ---- bờm dài, chải ra sau – rủ xuống
    cx, cy = HEAD[0] + 20, HEAD[1] + 8
    # Bờm vừa phải so với thân (không trùm quá nửa người).
    core = ellipsoids_mesh("ManeCore", [((cx, cy - 1, 0), (27, 32, 22)), ((cx + 4, cy + 25, 0), (19, 20, 17))])
    mc = add_object("ManeCore", core, [skin_material("ManeSkin", "#2A1206")], "neck")
    with_fur(mc, mane, density=11000, length=(0.33, 0.62), radius=0.0055,
             comb=(0.9, 0, -0.45), lift=0.7, gravity=0.12, jitter=0.35, seed=4,
             dark_from=((cx - 30) * S, (cx + 24) * S))
    parts.append(mc)

    tx, ty, _ = TAIL[-1]
    tm = add_object("TailTuft", ellipsoids_mesh("TailTuft", [((tx, ty - 2, 0), (6, 9, 6))]),
                    [skin_material("TuftSkin", "#1A0C06")], f"tail_{len(TAIL) - 2}")
    with_fur(tm, tuft, density=30000, length=(0.25, 0.42), radius=0.005,
             comb=(0.2, 0, 1.0), lift=0.8, gravity=0.12, jitter=0.4, seed=5)
    parts.append(tm)

    for p in parts:
        rig.bind(p)
    return rig


def pose(rig, t=0.0, attack=-1.0, defeat=0.0, mouth=0.0):
    """Dáng tại một khung — cùng nhịp với paintLion() bản vector. Đứng chờ
    là dáng rình: đầu thấp hơn vai, gầm gừ hé nanh."""
    rig.rest()
    breath = math.sin(t * 2 * math.pi) * 0.5 + 0.5
    fall = smooth(defeat)
    windup = strike = 0.0
    if attack >= 0:
        p = attack
        windup = smooth(p / 0.4) if p < 0.4 else (1 - smooth((p - 0.4) / 0.15) if p < 0.55 else 0)
        strike = 0 if p < 0.4 else (smooth((p - 0.4) / 0.15) if p < 0.55 else 1 - smooth((p - 0.55) / 0.45))
    roar = max(0.22 + mouth, strike, windup * 0.5) * (1 - fall * 0.6)

    shift = 10 * windup - 18 * strike + 10 * fall
    drop = 6 * windup + 34 * fall - breath * 1.5
    tilt = math.radians(-3 * strike + 4 * windup + 2)  # vai cao, chúi ra trước

    def body_pt(p):
        q = rot2(p, (20, -86), tilt)
        return (q[0] + shift, q[1] + drop, p[2])

    rig.set("body", body_pt(BONES["body"][0]), body_pt(BONES["body"][1]))
    rig.set("chest", body_pt(BONES["chest"][0]), body_pt(BONES["chest"][1]))

    head_dx = -16 * strike + 4 * windup - 10 * fall - 3
    head_dy = 26 * fall + 4 * windup + 9 + math.sin(t * 2 * math.pi) * 1.2  # đầu thấp hơn vai
    head_rot = math.radians(-14 * fall + 3 * windup - 6 * strike + 6)
    neck_a = body_pt(BONES["neck"][0])
    hb = BONES["head"]
    h0 = (hb[0][0] + shift + head_dx, hb[0][1] + drop + head_dy, 0)
    rig.set("neck", neck_a, h0)
    h1 = rot2((h0[0] + hb[1][0] - hb[0][0], h0[1] + hb[1][1] - hb[0][1], 0), h0, head_rot)
    rig.set("head", h0, h1)
    jb = BONES["jaw"]
    j0 = rot2((h0[0] + jb[0][0] - hb[0][0], h0[1] + jb[0][1] - hb[0][1], 0), h0, head_rot)
    j1 = (j0[0] + jb[1][0] - jb[0][0], j0[1] + jb[1][1] - jb[0][1], 0)
    rig.set("jaw", j0, rot2(j1, j0, head_rot + math.radians(-26 * roar)))

    swipe = strike * (1 - fall)
    for leg, j in LEGS.items():
        hip = body_pt(j[0])
        paw = list(j[3])
        if leg == "fl_n":
            ground = (j[3][0] + 10 * windup - 36 * fall, 0)
            paw = [ground[0] + (-120 - ground[0]) * swipe, -56 * swipe, j[3][2]]
        elif leg == "fl_f":
            paw[0] += 8 * windup - 30 * fall
        else:
            paw[0] += 8 * fall
        front = leg.startswith("f")
        ankle = (paw[0] + (j[2][0] - j[3][0]), paw[1] + (j[2][1] - j[3][1]), j[3][2])
        l1 = math.dist(j[1][:2], j[0][:2])
        l2 = math.dist(j[2][:2], j[1][:2])
        knee = two_bone(hip, ankle, l1, l2, -1 if front else 1)
        knee = (knee[0], knee[1], j[0][2])
        rig.set(leg + "_1", (hip[0], hip[1], j[0][2]), knee)
        rig.set(leg + "_2", knee, ankle)
        rig.set(leg + "_3", ankle, tuple(paw))

    prev = body_pt(TAIL[0])
    ang_acc = 0.0
    for i in range(len(TAIL) - 1):
        a, b = TAIL[i], TAIL[i + 1]
        seg = Vector((b[0] - a[0], b[1] - a[1]))
        ang_acc += math.radians(
            (7 + 10 * windup) * math.sin(t * 2 * math.pi + i * 0.6) * (i + 1) / 3 + 26 * fall * (1 if i < 2 else 0.4)
        )
        c, s = math.cos(ang_acc), math.sin(ang_acc)
        v = Vector((seg.x * c - seg.y * s, seg.x * s + seg.y * c))
        nxt = (prev[0] + v.x, prev[1] + v.y, 0)
        rig.set(f"tail_{i}", prev, nxt)
        prev = nxt


# Khung hình theo đơn vị vẽ: đủ chỗ cho vuốt vung (x≈-150), bờm và chùm đuôi.
FRAME_X = (-195, 195)
FRAME_Y = (-220, 18)


def lights(scene):
    # Nắng chiều gắt trên-trái (đổ bóng sâu vào rãnh cơ), viền cam rực sau lưng.
    add_sun(scene, "Key", (0.85, 0.35, -0.4), 6.0, "#FFD6A0", angle=1.0)
    add_sun(scene, "Rim", (-0.6, -0.9, -0.35), 7.0, "#FF8A3A", angle=1.5)


def main():
    scene = reset_scene(samples=64, world_hex="#3A4258", world_strength=0.16)
    rig = build()
    lights(scene)
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=1.6, yaw=-14, pitch=6)
    anchor, ppu = anchor_info(scene, cam)
    print(f"LION anchor={tuple(round(c, 1) for c in anchor)} ppu={ppu:.3f}")
    out = os.path.join(ROOT, "build", "blender", "lion")
    if STILL:
        render_stills(scene, out, [
            ("idle", lambda: pose(rig, 0)),
            ("windup", lambda: pose(rig, 0.25, attack=0.38)),
            ("strike", lambda: pose(rig, 0.25, attack=0.55)),
            ("defeat", lambda: pose(rig, 0.25, defeat=1)),
        ])
        pose(rig, 0)
        save_blend("nemea_lion")
        return
    anims = {
        "idle": [lambda k=k: pose(rig, k / 16) for k in range(16)],
        "attack": [lambda k=k: pose(rig, 0.25, attack=k / 15) for k in range(16)],
        "defeat": [lambda k=k: pose(rig, 0.25, defeat=k / 9) for k in range(10)],
    }
    files = render_anims(scene, out, anims, keyframe=rig.keyframe)
    sprites = os.path.join(ROOT, "assets", "sprites")
    os.makedirs(sprites, exist_ok=True)
    pack_atlas(files, anchor, ppu, os.path.join(sprites, "nemea_lion.png"), os.path.join(sprites, "nemea_lion.json"))
    pose(rig, 0)
    save_blend("nemea_lion")


main()
