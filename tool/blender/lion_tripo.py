"""Sư tử Nemea từ mô hình Tripo3D (art_src/tripo/nemea_lion.glb), thay bản
dựng bằng khối của lion_nemea.py: cùng máy quay, đèn, bóng đổ, điểm neo, nên
sân khấu (lionX, lionScale, điểm trúng đòn) không phải đổi.

    bash tool/blender/render.sh lion_tripo --still   # vài khung xem nhanh
    bash tool/blender/render.sh lion_tripo           # ghi đè atlas nemea_lion
    python tool/repack_sprites.py nemea_lion --scale 0.8   # vừa ngân sách trang

Mô hình Tripo không có xương: gắn khung xương phẳng (Rig của boss_kit) theo
khớp đọc trên ảnh nhìn ngang có lưới toạ độ, trọng số theo khoảng cách.
Động tác: idle, attack (vồ cào), defeat, pounce (pha 2: nhảy vồ), wrestled
(pha 2: bị người chơi vật, chồm ngửa ra sau) — xem LionPounce.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403
import lion_nemea as ln  # noqa: E402
from sprite_kit import export_sprites  # noqa: E402
from choreo_kit import Move, dense_phases  # noqa: E402
from toon_kit import TOON, toonify  # noqa: E402
from tripo_kit import import_tripo, smooth_weights  # noqa: E402

GLB = os.path.join(ROOT, "art_src", "tripo", "nemea_lion.glb")

# Mũi giữ đúng chỗ bản cũ (đơn vị vẽ). [SPAN]: bề dài mũi–đuôi bản cũ; đuôi
# Tripo dài hơn, nên phóng thêm [GROW] cho bờm cao bằng bản cũ.
NOSE_X = -141
SPAN = 262
GROW = 1.18

# Khớp (đơn vị vẽ, y xuống, d = chiều sâu) đọc trên ảnh nhìn ngang có lưới.
# Chân: vai/hông → khuỷu/gối → cổ chân → mũi bàn chân.
NEAR, FAR = -45, 45
LEGS = {
    "fl_n": [(-45, -88, NEAR), (-42, -52, NEAR), (-40, -20, NEAR), (-64, -3, NEAR)],
    "fl_f": [(-68, -88, FAR), (-76, -50, FAR), (-82, -20, FAR), (-106, -3, FAR)],
    "bl_n": [(42, -100, NEAR), (52, -64, NEAR), (66, -42, NEAR), (48, -3, NEAR)],
    "bl_f": [(32, -100, FAR), (36, -64, FAR), (44, -40, FAR), (24, -3, FAR)],
}
TAIL = [(60, -104, 0), (85, -84, 0), (116, -64, 0), (146, -68, 0), (160, -94, 0), (156, -122, 0), (144, -138, 0)]
HEAD0 = (-95, -118, 0)  # gốc đầu (sau gáy)
BONES = {
    "body": ((62, -104, 0), (-40, -100, 0)),
    "chest": ((-40, -100, 0), (-55, -66, 0)),
    "neck": ((-40, -112, 0), HEAD0),
    "head": (HEAD0, (-140, -108, 0)),
    "jaw": ((-108, -98, 0), (-135, -86, 0)),
}
for _leg, _j in LEGS.items():
    BONES[_leg + "_1"] = (_j[0], _j[1])
    BONES[_leg + "_2"] = (_j[1], _j[2])
    BONES[_leg + "_3"] = (_j[2], _j[3])
BONES.update(chain_bones("tail_", TAIL))

# Thân xoay quanh điểm này (giữa lưng) khi ngóc/chúi.
PIVOT = (10, -100)


def import_lion():
    return import_tripo(GLB, NOSE_X, SPAN, GROW)


def same_side(bone, p):
    """Chân gần/xa chỉ nhận đỉnh cùng phía chiều sâu (chân không dính nhau)."""
    if "_n_" in bone and p.y > 0.05:
        return False
    if "_f_" in bone and p.y < -0.05:
        return False
    # Hàm chỉ nhận đỉnh quanh miệng (không kéo bờm cằm/ngực theo).
    if bone == "jaw" and (p.x > -100 * S or p.z > 112 * S or p.z < 70 * S):
        return False
    return True


def build():
    mesh = import_lion()
    rig = Rig("LionRig", BONES)
    rig.skin(mesh, near_filter=same_side)
    smooth_weights(mesh)
    rig.bind(mesh)
    return rig


# Biên đạo (choreo_kit): kênh theo đơn vị vẽ / độ, quanh dáng chờ READY.
#   shift, drop   dời thân (x dương = lùi, y dương = hạ thấp)
#   tilt          ngóc thân quanh giữa lưng (độ, + = ngóc phần trước lên)
#   hdx, hdy, hrot   dời gốc đầu, xoay đầu (độ, + = ngửa ra sau)
#   roar          há miệng 0–1
#   npx, npy / fpx, fpy   chân trước gần / xa: dời bàn chân so với chỗ đứng
#   air           chân trước rời đất (cổ chân nằm trên đường vai → bàn)
#   bpx, bpy      hai chân sau: dời bàn chân (đạp ra sau, nhấc lên)
#   flail         quẫy hai chân trước (lúc bị vật)
#   lash, tailup  biên độ quất đuôi, đuôi rũ (độ)
# Sư tử: nặng mà mềm như mèo — dồn trọng lượng trước khi ra đòn, vai lăn
# theo bước, đuôi quất trễ, đầu luôn nhìn con mồi.
READY = dict(shift=0, drop=0, tilt=2, hdx=0, hdy=0, hrot=0, roar=0.22, npx=0, npy=0, fpx=0, fpy=0,
             air=0, bpx=0, bpy=0, flail=0, lash=7, tailup=0)
LAG = dict(tilt=0.006, hdx=0.015, hdy=0.015, hrot=0.02, roar=0.01, lash=0.04, tailup=0.05)

# Vồ cào (pha 1; tiến độ sân khấu, chạm ~0,55): hạ người dồn sức, ngóc vai,
# giương chân trước gần lên cạnh ngực (vuốt giương) → vung theo đường cung
# qua trước mặt → cào xuống đất → thu chân, về thế rình.
ATTACK = Move(READY, [
    (0.12, dict(shift=4, drop=3, hdy=3, lash=12)),
    (0.30, dict(shift=9, drop=6, tilt=5, hdx=4, hdy=2, roar=0.4, npx=6, npy=-6, lash=16)),
    (0.42, dict(shift=10, drop=3, tilt=10, hdx=5, hdy=-3, hrot=4, roar=0.55, npx=8, npy=-40, air=1)),
    (0.48, dict(shift=10, drop=3, tilt=11, hdx=6, hdy=-4, hrot=5, roar=0.6, npx=10, npy=-44, air=1)),
    (0.52, dict(shift=-6, drop=2, tilt=5, hdx=-6, roar=0.9, npx=-40, npy=-62, air=1)),
    (0.56, dict(shift=-18, drop=2, tilt=-3, hdx=-16, hdy=0, hrot=-4, roar=1, npx=-86, npy=-50, air=1, lash=20)),
    (0.64, dict(shift=-20, drop=4, tilt=-5, hdx=-14, hdy=3, hrot=-6, roar=0.9, npx=-80, npy=-6, air=0.3)),
    (0.78, dict(shift=-10, drop=2, tilt=0, hdx=-6, roar=0.5, npx=-30, npy=0, air=0, lash=12)),
    (0.90, dict(shift=-2, drop=0, tilt=2, hdx=-1, npx=-4, roar=0.3)),
], LAG)

# Nhảy vồ (pha 2): hạ sát đất, nhún mông hai nhịp kiểu mèo → bật bằng chân
# sau, bay chồm hai chân trước vươn tới → đáp, trượt, đứng lên.
POUNCE = Move(READY, [
    (0.15, dict(shift=6, drop=6, tilt=0, hdy=4, lash=14, tailup=-6)),
    (0.30, dict(shift=12, drop=10, tilt=-2, hdy=6, hrot=-2, roar=0.5, bpx=3)),
    (0.36, dict(shift=15, drop=11, bpx=5)),
    (0.42, dict(shift=12, drop=10, bpx=3)),
    (0.48, dict(shift=15, drop=11, tilt=-3, hdy=6, roar=0.6, bpx=5, lash=18)),
    (0.52, dict(shift=-6, drop=-6, tilt=8, hdx=-6, hdy=0, hrot=4, roar=0.9, npx=-46, npy=-36, fpx=-22, fpy=-30,
                air=1, bpx=20, bpy=6)),
    (0.58, dict(shift=-40, drop=-26, tilt=12, hdx=-10, hrot=6, roar=1, npx=-94, npy=-67, fpx=-44, fpy=-55,
                air=1, bpx=30, bpy=14, lash=22)),
    (0.66, dict(shift=-42, drop=-24, tilt=12, hdx=-10, npx=-96, npy=-66, fpx=-46, fpy=-54, bpx=30, bpy=14)),
    (0.80, dict(shift=-24, drop=4, tilt=0, hdx=-6, hrot=0, roar=0.6, npx=-30, npy=0, fpx=-26, fpy=0, air=0,
                bpx=8, bpy=0, lash=14)),
    (0.92, dict(shift=-6, drop=1, tilt=2, hdx=-1, npx=-6, fpx=-6, bpx=2, roar=0.3)),
], LAG)

# Bị vật (người chơi giữ tay thẳng): chồm ngửa ra sau, hai chân trước co
# lên ngực quẫy, gầm; nhả ra từ 0,7.
WRESTLED = Move(READY, [
    (0.25, dict(shift=16, drop=6, tilt=24, hdx=6, hdy=-8, hrot=22, roar=1, npx=22, npy=-75, fpx=46, fpy=-69,
                air=1, flail=1, lash=17)),
    (0.70, dict(shift=16, drop=6, tilt=24, hdx=6, hdy=-8, hrot=22, roar=1, npx=22, npy=-75, fpx=46, fpy=-69,
                air=1, flail=1, lash=17)),
], LAG)

# Gục: loạng choạng gầm đau → chân trước khuỵu trước (vai đổ, bàn trượt tới)
# → chân sau gập → nằm rạp, đầu gục sau cùng, đuôi rũ.
DEFEAT = Move(READY, [
    (0.25, dict(shift=4, drop=4, tilt=4, hdx=2, hrot=4, roar=0.7)),
    (0.50, dict(shift=6, drop=16, tilt=-8, hdy=10, hrot=-8, roar=0.4, npx=-14, fpx=-14)),
    (0.75, dict(shift=9, drop=30, tilt=-4, hdx=-4, hdy=18, hrot=-12, roar=0.2, npx=-28, fpx=-28, bpx=6, lash=3, tailup=14)),
    (1.00, dict(shift=10, drop=34, tilt=-2, hdx=-6, hdy=22, hrot=-14, roar=0.13, npx=-34, fpx=-34, bpx=8, lash=1,
                tailup=20)),
], dict(LAG, hdy=0.06, hrot=0.08, tailup=0.08))


# Vồ cào và nhảy vồ: 36 khung, 15 dồn quanh cú chạm (0,46–0,70).
ATTACK_PHASES = dense_phases(0.04, 0.46, 0.70, 0.016)


def idle_channels(t):
    """Đứng rình thở chậm: sườn phập phồng, trọng lượng dồn qua lại giữa hai
    chân trước, đầu đảo nhẹ theo con mồi, đuôi lượn và giật chóp."""
    a = 2 * math.pi * t
    v = dict(READY)
    v.update(
        drop=-1.5 * (0.5 + 0.5 * math.sin(a)),
        shift=1.2 * math.sin(a + 0.5),
        tilt=READY["tilt"] + 0.8 * math.sin(a - 0.4),
        hdx=1.0 * math.sin(a - 0.9),
        hdy=1.2 * math.sin(a),
        hrot=2.0 * math.sin(a - 1.4),
        npx=0.8 * math.sin(a + 0.5),
        roar=0.22 + 0.06 * max(0.0, math.sin(a - 2.0)),
    )
    return v


def pose(rig, v, t=0.0):
    """Đặt dáng theo kênh [v] (xem READY); [t] = thời gian vòng đuôi / quẫy."""
    rig.rest()
    shift, drop = v["shift"], v["drop"]
    tilt = math.radians(v["tilt"])

    def body_pt(p):
        q = rot2(p, PIVOT, tilt)
        return (q[0] + shift, q[1] + drop, p[2])

    rig.set("body", body_pt(BONES["body"][0]), body_pt(BONES["body"][1]))
    rig.set("chest", body_pt(BONES["chest"][0]), body_pt(BONES["chest"][1]))

    head_rot = math.radians(v["hrot"])
    hb = BONES["head"]
    h0b = body_pt(hb[0])
    h0 = (h0b[0] + v["hdx"], h0b[1] + v["hdy"], 0)
    rig.set("neck", body_pt(BONES["neck"][0]), h0)
    h1 = rot2((h0[0] + hb[1][0] - hb[0][0], h0[1] + hb[1][1] - hb[0][1], 0), h0, head_rot + tilt)
    rig.set("head", h0, h1)
    jb = BONES["jaw"]
    j0 = rot2((h0[0] + jb[0][0] - hb[0][0], h0[1] + jb[0][1] - hb[0][1], 0), h0, head_rot + tilt)
    j1 = (j0[0] + jb[1][0] - jb[0][0], j0[1] + jb[1][1] - jb[0][1], 0)
    # Mô hình há sẵn: đứng chờ khép bớt (gầm gừ), gầm thì há rộng thêm.
    roar = v["roar"]
    rig.set("jaw", j0, rot2(j1, j0, head_rot + tilt + math.radians(12 * (1 - roar) - 10 * roar)))

    flail = math.sin(t * 2 * math.pi * 3 + 1.0) * v["flail"]
    offs = {"fl_n": (v["npx"] + 6 * flail, v["npy"] - 6 * flail), "fl_f": (v["fpx"] - 5 * flail, v["fpy"] + 5 * flail),
            "bl_n": (v["bpx"], -v["bpy"]), "bl_f": (v["bpx"], -v["bpy"])}
    for leg, j in LEGS.items():
        front = leg.startswith("f")
        hip = body_pt(j[0])
        dx, dy = offs[leg]
        # Chân trước đi theo thân một phần (dồn trọng lượng), chân sau bám đất.
        paw = (j[3][0] + dx + (0.25 * shift if front else 0), j[3][1] + dy, j[3][2])
        ankle = (paw[0] + (j[2][0] - j[3][0]), paw[1] + (j[2][1] - j[3][1]), j[3][2])
        if front and v["air"] > 0:
            # Chân trước rời đất: cổ chân dần nằm trên đường vai → bàn (không gập ngược).
            lifted = (paw[0] + (hip[0] - paw[0]) * 0.3, paw[1] + (hip[1] - paw[1]) * 0.3)
            k = min(1.0, v["air"])
            ankle = (ankle[0] + (lifted[0] - ankle[0]) * k, ankle[1] + (lifted[1] - ankle[1]) * k, j[3][2])
        l1 = math.dist(j[1][:2], j[0][:2])
        l2 = math.dist(j[2][:2], j[1][:2])
        knee = two_bone(hip, ankle, l1, l2, -1 if front else 1)
        knee = (knee[0], knee[1], j[0][2])
        rig.set(leg + "_1", (hip[0], hip[1], j[0][2]), knee)
        rig.set(leg + "_2", knee, ankle)
        rig.set(leg + "_3", ankle, paw)

    # Đuôi: sóng chạy từ gốc ra chóp (chóp trễ nhất, giật mạnh nhất).
    prev = body_pt(TAIL[0])
    ang_acc = tilt
    for i in range(len(TAIL) - 1):
        a, b = TAIL[i], TAIL[i + 1]
        seg = Vector((b[0] - a[0], b[1] - a[1]))
        ang_acc += math.radians(v["lash"] * math.sin(t * 2 * math.pi - i * 0.6) * (i + 1) / 4)
        ang_acc += math.radians(v["tailup"] * (1 if i < 2 else 0.3))
        c, s = math.cos(ang_acc), math.sin(ang_acc)
        w = Vector((seg.x * c - seg.y * s, seg.x * s + seg.y * c))
        nxt = (prev[0] + w.x, prev[1] + w.y, 0)
        rig.set(f"tail_{i}", prev, nxt)
        prev = nxt


def tracks(scene, cam, rig, setups):
    """Độ dời (đơn vị sân khấu) của đầu (giữa xương đầu) và mũi chân trước
    gần so với dáng chờ, từng khung — vệt vuốt, sóng gầm, khiên trên sân khấu
    (lion_art.dart) bám đúng chỗ trong sprite."""
    from sprite_kit import _px, frame_scale
    _, ppu = frame_scale(scene, cam, P(0, 0), 50 * ln.LION_SCALE)
    pb = rig.arm.pose.bones
    mw = rig.arm.matrix_world

    def at():
        bpy.context.view_layer.update()
        h = _px(scene, cam, mw @ ((pb["head"].head + pb["head"].tail) / 2))
        p = _px(scene, cam, mw @ pb["fl_n_3"].tail)
        return h, p

    pose(rig, READY)
    h0, p0 = at()
    head, paw = [], []
    for setup in setups:
        setup()
        h, p = at()
        head.append([round((h.x - h0.x) / ppu, 1), round((h.y - h0.y) / ppu, 1)])
        paw.append([round((p.x - p0.x) / ppu, 1), round((p.y - p0.y) / ppu, 1)])
    return head, paw


def main():
    scene = reset_scene(samples=64, world_hex="#9DB6D2", world_strength=0.5)
    rig = build()
    ln.lights(scene)
    ln.shadow_floor()
    if TOON:
        toonify(scene)
    tag = "_toon" if TOON else ""
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "lion_tripo" + tag)
        setup_camera(scene, ln.FRAME_X, ln.FRAME_Y, px_per_unit=2.6, yaw=-14, pitch=6)
        render_stills(scene, out, [
            ("idle", lambda: pose(rig, idle_channels(0))),
            ("raise", lambda: pose(rig, ATTACK.at(0.47), 0.25)),
            ("strike", lambda: pose(rig, ATTACK.at(0.57), 0.25)),
            ("rake", lambda: pose(rig, ATTACK.at(0.66), 0.25)),
            ("crouch", lambda: pose(rig, POUNCE.at(0.45), 0.25)),
            ("pounce", lambda: pose(rig, POUNCE.at(0.6), 0.25)),
            ("wrestled", lambda: pose(rig, WRESTLED.at(0.45), 0.15)),
            ("buckle", lambda: pose(rig, DEFEAT.at(0.55), 0.25)),
            ("defeat", lambda: pose(rig, DEFEAT.at(1), 0.25)),
        ])
        pose(rig, READY)
        save_blend("nemea_lion_tripo" + tag)
        return
    cam = setup_camera(scene, ln.FRAME_X, ln.FRAME_Y, px_per_unit=2.2, yaw=-14, pitch=6)
    attack = [lambda p=p: pose(rig, ATTACK.at(p), 0.25 + p * 0.4) for p in ATTACK_PHASES]
    pounce = [lambda p=p: pose(rig, POUNCE.at(p), 0.25 + p * 0.4) for p in ATTACK_PHASES]
    anims = {
        "idle": [lambda k=k: pose(rig, idle_channels(k / 48), k / 48) for k in range(48)],
        "attack": attack,
        "defeat": [lambda k=k: pose(rig, DEFEAT.at(k / 19), 0.25 + k / 19 * 0.3) for k in range(20)],
        "pounce": pounce,
        "wrestled": [lambda k=k: pose(rig, WRESTLED.at(k / 23), k / 23 * 0.33) for k in range(24)],
    }
    head_a, paw_a = tracks(scene, cam, rig, attack)
    head_p, _ = tracks(scene, cam, rig, pounce)
    export_sprites(scene, cam, "nemea_lion" + tag, anims, P(0, 0), 50 * ln.LION_SCALE,
                   extra={"idlePeriod": 3.0, "headAttack": head_a, "pawAttack": paw_a, "headPounce": head_p,
                          "phases": {"attack": ATTACK_PHASES, "pounce": ATTACK_PHASES}})
    pose(rig, READY)
    save_blend("nemea_lion_tripo" + tag)


if __name__ == "__main__":
    main()
