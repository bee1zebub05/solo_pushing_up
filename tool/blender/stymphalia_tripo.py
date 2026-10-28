"""Chim Stymphalia (màn 1.1 + đàn chim quanh hang ở 1.8) từ mô hình Tripo3D
(art_src/tripo/Stymphalia_bird.glb): chim săn mồi lông đồng như lưỡi dao,
mỏ móc đồng, mắt đỏ. Thay bản khối ghép của stymphalia.py: cùng máy quay, đèn,
điểm neo (tâm thân), tỉ lệ, tên atlas `stymphalian_bird` (idle vỗ cánh,
attack bổ nhào mổ, defeat rũ cánh rơi) → sân khấu không phải đổi; game tự
nhân một con thành đàn (nemea_monster_art _birds, nemea_boss _paintFlock).

    bash tool/blender/render.sh stymphalia_tripo --still         # vài khung xem nhanh
    bash tool/blender/render.sh stymphalia_tripo                 # ghi đè atlas
    bash tool/blender/render.sh stymphalia_tripo --toon          # bản 2.5D

Tripo dựng chim nằm chéo 45°: xoay -45° cho đầu chĩa -X (trái màn hình),
hai cánh xoè theo chiều sâu (gần máy quay = d âm). Khớp đọc trên ảnh nhìn
ngang và từ trên có lưới (đơn vị vẽ, S = 1/50 m).
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403
from human_kit import camera  # noqa: E402
from sprite_kit import export_sprites  # noqa: E402
from motion_kit import Move, Track, dense_phases, wingbeat  # noqa: E402
from toon_kit import TOON, toonify  # noqa: E402
from tripo_kit import follow_nearest, islands, smooth_weights, surface_regions  # noqa: E402

GLB = os.path.join(ROOT, "art_src", "tripo", "Stymphalia_bird.glb")
ROT = -45  # độ quanh trục đứng
LENGTH = 65  # mỏ → chóp đuôi (đơn vị vẽ, 1,3 m)
BODY_Y = 5  # tâm thân thấp hơn tâm khung bao chừng này → dời về gốc (điểm neo)
UNITS_PER_M = 32  # như stymphalia.py


def J(x, y, d):
    """Khớp đọc trên ảnh lưới (tâm khung bao) → toạ độ quanh tâm thân."""
    return (x, y - BODY_Y, d)


SHOULDER = {"n": J(-4, 2, -4), "f": J(-4, 2, 10)}
WRIST = {"n": J(0, -6, -18), "f": J(2, -6, 20)}
TIP = {"n": J(6, -14, -32), "f": J(10, -14, 33)}
TAIL_BASE, TAIL_MID, TAIL_TIP = J(8, 8, 3), J(20, 10, 2), J(32, 12, 2)
CHEST, NECK, BEAK = J(-8, 6, 3), J(-20, 1, 4), J(-33, 2, 4)
LEG = (J(2, 9, 3), J(8, 15, 3))

BONES = {
    "body": (TAIL_BASE, CHEST),
    "neck": (CHEST, NECK),
    "head": (NECK, BEAK),
    "tail0": (TAIL_BASE, TAIL_MID),
    "tail1": (TAIL_MID, TAIL_TIP),
    "legs": LEG,
}
for _s in "nf":
    BONES[f"wing_{_s}0"] = (SHOULDER[_s], WRIST[_s])
    BONES[f"wing_{_s}1"] = (WRIST[_s], TIP[_s])


def import_bird():
    bpy.ops.import_scene.gltf(filepath=GLB)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    for o in list(bpy.context.scene.objects):
        if o.type == "EMPTY" and mesh.parent == o:
            mesh.matrix_world = o.matrix_world @ mesh.matrix_local
            mesh.parent = None
            bpy.data.objects.remove(o)
    mesh.matrix_world = Matrix.Rotation(math.radians(ROT), 4, "Z") @ mesh.matrix_world
    bpy.context.view_layer.update()
    ws = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
    lo_x, hi_x = min(p.x for p in ws), max(p.x for p in ws)
    k = LENGTH * S / (hi_x - lo_x)
    c = Vector(((lo_x + hi_x) / 2, (min(p.y for p in ws) + max(p.y for p in ws)) / 2,
                (min(p.z for p in ws) + max(p.z for p in ws)) / 2))
    mesh.matrix_world = (Matrix.Translation(Vector((0, 0, BODY_Y * S))) @ Matrix.Scale(k, 4)
                         @ Matrix.Translation(-c) @ mesh.matrix_world)
    bpy.context.view_layer.update()
    mesh.data.transform(mesh.matrix_world)
    mesh.matrix_world = Matrix.Identity(4)
    # Lông đồng: ánh kim nhẹ (texture Tripo đã vẽ sẵn sáng tối).
    for slot in mesh.material_slots:
        bsdf = next(n for n in slot.material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Roughness"].default_value = 0.55
        bsdf.inputs["Metallic"].default_value = 0.35
        bsdf.inputs["Specular IOR Level"].default_value = 0.4
    return mesh


def build():
    mesh = import_bird()
    rig = Rig("BirdRig", BONES)
    # Cánh nằm dọc chiều sâu, vỗ quanh trục dọc thân: lấy trục thân làm mốc
    # xoắn (mốc mặc định gần song song với xương cánh → cánh vặn xoắn, lông
    # phủ cánh lật dựng lên khi cánh xuống thấp).
    rig.up = {n: Vector((1, 0, 0)) for n in BONES if n.startswith("wing_")}

    def near(p, q, r):
        return (p - P(*q)).length / S < r

    # Cánh, đuôi, đầu tách nhau trên bề mặt (mép cánh sau chồng lên gốc đuôi
    # trong không gian): mỗi đỉnh thuộc phần tới được gần nhất theo bề mặt.
    region = surface_regions(mesh, {
        "wing_n": lambda p: near(p, TIP["n"], 7),
        "wing_f": lambda p: near(p, TIP["f"], 7),
        "tail": lambda p: near(p, TAIL_TIP, 6),
        "head": lambda p: near(p, BEAK, 5),
        "body": lambda p: near(p, J(0, 6, 3), 5),
    })

    def allowed(bone, p):
        lab = region.get(tuple(round(c, 5) for c in p))
        if lab is None or lab == "body":
            return not bone.startswith("wing_") or bone.endswith("0")
        if lab == "head":
            return bone in ("head", "neck")
        if lab == "tail":
            return bone.startswith("tail") or bone == "body"
        return bone.startswith(lab) or bone == "body"

    rig.skin(mesh, near_filter=allowed)
    smooth_weights(mesh, islands_below=0)
    follow_nearest(mesh, islands(mesh))
    rig.bind(mesh)
    return rig


def rot_yd(p, pivot, ang):
    """Xoay (y, d) quanh [pivot] (vỗ cánh: quanh trục dọc thân)."""
    y, d = p[1] - pivot[1], p[2] - pivot[2]
    c, s = math.cos(ang), math.sin(ang)
    return (p[0], pivot[1] + y * c - d * s, pivot[2] + y * s + d * c)


def rot_xy(p, pivot, ang):
    """Xoay (x, y) quanh [pivot] (ngóc/chúi trong mặt phẳng nhìn ngang)."""
    q = rot2(p, pivot[:2], ang)
    return (q[0], q[1], p[2])


# Biên đạo (motion_kit), kênh quanh dáng chờ READY:
#   flap   góc vỗ cánh (độ, + = cánh lên)
#   fold   mút cánh so với cánh trong (độ, + = cong lên, âm = rủ xuống)
#   sweep  quét cánh ra sau (độ, cụp cánh khi bổ nhào)
#   flex   gập khuỷu + cổ tay, sải cánh co lại (0 … 1)
#   x, y   dời thân (đơn vị vẽ: x âm = tới trước, y dương = xuống)
#   pitch  chúc thân (độ, + = chúc mũi xuống)   neck, head  gập cổ, gật đầu (+ = xuống)
#   tail   cong đuôi (độ, + = xuống)            legs  0 co … 1 duỗi móng
READY = dict(flap=0, fold=0, sweep=0, flex=0, x=0, y=0, pitch=0, neck=0, head=0, tail=0, legs=0)
LAG = dict(pitch=0.01, neck=0.02, head=0.035, tail=0.05, legs=0.03)

# Bổ nhào mổ (tiến độ sân khấu, chạm ~0,55): vỗ mạnh bay ngược lên, ngửa cổ
# kéo đầu ra sau như cánh cung → cụp cánh vuốt ra sau, chúc mũi lao xuống,
# cổ phóng mỏ tới, móng duỗi → khựng → xoè cánh hãm, vỗ bay về chỗ cũ.
ATTACK = Move(READY, [
    (0.08, dict(y=1, pitch=-6)),
    (0.18, dict(y=-3, pitch=-10, neck=-12, head=-6)),
    (0.28, dict(y=-5, x=3, pitch=-16, neck=-22, head=-10, tail=10)),
    (0.38, dict(y=-8, x=5, pitch=-20, neck=-30, head=-14, tail=14)),
    (0.47, dict(y=-10, x=6, pitch=-22, neck=-34, head=-16, tail=16)),
    (0.50, dict(flap=55, fold=0, sweep=0, flex=0, y=-10, x=6, pitch=-22, neck=-34, head=-16, tail=16)),
    (0.54, dict(flap=-10, fold=-24, sweep=50, flex=0.7, y=-2, x=-8, pitch=24, neck=8, head=6, tail=-6, legs=0.6)),
    (0.58, dict(flap=-24, fold=-14, sweep=62, flex=0.9, y=8, x=-18, pitch=34, neck=22, head=12, tail=-10, legs=1)),
    (0.64, dict(flap=-24, fold=-14, sweep=62, flex=0.9, y=9, x=-19, pitch=34, neck=22, head=12, tail=-10, legs=1)),
    (0.72, dict(y=4, x=-12, pitch=-6, neck=0, head=0, tail=8, legs=0.5)),
    (0.82, dict(y=0, x=-5, pitch=-4, legs=0.1)),
    (0.92, dict(y=-1, x=-1, pitch=0, legs=0)),
], LAG)

# Gục: bị đánh văng — cánh rũ quặp, đầu ngoẹo, đuôi xoè, thân lật chúc xuống
# (sân khấu tự xoay sprite và cho rơi theo trọng lực).
DEFEAT = Move(READY, [
    (0.3, dict(flap=60, fold=-30, pitch=-20, neck=-20, head=-20, tail=-20, legs=0.8)),
    (1.0, dict(flap=-50, fold=40, sweep=-10, pitch=40, neck=30, head=40, tail=-30, legs=1)),
], dict(LAG, head=0.1))


# Cánh trong đòn: vỗ theo nhịp thật (wingbeat) — số nhịp đã qua theo tiến độ
# đòn (0 = cánh ở đỉnh): 2 nhịp bay ngược lên, lơ lửng ở đỉnh, bổ nhào (cánh
# cụp theo khoá ATTACK, trọng số DIVE), xoè cánh hãm rồi vỗ về chỗ cũ.
BEATS = Track([(0.0, -0.3), (0.08, 0.0), (0.28, 1.0), (0.47, 2.0), (0.5, 2.0), (0.72, 3.0), (0.92, 4.0),
               (1.0, 4.3)])
DIVE = Track([(0.0, 0.0), (0.49, 0.0), (0.54, 1.0), (0.66, 1.0), (0.72, 0.0), (1.0, 0.0)])


def beat_wings(b, flap=47, lift=2.2):
    """Kênh cánh + nảy thân cho nhịp vỗ [b] (motion_kit.wingbeat)."""
    w = wingbeat(b)
    return dict(flap=-12 + flap * w["arm"], fold=(80 if w["bend"] < 0 else 60) * w["bend"], sweep=30 * w["sweep"], flex=w["flex"],
                lift=lift * w["lift"])


def attack_channels(p):
    v = ATTACK.at(p)
    k = DIVE.at(p)
    w = beat_wings(BEATS.at(p), flap=50, lift=1.6)
    for c in ("flap", "fold", "sweep", "flex"):
        v[c] = k * v[c] + (1 - k) * w[c]
    v["y"] -= (1 - k) * w["lift"]
    return v


# Bổ nhào: ~35 khung, 15 dồn quanh cú mổ.
ATTACK_PHASES = dense_phases(0.04, 0.46, 0.70, 0.016)


def idle_channels(t):
    """Vỗ cánh lơ lửng theo nhịp chim thật (motion_kit.wingbeat): đập xuống
    cánh duỗi hết, mút cánh trễ hơi cong lên; nâng lên cổ tay dẫn trước, sải
    cánh co, mút cánh rủ xuống quặt ra sau, gần đỉnh mới bật duỗi. Thân cao
    nhất cuối nhịp đập; đầu giữ yên trong không gian (cổ bù lại nhịp nảy của
    thân, như chim thật); đuôi trễ theo — vòng lặp liền."""
    w = beat_wings(t)
    lag = wingbeat(t - 0.12)["lift"]
    return dict(READY, flap=w["flap"], fold=w["fold"], sweep=w["sweep"], flex=w["flex"],
                y=-w["lift"], pitch=1.5 * lag, neck=2.5 * w["lift"] / 2.2, head=-1.5 * w["lift"] / 2.2,
                tail=-5 * lag)


def pose(rig, v):
    rig.rest()
    # rot2 dương = ngóc lên (y xuống): kênh + = chúc xuống nên đảo dấu.
    pitch = -math.radians(v["pitch"])
    pivot = J(0, 6, 3)

    def body(p):
        q = rot_xy(p, pivot, pitch)
        return (q[0] + v["x"], q[1] + v["y"], q[2])

    rig.set("body", body(TAIL_BASE), body(CHEST))
    neck_a = -math.radians(v["neck"])
    neck = rot_xy(NECK, CHEST, neck_a)
    rig.set("neck", body(CHEST), body(neck))
    beak = rot_xy(rot_xy(BEAK, NECK, neck_a), neck, -math.radians(v["head"]))
    rig.set("head", body(neck), body(beak))
    tail_a = math.radians(v["tail"])
    mid = rot_xy(TAIL_MID, TAIL_BASE, tail_a)
    tip = rot_xy(rot_xy(TAIL_TIP, TAIL_BASE, tail_a), mid, tail_a * 0.6)
    rig.set("tail0", body(TAIL_BASE), body(mid))
    rig.set("tail1", body(mid), body(tip))
    # Móng: co dưới bụng → duỗi tới trước–xuống để quắp.
    l0, l1 = LEG
    reach = (l1[0] - 10 * v["legs"], l1[1] + 3 * v["legs"], l1[2])
    rig.set("legs", body(l0), body(reach))
    flap = math.radians(v["flap"])
    fold = math.radians(v["fold"])
    sweep = math.radians(v["sweep"])
    for s, sign in (("n", -1), ("f", 1)):
        sh = SHOULDER[s]
        # Cánh gần (d âm) nâng lên = xoay (y,d) chiều âm; cánh xa ngược dấu.
        wr = rot_yd(WRIST[s], sh, sign * flap)
        tp = rot_yd(TIP[s], sh, sign * flap)
        tp = rot_yd(tp, wr, sign * fold)
        # Gập khuỷu: cổ tay kéo về phía vai và lùi ra sau, mút cánh đi theo.
        k = 1 - 0.32 * v["flex"]
        w2 = (wr[0] + 3 * v["flex"], sh[1] + (wr[1] - sh[1]) * k, sh[2] + (wr[2] - sh[2]) * k)
        tp = (tp[0] + w2[0] - wr[0], tp[1] + w2[1] - wr[1], tp[2] + w2[2] - wr[2])
        wr = w2
        # Quét ra sau: dời cổ tay, mút cánh về phía đuôi (x dương), sát thân hơn.
        wr = (wr[0] + 8 * math.sin(sweep), wr[1], sh[2] + (wr[2] - sh[2]) * math.cos(sweep))
        tp = (tp[0] + 22 * math.sin(sweep), tp[1], sh[2] + (tp[2] - sh[2]) * math.cos(sweep) ** 2)
        rig.set(f"wing_{s}0", body(sh), body(wr))
        rig.set(f"wing_{s}1", body(wr), body(tp))
    bpy.context.view_layer.update()


def lights(scene):
    # Như stymphalia.py: nắng ấm trên-trái, viền lạnh làm nổi lông đồng.
    add_sun(scene, "Key", (0.55, 0.6, -0.6), 5.0, "#FFE0B4", angle=2.5)
    add_sun(scene, "Rim", (0.7, -0.4, -0.35), 3.5, "#C8D8FF", angle=4)
    add_sun(scene, "Bounce", (-0.1, 0.3, 0.9), 0.6, "#C8A880", angle=30)


def main():
    scene = reset_scene(samples=64, world_hex="#9DB6D2", world_strength=0.5)
    rig = build()
    lights(scene)
    if TOON:
        toonify(scene, width=0.02, block=8, colors=10)
    tag = "_toon" if TOON else ""
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "stymphalia_tripo" + tag)
        os.makedirs(out, exist_ok=True)
        camera(scene, 0.05, 0.22, 2.1, 1.95, 300, yaw=-22, pitch=14)
        for name, v in (("up", idle_channels(0)), ("down", idle_channels(0.25)), ("bottom", idle_channels(0.52)),
                        ("recover", idle_channels(0.7)), ("late", idle_channels(0.86)), ("rise", attack_channels(0.38)),
                        ("top", attack_channels(0.48)), ("dive", attack_channels(0.55)), ("strike", attack_channels(0.6)),
                        ("brake", attack_channels(0.74)), ("defeat", DEFEAT.at(1))):
            pose(rig, v)
            render_to(scene, os.path.join(out, f"bird_{name}.png"))
        pose(rig, READY)
        save_blend("stymphalian_bird_tripo" + tag)
        return
    cam = camera(scene, 0.05, 0.22, 2.1, 1.95, 130, yaw=-22, pitch=14)
    anims = {
        "idle": [lambda k=k: pose(rig, idle_channels(k / 24)) for k in range(24)],
        "attack": [lambda p=p: pose(rig, attack_channels(p)) for p in ATTACK_PHASES],
        "defeat": [lambda k=k: pose(rig, DEFEAT.at((k + 1) / 16)) for k in range(16)],
    }
    export_sprites(scene, cam, "stymphalian_bird" + tag, anims, (0, 0, 0), UNITS_PER_M,
                   extra={"idlePeriod": 0.7, "phases": {"attack": ATTACK_PHASES}})
    pose(rig, READY)
    save_blend("stymphalian_bird_tripo" + tag)


if __name__ == "__main__":
    main()
