"""Cánh chim lông vũ thật (từng chiếc lông) cho chim Stymphalia và Harpy.

Cánh gồm 3 đốt nối chuỗi bằng empty (vai → khuỷu → cổ tay), mỗi đốt mang
một lưới lông cứng: đốt trong (lông tam cấp + lông bao), cẳng cánh (lông thứ
cấp + 2 hàng lông bao), bàn cánh (lông sơ cấp xoè + lông bao sơ cấp). Đập
cánh = xoay cả cánh quanh trục thân (X); gập bàn cánh khi nâng cánh.

Hệ toạ độ cục bộ của cánh GẦN máy quay (sải theo −Y, lông chĩa về sau +X,
mặt trên +Z); cánh xa là ảnh gương (y → −y). Đơn vị mét.
"""

import math
import random

import bpy
from mathutils import Euler, Matrix, Vector

from boss_kit import _nodes, add_object, srgb
from human_kit import raw_tube, store_point_attr

U = 50  # mét → đơn vị vẽ (ellipsoids_mesh nhận đơn vị vẽ)


def E(c, r, rot=0.0):
    """Ellipsoid theo mét (x tới sau, y sâu, z lên) → đối số ellipsoids_mesh.
    [rot] độ: ngóc lên (dương = đầu trước ngóc lên)."""
    return ((c[0] * U, -c[2] * U, c[1] * U), (r[0] * U, r[2] * U, r[1] * U), rot)



# ---------------------------------------------------------------- lông vũ


def feather_material(name, dark, light, sheen="#E8B060", metallic=0.65, rough=0.32):
    """Lông vũ ánh kim: màu theo thuộc tính `feather_t` (0 = tối/lưng, 1 =
    sáng/ức) cộng sai khác từng chiếc (Random Per Island); ánh đồng loang
    theo hướng nhìn (mép lông bắt sáng)."""
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    N, L = nt.nodes, nt.links.new
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    geo = N.new("ShaderNodeNewGeometry")
    attr = N.new("ShaderNodeAttribute")
    attr.attribute_type = "GEOMETRY"
    attr.attribute_name = "feather_t"
    mix_t = N.new("ShaderNodeMath")
    mix_t.operation = "MULTIPLY_ADD"
    L(geo.outputs["Random Per Island"], mix_t.inputs[0])
    mix_t.inputs[1].default_value = 0.14
    L(attr.outputs["Fac"], mix_t.inputs[2])
    ramp = N.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, srgb(dark)
    els[1].position, els[1].color = 1.0, srgb(light)
    L(mix_t.outputs[0], ramp.inputs["Fac"])
    # Ánh kim ở mép (Fresnel) — lông đồng loé khi nghiêng.
    fres = N.new("ShaderNodeLayerWeight")
    fres.inputs["Blend"].default_value = 0.35
    sh = N.new("ShaderNodeMix")
    sh.data_type = "RGBA"
    L(fres.outputs["Facing"], sh.inputs["Factor"])
    L(ramp.outputs["Color"], sh.inputs[6])
    sh.inputs[7].default_value = srgb(sheen)
    L(sh.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Anisotropic"].default_value = 0.6
    # Vân lông (barbs) chạy chéo.
    wave = N.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = 180
    wave.inputs["Distortion"].default_value = 2
    tc = N.new("ShaderNodeTexCoord")
    L(tc.outputs["Object"], wave.inputs["Vector"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.18
    L(wave.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def plumage(name, body, mat, density=0.0105, length=(0.04, 0.058), width=0.0125, small_front=-0.27,
            seed=3, avoid=(), flow=(1, 0, -0.25)):
    """Lông xếp ngói phủ kín lưới [body]: mỗi chiếc là dải cong dẹt nằm sát da,
    ngọn chĩa về sau–xuống, ngọn cao hơn gốc để che gốc chiếc phía sau. Lông
    trước [small_front] (đầu, cổ) nhỏ dần. `feather_t` 0 = lưng, 1 = ức."""
    rnd = random.Random(seed)
    mesh = body.data
    pts = [(v.co.copy(), v.normal.copy()) for v in mesh.vertices]
    rnd.shuffle(pts)
    taken = {}
    cell = density
    verts, faces, ft = [], [], []
    back = Vector(flow).normalized()
    for p, n in pts:
        k = (int(p.x // cell), int(p.y // cell), int(p.z // cell))
        if any((p - e).length < 0.024 for e in avoid):
            continue
        if any(taken.get((k[0] + a, k[1] + b, k[2] + c)) for a in (-1, 0, 1) for b in (-1, 0, 1) for c in (-1, 0, 1)):
            continue
        taken[k] = True
        d = back - n * n.dot(back)
        if d.length < 0.2:
            d = Vector((0, 0, -1)) - n * n.z
        d.normalize()
        w = n.cross(d).normalized()
        f = 1.0 if p.x > small_front else max(0.35, 1 - (small_front - p.x) * 6)
        L = rnd.uniform(*length) * f
        W = width * f * rnd.uniform(0.85, 1.1)
        tone = min(1.0, max(0.0, 0.5 - n.z * 0.9 + (0.25 if p.x < -0.05 and p.z < 0 else 0)))
        base = len(verts)
        steps = 5
        for i in range(steps + 1):
            t = i / steps
            c = p + d * L * t + n * (0.0015 + 0.006 * t)
            hw = W * math.sin(math.pi * (0.12 + 0.8 * t)) ** 0.7 * (1 - 0.35 * t * t)
            verts += [c - w * hw, c + n * 0.0012, c + w * hw]
            ft += [tone] * 3
        for i in range(steps):
            o = base + i * 3
            faces += [(o, o + 1, o + 4, o + 3), (o + 1, o + 2, o + 5, o + 4)]
    m = bpy.data.meshes.new(name)
    m.from_pydata(verts, [], faces)
    m.update()
    obj = add_object(name, m, [mat])
    store_point_attr(obj, "feather_t", ft)
    return obj


def blade(name, root, d, up, length, half_w, mat, curve=0.08, tone=0.6):
    """Lông dao (đuôi, mào): dải dẹt nhọn ngọn, cong theo [up], có sống giữa."""
    d = Vector(d).normalized()
    up = Vector(up).normalized()
    w = up.cross(d).normalized()
    verts, faces = [], []
    steps = 10
    for i in range(steps + 1):
        t = i / steps
        c = Vector(root) + d * length * t + up * curve * length * math.sin(math.pi * t * 0.8)
        hw = half_w * (math.sin(math.pi * min(1.0, 0.1 + t * 0.95)) ** 0.5) * (1 - t ** 3)
        verts += [c - w * hw, c + up * half_w * 0.18, c + w * hw]
    for i in range(steps):
        o = i * 3
        faces += [(o, o + 1, o + 4, o + 3), (o + 1, o + 2, o + 5, o + 4)]
    m = bpy.data.meshes.new(name)
    m.from_pydata(verts, [], faces)
    m.update()
    obj = add_object(name, m, [mat])
    store_point_attr(obj, "feather_t", [tone] * len(verts))
    return obj





def _feathers(name, specs, mat, mirror):
    """[specs]: (gốc, hướng, dài, nửa rộng, độ cao lớp, độ cong) → một lưới.
    Mỗi chiếc là phiến lông dẹt (nằm trong mặt cánh) có sống lông gồ giữa:
    rộng gần đều từ gốc, ngọn thuôn nhọn như lưỡi dao, phiến ngoài hẹp hơn
    phiến trong, cong xuống theo [độ cong]."""
    verts, faces = [], []
    up = Vector((0, 0, 1))
    steps = 9
    for root, d, length, half_w, lift, bend in specs:
        root = Vector(root) + up * lift
        d = Vector(d).normalized()
        w = up.cross(d).normalized()
        base = len(verts)
        for i in range(steps + 1):
            t = i / steps
            c = root + d * length * t - up * bend * length * math.sin(math.pi * t * 0.9) * 0.8
            prof = min(1.0, 0.3 + t * 5) * (1.0 if t < 0.62 else math.cos((t - 0.62) / 0.38 * math.pi / 2) ** 0.8)
            hw = half_w * prof
            verts += [c - w * hw * 0.7, c + up * half_w * 0.12 * (1 - t), c + w * hw]
        for i in range(steps):
            o = base + i * 3
            faces += [(o, o + 1, o + 4, o + 3), (o + 1, o + 2, o + 5, o + 4)]
    if mirror:
        verts = [Vector((v.x, -v.y, v.z)) for v in verts]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    return add_object(name, mesh, [mat])


class Wing:
    """Một cánh. [span] = (đốt trong, cẳng cánh, bàn cánh) m; [scale] phóng lông."""

    def __init__(self, name, shoulder, mat, arm_mat, far=False, span=(0.22, 0.3, 0.2), scale=1.0, seed=1,
                 primaries=10, secondaries=11):
        rnd = random.Random(seed)
        self.far = far
        self.sgn = 1 if far else -1  # hướng sải theo y
        l1, l2, l3 = span
        self.span = span
        self.joints = []
        parent = None
        for k, (seg, at) in enumerate((("Arm", Vector(shoulder)), ("Fore", Vector((0, self.sgn * l1, 0))),
                                       ("Hand", Vector((0, self.sgn * l2, 0))))):
            e = bpy.data.objects.new(f"{name}{seg}", None)
            bpy.context.scene.collection.objects.link(e)
            if parent:
                e.parent = parent
            e.location = at
            self.joints.append(e)
            parent = e
        s = scale
        mir = far
        J = lambda v: rnd.uniform(-v, v)  # noqa: E731

        # Đốt trong: lông tam cấp dài rủ về sau + lông bao vai.
        arm = []
        for i in range(6):
            y = -l1 * (0.1 + 0.85 * i / 5)
            arm.append(((0.02, y, 0), (1, J(0.05) + 0.15 * i / 5 * -1, 0), (0.2 + 0.03 * i) * s, 0.03 * s, 0.0, 0.08))
            arm.append(((0.0, y, 0), (1, -0.1, 0), (0.1 + J(0.02)) * s, 0.026 * s, 0.012, 0.05))
        # Cẳng cánh: lông thứ cấp + 2 hàng lông bao.
        fore = []
        for i in range(secondaries):
            y = -l2 * (0.02 + 0.96 * i / (secondaries - 1))
            ang = math.radians(4 + 10 * i / secondaries)
            d = (math.cos(ang), -math.sin(ang), 0)
            fore.append(((0.02, y, 0), d, (0.3 + J(0.015)) * s, 0.034 * s, 0.0, 0.07))
            fore.append(((0.01, y, 0), d, (0.15 + J(0.012)) * s, 0.03 * s, 0.012, 0.05))
            fore.append(((-0.01, y + 0.01, 0), d, (0.075 + J(0.01)) * s, 0.024 * s, 0.022, 0.04))
        # Bàn cánh: lông sơ cấp xoè từ hướng sau ra hướng sải.
        hand = []
        for i in range(primaries):
            t = i / (primaries - 1)
            y = -l3 * (0.05 + 0.75 * t)
            beta = math.radians(16 + 66 * t)
            d = (math.cos(beta), -math.sin(beta), 0)
            hand.append(((0.015, y, -0.004 * i), d, (0.34 + 0.16 * math.sin(math.pi * min(1, t * 1.25))) * s,
                         (0.032 - 0.008 * t) * s, 0.0, 0.06))
            hand.append(((0.0, y, 0), d, (0.13 + J(0.01)) * s, 0.028 * s, 0.014, 0.04))
        self.parts = [
            _feathers(f"{name}ArmF", arm, mat, mir),
            _feathers(f"{name}ForeF", fore, mat, mir),
            _feathers(f"{name}HandF", hand, mat, mir),
        ]
        # Xương cánh bọc lông nhỏ (mép trước).
        bones = [raw_tube(f"{name}Bone{k}", [Vector((0, 0, 0)), Vector((0, self.sgn * L, 0))], [r0, r1], sides=12)
                 for k, (L, r0, r1) in enumerate(((l1, 0.017 * s, 0.012 * s), (l2, 0.012 * s, 0.008 * s),
                                                  (l3, 0.008 * s, 0.004 * s)))]
        for k, (joint, part) in enumerate(zip(self.joints, self.parts)):
            if mir is False:
                pass
            part.parent = joint
            b = add_object(f"{name}Bone{k}", bones[k], [arm_mat])
            b.parent = joint

    def pose(self, flap, fold=0.0, sweep=0.0):
        """[flap] rad: nâng cánh (+ lên trên, − xuống dưới); [fold] 0–1 gập
        cẳng + bàn cánh ra sau; [sweep] rad: cả cánh quét ra sau (lượn)."""
        s = self.sgn
        root, fore, hand = self.joints
        root.rotation_euler = Euler((flap * s, 0, -sweep * s), "ZXY")
        fore.rotation_euler = Euler((0, 0, -0.9 * fold * s), "XYZ")
        hand.rotation_euler = Euler((0, 0, 1.6 * fold * s), "XYZ")


def flap_cycle(phase):
    """Pha đập cánh 0–1 → (nâng, gập): hạ cánh nhanh (0–0,45) duỗi thẳng,
    nâng cánh chậm hơn (0,45–1) gập bàn cánh."""
    if phase < 0.45:
        t = phase / 0.45
        return math.radians(75 - 135 * (0.5 - 0.5 * math.cos(math.pi * t))), 0.05
    t = (phase - 0.45) / 0.55
    return math.radians(-60 + 135 * (0.5 - 0.5 * math.cos(math.pi * t))), 0.55 * math.sin(math.pi * t)
