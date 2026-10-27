"""Hydra non (màn 1.6, mini-boss) từ mô hình Tripo3D
(art_src/tripo/three-headed dragon 3d model.glb): rắn đầm lầy Lerna thân cuộn
tròn, ba cổ, nọc xanh rỉ miệng. Thay bản khối ghép của hydra.py: cùng điểm
neo, tỉ lệ sân khấu, tên atlas young_hydra và các chuỗi idle_h1..3,
attack_h1..3 → sân khấu không phải đổi.

    bash tool/blender/render.sh hydra_tripo --still   # vài khung xem nhanh
    bash tool/blender/render.sh hydra_tripo           # ghi đè atlas
    python tool/repack_sprites.py young_hydra --scale 0.8

Mỗi cổ một chuỗi xương (đọc trên ảnh nhìn ngang có lưới + dò chiều sâu theo
lát). Đầu bị chém: cả cổ và đầu thu vào gốc trong vòng thân (xương thu nhỏ),
thay bằng gốc cụt đỏ. Đầu dưới (gần người chơi nhất) mất trước, như bản cũ.
"""

import math
import os
import sys

import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403
from sprite_kit import export_sprites  # noqa: E402
from choreo_kit import Move, dense_phases  # noqa: E402
from toon_kit import TOON, toonify  # noqa: E402
from tripo_kit import follow_nearest, import_tripo, islands, smooth_weights, surface_regions  # noqa: E402

GLB = os.path.join(ROOT, "art_src", "tripo", "three-headed dragon 3d model.glb")
STAGE_SCALE = 1.25  # như hydra.py
HEADS = 3

# Khớp đọc ở cách đặt mõm -120, dài 200 (đơn vị vẽ); [J] đổi sang cách đặt
# thật: mõm [NOSE_X], phóng [GROW] cho cao như Hydra cũ (~170).
READ_NOSE = -120
NOSE_X = -112
GROW = 1.15


def J(p):
    return (NOSE_X + (p[0] - READ_NOSE) * GROW, p[1] * GROW, p[2] * GROW)


# Cổ i: gốc trong vòng thân → hai khớp → gáy; đầu: gáy → mõm. Đầu 0 thấp nhất
# (gần người chơi), 1 giữa, 2 trên cùng (cổ chữ S phía trước).
NECKS = [
    [(-40, -42, 30), (-38, -60, 34), (-60, -70, 32), (-90, -72, 30)],
    [(-30, -42, 38), (-30, -70, 42), (-45, -92, 42), (-80, -97, 40)],
    [(-20, -45, -8), (-28, -80, -6), (-38, -122, -5), (-68, -130, -5)],
]
SNOUTS = [(-120, -70, 30), (-110, -94, 40), (-97, -122, -5)]
# Gốc cụt hiện chỗ cổ trồi khỏi vòng thân, phía trước cổ chữ S (thấy được).
STUMPS = [(-56, -46, 24), (-46, -50, 30), (-26, -48, -8)]
COIL = [(-80, -15, 0), (-30, -18, 0), (20, -18, 0)]
TAIL = [(20, -15, 15), (60, -15, 25), (75, -25, 30), (60, -40, 40), (35, -45, 42)]

NECKS = [[J(p) for p in n] for n in NECKS]
SNOUTS = [J(p) for p in SNOUTS]
COIL = [J(p) for p in COIL]
TAIL = [J(p) for p in TAIL]
STUMPS = [J(p) for p in STUMPS]

BONES = {}
BONES.update(chain_bones("coil_", COIL))
BONES.update(chain_bones("tail_", TAIL))
for _i, _n in enumerate(NECKS):
    BONES.update(chain_bones(f"n{_i}_", _n))
    BONES[f"head{_i}"] = (_n[-1], SNOUTS[_i])

FRAME_X = (-165, 125)
FRAME_Y = (-195, 14)


def build():
    mesh = import_tripo(GLB, NOSE_X, 200, GROW)
    rig = Rig("HydraRig", BONES)
    # Ba cổ chồng nhau khi nhìn ngang nhưng tách nhau trên bề mặt: mỗi đỉnh
    # thuộc đầu (hoặc thân) tới được gần nhất theo bề mặt, chỉ nhận xương của
    # phần đó — giọt nọc dính miệng đầu giữa không bị đầu dưới kéo theo.
    seeds = {f"h{i}": (lambda p, sn=SNOUTS[i]: (p / S - Vector((sn[0], sn[2], -sn[1]))).length < 12 * GROW)
             for i in range(HEADS)}
    seeds["body"] = lambda p: p.z / S < 22 * GROW
    region = surface_regions(mesh, seeds)

    def allowed(bone, p):
        lab = region.get(tuple(round(c, 5) for c in p))
        if lab is None:
            return True
        if lab == "body":
            return bone.startswith(("coil_", "tail_")) or bone.endswith("_0")
        i = lab[1]
        return bone.startswith((f"n{i}_", f"head{i}", "coil_"))

    rig.skin(mesh, near_filter=allowed)
    smooth_weights(mesh, islands_below=0)
    # Giọt nọc, gai rời: đi theo chỗ đầu/cổ cạnh nó (không bị kéo thành vệt).
    follow_nearest(mesh, islands(mesh))
    rig.bind(mesh)
    stumps = [stump(i) for i in range(HEADS)]
    return rig, stumps


def stump(i):
    """Gốc cổ cụt đỏ (đầu đã bị chém), hiện thay cổ đã thu vào thân."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=7 * S * GROW, radius2=5.5 * S * GROW,
                          depth=6 * S * GROW)
    mesh = bpy.data.meshes.new(f"Stump{i}")
    bm.to_mesh(mesh)
    bm.free()
    scale = skin_material(f"StumpScale{i}", "#55652A", rough=0.6, noise_scale=30)
    flesh = skin_material(f"StumpFlesh{i}", "#8A1E18", rough=0.35, sss=0.3)
    obj = add_object(f"Stump{i}", mesh, [scale, flesh])
    # Mặt cắt trên cùng màu thịt đỏ.
    top = max(p.co.z for p in mesh.vertices)
    for poly in mesh.polygons:
        if all(abs(mesh.vertices[v].co.z - top) < 1e-6 for v in poly.vertices):
            poly.material_index = 1
    base = STUMPS[i]
    obj.location = P(*base)
    obj.rotation_euler = (math.radians(25), math.radians(-20), 0)  # mặt cắt ngả về máy quay, người chơi
    return obj


# Biên đạo (choreo_kit). Đầu ra đòn (đầu sống gần người chơi nhất):
#   hx, hy  dời đầu (đơn vị vẽ: x dương = lùi, y dương = xuống)
#   curl    cổ cong chữ S (dương = khúc giữa võng ra sau, như rắn hổ mang thu thế)
#   tilt    gằm đầu (độ, + = chúc mõm xuống mổ)
# Các đầu khác: ox, oy, otilt (rụt lại rít, rồi chồm theo).
# Rắn: cổ uốn theo sóng truyền từ gốc lên đầu; thu thế chậm, mổ cực nhanh,
# rút về có nảy nhẹ.
READY = dict(hx=0, hy=0, curl=0, tilt=0, ox=0, oy=0, otilt=0)
LAG = dict(tilt=0.02, curl=0.01, ox=0.03, oy=0.03, otilt=0.04)

ATTACK = Move(READY, [
    (0.10, dict(hx=4, hy=-4, curl=4, tilt=-6, ox=2, oy=-2)),
    (0.25, dict(hx=12, hy=-10, curl=9, tilt=-14, ox=4, oy=-4, otilt=-8)),
    (0.38, dict(hx=16, hy=-14, curl=12, tilt=-20, ox=5, oy=-5, otilt=-10)),
    (0.48, dict(hx=17, hy=-15, curl=13, tilt=-22, ox=5, oy=-5, otilt=-10)),
    (0.53, dict(hx=-10, hy=12, curl=-2, tilt=10)),
    (0.58, dict(hx=-36, hy=34, curl=-4, tilt=24, ox=-4, oy=2, otilt=6)),
    (0.65, dict(hx=-37, hy=35, curl=-4, tilt=26, ox=-5, oy=3, otilt=6)),
    (0.76, dict(hx=-14, hy=12, curl=6, tilt=0, ox=-2, oy=1, otilt=2)),
    (0.87, dict(hx=4, hy=-3, curl=3, tilt=-6, ox=1, oy=-1, otilt=-2)),
], LAG)


# Ba bản (1, 2, 3 đầu) nên khung ít hơn quái khác: 29 khung, 12 quanh cú mổ
# (nhiều hơn thì 3 bản vượt 4 trang ảnh ở độ nét 0,7).
ATTACK_PHASES = dense_phases(0.05, 0.46, 0.70, 0.02)


def pose(rig, stumps, v=READY, t=0.0, alive=HEADS):
    """Cổ lắc lư theo sóng, lệch pha giữa các đầu; đầu sống thấp nhất (gần
    người chơi) ra đòn theo kênh [v]; đầu đã chém thu vào dưới gốc cụt."""
    rig.rest()
    current = HEADS - alive
    breath = math.sin(t * 2 * math.pi)
    for k in range(len(COIL) - 1):
        a, b = COIL[k], COIL[k + 1]
        rig.set(f"coil_{k}", (a[0], a[1] - 0.6 * breath, a[2]), (b[0], b[1] - 0.6 * breath, b[2]))
    prev = TAIL[0]
    ang = 0.0
    for k in range(len(TAIL) - 1):
        a, b = TAIL[k], TAIL[k + 1]
        ang += math.radians(5 * math.sin(t * 2 * math.pi - k * 0.8) * (k + 1) / 2)
        d = Vector((b[0] - a[0], b[1] - a[1]))
        c, s = math.cos(ang), math.sin(ang)
        nxt = (prev[0] + d.x * c - d.y * s, prev[1] + d.x * s + d.y * c, b[2])
        rig.set(f"tail_{k}", prev, nxt)
        prev = nxt

    for i in range(HEADS):
        cut = i < current
        stumps[i].hide_render = not cut
        chain = NECKS[i]
        if cut:
            # Cổ và đầu thu vào gốc trong thân (ẩn dưới gốc cụt).
            root = chain[0]
            for k in range(len(chain) - 1):
                rig.set(f"n{i}_{k}", root, (root[0], root[1] - 1, root[2]))
                rig.arm.pose.bones[f"n{i}_{k}"].scale = (0.02, 0.02, 0.02)
            rig.set(f"head{i}", root, (root[0] - 1, root[1], root[2]))
            rig.arm.pose.bones[f"head{i}"].scale = (0.02, 0.02, 0.02)
            continue
        ph = t * 2 * math.pi + i * 1.7
        if i == current:
            hx, hy, curl, tilt = v["hx"], v["hy"], v["curl"], v["tilt"]
        else:
            hx, hy, curl, tilt = v["ox"], v["oy"], 0.0, v["otilt"]
        pts = []
        for k, p in enumerate(chain):
            f = k / (len(chain) - 1)
            w = f ** 1.2
            # Sóng chạy từ gốc lên đầu (pha trễ theo f) + dời đầu + võng chữ S.
            dx = 3.5 * math.sin(ph - 1.6 * f) * w + hx * f ** 1.3 + curl * math.sin(math.pi * f)
            dy = 3.0 * math.cos(ph - 1.6 * f) * w + hy * f ** 1.3 - 0.4 * curl * math.sin(math.pi * f)
            pts.append((p[0] + dx, p[1] + dy, p[2]))
        for k in range(len(pts) - 1):
            rig.set(f"n{i}_{k}", pts[k], pts[k + 1])
        h = pts[-1]
        sn = SNOUTS[i]
        tilt += 6 * math.sin(ph - 0.6)  # đầu lắc trễ sau cổ
        tip = rot2((h[0] + sn[0] - chain[-1][0], h[1] + sn[1] - chain[-1][1], sn[2]), h, math.radians(tilt))
        rig.set(f"head{i}", h, (tip[0], tip[1], sn[2]))
    bpy.context.view_layer.update()


def lights(scene):
    # Như hydra.py: nắng ấm, viền xanh đầm lầy.
    add_sun(scene, "Key", (0.55, 0.6, -0.6), 4.5, "#FFE0B4", angle=2.5)
    add_sun(scene, "Rim", (0.7, -0.4, -0.35), 4.0, "#B8FFC8", angle=4)
    add_sun(scene, "Bounce", (-0.1, 0.3, 0.9), 0.6, "#A8C080", angle=30)


def shadow_floor():
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=10)
    mesh = bpy.data.meshes.new("Floor")
    bm.to_mesh(mesh)
    bm.free()
    floor = add_object("Floor", mesh, [], smooth_shade=False)
    floor.is_shadow_catcher = True


def main():
    scene = reset_scene(samples=64, world_hex="#9DB6D2", world_strength=0.5)
    rig, stumps = build()
    lights(scene)
    shadow_floor()
    if TOON:
        toonify(scene)
    tag = "_toon" if TOON else ""
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "hydra_tripo" + tag)
        os.makedirs(out, exist_ok=True)
        setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=3.4, yaw=-14, pitch=6)
        for name, alive, v, t in (("idle", 3, READY, 0), ("coil", 3, ATTACK.at(0.45), 0.3),
                                  ("strike", 3, ATTACK.at(0.6), 0.4), ("cut1", 2, READY, 0.5),
                                  ("cut2", 1, ATTACK.at(0.6), 0.4)):
            pose(rig, stumps, v, t, alive)
            render_to(scene, os.path.join(out, f"hydra_{name}.png"))
        pose(rig, stumps)
        save_blend("young_hydra_tripo" + tag)
        return
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=2.9, yaw=-14, pitch=6)
    anims = {}
    for alive in (1, 2, 3):
        def run(v, t, alive=alive):
            pose(rig, stumps, v, t, alive)
        anims[f"idle_h{alive}"] = [lambda k=k, run=run: run(READY, k / 28) for k in range(28)]
        # Đòn 1,2 s trên chu kỳ lắc 2,8 s: các đầu khác vẫn lắc tiếp trong lúc mổ.
        anims[f"attack_h{alive}"] = [lambda p=p, run=run: run(ATTACK.at(p), 0.2 + p * 1.2 / 2.8)
                                     for p in ATTACK_PHASES]
    export_sprites(scene, cam, "young_hydra" + tag, anims, P(0, 0), 50 * STAGE_SCALE, extra={"idlePeriod": 2.8, "phases": {f"attack_h{a}": ATTACK_PHASES for a in (1, 2, 3)}})
    pose(rig, stumps)
    save_blend("young_hydra_tripo" + tag)


if __name__ == "__main__":
    main()
