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
from choreo_kit import Move, dense_phases  # noqa: E402
from toon_kit import TOON, toonify  # noqa: E402
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


# Biên đạo (choreo_kit): kênh theo đơn vị vẽ / độ, quanh dáng chờ READY.
#   shift, drop   dời thân (x dương = lùi, y dương = hạ thấp)
#   tilt          nghiêng thân quanh hông (độ, âm = hạ vai, chổng mông)
#   head          gằm đầu (độ, + = cúi, âm = hất nanh lên); hx, hy dời gốc đầu
#   fnx, fnl / ffx, ffl   móng trước gần / xa: dời ngang, nhấc lên
#   bnx, bfx, bl  móng sau gần / xa dời ngang, nhấc lên (cả hai)
#   tail, wag     đuôi cong lên (độ), biên độ vẫy
# Lợn rừng: nặng đầu, nóng nảy — khịt, cào đất, dồn sức chân sau rồi bật
# một phát; sau cú húc lắc đầu như rũ máu.
READY = dict(shift=0, drop=0, tilt=0, head=0, hx=0, hy=0, fnx=0, fnl=0, ffx=0, ffl=0,
             bnx=0, bfx=0, bl=0, tail=0, wag=4)
LAG = dict(tilt=0.006, hx=0.012, hy=0.012, head=0.02, tail=0.04, wag=0.04)

# Đòn húc (tiến độ sân khấu: lấy đà 0–0,5 — sân khấu cũng phát nửa này chậm
# theo `charge` khi báo húc thật — ra đòn 0,5–0,65, chạm ~0,58, thu về).
ATTACK = Move(READY, [
    (0.06, dict(drop=1, head=5, tail=10, wag=2)),
    (0.14, dict(shift=4, tilt=-2, head=10, fnx=-6, fnl=7, tail=18)),
    (0.21, dict(shift=5, fnx=-4, fnl=0)),
    (0.28, dict(shift=7, tilt=-4, drop=2, head=13, fnx=10, fnl=0)),
    (0.34, dict(shift=9, fnx=-6, fnl=7)),
    (0.40, dict(shift=10, fnx=-4, fnl=0)),
    (0.45, dict(shift=12, tilt=-6, drop=3, head=16, fnx=8, fnl=0, bnx=4, bfx=4, tail=28)),
    (0.49, dict(shift=13, tilt=-7, drop=4, head=17, fnx=2, fnl=0, bnx=5, bfx=5, bl=0)),
    (0.53, dict(shift=-8, drop=-2, tilt=1, head=12, fnx=-14, fnl=8, ffx=-12, ffl=6, bnx=8, bfx=8, bl=0, tail=35, wag=0)),
    (0.58, dict(shift=-34, drop=0, tilt=4, head=-30, hx=-4, hy=-4, fnx=-26, fnl=4, ffx=-24, ffl=2,
                bnx=-14, bfx=-16, bl=4, tail=30)),
    (0.66, dict(shift=-36, tilt=3, head=-34, hx=-5, hy=-5, fnx=-28, fnl=0, ffx=-26, ffl=0, bnx=-18, bfx=-20, bl=0)),
    (0.76, dict(shift=-26, tilt=0, head=10, hx=-2, hy=2, fnx=-20, bnx=-14, bfx=-16, tail=20)),
    (0.84, dict(shift=-14, head=-8, hx=0, hy=0, fnx=-10, fnl=4, ffx=-12, bnx=-6, bfx=-8)),
    (0.92, dict(shift=-4, head=4, fnx=-2, fnl=0, ffx=-2, bnx=0, bfx=0, tail=8, wag=3)),
], LAG)


ATTACK_PHASES = dense_phases(0.035, 0.46, 0.70, 0.016)  # 39 khung, 15 quanh cú đánh


def idle_channels(t):
    """Đứng thở nặng: thân phập phồng, cứ mỗi chu kỳ khịt mũi hất đầu một
    cái, móng trước dồn trọng lượng, đuôi vẫy — vòng lặp liền."""
    a = 2 * math.pi * t
    snort = max(0.0, math.sin(a)) ** 6  # nhói ngắn quanh giữa nửa chu kỳ đầu
    v = dict(READY)
    v.update(
        drop=-0.8 * (0.5 + 0.5 * math.sin(a)) + 0.6 * math.sin(2 * a),
        shift=0.8 * math.sin(a + 0.4),
        tilt=0.8 * math.sin(a - 0.3),
        head=3 * math.sin(a - 0.8) - 7 * snort,
        hy=-1.0 * snort,
        fnx=0.8 * math.sin(a + 1.0),
        tail=6 * math.sin(a - 1.5),
        wag=6,
    )
    return v


def pose(rig, v, t=0.0):
    """Đặt dáng theo kênh biên đạo [v] (xem READY); [t] = thời gian vòng vẫy đuôi."""
    rig.rest()
    shift, drop = v["shift"], v["drop"]
    tilt = math.radians(v["tilt"])

    def body_pt(p):
        q = rot2(p, (10, -50), tilt)
        return (q[0] + shift, q[1] + drop, p[2])

    rig.set("body", body_pt(BONES["body"][0]), body_pt(BONES["body"][1]))
    rig.set("chest", body_pt(BONES["chest"][0]), body_pt(BONES["chest"][1]))
    hb = BONES["head"]
    h0 = body_pt(hb[0])
    h0 = (h0[0] + v["hx"], h0[1] + v["hy"], 0)
    rig.set("neck", body_pt(BONES["neck"][0]), h0)
    rig.set("head", h0, rot2((h0[0] + hb[1][0] - hb[0][0], h0[1] + hb[1][1] - hb[0][1], 0), h0,
                             tilt - math.radians(v["head"])))  # rot2 dương = ngẩng

    paws = {"fl_n": (v["fnx"], v["fnl"]), "fl_f": (v["ffx"], v["ffl"]),
            "bl_n": (v["bnx"], v["bl"]), "bl_f": (v["bfx"], v["bl"])}
    for leg, j in LEGS.items():
        hip = body_pt(j[0])
        front = leg.startswith("f")
        dx, lift = paws[leg]
        paw = (j[3][0] + dx + shift * (0.2 if front else 0.0), j[3][1] - lift, j[3][2])
        ankle = (paw[0] + (j[2][0] - j[3][0]), paw[1] + (j[2][1] - j[3][1]), j[3][2])
        l1 = math.dist(j[1][:2], j[0][:2])
        l2 = math.dist(j[2][:2], j[1][:2])
        knee = two_bone(hip, ankle, l1, l2, -1 if front else 1)
        knee = (knee[0], knee[1], j[0][2])
        rig.set(leg + "_1", (hip[0], hip[1], j[0][2]), knee)
        rig.set(leg + "_2", knee, ankle)
        rig.set(leg + "_3", ankle, paw)

    prev = body_pt(TAIL[0])
    ang = tilt
    for i in range(len(TAIL) - 1):
        a, b = TAIL[i], TAIL[i + 1]
        ang += math.radians(v["wag"] * 3 * math.sin(t * 6 * math.pi + i) + v["tail"] * 0.7)
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
    if TOON:
        toonify(scene)
    tag = "_toon" if TOON else ""
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "boar_tripo" + tag)
        os.makedirs(out, exist_ok=True)
        setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=4.0, yaw=-14, pitch=6)
        for name, v in (("idle", idle_channels(0.25)), ("scrape", ATTACK.at(0.28)), ("coil", ATTACK.at(0.49)),
                        ("burst", ATTACK.at(0.53)), ("strike", ATTACK.at(0.6)), ("shake", ATTACK.at(0.78))):
            pose(rig, v, 0.2)
            render_to(scene, os.path.join(out, f"boar_{name}.png"))
        pose(rig, READY)
        save_blend("erymanthian_boar_tripo" + tag)
        return
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=3.4, yaw=-14, pitch=6)
    anims = {
        "idle": [lambda k=k: pose(rig, idle_channels(k / 44), k / 44) for k in range(44)],
        "attack": [lambda p=p: pose(rig, ATTACK.at(p), p) for p in ATTACK_PHASES],
    }
    export_sprites(scene, cam, "erymanthian_boar" + tag, anims, P(0, 0), 50 * STAGE_SCALE, extra={"idlePeriod": 2.6, "phases": {"attack": ATTACK_PHASES}})
    pose(rig, READY)
    save_blend("erymanthian_boar_tripo" + tag)


if __name__ == "__main__":
    main()
