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

import bmesh
import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403
from sprite_kit import export_sprites  # noqa: E402

LION_SCALE = 0.72  # lionScale trong lib/art/bosses/nemea_boss.dart

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
    # Ba vết vuốt chéo ở hông, một vết giáo ở mông: vệt da trụi mảnh.
    ([(6, -108), (14, -92), (26, -72)], 2.6),
    ([(17, -110), (25, -94), (37, -74)], 2.6),
    ([(28, -111), (36, -96), (48, -77)], 2.4),
    ([(56, -108), (70, -99), (86, -93)], 2.2),
]
HEAD_SCARS = [
    ([H(-27, -24)[:2], H(-21, -9)[:2], H(-15, 9)[:2]], 2.8),  # vết rạch dọc xuyên mắt
    ([H(-44, -3)[:2], H(-34, 4)[:2]], 2.0),  # mõm
    ([H(-6, -18)[:2], H(5, -6)[:2]], 2.0),  # trán
]


def build():
    # Da dưới lớp lông cùng tông lông (khe giữa sợi không lộ mảng sẫm); sẹo
    # là vệt da trụi hồng xám, không phải vết nứt đỏ.
    hide = skin_material("Hide", "#9C6E38", rough=0.9, scar="#7A5C52", noise_scale=24)
    nose_mat = skin_material("Nose", "#2A1612", rough=0.42, noise_scale=60)
    lip_mat = skin_material("Lip", "#1A0E0A", rough=0.45)
    mouth_mat = skin_material("Mouth", "#3E0A0E", rough=0.4, sss=0.3)
    gum_mat = skin_material("Gum", "#4A1A1C", rough=0.4, sss=0.2)
    tongue_mat = skin_material("Tongue", "#9A2A30", rough=0.35, sss=0.4)
    fang_mat = skin_material("Fang", "#E6D9B6", rough=0.28)
    claw_mat = skin_material("Claw", "#CFC2A6", rough=0.3)
    # Mắt hổ phách thật (không loá): tròng ướt, ánh sáng nhẹ đủ đọc từ xa.
    eye_mat = glow_material("Eye", "#C86A10", strength=0.35, base="#B8781C")
    pupil_mat = skin_material("Pupil", "#050302", rough=0.05)
    rim_mat = skin_material("EyeRim", "#120A06", rough=0.5)
    white_mat = skin_material("Blaze", "#E8DCC4", rough=0.8)

    # Lông vàng sẫm ánh kim (da thần thoại), bụng sáng → lưng sẫm; bờm vàng gần
    # mặt → nâu đen phía sau; chùm đuôi đen.
    coat = fur_material("Coat", [(0.0, "#E2C690"), (0.4, "#B07C3A"), (0.75, "#7A4C1C"), (1.0, "#46290E")], sheen=-0.1)
    pale = fur_material("PaleFur", [(0.0, "#F4ECDA"), (1.0, "#C8B494")])
    mane = fur_material("ManeFur", [(0.0, "#D2913A"), (0.25, "#9A4C1A"), (0.55, "#4E200C"), (1.0, "#160805")])
    tuft = fur_material("TuftFur", [(0.0, "#2A140A"), (1.0, "#0C0604")])

    rig = Rig("LionRig", BONES)
    parts = []

    # ---- thân + chân + đuôi: một khối metaball; các bó cơ cứng (stiffness cao)
    # để thớ cơ tách rõ dưới lớp lông ngắn.
    els = [
        ball(-40, -86, 0, 42, sx=1.15, sy=1.1, sz=0.8),  # ngực, vai
        ball(-30, -110, 0, 22, sx=1.5, sy=0.7, sz=0.9),  # u vai
        ball(12, -86, 0, 37, sx=1.75, sy=0.95, sz=0.74),  # thân giữa
        ball(10, -64, 0, 27, sx=1.8, sy=0.72, sz=0.7),  # bụng sâu
        ball(40, -66, 0, 22, sx=1.2, sy=0.7, sz=0.68),  # hạ sườn
        ball(64, -84, 0, 37, sx=1.08, sy=0.98, sz=0.8),  # mông, đùi sau (lưng gần thẳng, không gù hông)
        ball(-52, -64, 0, 26, sx=0.85, sy=1.0, sz=0.75),  # ức
    ]
    for sd in (NEAR, FAR):
        s = 1 if sd > 0 else -1
        els += [
            ball(-36, -112, 15 * s, 14, sx=1.4, sy=0.8, sz=0.6, stiff=2.4),  # bả vai
            ball(-50, -92, 17 * s, 13, sx=0.9, sy=1.2, sz=0.6, stiff=2.4),  # cơ delta
            ball(-36, -72, 18 * s, 12, sx=0.9, sy=1.3, sz=0.6, stiff=2.4),  # tam đầu
            ball(56, -70, 19 * s, 14, sx=0.9, sy=1.2, sz=0.6, stiff=2.4),  # đùi trước
            ball(90, -72, 18 * s, 13, sx=0.9, sy=1.2, sz=0.6, stiff=2.4),  # khoeo
        ]
    for leg, j in LEGS.items():
        front = leg.startswith("f")
        r1, r2, r3 = (25, 20, 15) if front else (27, 16, 12)
        # Khối vai/hông chân: chân sau nhỏ hơn để lưng không gù ở hông.
        els.append(ball(*j[0], r1 + (10 if front else 3), sx=1, sy=1.25 if front else 1.0, sz=0.6))
        els.append(capsule(j[0], j[1], r1))
        els.append(capsule(j[1], j[2], r2))
        els.append(capsule(j[2], lerp(j[2], j[3], 0.7), r3))  # cổ chân (bàn dựng riêng)
        if front:  # cơ cẳng tay cuồn cuộn, khuỷu nhô
            els.append(ball(*lerp(j[1], j[2], 0.3), 15, sx=0.9, sy=1.25, sz=0.8, stiff=2.4))
            els.append(ball(j[1][0] + 8, j[1][1] + 2, j[1][2], 8, stiff=2.4))
        else:  # bắp chân, gót xương nhô
            els.append(ball(*lerp(j[1], j[2], 0.3), 13, sx=1.0, sy=1.1, sz=0.8, stiff=2.4))
            els.append(ball(j[2][0] + 4, j[2][1] - 2, j[2][2], 6, stiff=2.6))
    for a, b in zip(TAIL, TAIL[1:]):
        els.append(capsule(a, b, 7.5 if a == TAIL[0] else 6, stiff=2.5))
    body = add_object("LionBody", subdivided(metaball_mesh("LionBody", els)), [hide])
    paint_scars(body, BODY_SCARS)
    rig.skin(body, [n for n in BONES if n != "jaw"], near_filter=same_side)
    # Lông thân ngắn (cơ lộ ra), chải ra sau và xuống.
    with_fur(body, coat, density=46000, length=(0.08, 0.13), radius=0.0055,
             comb=(0.9, 0, -0.6), lift=0.18, gravity=0.01, jitter=0.2, seed=1)
    parts.append(body)

    # ---- đầu (tỉ lệ sư tử thật, nhìn nghiêng): sọ thấp, trán dốc nhẹ xuống
    # sống mũi dài phẳng, mõm sâu vuông, đệm ria phồng, gò má rộng, gờ mày
    # nặng che mắt; tai tròn nhỏ gần như chìm trong bờm.
    head = ellipsoids_mesh("Head", [
        (H(6, -5), R(23, 19, 19)),  # sọ
        (H(-12, -10), R(17, 9.5, 16)),  # gờ trán
        (H(-31, -7), R(21, 8, 11.5), -4),  # sống mũi dài phẳng
        (H(-34, 4), R(16, 12, 12.5)),  # khối mõm
        (H(-45, 3), R(8, 10.5, 11)),  # mõm trước vuông
        (H(-41, 10, -7), R(10, 7.5, 7)), (H(-41, 10, 7), R(10, 7.5, 7)),  # đệm ria
        (H(-6, 6, -9), R(13, 11, 8)), (H(-6, 6, 9), R(13, 11, 8)),  # gò má (chìm trong bờm)
        (H(-21, -12.5, -10), R(10, 4, 6), 14), (H(-21, -12.5, 10), R(10, 4, 6), 14),  # gờ mày
        (H(-36, -9.5), R(1.3, 1.5, 7)), (H(-40, -8.6), R(1.3, 1.4, 6.5)),  # nếp nhăn mũi (gầm gừ)
        (H(12, -21, -12), R(6, 7, 3), 30), (H(12, -21, 12), R(6, 7, 3), 30),  # tai
    ], voxel=0.012)
    head = subdivided(head)
    h = add_object("Head", head, [hide], "head")
    paint_scars(h, HEAD_SCARS)
    with_fur(h, coat, density=36000, length=(0.025, 0.045), radius=0.004,
             comb=(1.0, 0, 0.15), lift=0.4, gravity=0.0, jitter=0.2, seed=2)
    parts.append(h)
    # Lông trắng kem ở môi trên và cằm — dấu hiệu nhận ra sư tử thật từ xa.
    muzzle = add_object("Muzzle", ellipsoids_mesh("Muzzle", [
        (H(-43, 12, -6.5), R(8, 4.5, 5.5)), (H(-43, 12, 6.5), R(8, 4.5, 5.5)),
    ], voxel=0.008), [white_mat], "head")
    with_fur(muzzle, pale, density=30000, length=(0.012, 0.022), radius=0.0022,
             comb=(-0.2, 0, -1.0), lift=0.6, gravity=0.0, jitter=0.2, seed=6)
    parts.append(muzzle)
    # Môi đen viền miệng (sư tử có môi sẫm rõ khi gầm).
    lips = [(H(-46, 12.5, d), H(-36, 15, d * 1.2), H(-24, 15.5, d * 1.4), 1.6 * K) for d in (-8, 8)]
    parts.append(add_object("Lips", tapered_tubes("Lips", lips, 8, 8, taper=0.4), [lip_mat], "head"))
    jaw = ellipsoids_mesh("Jaw", [(H(-30, 20), R(16, 5.5, 10.5)), (H(-15, 18), R(13, 7, 11.5)),
                                  (H(-42, 19), R(6, 5.5, 8))])
    jo = add_object("Jaw", jaw, [hide], "jaw")
    with_fur(jo, pale, density=30000, length=(0.02, 0.04), radius=0.0024,
             comb=(0.4, 0, -1.0), lift=0.4, gravity=0.002, jitter=0.22, seed=3)
    parts.append(jo)
    # Mũi da hình chữ T: đệm mũi rộng phủ đầu mõm, sống dọc xuống môi trên.
    nose = ellipsoids_mesh("Nose", [
        (H(-50.5, -1.5), R(2.2, 4.4, 8), -22),
        (H(-50.5, 4.5), R(1.6, 3.6, 2), -10),
        (H(-51.5, 1.5, -4.2), R(1.2, 1.4, 2.2)), (H(-51.5, 1.5, 4.2), R(1.2, 1.4, 2.2)),
    ], voxel=0.005, smooth_iter=2)
    parts.append(add_object("Nose", nose, [nose_mat], "head"))
    parts.append(add_object("MouthIn", uv_ellipsoid("MouthIn", H(-30, 16), R(15, 6, 9)), [mouth_mat], "head"))
    parts.append(add_object("Gum", uv_ellipsoid("Gum", H(-32, 13.5), R(14, 2.2, 9.5)), [gum_mat], "head"))
    parts.append(add_object("Tongue", uv_ellipsoid("Tongue", H(-28, 20), R(11, 3, 6.5)), [tongue_mat], "jaw"))
    # Nanh dài cong, răng cửa nhỏ.
    fangs_up, fangs_lo = [], []
    for d in (-6.8, 6.8):
        fangs_up.append((H(-42, 12, d), H(-42.5, 19, d), H(-41, 26, d * 0.95), 2.8 * K))
        fangs_lo.append((H(-37, 21, d * 0.9), H(-37.5, 16, d * 0.9), H(-39, 11, d * 0.85), 2.3 * K))
        for k in range(3):
            dd = d * 0.35 * (k - 1)
            fangs_up.append((H(-45 + k * 0.6, 12.5, dd), H(-45, 14.5, dd), H(-45, 16, dd), 0.9 * K))
        fangs_up.append((H(-28, 13, d), H(-28, 16, d), H(-28.5, 18.5, d), 1.6 * K))
    parts.append(add_object("FangsUp", tapered_tubes("FangsUp", fangs_up, 8, 6, taper=1.15), [fang_mat], "head"))
    parts.append(add_object("FangsLo", tapered_tubes("FangsLo", fangs_lo, 8, 6, taper=1.15), [fang_mat], "jaw"))
    # Mắt nhỏ, hướng trước, nằm sâu dưới gờ mày: hạnh nhân viền đen, tròng
    # hổ phách, đồng tử TRÒN (sư tử không có đồng tử khe).
    for d in (-10.4, 10.4):
        side = 1 if d < 0 else -1
        parts.append(add_object("EyeRim", ellipsoids_mesh("EyeRim", [(H(-22, -7, d), R(5.4, 2.8, 2.2), 12)], voxel=0.005, smooth_iter=2), [rim_mat], "head"))
        parts.append(add_object("Eye", ellipsoids_mesh("Eye", [(H(-22.6, -7, d - 0.6 * side), R(4.2, 2.1, 2.0), 12)], voxel=0.004, smooth_iter=2), [eye_mat], "head"))
        parts.append(add_object("Pupil", uv_ellipsoid("Pupil", H(-23.6, -7, d - 1.6 * side), R(1.1, 1.1, 0.8), 12, 8), [pupil_mat], "head"))
        parts.append(add_object("Lid", ellipsoids_mesh("Lid", [(H(-22, -9.4, d - 0.5 * side), R(5.8, 1.8, 2.6), 16)], voxel=0.005, smooth_iter=2), [hide], "head"))

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

    # ---- bờm: vành lông ôm quanh mặt (gắn đầu) + khối bờm cổ – vai – ngực
    # (gắn cổ). Gần mặt vàng cháy, ra sau sẫm dần tới nâu đen; sợi dài rủ.
    ring = ellipsoids_mesh("ManeRing", [(H(8, 0), R(18, 25, 22)), (H(0, 18), R(16, 12, 17))])
    mr = add_object("ManeRing", ring, [skin_material("ManeSkin", "#3A1A08")], "head")
    with_fur(mr, mane, density=14000, length=(0.22, 0.4), radius=0.005,
             comb=(1.0, 0, 0.05), lift=0.9, gravity=0.05, jitter=0.35, seed=7,
             dark_from=((HEAD[0] - 6) * S, (HEAD[0] + 60) * S))
    parts.append(mr)
    core = ellipsoids_mesh("ManeCore", [
        ((-44, -104, 0), (28, 30, 24)),  # gáy
        ((-30, -116, 0), (22, 18, 20)),  # u vai
        ((-50, -76, 0), (22, 26, 21)),  # ngực
    ])
    mc = add_object("ManeCore", core, [skin_material("ManeSkin2", "#2A1206")], "neck")
    with_fur(mc, mane, density=11000, length=(0.4, 0.72), radius=0.0058,
             comb=(0.8, 0, -0.55), lift=0.75, gravity=0.14, jitter=0.38, seed=4,
             dark_from=((HEAD[0] - 6) * S, (HEAD[0] + 70) * S))
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
    # Nắng chiều ấm trên-trái (cùng hướng các quái chương 1), viền cam sau
    # lưng tách bờm khỏi nền, ánh hắt đất nâu dưới bụng.
    add_sun(scene, "Key", (0.55, 0.6, -0.6), 5.0, "#FFDDB0", angle=2.5)
    add_sun(scene, "Rim", (0.7, -0.4, -0.35), 5.0, "#FFB070", angle=4)
    add_sun(scene, "Bounce", (-0.1, 0.3, 0.9), 0.6, "#C8A880", angle=30)


def shadow_floor():
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=12)
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
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "lion")
        setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=2.6, yaw=-14, pitch=6)
        render_stills(scene, out, [
            ("idle", lambda: pose(rig, 0)),
            ("windup", lambda: pose(rig, 0.25, attack=0.38)),
            ("strike", lambda: pose(rig, 0.25, attack=0.55)),
            ("defeat", lambda: pose(rig, 0.25, defeat=1)),
        ])
        pose(rig, 0)
        save_blend("nemea_lion")
        return
    # Sân khấu vẽ sư tử ×lionScale (0,72): ~3 px/đơn vị sân khấu như quái khác.
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=2.2, yaw=-14, pitch=6)
    anims = {
        "idle": [lambda k=k: pose(rig, k / 8) for k in range(8)],
        "attack": [lambda k=k: pose(rig, 0.25, attack=k / 11) for k in range(12)],
        "defeat": [lambda k=k: pose(rig, 0.25, defeat=k / 6) for k in range(7)],
    }
    export_sprites(scene, cam, "nemea_lion", anims, P(0, 0), 50 * LION_SCALE, extra={"idlePeriod": 3.0})
    pose(rig, 0)
    save_blend("nemea_lion")


main()
