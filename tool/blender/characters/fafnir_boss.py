"""Kỳ công 2 — Rồng Fafnir (fantasy realism), cảm hứng từ tranh đã hết bản
quyền: Delitz "Siegfried and the dragon" (1917, rồng-rắn cuộn mình, hàm dài
răng lởm chởm, sừng cong) và Rackham (1911). Rồng-rắn (lindworm) không cánh
như phiến đá khắc Ramsund, cuộn trên kho vàng, vảy đá xanh sẫm, sương giá
đóng trên gai lưng, mắt xanh băng phát sáng.

    bash tool/blender/render.sh fafnir_boss --still   # vài khung xem nhanh
    bash tool/blender/render.sh fafnir_boss           # hoạt hình + atlas

Gốc toạ độ: điểm (330, 220) của sân khấu 400×260 (chân boss trên mặt đất).
"""

import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import paths  # noqa: E402,F401  (kits/, motion/, render/ — rules/dohoa/README.md)
from boss_kit import *  # noqa: E402,F401,F403

ANCHOR = (330, 220)  # toạ độ sân khấu của gốc
FRAME_X = (-152, 128)
FRAME_Y = (-168, 16)

# Sống thân từ ngọn đuôi tới gáy (x, y, d): đuôi vắt trước đống vàng, thân
# vòng ra sau rồi trồi lên, cổ vươn sang trái về phía người chơi.
SPINE = [
    (112, -4, -12), (90, -8, -24), (60, -12, -30), (26, -14, -28), (-4, -17, -14),
    (-18, -22, 10), (-4, -26, 32), (32, -28, 36), (62, -34, 20), (66, -50, 0),
    (50, -66, -8), (24, -78, -10), (0, -88, -8), (-18, -100, -6), (-32, -110, -4),
]
STATIC = 9  # các điểm trước chỉ số này nằm yên (vòng thân trên kho vàng)
HEAD_K = 1.2  # đầu phóng to cho dễ đọc từ xa
HEAD_LEN = 46 * HEAD_K  # gáy → chóp mõm
# Hai chân trước mọc ở gốc cổ (chỗ thân trồi lên), khuỷu chĩa ra sau, vuốt
# bám xuống đống vàng phía trước.
LEGS = {
    "leg_n": [(50, -52, -16), (66, -30, -22), (36, -3, -24)],
    "leg_f": [(64, -54, 16), (80, -30, 22), (54, -3, 24)],
}


def radius(t):
    """Bán kính thân theo t (0 = ngọn đuôi, 1 = gáy)."""
    if t < 0.18:
        return 2 + 9 * smooth(t / 0.18)
    if t < 0.62:
        return 11 + 7 * smooth((t - 0.18) / 0.44)
    if t < 0.86:
        return 18 - 6 * smooth((t - 0.62) / 0.24)
    return 12 - 3 * smooth((t - 0.86) / 0.14)


def build():
    hide = scales_material("Hide", back="#34504F", belly="#9C9174", edge="#0A1213",
                           scale_uv=(10, 12), plates=22, belly_band=0.12, frost="#DCEBF5", bump_strength=0.8)
    head_mat = solid_scales_material("HeadScales", "#36504E", "#0A1213", scale=22)
    socket = skin_material("Socket", "#0A0F12", rough=0.6)
    breath = glow_material("Breath", "#9FE8FF", strength=4, base="#203040")
    horn = skin_material("Horn", "#CFC4A8", rough=0.5, noise_scale=40)
    tooth = skin_material("Tooth", "#EFE6CF", rough=0.35)
    mouth = skin_material("Mouth", "#3A0E14", rough=0.4, sss=0.2)
    eye = glow_material("Eye", "#8FEFFF", strength=14)
    frost_spike = skin_material("Spike", "#6E7774", rough=0.55, noise_scale=30)
    gold = gold_material()

    # ---- xương: chuỗi sống thân, đầu, hàm, hai chân trước
    bones = chain_bones("sp", SPINE)
    head_base = SPINE[-1]
    snout = (head_base[0] - HEAD_LEN, head_base[1] + 4, 0)
    bones["head"] = (head_base, snout)
    bones["jaw"] = ((head_base[0] - 4 * HEAD_K, head_base[1] + 10 * HEAD_K, 0), (snout[0] + 4, snout[1] + 10 * HEAD_K, 0))
    for leg, j in LEGS.items():
        bones[leg + "1"] = (j[0], j[1])
        bones[leg + "2"] = (j[1], j[2])
    rig = Rig("FafnirRig", bones)

    # ---- thân
    body_mesh, _ = tube_mesh("Body", SPINE, radius, sides=32, samples_per_seg=10, dorsal=(0.2, -1, 0), flatten=0.92)
    body = add_object("Body", body_mesh, [hide])
    rig.skin(body, [n for n in bones if n.startswith("sp")])
    parts = [body]

    # Gai sống lưng: hàng gai sừng dọc lưng, to dần về phía vai, sương giá ở ngọn.
    curve = catmull(SPINE, 10)
    spikes = []
    rng = np.random.default_rng(3)
    for i in range(30, len(curve) - 4, 3):
        p = curve[i]
        t = i / (len(curve) - 1)
        tan = (curve[i + 1] - curve[i - 1]).normalized()
        up = Vector((0.2, -1, 0))
        up = (up - tan * up.dot(tan)).normalized()
        r = radius(t)
        h = (3 + r * 0.6) * rng.uniform(0.7, 1.25)
        base = p + up * r * 0.85
        tip = base + up * h - tan * h * 0.55
        mid = base + up * h * 0.55
        spikes.append((tuple(base), tuple(mid), tuple(tip), 1.6 + r * 0.17))
    sp = add_object("Spikes", tapered_tubes("Spikes", spikes, sides=6, steps=5, flat=0.6, taper=1.0), [frost_spike])
    rig.skin(sp, [n for n in bones if n.startswith("sp")])
    parts.append(sp)

    # ---- đầu: sọ dài, gờ mày gồ, hốc mắt sâu, mõm có tấm sừng sống mũi;
    # hàm dưới riêng để há. Phóng HEAD_K cho dễ đọc từ xa.
    hx, hy, _ = head_base
    K = HEAD_K

    def W(x, y, d=0.0):
        return (hx + x * K, hy + y * K, d * K)

    def R(*r):
        return tuple(v * K for v in r)

    head = ellipsoids_mesh("Head", [
        (W(-10, -2), R(15, 12, 13)),
        (W(4, 1), R(11, 10, 10)),  # gáy phủ mối nối với cổ
        (W(-30, 2), R(20, 8, 9.5), -6),
        (W(-43, 4), R(10, 6.5, 8), -8),
        (W(-18, -10, -6.5), R(12, 4.5, 5), 12),  # gờ mày gồ
        (W(-18, -10, 6.5), R(12, 4.5, 5), 12),
        (W(-6, 4, -8), R(10, 8, 5.5)),  # gò má
        (W(-6, 4, 8), R(10, 8, 5.5)),
        (W(-34, -4.5), R(14, 2.6, 4), -10),  # sống mũi
        (W(-46, -1, -3.2), R(4, 3, 2.4)),  # gò lỗ mũi
        (W(-46, -1, 3.2), R(4, 3, 2.4)),
    ], voxel=0.01)
    h = add_object("Head", head, [head_mat], "head")
    jaw = ellipsoids_mesh("Jaw", [
        (W(-22, 12), R(22, 4.5, 8.5), -3),
        (W(-6, 10), R(9, 6, 9)),
        (W(-40, 12), R(7, 4, 6.5), -5),
    ], voxel=0.01)
    jw = add_object("Jaw", jaw, [head_mat], "jaw")
    mo = add_object("MouthIn", uv_ellipsoid("MouthIn", W(-24, 8), R(20, 4, 7)), [mouth], "head")
    parts += [h, jw, mo]
    # Răng lởm chởm kiểu Delitz: hàm trên chĩa xuống, hàm dưới chĩa lên, nanh dài.
    up_teeth, lo_teeth = [], []
    for k in range(10):
        x = -12 - k * 3.9
        L = 4 + (4 if k in (6, 7) else 2.2 if k % 3 == 0 else 0)
        for d in (-6.5, 6.5):
            up_teeth.append((W(x, 7, d), W(x - 0.5, 7 + L * 0.5, d), W(x - 1.5, 7 + L, d * 0.95), 1.3 * K))
            lo_teeth.append((W(x + 1.5, 10, d * 0.9), W(x + 1.2, 10 - L * 0.4, d * 0.9), W(x, 10 - L * 0.8, d * 0.85), 1.1 * K))
    parts.append(add_object("TeethUp", tapered_tubes("TeethUp", up_teeth, 6, 4, taper=1.1), [tooth], "head"))
    parts.append(add_object("TeethLo", tapered_tubes("TeethLo", lo_teeth, 6, 4, taper=1.1), [tooth], "jaw"))
    horns, jaw_spikes = [], []
    for s in (-1, 1):
        # Sừng chính cong ra sau rồi vểnh lên, cặp sừng phụ song song bên dưới.
        horns.append((W(-8, -10, 8 * s), W(16, -32, 13 * s), W(32, -24, 16 * s), 3.8 * K))
        horns.append((W(-2, -4, 10 * s), W(16, -12, 14 * s), W(26, -6, 17 * s), 2.4 * K))
        # Sừng má toả ra sau.
        horns.append((W(-2, 2, 9.6 * s), W(10, -2, 13 * s), W(18, 2, 15 * s), 2.0 * K))
        # Hàng gai mày nhỏ trên gờ mắt.
        for k in range(4):
            x = -28 + k * 5
            horns.append((W(x, -12, 6 * s), W(x + 1.5, -15, 7 * s), W(x + 4, -17 - k * 0.6, 7.5 * s), (1.1 + 0.15 * k) * K))
        # Vây gai dọc má (mép sau hàm).
        for k in range(3):
            jaw_spikes.append((W(-10 + k * 4, 12, 7.5 * s), W(-8 + k * 4, 16, 9 * s), W(-4 + k * 5, 19, 10.5 * s), 1.2 * K))
    # Râu gai dưới cằm (rồng Bắc Âu).
    for k in range(5):
        x = -36 + k * 6
        jaw_spikes.append((W(x, 14.5), W(x + 2, 19), W(x + 5, 23 + k * 0.8), (1.0 + 0.1 * k) * K))
    parts.append(add_object("Horns", tapered_tubes("Horns", horns, 8, 8, taper=1.0), [horn], "head"))
    parts.append(add_object("JawSpikes", tapered_tubes("JawSpikes", jaw_spikes, 6, 6, taper=1.0), [horn], "jaw"))
    # Hốc mắt tối, nhãn cầu xanh băng phát sáng lọt trong hốc.
    for d in (-9, 9):
        parts.append(add_object("Socket", uv_ellipsoid("Socket", W(-21.5, -5, d), R(4.2, 2.6, 2.0)), [socket], "head"))
        parts.append(add_object("Eye", uv_ellipsoid("Eye", W(-23, -5, d * 1.12), R(3.4, 1.7, 1.6)), [eye], "head"))
    for d in (-3.5, 3.5):
        parts.append(add_object("Nostril", uv_ellipsoid("Nostril", W(-49, 0, d), R(1.6, 1.2, 1.2)), [mouth], "head"))
    # Hơi băng sáng trong miệng (đòn phun hơi lạnh).
    parts.append(add_object("Frostbreath", uv_ellipsoid("Frostbreath", W(-20, 9), R(14, 2.2, 4)), [breath], "jaw"))

    # ---- hai chân trước bám vàng, vuốt sừng
    for leg, j in LEGS.items():
        m = metaball_mesh(leg, [
            ball(*j[0], 14, sx=1.1, sy=1.3, sz=0.8),  # bắp vai
            capsule(j[0], j[1], 9), capsule(j[1], j[2], 6.5),
            ball(*lerp(j[1], j[2], 0.3), 8, sx=1.0, sy=1.0, sz=0.9),  # cơ cẳng
            ball(j[2][0] - 3, j[2][1] - 2, j[2][2], 8, sx=1.5, sy=0.6, sz=1.1, stiff=3),
        ], resolution=0.025)
        o = add_object(leg, m, [head_mat])
        rig.skin(o, [leg + "1", leg + "2"])
        parts.append(o)
        px, py, pd = j[2]
        claws = [((px - 7 + 2.5 * k, py - 3, pd + 3.4 * (k - 1.5)), (px - 12 + 2.5 * k, py - 1, pd + 3.8 * (k - 1.5)),
                  (px - 15 + 2.5 * k, py + 3, pd + 4 * (k - 1.5)), 1.7) for k in range(4)]
        parts.append(add_object(leg + "Claws", tapered_tubes(leg + "Claws", claws, 6, 5, taper=1.1), [horn], leg + "2"))

    for p in parts:
        rig.bind(p)

    # ---- kho vàng: gò vàng + hàng nghìn đồng xu (geometry nodes, Poisson)
    mound = ellipsoids_mesh("Hoard", [
        ((20, 4, 0), (78, 16, 46)), ((-30, 6, -10), (40, 10, 30)), ((70, 6, 12), (40, 10, 30)),
    ], voxel=0.03)
    hoard = add_object("Hoard", mound, [gold])
    coins_on(hoard, gold)
    add_treasure(gold)
    return rig


def coins_on(obj, mat):
    """Đồng xu rải ngẫu nhiên trên gò vàng, nghiêng lộn xộn."""
    ng = bpy.data.node_groups.new("Coins", "GeometryNodeTree")
    ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    N, L = ng.nodes, ng.links.new
    gi, go = N.new("NodeGroupInput"), N.new("NodeGroupOutput")
    dist = N.new("GeometryNodeDistributePointsOnFaces")
    dist.distribute_method = "POISSON"
    dist.inputs["Distance Min"].default_value = 0.035
    dist.inputs["Density Max"].default_value = 2500
    L(gi.outputs[0], dist.inputs["Mesh"])
    coin = N.new("GeometryNodeMeshCylinder")
    coin.inputs["Vertices"].default_value = 16
    coin.inputs["Radius"].default_value = 0.05
    coin.inputs["Depth"].default_value = 0.008
    rot = N.new("FunctionNodeRandomValue")
    rot.data_type = "FLOAT_VECTOR"
    rot.inputs["Min"].default_value = (-0.7, -0.7, 0)
    rot.inputs["Max"].default_value = (0.7, 0.7, 6.3)
    euler = N.new("FunctionNodeEulerToRotation")
    L(rot.outputs[0], euler.inputs[0])
    inst = N.new("GeometryNodeInstanceOnPoints")
    L(dist.outputs["Points"], inst.inputs["Points"])
    L(coin.outputs["Mesh"], inst.inputs["Instance"])
    L(euler.outputs[0], inst.inputs["Rotation"])
    real = N.new("GeometryNodeRealizeInstances")
    L(inst.outputs[0], real.inputs[0])
    sm = N.new("GeometryNodeSetMaterial")
    L(real.outputs[0], sm.inputs[0])
    sm.inputs["Material"].default_value = mat
    join = N.new("GeometryNodeJoinGeometry")
    L(sm.outputs[0], join.inputs[0])
    L(gi.outputs[0], join.inputs[0])
    L(join.outputs[0], go.inputs[0])
    obj.modifiers.new("Coins", "NODES").node_group = ng


def add_treasure(gold):
    """Vài món nổi bật trên kho: chén vàng, mũ trụ, chuôi kiếm cắm nghiêng."""
    cup = ellipsoids_mesh("Goblet", [((86, -10, -20), (7, 6, 7)), ((86, -2, -20), (2, 6, 2)), ((86, 2, -20), (6, 1.5, 6))], voxel=0.01)
    add_object("Goblet", cup, [gold])
    helm = ellipsoids_mesh("Helm", [((-48, -4, -24), (11, 9, 10)), ((-48, -1, -24), (13, 2, 12))], voxel=0.012)
    add_object("Helm", helm, [skin_material("Iron", "#5E6466", rough=0.45, metallic=0.9)])
    sword = tapered_tubes("Sword", [((104, -2, 8), (108, -26, 8), (111, -48, 8), 1.6)], 4, 3, flat=2.2, taper=0.2)
    add_object("Sword", sword, [skin_material("Steel", "#AEB8BC", rough=0.25, metallic=1.0)])
    guard = tapered_tubes("Guard", [((100, -40, 8), (111, -42, 8), (122, -40, 8), 1.2)], 6, 3, taper=0.0)
    add_object("Guard", guard, [gold])


def pose(rig, t=0.0, attack=-1.0, defeat=0.0):
    """Dáng tại một khung: thở (t 0–1 một nhịp), đòn 3 pha, gục."""
    rig.rest()
    windup, strike, recover = attack_pose(attack)
    fall = smooth(defeat)
    breath = math.sin(t * 2 * math.pi)
    # Độ dời của gáy: lấy đà rướn ra sau – lên, ra đòn lao xuống về phía người
    # chơi (phun hơi băng), gục thì đổ sập xuống đất.
    hdx = 18 * windup - 38 * strike - 6 * recover - 30 * fall
    hdy = -16 * windup + 26 * strike + 98 * fall + 2.5 * breath
    pts = [list(p) for p in SPINE]
    n = len(SPINE)
    for i in range(STATIC, n):
        w = ((i - STATIC + 1) / (n - STATIC)) ** 1.6
        pts[i][0] += hdx * w
        pts[i][1] += hdy * w
        # Gục: cả phần thân trồi cũng sụp xuống.
        pts[i][1] += fall * 30 * (1 - w)
        # Ra đòn: cổ cong vồng lên giữa chừng (không duỗi thẳng đơ).
        pts[i][1] -= strike * 22 * math.sin(math.pi * w)
    for i in range(n - 1):
        rig.set(f"sp{i}", pts[i], pts[i + 1])
    base = tuple(pts[-1])
    # Đầu: lấy đà ngẩng lên, ra đòn chúi xuống, gục thì nghiêng nằm.
    ang = math.radians(-14 * windup + 16 * strike + 10 * fall + 2 * breath)
    tip = rot2((base[0] - HEAD_LEN, base[1] + 4, 0), base, ang)
    rig.set("head", base, tip)
    jaw0 = rot2((base[0] - 4, base[1] + 10, 0), base, ang)
    jaw1 = rot2((tip[0] + 4, tip[1] + 10, 0), base, ang)
    opened = max(0.35 * windup, strike, 0.3 * fall)
    rig.set("jaw", jaw0, rot2(jaw1, jaw0, math.radians(-30 * opened)))
    # Chân trước: vai theo thân, vuốt bám vàng (gục thì duỗi ra).
    for leg, j in LEGS.items():
        sh = (j[0][0] + hdx * 0.08, j[0][1] + hdy * 0.06 + 26 * fall, j[0][2])
        paw = (j[2][0] - 10 * fall, j[2][1], j[2][2])
        l1 = math.dist(j[0][:2], j[1][:2])
        l2 = math.dist(j[1][:2], j[2][:2])
        el = two_bone(sh, paw, l1, l2, -1)  # khuỷu chĩa ra sau (+x)
        rig.set(leg + "1", sh, (el[0], el[1], j[1][2]))
        rig.set(leg + "2", (el[0], el[1], j[1][2]), paw)


def lights(scene):
    # Trăng lạnh trên-trái, cực quang xanh lục viền sau-phải, ánh vàng hắt từ kho.
    add_sun(scene, "Moon", (0.7, 0.5, -0.6), 3.2, "#CFE2FF")
    add_sun(scene, "Aurora", (-0.6, -0.9, -0.3), 5.0, "#7DFFC8", angle=2)
    add_point(scene, "HoardGlow", (20, -12, -50), 260, "#FFB050", radius=1.5)
    add_point(scene, "HoardFill", (-40, -20, -60), 150, "#FFD27A", radius=1.0)


def main():
    scene = reset_scene(samples=64, world_hex="#3A4A6A", world_strength=0.35)
    rig = build()
    lights(scene)
    cam = setup_camera(scene, FRAME_X, FRAME_Y, px_per_unit=2.0)
    anchor, ppu = anchor_info(scene, cam)
    print(f"FAFNIR anchor={tuple(round(c, 1) for c in anchor)} ppu={ppu:.3f}")
    out = os.path.join(ROOT, "build", "blender", "fafnir")
    if STILL:
        render_stills(scene, out, [
            ("idle", lambda: pose(rig, 0)),
            ("windup", lambda: pose(rig, 0.25, attack=0.48)),
            ("strike", lambda: pose(rig, 0.25, attack=0.62)),
            ("defeat", lambda: pose(rig, 0.25, defeat=1)),
        ])
        save_blend("fafnir")
        return
    anims = {
        "idle": [lambda k=k: pose(rig, k / 12) for k in range(12)],
        "attack": [lambda k=k: pose(rig, 0.25, attack=k / 15) for k in range(16)],
        "defeat": [lambda k=k: pose(rig, 0.25, defeat=k / 9) for k in range(10)],
    }
    files = render_anims(scene, out, anims, keyframe=rig.keyframe)
    sprites = os.path.join(ROOT, "assets", "sprites")
    os.makedirs(sprites, exist_ok=True)
    pack_atlas(files, anchor, ppu, os.path.join(sprites, "fafnir.png"), os.path.join(sprites, "fafnir.json"))
    pose(rig, 0)
    save_blend("fafnir")


main()
