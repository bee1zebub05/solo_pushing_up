"""Lợn rừng Erymanthus (màn 1.4, tinh anh) từ mô hình Tripo3D
(art_src/tripo/lon_rung_Erymanthus.glb), thay bản khối ghép của boar.py:
cùng máy quay, đèn, điểm neo, tỉ lệ sân khấu → ghi đè atlas erymanthian_boar,
sân khấu không phải đổi.

    bash tool/blender/render.sh boar_tripo --still   # vài khung xem nhanh
    bash tool/blender/render.sh boar_tripo           # ghi đè atlas

Khớp đọc trên ảnh nhìn ngang có lưới (đơn vị vẽ). Nhịp đòn như boar.py:
lấy đà = lùi, cúi đầu, cào chân trước; ra đòn = lao húc, hất nanh lên. Sân
khấu dùng nửa đầu chuỗi `attack` làm lấy đà theo `charge` (mũi tên đỏ).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403
from sprite_kit import export_sprites  # noqa: E402
from tripo_kit import import_tripo, smooth_weights  # noqa: E402

GLB = os.path.join(ROOT, "art_src", "tripo", "lon_rung_Erymanthus.glb")
STAGE_SCALE = 1.25  # như boar.py: bản vector vẽ ×1,25 trên sân khấu
NOSE_X, SPAN = -100, 170  # mũi và bề dài mũi–đuôi như bản cũ
# Lông gáy dựng cao hơn bản cũ ~23%: thu nhỏ để đỉnh lông không chạm mép khung.
GROW = 0.9

NEAR, FAR = -38, 38
LEGS = {
    "fl_n": [(-28, -50, NEAR), (-30, -28, NEAR), (-38, -12, NEAR), (-50, -3, NEAR)],
    "fl_f": [(-40, -50, FAR), (-46, -28, FAR), (-54, -12, FAR), (-64, -3, FAR)],
    "bl_n": [(48, -55, NEAR), (56, -32, NEAR), (62, -14, NEAR), (56, -2, NEAR)],
    "bl_f": [(40, -55, FAR), (46, -32, FAR), (50, -14, FAR), (44, -4, FAR)],
}
TAIL = [(55, -72, 0), (62, -78, 0), (66, -70, 0), (66, -58, 0)]
BONES = {
    "body": ((55, -60, 0), (-40, -60, 0)),
    "chest": ((-40, -60, 0), (-45, -38, 0)),
    "neck": ((-40, -70, 0), (-70, -72, 0)),
    "head": ((-70, -72, 0), (-100, -52, 0)),
}
for _leg, _j in LEGS.items():
    BONES[_leg + "_1"] = (_j[0], _j[1])
    BONES[_leg + "_2"] = (_j[1], _j[2])
    BONES[_leg + "_3"] = (_j[2], _j[3])
BONES.update(chain_bones("tail_", TAIL))


def same_side(bone, p):
    """Chân gần/xa chỉ nhận đỉnh cùng phía chiều sâu."""
    if "_n_" in bone and p.y > 0.05:
        return False
    if "_f_" in bone and p.y < -0.05:
        return False
    return True


def build():
    mesh = import_tripo(GLB, NOSE_X, SPAN, GROW)
    rig = Rig("BoarRig", BONES)
    rig.skin(mesh, near_filter=same_side)
    smooth_weights(mesh)
    rig.bind(mesh)
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


# Khung, đèn, sàn như boar.py (boar.py chạy main() khi nạp nên chép lại).
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
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "boar_tripo")
        os.makedirs(out, exist_ok=True)
        setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=4.0, yaw=-14, pitch=6)
        for name, kw in (("idle", dict(t=0)), ("windup", dict(t=0.2, attack=0.4)),
                         ("strike", dict(t=0.2, attack=0.58))):
            pose(rig, **kw)
            render_to(scene, os.path.join(out, f"boar_{name}.png"))
        pose(rig, 0)
        save_blend("erymanthian_boar_tripo")
        return
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=3.4, yaw=-14, pitch=6)
    anims = {
        "idle": [lambda k=k: pose(rig, k / 6) for k in range(6)],
        "attack": [lambda k=k: pose(rig, 0.2, attack=k / 9) for k in range(10)],
    }
    export_sprites(scene, cam, "erymanthian_boar", anims, P(0, 0), 50 * STAGE_SCALE, extra={"idlePeriod": 2.2})
    pose(rig, 0)
    save_blend("erymanthian_boar_tripo")


if __name__ == "__main__":
    main()
