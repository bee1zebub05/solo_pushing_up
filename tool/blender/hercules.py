# blender: user-prefs  (cần tiện ích MPFB — xem tool/blender/render.sh)
"""Hercules hiện về ở cảnh mở đầu Kỳ công 1 (lib/ui/nemea_intro_screen.dart):
người khổng lồ trung niên cơ bắp cuồn cuộn, râu quai nón xoăn, vòng nguyệt
quế vàng, khoác da Sư tử Nemea (mũ đầu sư tử, tấm da sau lưng), chuỳ gỗ ô
liu sần sùi chống đất. Dựng lại từ bộ nhân vật (hero.py: thân MPFB, áo
exomis, đai, sandal, áo da sư tử) với tham số người khác.

    bash tool/blender/render.sh hercules --still   # ảnh duyệt
    bash tool/blender/render.sh hercules           # atlas `hercules`

Chuỗi: `idle` (đứng, tay buông) và `talk` (giơ tay phải khi nói, 0 → 1).
Quay mặt sang phải như nhân vật; Flutter lật ngang để Hercules nhìn về
người chơi. Cùng tỉ lệ mét → đơn vị sân khấu với nhân vật.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import hero  # noqa: E402
from boss_kit import STILL, ROOT, add_object, fur_material, gold_material, parent_to_bone, render_to  # noqa: E402
from human_kit import camera, make_human, raw_ellipsoid, shadow_catcher, tapered_world, weights_by_group  # noqa: E402

# Màu thật (không nhân màu ở Flutter); tóc xoăn đen, da rám nắng.
hero.STILL = True
hero.FEMALE = False
hero.SKIN = "#B98058"
hero.HAIR = "#1C120C"


def build_human(fat=0.35):
    return make_human(1.0, muscle=1.0, weight=0.62, height=0.9, age=0.68, scale=hero.K)


hero.build_human = build_human


def beard(body, rig, co):
    """Râu quai nón xoăn: phủ cằm, má dưới, viền hàm (trước và hai bên mặt)."""
    w = weights_by_group(body)
    bl = rig.data.bones
    head = bl["head"]
    lips = [co[i] for i in range(len(co)) if w[i].get("lips", 0) > 0.5]
    mouth_z = sum((p.z for p in lips), 0.0) / max(1, len(lips))
    jaw_top = mouth_z + (head.tail_local.z - head.head_local.z) * 0.18
    normals = [v.normal for v in body.data.vertices]
    g = body.vertex_groups.new(name="beard")
    for i, p in enumerate(co):
        if w[i].get("head", 0) < 0.5 or w[i].get("HelperGeometry", 0) > 0.5 or w[i].get("lips", 0) > 0.3:
            continue
        if p.z < jaw_top and normals[i].y < 0.35 and p.z > head.head_local.z - 0.03:
            g.add([i], 1.0, "REPLACE")
    mass = hero.shell_copy(body, "BeardMass", "beard", 0.006, 0.0, [hero.hair_mass_material()])
    mass.add_rest_position_attribute = True
    hair = fur_material("Beard", [(0.0, "#4A3020"), (0.5, hero.HAIR), (1.0, "#0A0604")], sheen=0.06)
    hero.with_fur(mass, hair, density=60000, length=(0.018, 0.04), radius=0.0011, comb=(0, -0.2, -1.0), lift=0.5,
                  gravity=0.006, jitter=1.0, seed=31, resolution=6)


def laurel(body, rig):
    """Vòng nguyệt quế vàng: hai cành lá mác ôm quanh đầu trên tai."""
    bl = rig.data.bones
    c = rig.matrix_world @ bl["head"].head_local.lerp(bl["head"].tail_local, 0.62)
    gold = gold_material("LaurelGold", "#E8B840", rough=0.3)
    strands = []
    for side in (-1, 1):
        for k in range(9):
            a = math.radians(-70 + k * 17)
            # Vòng elip quanh đầu (MPFB nhìn về −Y), lá chĩa về phía trán.
            p = c + Vector((side * 0.085 * math.cos(a), 0.095 * math.sin(a) + 0.01, 0.025)) * hero.K
            tip = p + Vector((side * 0.012, -0.028, 0.012)) * hero.K
            strands.append((p, p.lerp(tip, 0.5) + Vector((0, 0, 0.006)), tip, 0.006 * hero.K))
    o = add_object("Laurel", tapered_world("Laurel", strands, flat=3.0, taper=0.9), [gold])
    parent_to_bone(o, rig, "head")


def club():
    """Chuỳ gỗ ô liu: thân thon dần, mấu cành cụt, đầu chuỳ to sần."""
    from boss_kit import skin_material
    wood = skin_material("ClubWood", "#6A4A30", rough=0.8, noise_scale=40)
    # Từ đầu chuỳ (to) xuống cán chống đất (thon).
    pts = [Vector((0.25, 0.06, 0.95)), Vector((0.22, 0.06, 0.45)), Vector((0.2, 0.06, 0.0))]
    o = add_object("Club", tapered_world("Club", [(pts[0], pts[1], pts[2], 0.075)], sides=14, taper=0.4), [wood])
    knots = []
    for k, (z, a) in enumerate(((0.55, 0.3), (0.7, 2.4), (0.82, 4.1), (0.4, 5.0))):
        b = Vector((0.22 + 0.03 * z, 0.06, z))
        d = Vector((math.cos(a), math.sin(a), 0.4)).normalized() * 0.07
        knots.append((b, b + d * 0.6, b + d, 0.022))
    add_object("ClubKnots", tapered_world("ClubKnots", knots, taper=0.7), [wood])
    return o


class HerculesPoser(hero.Poser):
    def talk(self, x0, k):
        """Đứng, tay phải giơ lên ngang đầu, lòng bàn tay hướng ra trước (đang nói)."""
        self.standing(x0)
        if k <= 0:
            return
        sh = self.world("upperarm_r", 0.0)
        t, p, *_ = self.ik["r"]
        reach = (self.a + self.b) * 0.9
        rest = sh + Vector((0.03, -0.06, -reach))
        up = sh + Vector((0.18, -0.12, reach * 0.55))
        t.location = rest.lerp(up, k)
        p.location = sh + Vector((0.1, -0.4, -0.3 + 0.5 * k))
        self.set_palm("r", Vector((0.1, 0, 1)).lerp(Vector((0.05, 0, -1)), 1 - k), Vector((1, 0, 0)))
        bpy.context.view_layer.update()


def main():
    scene = hero.reset_scene(samples=128, world_hex="#9DB6D2", world_strength=0.55, keep_prefs=True)
    body, rig, layers = hero.build()
    co = hero.rest_coords(body)
    beard(body, rig, co)
    laurel(body, rig)
    club()
    poser = HerculesPoser(rig)
    hero.lights(scene)
    shadow_catcher()
    upm = 111.4  # cùng tỉ lệ mét → đơn vị sân khấu với nhân vật (hero.py in ra 111,4)
    x0 = 0.0
    out = os.path.join(ROOT, "build", "blender", "hercules")
    os.makedirs(out, exist_ok=True)
    if STILL:
        camera(scene, 0.0, 1.05, 1.5, 2.3, 400)
        for name, k in (("idle", 0.0), ("talk", 1.0)):
            poser.talk(x0, k)
            render_to(scene, os.path.join(out, f"{name}.png"))
        from boss_kit import save_blend
        save_blend("hercules")
        return
    from sprite_kit import export_sprites
    anims = {
        "idle": [lambda: poser.talk(x0, 0.0)],
        "talk": [lambda k=k: poser.talk(x0, k / 3) for k in range(4)],
    }
    cam = camera(scene, 0.0, 1.05, 1.6, 2.4, 3.0 * upm * 0.85, yaw=-10, pitch=7)
    export_sprites(scene, cam, "hercules", anims, Vector(), upm, extra={"talkPeriod": 1.6})


main()
