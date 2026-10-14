# blender: user-prefs  (cần tiện ích MPFB + gói tài nguyên hệ thống — xem rules/dohoa.md mục 10)
"""Susanoo cuồng nộ, thần bão (Kỳ công Izumo, boss mở màn). Theo tranh tham
khảo người dùng chọn (thần tóc bạc giáp trắng–vàng cầm kiếm, hào quang sau
lưng) và tranh Kuniyoshi "Susanoo và rồng nước": da trắng ngà như tượng
cẩm thạch, cơ bắp, tóc bạc dài ánh lục–tím tung theo gió bão, mắt lục phát
sáng; vương miện vàng đính đá lam, chùm lông trắng dựng; chuỗi ngọc trai, giáp
vai vàng, giáp tay trắng viền vàng, đai vàng mặt tròn, váy giáp trắng viền
vàng trên quần chàm; kiếm Totsuka thẳng hai lưỡi; vòng hào quang vàng; lửa
ma (onibi) xanh lam bay quanh — thần đang bị Trì Trệ làm phát cuồng.

    bash tool/blender/render.sh susanoo_boss --still     # ảnh duyệt
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from bird_kit import blade, feather_material  # noqa: E402
from boss_kit import ROOT, add_object, add_sun, glow_material, gold_material, parent_to_bone, render_to, \
    reset_scene, skin_material  # noqa: E402
from hair_kit import hair_material, ribbon_locks, strand_locks  # noqa: E402
from human_kit import camera, group_center, raw_ellipsoid, raw_tube, rest_coords, shadow_catcher, \
    tapered_world  # noqa: E402
from japan_kit import StandPoser, beads, body_ring, boss_human, bone_point, ellipse_ring, flame, flame_material, \
    hakama, head_frame, limb_band, painted_skin, silk_material  # noqa: E402

S = 1.25

SUSANOO_BODY = {
    "torso-vshape-incr": 1.0,
    "measure-shoulder-dist-incr": 1.0,
    "torso-muscle-pectoral-incr": 1.0,
    "torso-muscle-dorsi-incr": 1.0,
    "stomach-tone-incr": 1.0,
    "measure-waist-circ-decr": 0.4,
    "neck-scale-horiz-incr": 0.7,
    "measure-neck-circ-incr": 0.8,
    "chin-width-incr": 0.5,
    "chin-prominent-incr": 0.5,
    "head-square": 0.6,
    "eyebrows-angle-down": 0.7,
}
for s_ in ("l", "r"):
    SUSANOO_BODY.update({
        f"{s_}-upperarm-muscle-incr": 1.0,
        f"{s_}-upperarm-shoulder-muscle-incr": 1.0,
        f"{s_}-upperarm-scale-horiz-incr": 0.8,
        f"{s_}-lowerarm-muscle-incr": 1.0,
        f"{s_}-upperleg-muscle-incr": 0.8,
    })


def storm_hair(rig, head_c, up, fwd, right):
    """Tóc bạc dài dày, ánh lục ở gốc và tím ở ngọn, tung về một bên như bị
    gió bão thổi; lọn mái rủ hai bên má."""
    rng = random.Random(21)
    lock_m = skin_material("SilverLock", "#DCE4E0", rough=0.45)
    strands = hair_material("SilverHair", "#A8C8B8", "#E8EEEA", "#C8B8E0", rough=0.3)
    back = -fwd
    wind = (back * 0.7 - right * 0.5).normalized()  # gió thổi ra sau, về phía xa người chơi
    locks, guides = [], []
    R = 0.1 * S
    for k in range(150):
        az = rng.uniform(-math.pi, math.pi)
        el = rng.uniform(-0.2, 1.3)
        d = (back * math.cos(az) + right * math.sin(az)) * math.cos(el) + up * math.sin(el)
        if d.dot(fwd) > (0.55 if el > 0.6 else 0.1):
            continue
        root = head_c + d * R
        length = rng.uniform(0.45, 0.8) * S
        tip = root + (wind * 0.8 + d * 0.25 - up * rng.uniform(0.3, 0.9)).normalized() * length
        mid = root.lerp(tip, 0.4) + d * 0.06 * S + up * 0.06 * S
        locks.append((root, mid, tip, rng.uniform(0.01, 0.018) * S))
        guides.append([root.lerp(mid, t * 2) if t < 0.5 else mid.lerp(tip, (t - 0.5) * 2)
                       for t in [i / 9 for i in range(10)]])
    # Hai lọn mái dài rủ trước tai.
    for s in (-1, 1):
        root = head_c + up * 0.07 * S + fwd * 0.06 * S + right * s * 0.06 * S
        tip = root + right * s * 0.05 * S - up * 0.4 * S + fwd * 0.04 * S
        mid = root + right * s * 0.06 * S - up * 0.12 * S + fwd * 0.03 * S
        for j in range(4):
            off = right * s * 0.008 * j * S
            locks.append((root + off, mid + off, tip + off * 2, 0.012 * S))
            guides.append([(root + off).lerp(mid + off, t * 2) if t < 0.5 else (mid + off).lerp(tip + off * 2, (t - 0.5) * 2)
                           for t in [i / 9 for i in range(10)]])
    ro = ribbon_locks("HairLocks", locks, lock_m, flat=1.8, taper=1.2)
    so = strand_locks("HairStrands", guides, strands, per_lock=55, spread=0.025 * S, clump=0.45, frizz=0.006 * S,
                      root_radius=0.0013 * S, seed=8)
    for o in (ro, so):
        parent_to_bone(o, rig, "head")


def crown(rig, head_c, up, fwd, right, gold, gem, plume):
    """Vương miện: vòng vàng chạm hoa văn ôm trán, mặt trước hình ngọn lửa
    đính đá lam, hai cánh vàng hai bên thái dương, chùm lông trắng dựng."""
    out = []
    c = head_c + up * 0.055 * S
    ring = [c + (right * math.cos(2 * math.pi * k / 48) * 0.098 + fwd * math.sin(2 * math.pi * k / 48) * 0.112) * S
            + up * 0.012 * S * math.sin(2 * math.pi * k / 48) for k in range(48)]
    out.append(add_object("Crown", raw_tube("Crown", ring, [(0.006 * S, 0.016 * S)] * 48, sides=8, closed=True), [gold]))
    front = c + fwd * 0.115 * S + up * 0.01 * S
    # Mặt lửa: các nhánh vàng cong toả lên như ngọn lửa.
    flames = []
    for k in range(7):
        a = math.radians(-60 + 20 * k)
        dd = (up * math.cos(a) + right * math.sin(a)).normalized()
        L = (0.09 - 0.02 * abs(k - 3) / 3) * S
        flames.append((front, front + dd * L * 0.5 + fwd * 0.01 * S, front + dd * L + up * 0.01 * S
                       - right * math.sin(a) * 0.01 * S, 0.012 * S))
    out.append(add_object("CrownFlame", tapered_world("CrownFlame", flames, flat=2.5, taper=1.0), [gold]))
    out.append(add_object("CrownGem", raw_ellipsoid("CrownGem", front + up * 0.012 * S + fwd * 0.012 * S,
                                                    (0.016 * S, 0.012 * S, 0.02 * S)), [gem]))
    for s in (-1, 1):
        t = c + right * s * 0.1 * S + fwd * 0.02 * S
        wing = [(t, t + right * s * 0.03 * S + up * 0.03 * S - fwd * 0.02 * S,
                 t + right * s * 0.02 * S + up * 0.08 * S - fwd * 0.05 * S, 0.014 * S),
                (t, t + right * s * 0.035 * S + up * 0.01 * S - fwd * 0.03 * S,
                 t + right * s * 0.03 * S + up * 0.05 * S - fwd * 0.08 * S, 0.01 * S)]
        out.append(add_object("CrownWing", tapered_world("CrownWing", wing, flat=2.6, taper=1.0), [gold]))
        out.append(add_object("CrownGemS", raw_ellipsoid("CrownGemS", t + fwd * 0.008 * S,
                                                         (0.009 * S,) * 3), [gem]))
    # Chùm lông trắng dựng sau mặt lửa.
    for k in range(9):
        a = math.radians(-40 + 10 * k)
        dd = (up * math.cos(a) + right * math.sin(a) * 0.8 - fwd * 0.25).normalized()
        out.append(blade(f"Plume{k}", c + fwd * 0.07 * S + up * 0.02 * S, dd, fwd, (0.16 + 0.04 * math.cos(a * 2)) * S,
                         0.02 * S, plume, curve=-0.12, tone=0.8))
    for o in out:
        parent_to_bone(o, rig, "head")


def pauldron(rig, side, gold, white, gem):
    """Giáp vai: ba lá vàng xếp chồng, viền trắng, đá lam giữa."""
    out = []
    sh = bone_point(rig, f"upperarm_{side}", 0.08)
    sx = 1 if side == "l" else -1
    for k in range(3):
        c = sh + Vector((sx * (0.03 + 0.02 * k), 0, 0.05 - 0.045 * k)) * S
        out.append(add_object(f"Pauldron{k}", raw_ellipsoid(f"Pauldron{k}", c, ((0.09 - 0.008 * k) * S,
                                                                               (0.095 - 0.008 * k) * S,
                                                                               0.035 * S)), [gold if k != 1 else white]))
    out.append(add_object("PauldronGem", raw_ellipsoid("PauldronGem", sh + Vector((sx * 0.08, -0.07, 0.06)) * S,
                                                       (0.018 * S,) * 3), [gem]))
    # Cuộn vàng hai bên (hoa văn xoắn).
    for k in range(2):
        b0 = sh + Vector((sx * (0.06 + 0.03 * k), -0.08, 0.02 - 0.04 * k)) * S
        out.append(add_object("PauldronCurl", tapered_world("PauldronCurl", [
            (b0, b0 + Vector((sx * 0.03, -0.01, 0.03)) * S, b0 + Vector((sx * 0.06, 0.0, 0.0)) * S, 0.01 * S)],
            taper=0.8), [gold]))
    for o in out:
        parent_to_bone(o, rig, f"upperarm_{side}")
    return out


def skirt_plates(rig, c, rx, ry, top_z, length, white, gold):
    """Váy giáp (kusazuri): các tấm trắng cong rủ quanh hông, viền vàng."""
    import bmesh
    out = []
    n = 9
    for k in range(n):
        a0 = math.pi * (1.05 + 0.9 * k / n)  # nửa trước + hai bên
        a1 = a0 + math.pi * 0.9 / n * 1.15
        bm = bmesh.new()
        rows = []
        for r in range(7):
            t = r / 6
            z = top_z - length * t
            flare = 1.0 + 0.35 * t
            row = []
            for j in range(5):
                a = a0 + (a1 - a0) * j / 4
                row.append(bm.verts.new(c + Vector((rx * flare * math.cos(a), ry * flare * math.sin(a), z - c.z))))
            rows.append(row)
        for r in range(6):
            for j in range(4):
                bm.faces.new((rows[r][j], rows[r][j + 1], rows[r + 1][j + 1], rows[r + 1][j]))
        mesh = bpy.data.meshes.new(f"Plate{k}")
        bm.to_mesh(mesh)
        bm.free()
        o = add_object(f"Plate{k}", mesh, [white])
        sol = o.modifiers.new("Thick", "SOLIDIFY")
        sol.thickness = 0.01 * S
        out.append(o)
        # Viền vàng dưới gấu tấm.
        hem = [c + Vector((rx * 1.36 * math.cos(a0 + (a1 - a0) * j / 8), ry * 1.36 * math.sin(a0 + (a1 - a0) * j / 8),
                           top_z - length - c.z)) for j in range(9)]
        out.append(add_object(f"PlateHem{k}", raw_tube(f"PlateHem{k}", hem, [(0.008 * S,) * 2] * 9, sides=8), [gold]))
        # Cuộn vân vàng giữa tấm.
        am = (a0 + a1) / 2
        cc = c + Vector((rx * 1.18 * math.cos(am), ry * 1.18 * math.sin(am), top_z - length * 0.5 - c.z))
        ring = [cc + Vector((math.cos(am) * 0.004, math.sin(am) * 0.004, 0)) * S
                + Vector((-math.sin(am), math.cos(am), 0)) * math.cos(2 * math.pi * j / 16) * 0.03 * S
                + Vector((0, 0, 1)) * math.sin(2 * math.pi * j / 16) * 0.03 * S for j in range(16)]
        out.append(add_object(f"PlateSwirl{k}", raw_tube(f"PlateSwirl{k}", ring, [(0.004 * S,) * 2] * 16, sides=6,
                                                         closed=True), [gold]))
    for o in out:
        parent_to_bone(o, rig, "pelvis")
    return out


def totsuka(grip, direction, flat_dir, steel, gold, wrap):
    """Kiếm Totsuka-no-Tsurugi: kiếm thẳng hai lưỡi cổ (ken), chắn vàng hình
    mây, chuôi quấn dây chàm, núm vàng."""
    d = direction.normalized()
    f = flat_dir.normalized()
    w = d.cross(f).normalized()
    out = []
    pommel = grip - d * 0.11 * S
    guard = grip + d * 0.07 * S
    out.append(add_object("Grip", raw_tube("Grip", [pommel, grip, guard], [(0.016 * S,) * 2, (0.017 * S,) * 2,
                                                                           (0.016 * S,) * 2], sides=10), [wrap]))
    out.append(add_object("Pommel", raw_ellipsoid("Pommel", pommel - d * 0.012 * S, (0.024 * S,) * 3), [gold]))
    out.append(add_object("Guard", raw_ellipsoid("Guard", guard, (0.07 * S, 0.07 * S, 0.016 * S)), [gold]))
    import bmesh
    bm = bmesh.new()
    L = 0.95 * S
    rows = []
    for i in range(12):
        t = i / 11
        c = guard + d * L * t
        hw = 0.034 * S * (1 - 0.25 * t) if t < 0.9 else 0.034 * S * 0.75 * (1 - (t - 0.9) / 0.1)
        th = 0.008 * S * (1 - 0.6 * t)
        rows.append([bm.verts.new(c - w * hw), bm.verts.new(c + f * th), bm.verts.new(c + w * hw),
                     bm.verts.new(c - f * th)])
    for i in range(11):
        for k in range(4):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % 4], rows[i + 1][(k + 1) % 4], rows[i + 1][k]))
    mesh = bpy.data.meshes.new("Blade")
    bm.to_mesh(mesh)
    bm.free()
    out.append(add_object("Blade", mesh, [steel], smooth_shade=False))
    return out


def halo(center, normal, up, gold, r=0.55):
    """Vòng hào quang vàng sau lưng: vòng tròn + tia lửa ngắn toả ra."""
    side = up.cross(normal).normalized()
    up2 = normal.cross(side).normalized()
    ring = [center + (side * math.cos(2 * math.pi * k / 96) + up2 * math.sin(2 * math.pi * k / 96)) * r * S
            for k in range(96)]
    out = [add_object("Halo", raw_tube("Halo", ring, [(0.012 * S, 0.012 * S)] * 96, sides=10, closed=True), [gold])]
    rays = []
    for k in range(24):
        a = 2 * math.pi * k / 24
        dd = side * math.cos(a) + up2 * math.sin(a)
        b0 = center + dd * r * S * 1.02
        rays.append((b0, b0 + dd * 0.05 * S + (side * -math.sin(a) + up2 * math.cos(a)) * 0.02 * S,
                     b0 + dd * (0.1 + 0.04 * (k % 2)) * S, 0.012 * S))
    out.append(add_object("HaloRays", tapered_world("HaloRays", rays, flat=2.4, taper=1.0), [gold]))
    return out


def build():
    body, rig, parts = boss_human(1.0, muscle=1.0, weight=0.55, height=1.0, age=0.5, proportions=1.0, scale=S,
                                  details=SUSANOO_BODY, eyebrows=None)
    skin = painted_skin("MarbleSkin", "#E6E8EA", "#BCC4CE", sss=0.25, rough=0.5)
    body.data.materials.clear()
    body.data.materials.append(skin)
    if "eyes" in parts:
        parts["eyes"].data.materials.clear()
        parts["eyes"].data.materials.append(glow_material("GodEye", "#A8FFD8", strength=3.0, base="#60D0A0"))
    co = rest_coords(body)
    bl = rig.data.bones
    head_c, up, fwd, right = head_frame(rig)
    gold = gold_material("GodGold", "#E2B656", rough=0.25)
    white = skin_material("WhiteArmor", "#ECEEF0", rough=0.3, noise_scale=30)
    gem = glow_material("Lapis", "#3A6AE8", strength=0.6, base="#1A3AA0")
    plume = feather_material("Plume", "#C8D0D8", "#FFFFFF", sheen="#E8F0FF", metallic=0.05, rough=0.5)
    pearl = skin_material("Pearl", "#F4F0EA", rough=0.15)
    navy = silk_material("Hakama", "#1E2648", pattern="#2E3868", trim="#C8A050", sheen=0.5)

    storm_hair(rig, head_c, up, fwd, right)
    # Mày bạc rậm chau.
    brow_m = skin_material("SilverBrow", "#E6ECE8", rough=0.5)
    for g, s in (("helper-l-eye", 1), ("helper-r-eye", -1)):
        c = group_center(body, g, co)
        side = -right if s > 0 else right
        lk = []
        for k in range(6):
            t = k / 5
            a = c + up * (0.022 + 0.005 * t) * S + fwd * 0.012 * S + side * (0.003 + 0.028 * t) * S
            tip = a + side * 0.03 * S + up * (0.018 - 0.006 * t) * S - fwd * 0.01 * S
            lk.append((a, a.lerp(tip, 0.5) + up * 0.006 * S, tip, 0.006 * S))
        o = ribbon_locks(f"Brow{s}", lk, brow_m, flat=1.8, taper=1.0)
        parent_to_bone(o, rig, "head")
    crown(rig, head_c, up, fwd, right, gold, gem, plume)

    # ---- chuỗi ngọc trai + cổ giáp vàng
    neck_base = bone_point(rig, "neck_01", 0.0) - up * 0.02 * S
    beads("Pearl", neck_base + fwd * 0.03 * S, 0.12 * S, 0.1 * S, 0.06 * S, 34, 0.012 * S, pearl, rig, "spine_03",
          big={25: (0.026 * S, gem)})
    beads("Pearl2", neck_base + fwd * 0.035 * S - up * 0.03 * S, 0.14 * S, 0.115 * S, 0.11 * S, 40, 0.011 * S, pearl,
          rig, "spine_03")
    pauldron(rig, "l", gold, white, gem)
    pauldron(rig, "r", gold, white, gem)

    # ---- giáp tay trắng viền vàng
    for s in ("l", "r"):
        limb_band(rig, f"lowerarm_{s}", 0.35, 0.95, 0.055 * S, 0.047 * S, white, f"Vambrace{s}")
        for t in (0.37, 0.93):
            limb_band(rig, f"lowerarm_{s}", t - 0.02, t + 0.02, 0.058 * S, 0.05 * S, gold, f"VamBand{s}")
        limb_band(rig, f"upperarm_{s}", 0.55, 0.62, 0.068 * S, 0.066 * S, gold, f"Armlet{s}")

    # ---- đai vàng + mặt tròn, váy giáp, quần chàm
    waist_z = bl["pelvis"].head_local.z + 0.06
    c, rx, ry = body_ring(body, co, waist_z, ("pelvis", "spine_01"), pad=0.03)
    belt = add_object("Belt", raw_tube("Belt", ellipse_ring(c, rx, ry, n=48), [(0.012 * S, 0.035 * S)] * 48, sides=10,
                                       closed=True), [gold])
    parent_to_bone(belt, rig, "pelvis")
    med = c - Vector((0, ry + 0.015 * S, 0))
    for o in (add_object("Medallion", raw_ellipsoid("Medallion", med, (0.05 * S, 0.014 * S, 0.05 * S)), [gold]),
              add_object("MedGem", raw_ellipsoid("MedGem", med - Vector((0, 0.012 * S, 0)), (0.02 * S, 0.008 * S,
                                                                                              0.02 * S)), [gem])):
        parent_to_bone(o, rig, "pelvis")
    hakama(body, co, rig, "Hakama", navy, flare=0.08 * S)
    skirt_plates(rig, c, rx * 1.15, ry * 1.2, c.z - 0.015 * S, 0.4 * S, white, gold)
    fire = flame_material("BlueOnibi", "#A8E8FF", "#2050E0", strength=2.2)
    return body, rig, {"gold": gold, "white": white, "fire": fire}


def pose(rig, mats):
    poser = StandPoser(rig, facing_deg=-40, scale=S)
    poser.place(stance=math.radians(15), crouch=math.radians(12))
    fwd, left, up = poser.frame()
    right = -left
    reach = poser.a + poser.b
    sh_r = poser.world("upperarm_r", 0.0)
    poser.arm("r", sh_r + fwd * reach * 0.45 + right * reach * 0.35 - up * reach * 0.6, sh_r + right * 0.5)
    sh_l = poser.world("upperarm_l", 0.0)
    poser.arm("l", sh_l + left * reach * 0.55 + fwd * reach * 0.5 - up * reach * 0.15, sh_l + left * 0.4 - up * 0.6)
    steel = skin_material("Steel", "#C8D4E0", rough=0.12, metallic=1.0, noise_scale=80)
    wrap = skin_material("GripWrap", "#1E2A58", rough=0.7, noise_scale=200)
    hand = poser.world("hand_r", 0.7)
    totsuka(hand, (fwd * 0.75 - up * 0.55 + right * 0.2), up, steel, mats["gold"], wrap)
    back = poser.world("spine_03", 0.8) - fwd * 0.22 * S
    halo(back, -fwd, up, mats["gold"], r=0.48)
    # Lửa ma xanh: một ngọn trên lòng bàn tay trái, vài ngọn bay quanh.
    palm = poser.world("hand_l", 0.6) + up * 0.05 * S
    flame("Onibi", palm, 0.24 * S, 0.1 * S, mats["fire"], lean=fwd * 0.04 * S, tongues=4, seed=2)
    rng = random.Random(6)
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        p = poser.world("spine_03", 0.5) + (left * math.cos(a) + up * math.sin(a) * 0.8) * 0.75 * S - fwd * 0.1 * S
        flame(f"OnibiF{k}", p, rng.uniform(0.1, 0.16) * S, 0.06 * S, mats["fire"], tongues=3, seed=10 + k)
    return poser


def lights(scene):
    add_sun(scene, "Key", (0.35, 0.75, -0.55), 3.4, "#FFF4E4", angle=3)
    add_sun(scene, "Rim", (-0.75, -0.3, -0.25), 3.6, "#9EC8FF", angle=4)
    add_sun(scene, "Fill", (0.2, 0.9, 0.2), 0.6, "#C8E0FF", angle=20)


def main():
    scene = reset_scene(samples=96, world_hex="#C9C4C0", world_strength=0.7, keep_prefs=True)
    body, rig, mats = build()
    pose(rig, mats)
    lights(scene)
    shadow_catcher()
    out = os.path.join(ROOT, "build", "blender", "susanoo")
    os.makedirs(out, exist_ok=True)
    camera(scene, 0.0, 1.25 * S, 2.8 * S, 2.9 * S, 240, yaw=-8, pitch=6)
    render_to(scene, os.path.join(out, "still_full.png"))
    pb = rig.pose.bones["head"]
    head = rig.matrix_world @ pb.head.lerp(pb.tail, 0.5)
    camera(scene, head.x - 0.05, head.z + 0.03, 0.65 * S, 0.65 * S, 850, yaw=-8, pitch=4)
    render_to(scene, os.path.join(out, "still_face.png"))
    from boss_kit import save_blend
    save_blend("susanoo_boss")


main()
