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


def pose(rig, stumps, t=0.0, attack=-1.0, alive=HEADS):
    """Cổ lắc lư lệch pha; đầu sống thấp nhất (gần người chơi) ra đòn: lấy
    đà ngóc lên, ra đòn mổ xuống tới trước; các đầu khác rít theo."""
    rig.rest()
    windup, strike, recover = attack_pose(attack)
    current = HEADS - alive
    breath = math.sin(t * 2 * math.pi)
    for k in range(len(COIL) - 1):
        a, b = COIL[k], COIL[k + 1]
        rig.set(f"coil_{k}", (a[0], a[1] - 0.6 * breath, a[2]), (b[0], b[1] - 0.6 * breath, b[2]))
    prev = TAIL[0]
    ang = 0.0
    for k in range(len(TAIL) - 1):
        a, b = TAIL[k], TAIL[k + 1]
        ang += math.radians(5 * math.sin(t * 2 * math.pi + k * 0.8) * (k + 1) / 2)
        v = Vector((b[0] - a[0], b[1] - a[1]))
        c, s = math.cos(ang), math.sin(ang)
        nxt = (prev[0] + v.x * c - v.y * s, prev[1] + v.x * s + v.y * c, b[2])
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
        dx = math.sin(ph) * 3.5
        dy = math.cos(ph) * 3
        tilt = math.sin(ph + 1) * 6
        if i == current:
            dx += 14 * windup - 34 * strike - 6 * recover
            dy += -12 * windup + 34 * strike
            tilt += -18 * windup + 22 * strike
        else:
            dx += 4 * windup
            dy += -4 * windup
        pts = []
        for k, p in enumerate(chain):
            f = (k / (len(chain) - 1)) ** 1.3
            pts.append((p[0] + dx * f, p[1] + dy * f, p[2]))
        for k in range(len(pts) - 1):
            rig.set(f"n{i}_{k}", pts[k], pts[k + 1])
        h = pts[-1]
        sn = SNOUTS[i]
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
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "hydra_tripo")
        os.makedirs(out, exist_ok=True)
        setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=3.4, yaw=-14, pitch=6)
        for name, alive, kw in (("idle", 3, dict(t=0)), ("windup", 3, dict(t=0.2, attack=0.4)),
                                ("strike", 3, dict(t=0.2, attack=0.58)), ("cut1", 2, dict(t=0.5)),
                                ("cut2", 1, dict(t=0.2, attack=0.58))):
            pose(rig, stumps, alive=alive, **kw)
            render_to(scene, os.path.join(out, f"hydra_{name}.png"))
        pose(rig, stumps)
        save_blend("young_hydra_tripo")
        return
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=2.9, yaw=-14, pitch=6)
    anims = {}
    for alive in (1, 2, 3):
        def run(alive=alive, **kw):
            pose(rig, stumps, alive=alive, **kw)
        anims[f"idle_h{alive}"] = [lambda k=k, run=run: run(t=k / 4) for k in range(4)]
        anims[f"attack_h{alive}"] = [lambda k=k, run=run: run(t=0.2, attack=k / 5) for k in range(6)]
    export_sprites(scene, cam, "young_hydra", anims, P(0, 0), 50 * STAGE_SCALE, extra={"idlePeriod": 2.8})
    pose(rig, stumps)
    save_blend("young_hydra_tripo")


if __name__ == "__main__":
    main()
