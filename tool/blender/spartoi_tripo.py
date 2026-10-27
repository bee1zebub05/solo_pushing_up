"""Spartoi (màn 1.2) từ mô hình Tripo3D (art_src/tripo/spartoi_3d_model.glb):
chiến binh đất sét khô nứt nẻ mọc lên từ răng rồng gieo xuống ruộng, giáp
đồng gỉ xanh, mũ mào răng rồng, khiên khắc rồng. Thay bản MPFB + đồ tạc của
hoplite.py --spartoi: cùng máy quay, đèn, điểm neo, tỉ lệ, tên atlas
`spartoi` (idle, attack, rise) → sân khấu không phải đổi.

    bash tool/blender/render.sh spartoi_tripo --still   # vài khung xem nhanh
    bash tool/blender/render.sh spartoi_tripo           # ghi đè atlas
    bash tool/blender/render.sh spartoi_tripo --toon    # bản 2.5D

Cùng khuôn xương với lính đá (stone_tripo.py): giáo tay phía xa, khiên tay
phía gần máy quay, gắn xương riêng. Khác hẳn ở biên đạo: lính đá là tượng
nặng, đâm giáo ngang qua vai, bò lên khỏi đất giơ tay như xác sống; Spartoi
là thứ vừa mọc từ răng rồng — khom, giật cục, NHẢY BỔ cắm giáo từ trên
xuống, trồi lên như mầm (mào răng rồng nhú trước) rồi bật vọt cả người.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403
from human_kit import camera, shadow_catcher  # noqa: E402
from sprite_kit import export_sprites  # noqa: E402
from motion_kit import Move, dense_phases  # noqa: E402
from toon_kit import TOON, toonify  # noqa: E402
from tripo_kit import follow_nearest, import_tripo_upright, islands, pin_to_bone, smooth_weights  # noqa: E402

GLB = os.path.join(ROOT, "art_src", "tripo", "spartoi_3d_model.glb")
HEIGHT = 104  # đơn vị vẽ, đỉnh mào răng rồng — như Spartoi cũ (K 1,05 / lính đá 1,12)
UNITS_PER_M = 66  # như hoplite.py
K = 1.05  # khung máy quay như hoplite.py --spartoi

# Khớp (đơn vị vẽ: x, y xuống, d chiều sâu) đọc trên ảnh nhìn ngang và nhìn
# trước có lưới. _n = phía gần máy quay (tay khiên, chân trái), _f = phía xa.
HIP = (6, -46, 3)
CHEST = (6, -76, 3)
NECK = (6, -80, 3)
CROWN = (5, -104, 3)
ARM = {
    "n": [(6, -77, -10), (5, -66, -14), (2, -56, -17)],
    "f": [(6, -77, 20), (4, -68, 26), (-9, -63, 30)],
}
LEG = {
    "n": [(6, -46, -6), (8, -27, -7), (6, -6, -8), (-6, -1, -8)],
    "f": [(6, -46, 13), (8, -27, 14), (6, -6, 15), (-6, -1, 15)],
}
GRIP = (-9, -63, 30)  # tay phải nắm giáo
SPEAR_UP = 41  # từ chỗ nắm tới mũi giáo
WRIST = 6  # độ gập cổ tay tối đa so với tư thế cầm gốc (gần như thẳng)
SHIELD = ((2, -52, -22), (2, -69, -22))  # tâm khiên → mép trên

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
    if bone.endswith("_n") and d > 1:
        return False
    if bone.endswith("_f") and d < 5:
        return False
    return True


def build():
    mesh = import_tripo_upright(GLB, HEIGHT, rot_z=-90)
    rig = Rig("SpartoiRig", BONES)
    rig.skin(mesh, near_filter=side_filter)
    isl = islands(mesh)
    # Mảnh riêng: giáo là cột mảnh dựng đứng cao nhất, khiên là đĩa phía gần.
    co = [v.co / S for v in mesh.data.vertices]
    pins = []
    sizes = {}
    for i, k in enumerate(isl):
        sizes.setdefault(int(k), []).append(i)
    for k, ids in sorted(sizes.items(), key=lambda kv: -len(kv[1]))[:8]:
        xs = [co[i].x for i in ids]
        ds = [co[i].y for i in ids]
        zs = [co[i].z for i in ids]
        tall = max(zs) - min(zs) > 70 and max(xs) - min(xs) < 10
        disk = sum(ds) / len(ds) < -12 and max(zs) - min(zs) > 25
        print("ISLAND", k, len(ids), "x", round(min(xs)), round(max(xs)), "d", round(min(ds)), round(max(ds)),
              "z", round(min(zs)), round(max(zs)), "spear" if tall else "shield" if disk else "")
        if tall:
            pins.append((ids, "spear"))
        elif disk:
            # Chỉ phần nằm trên mặt khiên (Tripo hay dính tay/chân vào mảnh khiên).
            pins.append(([i for i in ids if co[i].y < -15 and co[i].z > 30], "shield"))
    # Ghim sau khi làm mượt (không pha trọng số khiên với chân dính liền);
    # mảnh nhỏ còn lại (khoá ống đồng, quai, mào) đi theo chỗ cạnh nó.
    smooth_weights(mesh, islands_below=0)
    for ids, bone in pins:
        pin_to_bone(mesh, ids, bone)
    follow_nearest(mesh, isl, skip_groups=("spear", "shield"))
    # Nắm tay phải ghim vào giáo (luôn ôm cán), cổ tay pha trộn giáo/cẳng tay
    # cho chỗ nối cong mềm. Ghim SAU follow_nearest: ngón tay là mảnh nhỏ,
    # bước đó sẽ ghi đè trọng số.
    spear_ids = {i for ids, bone in pins if bone == "spear" for i in ids}
    fist, wrist = [], []
    for i, c in enumerate(co):
        if i in spear_ids:
            continue
        r = math.dist((c.x, -c.z, c.y), GRIP)
        if r < 5.0:
            fist.append(i)
        elif r < 8.5 and c.x > GRIP[0]:
            wrist.append(i)
    pin_to_bone(mesh, fist, "spear")
    for g in mesh.vertex_groups:
        if g.name in ("spear", "forearm_f"):
            g.add(wrist, 0.5, "REPLACE")
        else:
            g.remove(wrist)
    rig.bind(mesh)
    return rig


# Biên đạo (motion_kit): kênh theo đơn vị vẽ / độ, quanh dáng chờ READY.
#   hipx, hipy  dời hông (x âm = tới trước, y dương = hạ thấp)
#   tilt        ngả thân quanh hông (độ, + = ngả ra sau, âm = khom tới)
#   head        gằm đầu (độ, + = cúi)
#   sink        cả người chìm dưới đất (trồi lên)
#   nx, nl / fx, fl   bàn chân gần / xa: dời ngang, nhấc lên
#   hx, hy      tay giáo so với vai
#   spear       hướng giáo (độ: 90 = dựng đứng, 0 = chĩa thẳng tới, âm = chúc mũi)
#   sx, sy, srot      tay khiên: dời so với chỗ cũ, nghiêng khiên
# Spartoi: vừa chui khỏi đất, khom như thú săn, hung hăng mà vụng — giật
# cục (khoá sát nhau), đầu lắc, mũi giáo chúc thấp chĩa tới.
READY = dict(hipx=-1, hipy=3, tilt=-8, head=6, sink=0, nx=-3, nl=0, fx=1, fl=0,
             hx=-22, hy=10, spear=55, sx=-3, sy=0, srot=-4, grip=0)
LAG = dict(tilt=0.006, sx=0.01, sy=0.01, srot=0.014, hx=0.012, hy=0.012, spear=0.02, head=0.03)

# Nhảy bổ cắm giáo (khác hẳn cú đâm ngang qua vai của lính đá): giương giáo
# cầm ngược lên quá đầu, mũi chúc xuống; khiên thúc tới mở đường; nhún sâu
# → bật nhảy bổ tới (hai chân rời đất) → đáp khuỵu, cắm giáo từ trên xuống
# → khựng → giằng giáo khỏi đất, lắc đầu, khom lại. Tiến độ sân khấu, chạm ~0,55.
ATTACK = Move(READY, [
    (0.06, dict(hipy=5, tilt=-10, head=8, hx=-16, hy=4, grip=0)),
    (0.18, dict(hipy=5, tilt=-8, head=6, hx=-14, hy=-6, grip=1, spear=-40, sx=-6, sy=-4, srot=-6)),
    (0.30, dict(hipy=9, tilt=-6, head=6, hx=-2, hy=-34, spear=10, sx=-14, sy=-8, srot=-10, nx=-6)),
    (0.38, dict(hipy=10, tilt=-12, sx=-6, sy=-4, srot=-4)),
    (0.46, dict(hipx=4, hipy=12, tilt=-14, head=8, hx=2, hy=-30, spear=12, sx=-10, sy=-8, nx=-4, fx=2)),
    (0.50, dict(hipx=4, hipy=12, tilt=-14, head=8, hx=2, hy=-30, spear=12, sx=-10, sy=-8, nx=-4, fx=2)),
    (0.53, dict(hipx=-10, hipy=-1, tilt=-6, head=0, nx=-14, nl=7, fx=-8, fl=6, hx=-14, hy=-22, spear=-20)),
    (0.57, dict(hipx=-20, hipy=12, tilt=-26, head=10, nx=-20, nl=0, fx=-10, fl=0, hx=-30, hy=-2, spear=-65,
                sx=-4, sy=-2, srot=-2)),
    (0.66, dict(hipx=-21, hipy=13, tilt=-27, head=12, nx=-20, fx=-10, hx=-30, hy=-1, spear=-66)),
    (0.74, dict(hipx=-16, hipy=10, tilt=-18, head=4, hx=-22, hy=4, spear=-40)),
    (0.80, dict(head=16, grip=1)),
    (0.90, dict(hipx=-6, hipy=6, tilt=-10, head=2, nx=-8, nl=4, fx=-2, fl=3, hx=-20, hy=8, spear=55, grip=0)),
    (0.95, dict(hipx=-1, nx=-3, nl=0, fx=1, fl=0, head=6)),
], LAG)

# Trồi lên kiểu mầm răng rồng (khác lính đá bò lên giơ tay như xác sống):
# mào răng rồng nhú lên khỏi ruộng như mầm cây, đất rung một nhịp → cả người
# BẬT VỌT lên một phát, ngửa đầu, dang tay giáo và khiên → đáp khuỵu, gằm
# đầu vào thế khom. Mở màn và khi đứng dậy sau lần ngã đầu (ReviveOnce).
RISE = Move(READY, [
    (0.0, dict(sink=150, hipy=6, tilt=-6, head=20, hx=-6, hy=30, spear=90, sx=0, sy=4, srot=0)),
    (0.22, dict(sink=90, head=22)),
    (0.34, dict(sink=84, head=24)),
    (0.42, dict(sink=87, head=22)),
    (0.48, dict(sink=82, head=24)),
    (0.56, dict(sink=12, hipy=0, tilt=8, head=-22, hx=-12, hy=-34, spear=100, sx=-18, sy=-16, srot=-20,
                nl=6, fl=6)),
    (0.66, dict(sink=0, hipy=-2, tilt=6, head=-18, nl=5, fl=5)),
    (0.76, dict(sink=0, hipy=12, tilt=-18, head=16, hx=-20, hy=6, spear=70, sx=-8, sy=2, srot=-4, nl=0, fl=0)),
    (0.88, dict(hipy=6, tilt=-10, head=8)),
], dict(LAG, head=0.03, spear=0.03))


ATTACK_PHASES = dense_phases(0.035, 0.46, 0.70, 0.016)  # 39 khung, 15 quanh cú đánh


def idle_channels(t):
    """Khom thở dồn như thú sắp vồ: vai nhấp, đầu giật nhẹ hai nhịp mỗi chu kỳ,
    mũi giáo đảo thấp, khiên chỉnh theo — vòng lặp liền (hàm của 2πt)."""
    a = 2 * math.pi * t
    twitch = max(0.0, math.sin(2 * a)) ** 8
    v = dict(READY)
    v.update(
        hipx=READY["hipx"] + 1.0 * math.sin(a),
        hipy=READY["hipy"] + 1.2 * math.sin(2 * a),
        tilt=READY["tilt"] + 2.0 * math.sin(a - 0.5),
        head=READY["head"] + 3.0 * math.sin(a - 1.0) - 8 * twitch,
        hx=READY["hx"] + 1.5 * math.sin(a - 0.8),
        hy=READY["hy"] - 1.0 * math.cos(a - 0.8),
        spear=READY["spear"] + 6.0 * math.sin(a - 1.3),
        sx=READY["sx"] + 1.0 * math.sin(a - 0.6),
        srot=READY["srot"] + 3.0 * math.sin(a - 1.0),
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
        return el

    # Tay giáo: IK tới vị trí nắm (hx, hy). Giáo nằm trong nắm tay nên xoay
    # theo cẳng tay như lúc cầm gốc; [grip] 0 = cầm xuôi (mũi giáo phía ngón
    # cái, như mô hình), 1 = cầm ngược (mũi chúc phía ngón út — đâm từ trên
    # xuống mà cổ tay vẫn thẳng); giữa hai giá trị = xoay giáo trong tay. Cổ
    # tay chỉ gập thêm tối đa ±WRIST độ về hướng biên đạo [spear].
    def deg(p, q):
        return math.degrees(math.atan2(-(q[1] - p[1]), -(q[0] - p[0])))

    sh = body_pt(ARM["f"][0])
    hand = (sh[0] + v["hx"], sh[1] + v["hy"])
    el = arm("f", hand)
    grip = (hand[0], hand[1], GRIP[2])  # tâm nắm tay (GRIP trùng ngọn cẳng tay)
    natural = 90 + deg(el, hand) - deg(ARM["f"][1], ARM["f"][2]) + 180 * v["grip"]
    diff = (v["spear"] - natural + 180) % 360 - 180
    a = math.radians(natural + max(-WRIST, min(WRIST, diff)))
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
    if TOON:
        toonify(scene, block=4, colors=12)  # giữ hoa văn khiên, vân đất nứt
    tag = "_toon" if TOON else ""
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "spartoi_tripo" + tag)
        os.makedirs(out, exist_ok=True)
        camera(scene, -0.45 * K, 1.0 * K, 3.0 * K, 2.3 * K, 300)
        for name, v in (("idle", idle_channels(0)), ("raise", ATTACK.at(0.22)), ("coil", ATTACK.at(0.48)),
                        ("leap", ATTACK.at(0.53)), ("strike", ATTACK.at(0.6)), ("recover", ATTACK.at(0.8)),
                        ("rise_sprout", RISE.at(0.3)), ("rise_burst", RISE.at(0.6)), ("rise_land", RISE.at(0.78))):
            pose(rig, v)
            render_to(scene, os.path.join(out, f"spartoi_{name}.png"))
        pose(rig, READY)
        save_blend("spartoi_tripo" + tag)
        return
    cam = camera(scene, -0.45 * K, 1.0 * K, 3.0 * K, 2.3 * K, 200)
    attack = [lambda p=p: pose(rig, ATTACK.at(p)) for p in ATTACK_PHASES]
    anims = {
        "idle": [lambda k=k: pose(rig, idle_channels(k / 40)) for k in range(40)],
        "attack": attack,
        "rise": [lambda k=k: pose(rig, RISE.at(k / 25)) for k in range(26)],
    }
    tips = spear_tips(scene, cam, rig, attack)
    export_sprites(scene, cam, "spartoi" + tag, anims, (0, 0, 0), UNITS_PER_M,
                   extra={"idlePeriod": 2.4, "spearTip": tips, "phases": {"attack": ATTACK_PHASES}})
    pose(rig, READY)
    save_blend("spartoi_tripo" + tag)


if __name__ == "__main__":
    main()
