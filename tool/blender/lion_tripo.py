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


def phases(attack=-1.0, pounce=-1.0, wrestled=-1.0):
    """(lấy đà, ra đòn, nhảy, bị vật) 0–1 theo tiến độ từng động tác."""
    windup = strike = leap = pinned = 0.0
    p = attack if attack >= 0 else pounce
    if p >= 0:
        windup = smooth(p / 0.4) if p < 0.4 else (1 - smooth((p - 0.4) / 0.15) if p < 0.55 else 0)
        hit = 0 if p < 0.4 else (smooth((p - 0.4) / 0.15) if p < 0.55 else 1 - smooth((p - 0.55) / 0.45))
        if attack >= 0:
            strike = hit
        else:
            leap = hit
    if wrestled >= 0:
        pinned = smooth(wrestled / 0.25) * (1 - smooth((wrestled - 0.7) / 0.3))
    return windup, strike, leap, pinned


def pose(rig, t=0.0, attack=-1.0, defeat=0.0, pounce=-1.0, wrestled=-1.0):
    """Dáng tại một khung. attack: vồ cào bằng chân trước gần (pha 1);
    pounce: nhảy chồm cả hai chân trước (pha 2); wrestled: bị vật, chồm ngửa
    ra sau, chân trước quẫy; defeat: khuỵu nằm rạp, đầu gục."""
    rig.rest()
    breath = math.sin(t * 2 * math.pi) * 0.5 + 0.5
    fall = smooth(defeat)
    windup, strike, leap, pinned = phases(attack, pounce, wrestled)
    crouch = windup * (1.4 if pounce >= 0 else 1)
    roar = max(0.22, strike, leap, pinned, windup * 0.5) * (1 - fall * 0.6)

    shift = 10 * crouch - 18 * strike - 40 * leap + 16 * pinned + 10 * fall
    drop = 6 * crouch - 26 * leap + 6 * pinned + 34 * fall - breath * 1.5
    tilt = math.radians(-3 * strike + 4 * crouch + 12 * leap + 24 * pinned + 2 - 4 * fall)

    def body_pt(p):
        q = rot2(p, PIVOT, tilt)
        return (q[0] + shift, q[1] + drop, p[2])

    rig.set("body", body_pt(BONES["body"][0]), body_pt(BONES["body"][1]))
    rig.set("chest", body_pt(BONES["chest"][0]), body_pt(BONES["chest"][1]))

    # Đầu: rình thấp; lấy đà ngóc; vồ chúi; bị vật ngửa ra sau; gục sát đất.
    head_dx = -16 * strike - 10 * leap + 6 * pinned + 4 * crouch - 6 * fall
    head_dy = 4 * crouch + 22 * fall - 8 * pinned + math.sin(t * 2 * math.pi) * 1.2
    head_rot = math.radians(-14 * fall + 3 * crouch - 6 * strike - 4 * leap + 22 * pinned)
    nb = BONES["neck"]
    neck_a = body_pt(nb[0])
    hb = BONES["head"]
    h0b = body_pt(hb[0])
    h0 = (h0b[0] + head_dx, h0b[1] + head_dy, 0)
    rig.set("neck", neck_a, h0)
    h1 = rot2((h0[0] + hb[1][0] - hb[0][0], h0[1] + hb[1][1] - hb[0][1], 0), h0, head_rot + tilt)
    rig.set("head", h0, h1)
    jb = BONES["jaw"]
    j0 = rot2((h0[0] + jb[0][0] - hb[0][0], h0[1] + jb[0][1] - hb[0][1], 0), h0, head_rot + tilt)
    j1 = (j0[0] + jb[1][0] - jb[0][0], j0[1] + jb[1][1] - jb[0][1], 0)
    # Mô hình há sẵn: đứng chờ khép bớt (gầm gừ), gầm thì há rộng thêm.
    jaw = math.radians(12 * (1 - roar) - 10 * roar)
    rig.set("jaw", j0, rot2(j1, j0, head_rot + tilt + jaw))

    swipe = strike * (1 - fall)
    flail = math.sin(t * 2 * math.pi * 3 + 1.0)
    for leg, j in LEGS.items():
        front = leg.startswith("f")
        hip = body_pt(j[0])
        paw = list(j[3])
        if front:
            near = leg == "fl_n"
            paw[0] += 10 * crouch - 34 * fall
            if near:
                # Vồ cào: chân trước gần vung ra trước, lên cao.
                paw = [paw[0] + (-150 - paw[0]) * swipe, paw[1] + (-60 - paw[1]) * swipe, j[3][2]]
            # Nhảy: hai chân trước duỗi vươn ra trước.
            reach = (-158, -70) if near else (-150, -58)
            paw = [paw[0] + (reach[0] - paw[0]) * leap, paw[1] + (reach[1] - paw[1]) * leap, j[3][2]]
            # Bị vật: hai chân trước co lên ngực, quẫy.
            claw = (-58 + 6 * flail, -84 - 6 * flail) if near else (-76 - 5 * flail, -78 + 5 * flail)
            claw = (claw[0] + shift, claw[1] + drop)
            paw = [paw[0] + (claw[0] - paw[0]) * pinned, paw[1] + (claw[1] - paw[1]) * pinned, j[3][2]]
        else:
            # Nhảy: chân sau đạp ra sau, rời đất.
            paw[0] += 8 * fall + 30 * leap
            paw[1] -= 14 * leap
        ankle = (paw[0] + (j[2][0] - j[3][0]), paw[1] + (j[2][1] - j[3][1]), j[3][2])
        if front and (leap > 0 or pinned > 0):
            # Chân trước rời đất: cổ chân nằm trên đường vai → bàn (không gập ngược).
            ankle = (paw[0] + (hip[0] - paw[0]) * 0.3, paw[1] + (hip[1] - paw[1]) * 0.3, j[3][2])
        l1 = math.dist(j[1][:2], j[0][:2])
        l2 = math.dist(j[2][:2], j[1][:2])
        knee = two_bone(hip, ankle, l1, l2, -1 if front else 1)
        knee = (knee[0], knee[1], j[0][2])
        rig.set(leg + "_1", (hip[0], hip[1], j[0][2]), knee)
        rig.set(leg + "_2", knee, ankle)
        rig.set(leg + "_3", ankle, tuple(paw))

    # Đuôi: vẫy theo nhịp thở, quất mạnh khi lấy đà/nhảy, rũ khi gục.
    prev = body_pt(TAIL[0])
    ang_acc = 0.0
    lash = 7 + 10 * crouch + 8 * leap + 10 * pinned
    for i in range(len(TAIL) - 1):
        a, b = TAIL[i], TAIL[i + 1]
        seg = Vector((b[0] - a[0], b[1] - a[1]))
        ang_acc += math.radians(lash * math.sin(t * 2 * math.pi + i * 0.6) * (i + 1) / 4)
        ang_acc += math.radians(20 * fall * (1 if i < 2 else 0.3))
        if i == 0:
            # Gốc đuôi theo hông khi thân ngóc/chúi.
            ang_acc += tilt
        c, s = math.cos(ang_acc), math.sin(ang_acc)
        v = Vector((seg.x * c - seg.y * s, seg.x * s + seg.y * c))
        nxt = (prev[0] + v.x, prev[1] + v.y, 0)
        rig.set(f"tail_{i}", prev, nxt)
        prev = nxt


def main():
    scene = reset_scene(samples=64, world_hex="#9DB6D2", world_strength=0.5)
    rig = build()
    ln.lights(scene)
    ln.shadow_floor()
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "lion_tripo")
        setup_camera(scene, ln.FRAME_X, ln.FRAME_Y, px_per_unit=2.6, yaw=-14, pitch=6)
        render_stills(scene, out, [
            ("idle", lambda: pose(rig, 0)),
            ("windup", lambda: pose(rig, 0.25, attack=0.38)),
            ("strike", lambda: pose(rig, 0.25, attack=0.55)),
            ("defeat", lambda: pose(rig, 0.25, defeat=1)),
            ("pounce", lambda: pose(rig, 0.25, pounce=0.55)),
            ("wrestled", lambda: pose(rig, 0.25, wrestled=0.45)),
        ])
        pose(rig, 0)
        save_blend("nemea_lion_tripo")
        return
    cam = setup_camera(scene, ln.FRAME_X, ln.FRAME_Y, px_per_unit=2.2, yaw=-14, pitch=6)
    anims = {
        "idle": [lambda k=k: pose(rig, k / 8) for k in range(8)],
        "attack": [lambda k=k: pose(rig, 0.25, attack=k / 11) for k in range(12)],
        "defeat": [lambda k=k: pose(rig, 0.25, defeat=k / 6) for k in range(7)],
        "pounce": [lambda k=k: pose(rig, 0.25, pounce=k / 11) for k in range(12)],
        "wrestled": [lambda k=k: pose(rig, k / 9 * 0.33, wrestled=k / 9) for k in range(10)],
    }
    export_sprites(scene, cam, "nemea_lion", anims, P(0, 0), 50 * ln.LION_SCALE, extra={"idlePeriod": 3.0})
    pose(rig, 0)
    save_blend("nemea_lion_tripo")


if __name__ == "__main__":
    main()
