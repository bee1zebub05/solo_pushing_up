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

Động tác: idle, attack (thế đâm từ trên vai của hoplite), rise (trồi lên
từ đống đá: lúc mở màn và lúc ráp lại ở màn 1.7).
"""

import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403
from human_kit import camera, shadow_catcher  # noqa: E402
from sprite_kit import export_sprites  # noqa: E402
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
            pin_to_bone(mesh, ids, "spear")
        elif disk:
            pin_to_bone(mesh, ids, "shield")
    # Mảnh nhỏ còn lại (khoá ống đồng, quai, mào): đi theo chỗ thân cạnh nó.
    smooth_weights(mesh, islands_below=0)
    follow_nearest(mesh, isl, skip_groups=("spear", "shield"))
    rig.bind(mesh)
    return rig


def pose(rig, t=0.0, attack=-1.0, rise=1.0):
    """Đứng thủ thế; lấy đà = ngả người, giương giáo lên vai, mũi giáo chĩa
    tới; ra đòn = bước lao, đâm thẳng; rise 0 → 1: trồi lên từ đống đá."""
    rig.rest()
    windup, strike, recover = attack_pose(attack)
    breath = math.sin(t * 2 * math.pi)
    sink = 62 * (1 - smooth(rise))
    tilt = math.radians(5 * windup - 10 * strike + 18 * (1 - rise))
    shift = 3 * windup - 10 * strike
    lift = -0.6 * breath  # ngực phồng nhẹ khi thở

    def body_pt(p, chest=False):
        q = rot2(p, HIP[:2], tilt)
        return (q[0] + shift, q[1] + sink + (lift if chest else 0), p[2])

    rig.set("spine", body_pt(HIP), body_pt(CHEST, True))
    neck = body_pt(NECK, True)
    head_rot = math.radians(-4 * strike + 3 * windup)
    rig.set("head", neck, rot2((neck[0] + CROWN[0] - NECK[0], neck[1] + CROWN[1] - NECK[1], NECK[2]), neck, tilt + head_rot))

    # Chân: bàn chân bám đất (trừ khi đang trồi lên), chân gần bước tới khi đâm.
    for s, j in LEG.items():
        hip = body_pt(j[0])
        step = -8 * strike if s == "n" else 0
        paw = (j[3][0] + step + shift * 0.3, j[3][1] + sink, j[3][2])
        ankle = (paw[0] + j[2][0] - j[3][0], paw[1] + j[2][1] - j[3][1], j[2][2])
        l1 = math.dist(j[0][:2], j[1][:2])
        l2 = math.dist(j[1][:2], j[2][:2])
        knee = two_bone(hip, ankle, l1, l2, -1)
        knee = (knee[0], knee[1], j[1][2])
        rig.set(f"thigh_{s}", (hip[0], hip[1], j[0][2]), knee)
        rig.set(f"shin_{s}", knee, ankle)
        rig.set(f"foot_{s}", ankle, paw)

    def arm(s, hand):
        j = ARM[s]
        sh = body_pt(j[0], True)
        l1 = math.dist(j[0][:2], j[1][:2])
        l2 = math.dist(j[1][:2], j[2][:2])
        el = two_bone(sh, hand, l1, l2, -1)  # khuỷu chĩa xuống, ra sau
        el = (el[0], el[1], j[1][2])
        rig.set(f"upperarm_{s}", sh, el)
        rig.set(f"forearm_{s}", el, (hand[0], hand[1], j[2][2]))
        return sh

    # Tay giáo: đứng = nắm giáo dựng cạnh người; lấy đà = giương lên trên
    # vai, kéo ra sau; đâm = duỗi thẳng tới trước ngang vai.
    rest_hand = body_pt(ARM["f"][2], True)
    sh = body_pt(ARM["f"][0], True)
    back = (sh[0] + 10, sh[1] - 24)  # giáo nằm trên mũ, không cắt ngang mặt
    thrust = (sh[0] - 36, sh[1] - 2)
    hx = rest_hand[0] + (back[0] - rest_hand[0]) * windup
    hy = rest_hand[1] + (back[1] - rest_hand[1]) * windup
    hx += (thrust[0] - hx) * strike
    hy += (thrust[1] - hy) * strike
    arm("f", (hx, hy))
    grip = (hx - 2, hy, GRIP[2])
    aim = max(windup, strike)
    up = Vector((0, -1))
    fwd = Vector((-1, 0.14)).normalized()
    d = up.lerp(fwd, smooth(aim)).normalized()
    rig.set("spear", grip, (grip[0] + d.x * SPEAR_UP, grip[1] + d.y * SPEAR_UP, GRIP[2]))

    # Tay khiên: khiên che ngực, đẩy tới khi đâm.
    rh = body_pt(ARM["n"][2], True)
    hand_n = (rh[0] - 6 * strike - 2 * windup, rh[1] - 4 * windup)
    arm("n", hand_n)
    c0, c1 = SHIELD
    off = (c0[0] - ARM["n"][2][0], c0[1] - ARM["n"][2][1])
    center = (hand_n[0] + off[0], hand_n[1] + off[1], c0[2])
    rig.set("shield", center, rot2((center[0], center[1] + c1[1] - c0[1], c0[2]), center, tilt))


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
        for name, kw in (("idle", dict(t=0)), ("windup", dict(t=0.2, attack=0.45)),
                         ("strike", dict(t=0.2, attack=0.6)), ("rise", dict(t=0, rise=0.5))):
            pose(rig, **kw)
            render_to(scene, os.path.join(out, f"stone_{name}.png"))
        pose(rig)
        save_blend("stone_soldier_tripo")
        return
    cam = camera(scene, -0.45 * K, 1.0 * K, 3.0 * K, 2.3 * K, 200)
    anims = {
        "idle": [lambda k=k: pose(rig, t=k / 6) for k in range(6)],
        "attack": [lambda k=k: pose(rig, t=0.2, attack=k / 7) for k in range(8)],
        "rise": [lambda k=k: pose(rig, t=0, rise=k / 5) for k in range(6)],
    }
    export_sprites(scene, cam, "stone_soldier", anims, (0, 0, 0), UNITS_PER_M, extra={"idlePeriod": 2.6})
    pose(rig)
    save_blend("stone_soldier_tripo")


if __name__ == "__main__":
    main()
