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

from boss_kit import add_object
from human_kit import raw_tube, tapered_world


def _feathers(name, specs, mat, mirror):
    """[specs]: (gốc, hướng, dài, nửa rộng, độ cao lớp, độ cong) → một lưới."""
    strands = []
    for root, d, length, half_w, lift, bend in specs:
        root = Vector(root) + Vector((0, 0, lift))
        d = Vector(d).normalized()
        tip = root + d * length
        mid = root + d * length * 0.5 + Vector((0, 0, -bend * length))
        rad = half_w / 2.6
        strands.append((root, mid, tip - Vector((0, 0, bend * length * 0.6)), rad))
    if mirror:
        strands = [(Vector((a.x, -a.y, a.z)), Vector((b.x, -b.y, b.z)), Vector((c.x, -c.y, c.z)), r)
                   for a, b, c, r in strands]
    return add_object(name, tapered_world(name, strands, sides=8, steps=8, flat=2.6, taper=0.55), [mat])


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
                 for k, (L, r0, r1) in enumerate(((l1, 0.04 * s, 0.03 * s), (l2, 0.03 * s, 0.02 * s),
                                                  (l3, 0.02 * s, 0.01 * s)))]
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
