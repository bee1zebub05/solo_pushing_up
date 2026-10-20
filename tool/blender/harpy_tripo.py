"""Harpy (màn 1.5) từ mô hình Tripo3D (art_src/tripo/harpy 3d model.glb): nữ
quỷ chim gầy tái, cánh lông nâu tím, tay người móng vuốt, chân chim móng quắp.
Thay bản MPFB + cánh ghép của harpy.py: cùng máy quay, điểm neo, tỉ lệ, tên
atlas harpy (idle vỗ cánh, attack sà xuống quắp) → sân khấu không phải đổi.

    bash tool/blender/render.sh harpy_tripo --still   # vài khung xem nhanh
    bash tool/blender/render.sh harpy_tripo           # ghi đè atlas

Tripo dựng nhìn chính diện, cánh dang trong mặt phẳng trước mặt: xoay -55°
(mặt hướng trái nhưng cánh vẫn mở ra máy quay), như góc ¾ của bản cũ. Khớp
đọc trong hệ gốc của mô hình (x ngang, z cao, d trước–sau, mặt về -d), dáng
tính trong hệ gốc rồi mới xoay — vỗ cánh chỉ là xoay cánh quanh trục trước–sau.
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import *  # noqa: E402,F401,F403
from human_kit import camera, shadow_catcher  # noqa: E402
from sprite_kit import export_sprites  # noqa: E402
from tripo_kit import follow_nearest, import_tripo_upright, islands, smooth_weights, surface_regions  # noqa: E402

GLB = os.path.join(ROOT, "art_src", "tripo", "harpy 3d model.glb")
HEIGHT = 95  # đơn vị vẽ (1,9 m) từ móng chân tới chóp cánh
ROT = -55  # độ quanh trục đứng
LIFT = 37.5  # móng chân cách đất (đơn vị vẽ): Harpy lơ lửng
UNITS_PER_M = 62  # như harpy.py

# Khớp trong hệ gốc: (x, z, d) — x ngang (phải màn hình khi nhìn chính diện),
# z cao, d trước(-)/sau(+).
SPINE = [(-2, 40, -1), (-2, 62, -4)]
HEAD = [(-3, 70, -6), (-3, 84, -12)]
WINGS = {
    "r": [(-11, 68, 4), (-35, 82, 3), (-52, 92, 1)],
    "l": [(8, 68, 4), (30, 82, 3), (40, 94, 1)],
}
ARMS = {
    "r": [(-10, 64, -2), (-22, 52, -4), (-33, 42, -6)],
    "l": [(6, 64, -2), (18, 52, -4), (28, 42, -6)],
}
LEGS = {
    "r": [(-6, 42, 0), (-13, 28, -6), (-15, 15, -2), (-14, 3, -8)],
    "l": [(2, 42, 0), (-1, 26, -6), (0, 12, -2), (0, -1, -6)],
}


def T(p):
    """Hệ gốc (x, z, d) → toạ độ vẽ của Rig (x, y xuống, d) sau khi xoay, nâng."""
    c, s = math.cos(math.radians(ROT)), math.sin(math.radians(ROT))
    x, z, d = p
    return (x * c - d * s, -(z + LIFT), x * s + d * c)


BONES = {"spine": (T(SPINE[0]), T(SPINE[1])), "head": (T(HEAD[0]), T(HEAD[1]))}
for _s in "rl":
    for _k in range(2):
        BONES[f"wing_{_s}{_k}"] = (T(WINGS[_s][_k]), T(WINGS[_s][_k + 1]))
        BONES[f"arm_{_s}{_k}"] = (T(ARMS[_s][_k]), T(ARMS[_s][_k + 1]))
    for _k in range(3):
        BONES[f"leg_{_s}{_k}"] = (T(LEGS[_s][_k]), T(LEGS[_s][_k + 1]))


def build():
    mesh = import_tripo_upright(GLB, HEIGHT, rot_z=ROT)
    # Nâng lên lơ lửng (gốc toạ độ vẫn ở mặt đất ngay dưới thân, như bản cũ).
    mesh.data.transform(Matrix.Translation(Vector((0, 0, LIFT * S))))
    rig = Rig("HarpyRig", BONES)

    def near(p, q, r):
        return (p - P(*T(q))).length / S < r

    # Cánh, tay, chân sát nhau: mỗi đỉnh thuộc phần tới được gần nhất theo bề mặt.
    seeds = {
        "wing_r": lambda p: near(p, WINGS["r"][2], 10),
        "wing_l": lambda p: near(p, WINGS["l"][2], 10),
        "arm_r": lambda p: near(p, ARMS["r"][2], 6),
        "arm_l": lambda p: near(p, ARMS["l"][2], 6),
        "leg_r": lambda p: near(p, LEGS["r"][3], 6),
        "leg_l": lambda p: near(p, LEGS["l"][3], 6),
        "head": lambda p: near(p, HEAD[1], 7),
        "body": lambda p: near(p, SPINE[1], 8),
    }
    region = surface_regions(mesh, seeds)

    def allowed(bone, p):
        lab = region.get(tuple(round(c, 5) for c in p))
        if lab is None or lab == "body":
            return True
        if lab == "head":
            return bone in ("head", "spine")
        part, side = lab.split("_")
        return bone.startswith(f"{part}_{side}") or bone == "spine"

    rig.skin(mesh, near_filter=allowed)
    smooth_weights(mesh, islands_below=0)
    follow_nearest(mesh, islands(mesh))
    rig.bind(mesh)
    return rig


def rot_about(p, pivot, axis, ang):
    """Xoay điểm (x, z, d) quanh [pivot] theo trục 'x' (ngang), 'd' (trước–sau)."""
    x, z, d = (p[0] - pivot[0], p[1] - pivot[1], p[2] - pivot[2])
    c, s = math.cos(ang), math.sin(ang)
    if axis == "d":  # trong mặt phẳng x–z (vỗ cánh lên/xuống)
        x, z = x * c - z * s, x * s + z * c
    else:  # quanh trục ngang: trong mặt phẳng z–d (ngả trước/sau)
        z, d = z * c - d * s, z * s + d * c
    return (x + pivot[0], z + pivot[1], d + pivot[2])


def pose(rig, t=0.0, attack=-1.0):
    """Lơ lửng vỗ cánh; lấy đà = ngả ra sau, giương cánh cao, co móng; ra đòn
    = sà tới trước–xuống, cánh vẩy ra sau, móng chân vươn tới quắp."""
    rig.rest()
    windup, strike, recover = attack_pose(attack)
    ph = t * 2 * math.pi
    flap = math.radians(30 * math.sin(ph) * (1 - strike) + 38 * windup - 18 * strike)
    bob = 2.2 * math.cos(ph) * (1 - strike)
    pitch = math.radians(14 * windup - 28 * strike)  # âm = chúi tới trước (đỉnh về -d)
    move = (0, bob - 3 * windup - 16 * strike, -26 * strike)  # (x, z, d)
    hip = SPINE[0]

    def body(p):
        q = rot_about(p, hip, "x", pitch)
        return (q[0] + move[0], q[1] + move[1], q[2] + move[2])

    def put(name, a, b):
        rig.set(name, T(body(a)), T(body(b)))

    put("spine", *SPINE)
    nod = math.radians(4 * math.sin(ph + 0.8) - 10 * strike)
    put("head", HEAD[0], rot_about(HEAD[1], HEAD[0], "x", nod))
    for s, sign in (("r", -1), ("l", 1)):
        w = WINGS[s]
        pts = [w[0]] + [rot_about(p, w[0], "d", sign * flap) for p in w[1:]]
        # Cánh gập nhẹ ở cổ tay lúc vỗ lên, duỗi lúc vỗ xuống.
        pts[2] = rot_about(pts[2], pts[1], "d", sign * flap * 0.35)
        for k in range(2):
            put(f"wing_{s}{k}", pts[k], pts[k + 1])
        a = ARMS[s]
        sway = math.radians(6 * math.sin(ph + 1.5))
        hand = rot_about(a[2], a[0], "x", sway + math.radians(-30 * windup + 55 * strike))
        elbow = rot_about(a[1], a[0], "x", sway + math.radians(-20 * windup + 40 * strike))
        put(f"arm_{s}0", a[0], elbow)
        put(f"arm_{s}1", elbow, hand)
        g = LEGS[s]
        dangle = math.radians(5 * math.sin(ph + (0.4 if s == "r" else 1.2)))
        # Lấy đà co móng lên; ra đòn duỗi móng tới trước để quắp.
        knee_a = dangle + math.radians(-25 * windup + 70 * strike)
        pts = [g[0]]
        for k in range(1, 4):
            pts.append(rot_about(g[k], g[0], "x", knee_a * (1 + 0.25 * (k - 1))))
        for k in range(3):
            put(f"leg_{s}{k}", pts[k], pts[k + 1])
    bpy.context.view_layer.update()


def lights(scene):
    add_sun(scene, "Key", (0.55, 0.6, -0.6), 4.0, "#FFE0B4", angle=2.5)
    add_sun(scene, "Rim", (0.7, -0.4, -0.35), 3.5, "#D8C8FF", angle=4)
    add_sun(scene, "Bounce", (-0.1, 0.3, 0.9), 0.5, "#C8A880", angle=30)


def main():
    scene = reset_scene(samples=64, world_hex="#9DB6D2", world_strength=0.5)
    rig = build()
    lights(scene)
    shadow_catcher()
    if STILL:
        out = os.path.join(ROOT, "build", "blender", "harpy_tripo")
        os.makedirs(out, exist_ok=True)
        camera(scene, -0.2, 1.8, 3.1, 2.9, 300, yaw=-18, pitch=8)
        for name, kw in (("up", dict(t=0.25)), ("down", dict(t=0.75)), ("windup", dict(t=0.2, attack=0.45)),
                         ("strike", dict(t=0.2, attack=0.6))):
            pose(rig, **kw)
            render_to(scene, os.path.join(out, f"harpy_{name}.png"))
        pose(rig)
        save_blend("harpy_tripo")
        return
    # Khung rộng hơn bản cũ: cú sà lao sang trái ra ngoài khung 2,5 m.
    cam = camera(scene, -0.2, 1.8, 3.1, 2.9, 190, yaw=-18, pitch=8)
    anims = {
        "idle": [lambda k=k: pose(rig, t=k / 10) for k in range(10)],
        "attack": [lambda k=k: pose(rig, t=0.2, attack=k / 7) for k in range(8)],
    }
    export_sprites(scene, cam, "harpy", anims, (0, 0, 0), UNITS_PER_M, extra={"idlePeriod": 0.9})
    pose(rig)
    save_blend("harpy_tripo")


if __name__ == "__main__":
    main()
