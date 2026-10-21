"""Lính đá (màn 1.3 và 1.7) từ mô hình Tripo3D
(art_src/tripo/ancient warrior 3d model.glb): tượng hoplite cẩm thạch bị Trì
Trệ làm sống dậy. Thay bản người MPFB + đồ tạc của hoplite.py: cùng máy quay,
đèn, điểm neo, tỉ lệ → ghi đè atlas stone_soldier, sân khấu không phải đổi.

    bash tool/blender/render.sh stone_tripo --still   # vài khung xem nhanh
    bash tool/blender/render.sh stone_tripo           # ghi đè atlas

Tripo dựng người quay mặt về -Y: xoay -90° cho quay trái; tay khiên (trái)
về phía máy quay, tay giáo (phải) phía xa — như bản cũ. Giáo và khiên là
mảnh lưới riêng: gắn cứng vào xương riêng, đặt vào bàn tay mỗi khung, nên
giáo dựng đứng lúc đứng và chĩa ngang lúc đâm mà cẳng tay không phải bẻ.

Động tác theo biên đạo khoá (choreo_kit, xem ATTACK/RISE): idle (thế thủ
thở chậm), attack (đâm giáo qua vai kiểu hoplite: lấy đà – nén – bước dậm –
khựng – thu), rise (trồi lên từ đống đá: lúc mở màn và lúc ráp lại ở 1.7).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403
from human_kit import camera, shadow_catcher  # noqa: E402
from sprite_kit import export_sprites  # noqa: E402
from choreo_kit import Move  # noqa: E402
from tripo_kit import follow_nearest, import_tripo_upright, islands, pin_to_bone, smooth_weights  # noqa: E402

GLB = os.path.join(ROOT, "art_src", "tripo", "ancient warrior 3d model.glb")
HEIGHT = 110  # đơn vị vẽ (2,2 m), đỉnh mào mũ — như lính đá cũ
UNITS_PER_M = 66  # như hoplite.py: lính đá cao ~145 đơn vị sân khấu
K = 1.12  # khung máy quay như hoplite.py

# Khớp (đơn vị vẽ: x, y xuống, d chiều sâu) đọc trên ảnh nhìn ngang và nhìn
# trước có lưới. _n = phía gần máy quay (tay khiên, chân trái), _f = phía xa.
HIP = (8, -48, -8)
CHEST = (10, -82, -8)
NECK = (10, -84, -8)
CROWN = (6, -108, -8)
ARM = {
    "n": [(10, -80, -20), (8, -66, -24), (2, -56, -26)],
    "f": [(10, -80, 6), (8, -66, 8), (-10, -60, 10)],
}
LEG = {
    "n": [(8, -48, -16), (7, -27, -18), (8, -7, -19), (-3, -2, -19)],
    "f": [(8, -48, 0), (7, -27, 2), (8, -7, 2), (-3, -2, 2)],
}
GRIP = (-12, -60, 10)  # tay phải nắm giáo
SPEAR_UP = 48  # từ chỗ nắm tới mũi giáo
SHIELD = ((0, -58, -30), (0, -80, -30))  # tâm khiên → mép trên

BONES = {
    "spine": (HIP, CHEST),
    "head": (NECK, CROWN),
    "spear": (GRIP, (GRIP[0], GRIP[1] - SPEAR_UP, GRIP[2])),
    "shield": SHIELD,
}
for _s, _j in ARM.items():
    BONES[f"upperarm_{_s}"] = (_j[0], _j[1])
    BONES[f"forearm_{_s}"] = (_j[1], _j[2])
for _s, _j in LEG.items():
    BONES[f"thigh_{_s}"] = (_j[0], _j[1])
    BONES[f"shin_{_s}"] = (_j[1], _j[2])
    BONES[f"foot_{_s}"] = (_j[2], _j[3])


def side_filter(bone, p):
    """Giáo, khiên chỉ nhận đỉnh của mảnh riêng (gán sau). Tay/chân gần/xa
    chỉ nhận đỉnh cùng phía chiều sâu."""
    if bone in ("spear", "shield"):
        return False
    d = p.y / S
    if bone.endswith("_n") and d > -6:
        return False
    if bone.endswith("_f") and d < -10:
        return False
    return True


def build():
    mesh = import_tripo_upright(GLB, HEIGHT, rot_z=-90)
    rig = Rig("StoneRig", BONES)
    rig.skin(mesh, near_filter=side_filter)
    isl = islands(mesh)
    # Mảnh riêng: giáo là cột mảnh dựng đứng cao nhất, khiên là đĩa phía gần.
    co = [v.co / S for v in mesh.data.vertices]
    pins = []
    for k in range(1, 6):
        ids = [i for i in range(len(co)) if isl[i] == k]
        if not ids:
            continue
        xs = [co[i].x for i in ids]
        ds = [co[i].y for i in ids]
        zs = [co[i].z for i in ids]
        tall = max(zs) - min(zs) > 80 and max(xs) - min(xs) < 10
        disk = min(ds) < -25 and max(zs) - min(zs) > 30
        if tall:
            pins.append((ids, "spear"))
        elif disk:
            # Tripo dính ống chân + bàn chân vào cùng mảnh khiên: chỉ ghim
            # phần nằm trên mặt khiên, còn lại để da theo xương chân (trước
            # đây cả mảnh theo khiên → chân không bước được).
            pins.append(([i for i in ids if co[i].y < -23 and co[i].z > 30], "shield"))
    # Ghim sau khi làm mượt (không pha trọng số khiên với chân dính liền);
    # mảnh nhỏ còn lại (khoá ống đồng, quai, mào) đi theo chỗ cạnh nó.
    smooth_weights(mesh, islands_below=0)
    for ids, bone in pins:
        pin_to_bone(mesh, ids, bone)
    follow_nearest(mesh, isl, skip_groups=("spear", "shield"))
    rig.bind(mesh)
    return rig


# Biên đạo (choreo_kit): kênh theo đơn vị vẽ / độ, quanh dáng chờ READY.
#   hipx, hipy  dời hông (x âm = tới trước, y dương = hạ thấp)
#   tilt        ngả thân quanh hông (độ, + = ngả ra sau)
#   head        gằm đầu (độ, + = cúi nhìn qua vành khiên)
#   sink        cả tượng chìm trong đống đá (trồi lên)
#   nx, nl / fx, fl   bàn chân gần / xa: dời ngang, nhấc lên
#   hx, hy      tay giáo so với vai
#   spear       hướng giáo (độ: 90 = dựng đứng, 0 = chĩa thẳng tới, âm = chúc mũi)
#   sx, sy, srot      tay khiên: dời so với chỗ cũ, nghiêng khiên
# Tượng đá nặng: không nảy, không vọt; trọng tâm đi trước, tay sau, giáo và
# đầu trễ nhất — chậm, chắc, đúng kỹ thuật phalanx.
READY = dict(hipx=0, hipy=3, tilt=-2, head=2, sink=0, nx=0, nl=0, fx=0, fl=0,
             hx=-18, hy=17, spear=80, sx=-2, sy=-1, srot=0)
LAG = dict(tilt=0.008, sx=0.012, sy=0.012, srot=0.016, hx=0.02, hy=0.02, spear=0.03, head=0.035)

# Đòn đâm giáo hoplite (tiến độ sân khấu: lấy đà 0–0,5, ra đòn 0,5–0,65 —
# chạm ~0,55 — rồi thu về): hạ trọng tâm, nâng khiên → dồn sức chân sau,
# giương giáo qua vai cầm ngược tay (dory), mũi chĩa tới, nén thế → bước
# dậm chân trước, hông dẫn, thân đổ tới, tay duỗi phóng giáo ngang ngực →
# khựng ở đỉnh đòn → rút giáo, lùi chân về thế thủ.
ATTACK = Move(READY, [
    (0.10, dict(hipy=6, tilt=1, head=5, sx=-5, sy=-5, srot=-4, spear=74)),
    (0.26, dict(hipx=4, hipy=5, tilt=7, head=6, hx=-2, hy=-12, spear=40, sx=-7, sy=-7, srot=-6)),
    (0.40, dict(hipx=7, hipy=6, tilt=12, head=7, hx=6, hy=-29, spear=5, sx=-8, sy=-8, srot=-8, fx=1)),
    (0.48, dict(hipx=8, hipy=7, tilt=13, head=7, hx=7, hy=-30, spear=3, sx=-8, sy=-8, srot=-8, fx=1, nx=0, nl=0)),
    (0.52, dict(hipx=1, hipy=5, tilt=2, nx=-7, nl=4, hx=-8, hy=-19, spear=-6)),
    (0.56, dict(hipx=-9, hipy=7, tilt=-11, head=4, nx=-14, nl=0, fx=-2, hx=-30, hy=-7, spear=-10, sx=-3, sy=-5, srot=-2)),
    (0.66, dict(hipx=-10, hipy=8, tilt=-12, head=4, nx=-14, nl=0, fx=-2, hx=-31, hy=-6, spear=-11, sx=-3, sy=-5, srot=-2)),
    (0.78, dict(hipx=-5, hipy=6, tilt=-6, nx=-14, nl=0, fx=-1, hx=-17, hy=1, spear=22, sx=-4, sy=-4)),
    (0.86, dict(hipx=-2, hipy=4, nx=-7, nl=3, fx=0)),
    (0.93, dict(nx=0, nl=0, hx=-18, hy=15, spear=74)),
], LAG)

# Trồi lên từ dưới đất (kiểu xác sống trồi khỏi mộ; sân khấu vẽ thêm đất
# nứt, ụ đất, đá văng — nemea_monster_art _risingEarth): mũi giáo ló lên như
# đầu ngón tay → bàn tay nắm giáo vọt lên, cánh tay vươn thẳng, quơ quơ →
# mũ ngù trồi lên (đầu còn gằm) → vai, khiên; tay khiên chống đất đẩy người
# lên → đứng dậy, đầu ngẩng SAU CÙNG, vào thế thủ. Phần dưới mặt đất bị mặt
# hứng bóng che, nên trong sprite chỉ thấy phần đã trồi.
RISE = Move(READY, [
    (0.0, dict(sink=154, hipy=8, tilt=-22, head=34, hx=1, hy=-32, spear=92, sx=6, sy=10, srot=14)),
    (0.12, dict(sink=148, hx=1, hy=-32, spear=90)),
    (0.22, dict(sink=104, tilt=-24, head=36, hx=-3, hy=-33, spear=96)),
    (0.30, dict(sink=94, hx=-9, hy=-31, spear=106)),
    (0.38, dict(sink=89, hx=5, hy=-32, spear=80)),
    (0.46, dict(sink=80, tilt=-22, head=32, hx=-6, hy=-31, spear=100, sx=-6, sy=0, srot=6)),
    (0.56, dict(sink=58, hipy=10, tilt=-20, head=30, hx=-10, hy=-24, spear=96, sx=-16, sy=-2, srot=2)),
    (0.68, dict(sink=30, hipy=13, tilt=-16, head=24, hx=-14, hy=4, spear=94, sx=-14, sy=6, srot=0)),
    (0.80, dict(sink=6, hipy=12, tilt=-8, head=16, hx=-17, hy=14, spear=86, sx=-6, sy=2, srot=-1)),
    (0.90, dict(sink=0, hipy=6, tilt=-3, head=8, hx=-18, hy=17, spear=80, sx=-3, sy=-1, srot=0)),
], dict(LAG, head=0.08, spear=0.03))


def idle_channels(t):
    """Thế thủ thở chậm: trọng tâm đổi nhẹ trước–sau, mũi giáo lượn vòng nhỏ
    theo sau, khiên chỉnh theo — vòng lặp liền (hàm của 2πt)."""
    a = 2 * math.pi * t
    v = dict(READY)
    v.update(
        hipx=READY["hipx"] + 1.2 * math.sin(a),
        hipy=READY["hipy"] + 0.8 * math.sin(2 * a),
        tilt=READY["tilt"] + 1.5 * math.sin(a - 0.5),
        head=READY["head"] + 2.0 * math.sin(a - 1.2),
        hx=READY["hx"] + 1.0 * math.sin(a - 0.8),
        hy=READY["hy"] - 0.8 * math.cos(a - 0.8),
        spear=READY["spear"] + 4.0 * math.sin(a - 1.4),
        sx=READY["sx"] + 0.8 * math.sin(a - 0.6),
        srot=READY["srot"] + 2.0 * math.sin(a - 1.0),
    )
    return v


def pose(rig, v):
    """Đặt dáng theo kênh biên đạo [v] (xem READY)."""
    rig.rest()
    tilt = math.radians(v["tilt"])
    sink = v["sink"]

    def body_pt(p):
        q = rot2(p, HIP[:2], tilt)
        return (q[0] + v["hipx"], q[1] + v["hipy"] + sink, p[2])

    rig.set("spine", body_pt(HIP), body_pt(CHEST))
    neck = body_pt(NECK)
    crown = (neck[0] + CROWN[0] - NECK[0], neck[1] + CROWN[1] - NECK[1], NECK[2])
    rig.set("head", neck, rot2(crown, neck, tilt - math.radians(v["head"])))

    # Chân: IK, bàn chân bám đất (chìm theo sink lúc trồi lên); bước = nhấc chân.
    for s, j in LEG.items():
        hip = body_pt(j[0])
        paw = (j[3][0] + v[s + "x"], j[3][1] + sink - v[s + "l"], j[3][2])
        ankle = (paw[0] + j[2][0] - j[3][0], paw[1] + j[2][1] - j[3][1], j[2][2])
        l1 = math.dist(j[0][:2], j[1][:2])
        l2 = math.dist(j[1][:2], j[2][:2])
        knee = two_bone(hip, ankle, l1, l2, 1)  # gối chĩa tới trước
        knee = (knee[0], knee[1], j[1][2])
        rig.set(f"thigh_{s}", (hip[0], hip[1], j[0][2]), knee)
        rig.set(f"shin_{s}", knee, ankle)
        rig.set(f"foot_{s}", ankle, paw)

    def arm(s, hand):
        j = ARM[s]
        sh = body_pt(j[0])
        l1 = math.dist(j[0][:2], j[1][:2])
        l2 = math.dist(j[1][:2], j[2][:2])
        el = two_bone(sh, hand, l1, l2, -1)  # khuỷu chĩa xuống, ra sau
        el = (el[0], el[1], j[1][2])
        rig.set(f"upperarm_{s}", sh, el)
        rig.set(f"forearm_{s}", el, (hand[0], hand[1], j[2][2]))

    # Tay giáo: vị trí nắm so với vai; giáo xoay quanh chỗ nắm.
    sh = body_pt(ARM["f"][0])
    hand = (sh[0] + v["hx"], sh[1] + v["hy"])
    arm("f", hand)
    grip = (hand[0] - 2, hand[1], GRIP[2])
    a = math.radians(v["spear"])
    rig.set("spear", grip, (grip[0] - math.cos(a) * SPEAR_UP, grip[1] - math.sin(a) * SPEAR_UP, GRIP[2]))

    # Tay khiên: khiên che ngực, nâng lên lúc lấy đà, nghiêng theo thân.
    rh = body_pt(ARM["n"][2])
    hand_n = (rh[0] + v["sx"], rh[1] + v["sy"])
    arm("n", hand_n)
    c0, c1 = SHIELD
    off = (c0[0] - ARM["n"][2][0], c0[1] - ARM["n"][2][1])
    center = (hand_n[0] + off[0], hand_n[1] + off[1], c0[2])
    rig.set("shield", center, rot2((center[0], center[1] + c1[1] - c0[1], c0[2]), center, tilt + math.radians(v["srot"])))


def spear_tips(scene, cam, rig, setups):
    """Mũi giáo (đơn vị sân khấu quanh chân) từng khung đòn — sân khấu loé
    sao báo đòn đúng chỗ mũi giáo trong sprite (_spearGlint)."""
    from sprite_kit import _px, frame_scale
    anchor, ppu = frame_scale(scene, cam, (0, 0, 0), UNITS_PER_M)
    out = []
    for setup in setups:
        setup()
        bpy.context.view_layer.update()
        p = _px(scene, cam, rig.arm.matrix_world @ rig.arm.pose.bones["spear"].tail)
        out.append([round((p.x - anchor.x) / ppu, 1), round((p.y - anchor.y) / ppu, 1)])
    return out


def lights(scene):
    # Như hoplite.py: nắng ấm trên-trái, viền lạnh làm nổi đá.
    add_sun(scene, "Key", (0.55, 0.6, -0.6), 4.0, "#FFE0B4", angle=2.5)
    add_sun(scene, "Rim", (0.7, -0.4, -0.35), 3.5, "#C8D8FF", angle=4)
    add_sun(scene, "Bounce", (-0.1, 0.3, 0.9), 0.5, "#C8A880", angle=30)


def main():
    scene = reset_scene(samples=64, world_hex="#9DB6D2", world_strength=0.5)
    rig = build()
    lights(scene)
    shadow_catcher()
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "stone_tripo")
        os.makedirs(out, exist_ok=True)
        camera(scene, -0.45 * K, 1.0 * K, 3.0 * K, 2.3 * K, 300)
        for name, v in (("idle", idle_channels(0)), ("raise", ATTACK.at(0.26)), ("coil", ATTACK.at(0.47)),
                        ("step", ATTACK.at(0.53)), ("strike", ATTACK.at(0.6)),
                        ("recover", ATTACK.at(0.82)), ("rise_tip", RISE.at(0.12)), ("rise_hand", RISE.at(0.3)),
                        ("rise_helm", RISE.at(0.48)), ("rise_push", RISE.at(0.66)), ("rise_up", RISE.at(0.82))):
            pose(rig, v)
            render_to(scene, os.path.join(out, f"stone_{name}.png"))
        pose(rig, READY)
        save_blend("stone_soldier_tripo")
        return
    cam = camera(scene, -0.45 * K, 1.0 * K, 3.0 * K, 2.3 * K, 200)
    attack = [lambda k=k: pose(rig, ATTACK.at(k / 19)) for k in range(20)]
    anims = {
        "idle": [lambda k=k: pose(rig, idle_channels(k / 8)) for k in range(8)],
        "attack": attack,
        "rise": [lambda k=k: pose(rig, RISE.at(k / 15)) for k in range(16)],
    }
    tips = spear_tips(scene, cam, rig, attack)
    export_sprites(scene, cam, "stone_soldier", anims, (0, 0, 0), UNITS_PER_M,
                   extra={"idlePeriod": 3.2, "spearTip": tips})
    pose(rig, READY)
    save_blend("stone_soldier_tripo")


if __name__ == "__main__":
    main()
