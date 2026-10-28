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

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import paths  # noqa: E402,F401  (kits/, motion/, render/ — rules/dohoa/README.md)
import hero  # noqa: E402
from boss_kit import STILL, ROOT, add_object, fur_material, gold_material, parent_to_bone, render_to  # noqa: E402
from human_kit import camera, make_human, raw_ellipsoid, shadow_catcher, tapered_world, weights_by_group  # noqa: E402

# Màu thật (không nhân màu ở Flutter); tóc xoăn đen, da rám nắng.
hero.STILL = True
hero.FEMALE = False
hero.SKIN = "#A86E48"
hero.HAIR = "#1C120C"


# Dáng lực sĩ thần thoại bằng target chi tiết của MPFB (thân macro "cơ bắp"
# vẫn ra người tập gym bình thường): lưng chữ V, vai rộng, ngực và lưng xô
# nở, bắp tay–cẳng tay to, cổ bò, eo gọn, đùi bắp chân chắc, hàm vuông.
HERCULES_BODY = {
    "measure-upperarm-circ-incr": 1.0,
    "measure-thigh-circ-incr": 0.8,
    "measure-calf-circ-incr": 0.7,
    "torso-vshape-incr": 1.0,
    "measure-shoulder-dist-incr": 0.9,
    "torso-muscle-pectoral-incr": 1.0,
    "torso-muscle-dorsi-incr": 1.0,
    "torso-scale-depth-incr": 0.45,
    "torso-scale-horiz-incr": 0.5,
    "measure-bust-circ-incr": 0.8,
    "measure-waist-circ-decr": 0.35,
    "stomach-tone-incr": 1.0,
    "neck-scale-horiz-incr": 0.8,
    "neck-scale-depth-incr": 0.6,
    "measure-neck-circ-incr": 0.9,
    "measure-neck-height-decr": 0.4,
    "chin-width-incr": 0.6,
    "chin-prominent-incr": 0.5,
    "head-square": 0.7,
}
for s_ in ("l", "r"):
    HERCULES_BODY.update({
        f"{s_}-upperarm-muscle-incr": 1.0,
        f"{s_}-upperarm-shoulder-muscle-incr": 1.0,
        f"{s_}-upperarm-scale-horiz-incr": 1.0,
        f"{s_}-upperarm-scale-depth-incr": 1.0,
        f"{s_}-lowerarm-muscle-incr": 1.0,
        f"{s_}-lowerarm-scale-horiz-incr": 0.8,
        f"{s_}-lowerarm-scale-depth-incr": 0.6,
        f"{s_}-upperleg-muscle-incr": 0.9,
        f"{s_}-upperleg-scale-horiz-incr": 0.6,
        f"{s_}-upperleg-scale-depth-incr": 0.4,
        f"{s_}-lowerleg-muscle-incr": 0.8,
    })


def build_human(fat=0.35):
    return make_human(1.0, muscle=1.0, weight=0.75, height=1.0, age=0.68, proportions=1.0, scale=hero.K,
                      details=HERCULES_BODY)


hero.build_human = build_human

_tunic_group = hero.tunic_group


def skirt_only(body, rig, co):
    """Hercules cởi trần (khoe cơ ngực, bụng): áo exomis chỉ giữ phần váy
    dưới thắt lưng."""
    hem_z = _tunic_group(body, rig, co)
    waist_z = rig.data.bones["spine_01"].head_local.z + 0.04
    vg = body.vertex_groups["tunic"]
    vg.remove([i for i, p in enumerate(co) if p.z > waist_z])
    return hem_z


hero.tunic_group = skirt_only


def beard(body, rig, co):
    """Râu quai nón xoăn: phủ cằm, má dưới, viền hàm (trước và hai bên mặt)."""
    w = weights_by_group(body)
    bl = rig.data.bones
    head = bl["head"]
    lips = [co[i] for i in range(len(co)) if w[i].get("lips", 0) > 0.5]
    mouth_z = sum((p.z for p in lips), 0.0) / max(1, len(lips))
    jaw_top = mouth_z + (head.tail_local.z - head.head_local.z) * 0.18
    normals = [v.normal for v in body.data.vertices]
    # Tâm đầu theo chiều trước–sau: râu chỉ mọc ở nửa trước (cằm, má, hàm,
    # xuống tới cổ họng), không lan ra gáy.
    head_pts = [co[i] for i in range(len(co)) if w[i].get("head", 0) > 0.5]
    mid_y = sum((p.y for p in head_pts), 0.0) / max(1, len(head_pts))
    neck_z = bl["neck_01"].head_local.z + 0.02
    g = body.vertex_groups.new(name="beard")
    for i, p in enumerate(co):
        if w[i].get("HelperGeometry", 0) > 0.5 or w[i].get("lips", 0) > 0.3:
            continue
        if w[i].get("head", 0) + w[i].get("neck_01", 0) < 0.5:
            continue
        if neck_z < p.z < jaw_top and p.y < mid_y + 0.01 and normals[i].y < 0.5:
            g.add([i], 1.0, "REPLACE")
    mass = hero.shell_copy(body, "BeardMass", "beard", 0.012, 0.0, [hero.hair_mass_material()])
    mass.add_rest_position_attribute = True
    hair = fur_material("Beard", [(0.0, "#4A3020"), (0.5, hero.HAIR), (1.0, "#0A0604")], sheen=0.06)
    hero.with_fur(mass, hair, density=160000, length=(0.03, 0.06), radius=0.0016, comb=(0, -0.35, -1.0), lift=0.45,
                  gravity=0.008, jitter=0.9, seed=31, resolution=6)


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
            tip = p + Vector((side * 0.016, -0.04, 0.018)) * hero.K
            strands.append((p, p.lerp(tip, 0.5) + Vector((0, 0, 0.008)), tip, 0.011 * hero.K))
    o = add_object("Laurel", tapered_world("Laurel", strands, flat=3.0, taper=0.9), [gold])
    parent_to_bone(o, rig, "head")


def club(base, top):
    """Chuỳ gỗ ô liu chống đất: đầu chuỳ to sần ở dưới (gốc cây nhổ lên), cán
    thon lên tới [top] dưới lòng bàn tay, mấu cành cụt dọc thân."""
    from boss_kit import skin_material
    from human_kit import raw_tube
    wood = skin_material("ClubWood", "#5E3E26", rough=0.85, noise_scale=40)
    axis = top - base
    pts = [base + axis * t for t in (0.0, 0.08, 0.25, 0.5, 0.75, 0.95, 1.0)]
    radii = [(0.075, 0.075), (0.095, 0.09), (0.085, 0.08), (0.062, 0.06), (0.045, 0.045), (0.036, 0.036),
             (0.03, 0.03)]
    o = add_object("Club", raw_tube("Club", pts, radii, sides=18), [wood])
    side = axis.cross(Vector((0, 0, 1))).normalized()
    knots = []
    for t, a in ((0.18, 0.4), (0.3, 2.6), (0.45, 4.3), (0.62, 1.2)):
        b = base + axis * t
        d = (side * math.cos(a) + side.cross(axis.normalized()) * math.sin(a) + Vector((0, 0, 0.5))).normalized()
        knots.append((b, b + d * 0.045, b + d * 0.075, 0.024 * (1 - t * 0.6)))
    add_object("ClubKnots", tapered_world("ClubKnots", knots, taper=0.7), [wood])
    return o


# Quay ¾: mặt hướng giữa phải (+X) và máy quay (−Y) để thấy mặt và ngực
# (đứng nghiêng hẳn như nhân vật thì mặt, râu, cơ ngực đều khó đọc).
FACING = math.radians(52)


class HerculesPoser(hero.Poser):
    """Đứng ¾. Tay phải (phía máy quay) tì lên đầu cán chuỳ chống đất; tay
    trái (phía xa) buông, khi nói giơ ra trước về phía người chơi — cánh tay
    phía xa nên không che mặt."""

    def body_matrix(self, pitch, at=Vector()):
        from mathutils import Matrix
        return Matrix.Translation(at) @ Matrix.Rotation(pitch, 4, "Y") @ Matrix.Rotation(FACING, 4, "Z")             @ Matrix.Diagonal((hero.K, hero.K, hero.K, 1))

    @staticmethod
    def frame():
        """(trước mặt, bên trái nhân vật) trong toạ độ thế giới."""
        fwd = Vector((math.sin(FACING), -math.cos(FACING), 0))
        left = Vector((math.cos(FACING), math.sin(FACING), 0))
        return fwd, left

    def club_grip(self):
        """Chỗ cổ tay phải khi tì lên cán chuỳ (đã đặt dáng đứng)."""
        fwd, left = self.frame()
        sh = self.world("upperarm_r", 0.0)
        reach = self.a + self.b
        return sh - left * 0.2 + fwd * 0.12 - Vector((0, 0, reach * 0.88))

    def club_top(self):
        """Đầu cán chuỳ: ngay dưới giữa lòng bàn tay (trước cổ tay ~10 cm)."""
        fwd, _ = self.frame()
        return self.club_grip() + fwd * 0.1 - Vector((0, 0, 0.035))

    def talk(self, x0, k):
        """[k] 0 = tay trái buông, 1 = giơ ra trước cao ngang vai."""
        self.standing(x0)
        fwd, left = self.frame()
        up = Vector((0, 0, 1))
        t, p, *_ = self.ik["r"]
        sh = self.world("upperarm_r", 0.0)
        t.location = self.club_grip()
        p.location = sh - left * 0.5 - fwd * 0.2 - up * 0.2
        self.set_palm("r", fwd, -up)
        sh = self.world("upperarm_l", 0.0)
        t, p, *_ = self.ik["l"]
        reach = (self.a + self.b) * 0.95
        rest = sh + left * 0.1 + fwd * 0.06 - up * reach
        lift = sh + left * 0.1 + fwd * reach * 0.8 + up * reach * 0.3
        t.location = rest.lerp(lift, k)
        p.location = sh + left * 0.45 - fwd * 0.3 + up * (-0.3 + 0.4 * k)
        # Buông: ngón chỉ xuống, lòng bàn tay quay vào thân; giơ: ngón chỉ lên
        # hơi ra trước, lòng bàn tay hướng về người nghe.
        self.set_palm("l", -up * (1 - k) + (up * 0.9 + fwd * 0.3) * k, (-left).lerp(fwd, k))
        bpy.context.view_layer.update()


def main():
    scene = hero.reset_scene(samples=128, world_hex="#9DB6D2", world_strength=0.55, keep_prefs=True)
    body, rig, layers = hero.build()
    # Băng đầu đỏ là của người kế nhiệm; Hercules đội nguyệt quế.
    for o in [o for o in bpy.data.objects if o.name.startswith("Headband")]:
        bpy.data.objects.remove(o)
    co = hero.rest_coords(body)
    beard(body, rig, co)
    laurel(body, rig)
    poser = HerculesPoser(rig)
    poser.talk(0.0, 0.0)
    top = poser.club_top()
    club(Vector((top.x, top.y, 0.0)), top)
    hero.lights(scene)
    shadow_catcher()
    upm = 111.4  # cùng tỉ lệ mét → đơn vị sân khấu với nhân vật (hero.py in ra 111,4)
    x0 = 0.0
    out = os.path.join(ROOT, "build", "blender", "hercules")
    os.makedirs(out, exist_ok=True)
    if STILL:
        camera(scene, 0.0, 1.2, 1.7, 2.6, 380)
        for name, k in (("idle", 0.0), ("talk", 1.0)):
            poser.talk(x0, k)
            render_to(scene, os.path.join(out, f"{name}.png"))
        from boss_kit import save_blend
        save_blend("hercules")
        return
    from sprite_kit import export_sprites
    anims = {
        "idle": [lambda: poser.talk(x0, 0.0)],
        # 7 khung: khung kề nhau gần nhau, hoà khung không ra bóng ma tay.
        "talk": [lambda k=k: poser.talk(x0, k / 6) for k in range(7)],
    }
    cam = camera(scene, 0.0, 1.2, 1.8, 2.7, 3.0 * upm * 0.85, yaw=-10, pitch=7)
    export_sprites(scene, cam, "hercules", anims, Vector(), upm, extra={"talkPeriod": 1.6})


main()
