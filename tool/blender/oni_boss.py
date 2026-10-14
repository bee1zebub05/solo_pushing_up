# blender: user-prefs  (cần tiện ích MPFB + gói tài nguyên hệ thống — xem rules/dohoa.md mục 10)
"""Shuten-dōji, vua oni núi Ōe (Kỳ công Izumo). Theo tranh tham khảo người
dùng chọn (oni đỏ vác chuỳ gai) và tranh mộc bản Yoshitsuya / Yoshitoshi:
khổng lồ da đỏ xăm xoáy, bụng phệ cơ bắp, sừng đỏ sẫm có gờ, bờm trắng dựng
ngược từng lọn, mày trắng rậm, mắt hổ phách, nanh chìa; chuỗi hạt đen to có
mặt đồng vàng, đai thừng shimenawa với khoá mặt quỷ, tạp dề chàm thêu chữ 鬼,
quần hakama chàm vân mây, giáp tay vàng–đen, móng vuốt đen; vác chuỳ sắt gai
(kanabō) trên vai phải, tay trái nâng lửa ma đỏ.

    bash tool/blender/render.sh oni_boss --still     # ảnh duyệt
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import STILL, ROOT, add_object, add_sun, glow_material, gold_material, parent_to_bone, render_to, \
    reset_scene, skin_material  # noqa: E402
from hair_kit import hair_material, ribbon_locks, strand_locks  # noqa: E402
from human_kit import camera, group_center, raw_ellipsoid, raw_tube, rest_coords, shadow_catcher, \
    tapered_world, weights_by_group  # noqa: E402
from japan_kit import StandPoser, beads, body_ring, boss_human, bone_point, claws, ellipse_ring, flame, \
    flame_material, hakama, head_frame, horn, inflate, kanji_plate, limb_band, painted_skin, silk_material, \
    twisted_rope  # noqa: E402

S = 1.45  # khổng lồ lùn bè, ~2,3 m

ONI_BODY = {
    "stomach-pregnant-incr": 1.0,
    "torso-scale-horiz-incr": 1.0,
    "torso-scale-depth-incr": 0.8,
    "torso-scale-vert-decr": 0.4,
    "lowerlegs-height-decr": 0.6,
    "measure-lowerleg-height-decr": 0.5,
    "measure-shoulder-dist-incr": 1.0,
    "torso-muscle-pectoral-incr": 1.0,
    "neck-scale-horiz-incr": 1.0,
    "neck-scale-depth-incr": 0.8,
    "measure-neck-height-decr": 0.7,
    "chin-width-incr": 0.9,
    "chin-prominent-incr": 0.6,
    "head-square": 0.8,
    "mouth-scale-horiz-incr": 0.7,
    "mouth-angles-down": 0.8,
    "eyebrows-trans-down": 0.7,
    "eyebrows-angle-down": 0.8,
    "measure-upperarm-circ-incr": 1.0,
    "measure-thigh-circ-incr": 1.0,
    "measure-calf-circ-incr": 0.8,
}
for s_ in ("l", "r"):
    ONI_BODY.update({
        f"{s_}-upperarm-muscle-incr": 1.0,
        f"{s_}-upperarm-scale-horiz-incr": 1.0,
        f"{s_}-upperarm-scale-depth-incr": 1.0,
        f"{s_}-lowerarm-muscle-incr": 1.0,
        f"{s_}-lowerarm-scale-horiz-incr": 1.0,
        f"{s_}-lowerarm-scale-depth-incr": 0.8,
        f"{s_}-hand-scale-incr": 0.8,
        f"{s_}-upperleg-scale-horiz-incr": 0.8,
        f"{s_}-upperleg-scale-vert-decr": 0.6,
        f"{s_}-lowerleg-scale-vert-decr": 0.5,
        f"{s_}-lowerleg-scale-horiz-incr": 0.6,
        f"{s_}-foot-scale-incr": 0.6,
    })


def safe_details(d):
    """Bỏ target không có trong MPFB (tên khác giữa các bản)."""
    from bl_ext.blender_org.mpfb.services.targetservice import TargetService
    out = {}
    for k, v in d.items():
        if TargetService.target_full_path(k) is None:
            print("ONI bỏ target không có:", k)
            continue
        out[k] = v
    return out


def mane(rig, head_c, up, fwd, right):
    """Bờm trắng: lọn khối to dựng ngược ra sau và hai bên (dáng lửa), rủ
    xuống lưng; thêm sợi mảnh cho mềm viền."""
    rng = random.Random(4)
    white = skin_material("ManeLock", "#EEE8DC", rough=0.6, noise_scale=80)
    strands = hair_material("ManeHair", "#D8D0C2", "#F2EEE6", "#FFFFFF", rough=0.4)
    locks, guides = [], []
    R = 0.115 * S
    for k in range(110):
        # Gốc phân bố trên nửa sau + đỉnh đầu (không che mặt).
        az = rng.uniform(-math.pi * 0.95, math.pi * 0.95)  # quanh trục lên, 0 = sau gáy
        el = rng.uniform(-0.25, 1.15)
        back = -fwd
        d = (back * math.cos(az) + right * math.sin(az)) * math.cos(el) + up * math.sin(el)
        if d.dot(fwd) > 0.35:
            continue
        root = head_c + d * R
        length = rng.uniform(0.25, 0.55) * S
        # Hất lên rồi ra sau, đuôi rủ xuống theo trọng lực (dáng lửa cháy).
        # Hất ra rồi rủ xuống lưng/vai (đỉnh đầu dựng cao hơn, hai bên rủ nhiều).
        rise = 0.35 if el > 0.7 else -0.2
        tip = root + (d * 0.55 + back * 0.45 + up * (rise - rng.uniform(0.3, 1.0))).normalized() * length
        mid = root.lerp(tip, 0.4) + d * 0.08 * S + up * 0.07 * S
        locks.append((root, mid, tip, rng.uniform(0.016, 0.026) * S))
        g = [root.lerp(mid, t) if t < 0.5 else mid.lerp(tip, (t - 0.5) * 2) for t in [i / 7 for i in range(8)]]
        guides.append(g)
    ro = ribbon_locks("ManeLocks", [(a, b, c, r * 0.4) for a, b, c, r in locks], white, flat=1.8, taper=1.2)
    parent_to_bone(ro, rig, "head")
    so = strand_locks("ManeStrands", guides, strands, per_lock=70, spread=0.03 * S, clump=0.3,
                      frizz=0.01 * S, root_radius=0.0016 * S, seed=3)
    parent_to_bone(so, rig, "head")
    return [ro, so]


def brows(body, co, rig, up, fwd, right):
    """Mày trắng rậm chau xuống (lọn dẹt hất ra ngoài)."""
    white = skin_material("BrowWhite", "#F2EEE6", rough=0.6)
    out = []
    for g, s in (("helper-l-eye", 1), ("helper-r-eye", -1)):
        c = group_center(body, g, co)
        side = -right if s > 0 else right  # helper-l-eye là mắt trái nhân vật
        locks = []
        for k in range(6):
            t = k / 5
            a = c + up * (0.024 + 0.006 * t) * S + fwd * 0.012 * S + side * (0.004 + 0.03 * t) * S
            tip = a + side * 0.045 * S + up * (0.03 - 0.012 * t) * S - fwd * 0.01 * S
            locks.append((a, a.lerp(tip, 0.5) + up * 0.008 * S, tip, 0.009 * S))
        o = ribbon_locks(f"Brow{s}", locks, white, flat=2.0, taper=1.0)
        parent_to_bone(o, rig, "head")
        out.append(o)
    return out


def tusks(body, co, rig, up, fwd, right):
    """Nanh dưới chìa lên hai khoé miệng + hai nanh trên ngắn."""
    w = weights_by_group(body)
    lips = [co[i] for i in range(len(co)) if w[i].get("lips", 0) > 0.5]
    c = body.matrix_world @ (sum(lips, Vector()) / len(lips))
    ivory = skin_material("Tusk", "#F0E6CC", rough=0.35)
    strands = []
    for s in (-1, 1):
        base = c + right * s * 0.026 * S - up * 0.006 * S + fwd * 0.006 * S
        strands.append((base, base + up * 0.025 * S + fwd * 0.01 * S + right * s * 0.004 * S,
                        base + up * 0.045 * S + right * s * 0.012 * S, 0.0075 * S))
        b2 = c + right * s * 0.016 * S + up * 0.004 * S + fwd * 0.008 * S
        strands.append((b2, b2 - up * 0.012 * S, b2 - up * 0.02 * S + fwd * 0.003 * S, 0.0045 * S))
    o = add_object("Tusks", tapered_world("Tusks", strands, taper=1.0), [ivory])
    parent_to_bone(o, rig, "head")
    return o


def kanabo(grip, direction, length, mats):
    """Chuỳ sắt kanabō: cán sơn đen đai vàng, nửa đầu phình bát giác cắm gai
    vàng nhiều hàng; đuôi có vòng và tua đỏ. [grip] = chỗ nắm, [direction]
    hướng từ đuôi lên đầu chuỳ."""
    iron, gold, tassel = mats
    d = direction.normalized()
    butt = grip - d * length * 0.22
    top = butt + d * length
    side = d.orthogonal().normalized()
    up2 = d.cross(side)
    pts = [butt.lerp(top, t) for t in (0.0, 0.03, 0.3, 0.45, 0.6, 0.9, 0.98, 1.0)]
    radii = [(0.03,) * 2, (0.034,) * 2, (0.036,) * 2, (0.05,) * 2, (0.075,) * 2, (0.085,) * 2, (0.07,) * 2,
             (0.03,) * 2]
    radii = [(a * S, b * S) for a, b in radii]
    body = add_object("Kanabo", raw_tube("Kanabo", pts, radii, sides=8), [iron])
    body.data.polygons.foreach_set("use_smooth", [False] * len(body.data.polygons))
    out = [body]
    for t, r in ((0.04, 0.04), (0.28, 0.042), (0.47, 0.058), (0.96, 0.08)):
        c = butt.lerp(top, t)
        ring = [c + (side * math.cos(2 * math.pi * k / 24) + up2 * math.sin(2 * math.pi * k / 24)) * r * S
                for k in range(24)]
        out.append(add_object("KanaboBand", raw_tube("KanaboBand", ring, [(0.008 * S, 0.012 * S)] * 24,
                                                     sides=8, closed=True), [gold]))
    spikes = []
    for row in range(7):
        t = 0.55 + row * 0.055
        rr = (0.075 + 0.01 * math.sin(math.pi * (t - 0.5) / 0.5)) * S
        for k in range(8):
            a = 2 * math.pi * (k + 0.5 * (row % 2)) / 8
            n = side * math.cos(a) + up2 * math.sin(a)
            b0 = butt.lerp(top, t) + n * rr * 0.9
            spikes.append((b0, b0 + n * 0.02 * S, b0 + n * 0.045 * S, 0.014 * S))
    out.append(add_object("KanaboSpikes", tapered_world("KanaboSpikes", spikes, sides=8, taper=1.0), [gold]))
    # Tua đỏ ở đuôi.
    rng = random.Random(2)
    cords = []
    for k in range(14):
        a = 2 * math.pi * k / 14
        b0 = butt - d * 0.01 * S + (side * math.cos(a) + up2 * math.sin(a)) * 0.01 * S
        tip = b0 - Vector((0, 0, rng.uniform(0.14, 0.2) * S)) + (side * math.cos(a) + up2 * math.sin(a)) * 0.02 * S
        cords.append((b0, b0.lerp(tip, 0.5), tip, 0.006 * S))
    out.append(add_object("KanaboTassel", tapered_world("KanaboTassel", cords, sides=6, taper=0.6), [tassel]))
    return out


def apron(rig, center, rx, ry, waist_z, knee_z, fwd, mat, gold):
    """Tạp dề vải dày rủ trước bụng từ đai tới gối, thêu chữ 鬼 vàng."""
    import bmesh
    bm = bmesh.new()
    cols, rows = 12, 10
    width = rx * 1.0
    verts = []
    for r in range(rows + 1):
        z = waist_z - (waist_z - knee_z) * r / rows
        row = []
        for c in range(cols + 1):
            u = (c / cols - 0.5) * 2
            # Ôm cong bụng phía trên, phẳng dần, phồng nhẹ ra trước.
            ang = u * 0.9
            k = 1 - r / rows
            y = -(ry + 0.03 * S) * math.cos(ang) * (0.7 + 0.3 * k) - 0.17 * S * (1 - k) ** 0.8
            x = width * math.sin(ang) * (0.85 + 0.15 * k)
            row.append(bm.verts.new(center + Vector((x, y, z - center.z))))
        verts.append(row)
    for r in range(rows):
        for c in range(cols):
            bm.faces.new((verts[r][c], verts[r][c + 1], verts[r + 1][c + 1], verts[r + 1][c]))
    mesh = bpy.data.meshes.new("Apron")
    bm.to_mesh(mesh)
    bm.free()
    o = add_object("Apron", mesh, [mat])
    sol = o.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.008 * S
    parent_to_bone(o, rig, "pelvis")
    from mathutils import Matrix
    front = center + Vector((0, -(ry + 0.03 * S) - 0.1 * S - 0.006 * S, (waist_z + knee_z) / 2 - center.z + 0.04 * S))
    rot = Matrix.Rotation(math.radians(90), 3, "X")
    k = kanji_plate("Oni", "鬼", front, 0.14 * S, gold, rot=rot, depth=0.003 * S)
    k.parent = rig
    k.parent_type = "BONE"
    k.parent_bone = "pelvis"
    b = rig.data.bones["pelvis"]
    from mathutils import Matrix as M
    k.matrix_parent_inverse = (rig.matrix_world @ b.matrix_local @ M.Translation((0, b.length, 0))).inverted()
    return [o, k]


def buckle(rig, at, fwd, gold, iron, eye):
    """Khoá đai mặt quỷ: đĩa sắt đen, viền vàng, hai sừng nhỏ, mắt tím sáng."""
    out = []
    side = fwd.cross(Vector((0, 0, 1))).normalized()
    out.append(add_object("Buckle", raw_ellipsoid("Buckle", at, (0.075 * S, 0.03 * S, 0.065 * S)), [iron]))
    ring = [at + fwd * 0.012 * S + (side * math.cos(2 * math.pi * k / 32) * 0.075 * S
                                    + Vector((0, 0, 0.065 * S)) * math.sin(2 * math.pi * k / 32)) for k in range(32)]
    out.append(add_object("BuckleRim", raw_tube("BuckleRim", ring, [(0.007 * S, 0.007 * S)] * 32, sides=8,
                                                closed=True), [gold]))
    for s in (-1, 1):
        e = at + fwd * 0.03 * S + side * s * 0.026 * S + Vector((0, 0, 0.012 * S))
        out.append(add_object("BuckleEye", raw_ellipsoid("BuckleEye", e, (0.012 * S, 0.006 * S, 0.008 * S)), [eye]))
        b0 = at + side * s * 0.045 * S + Vector((0, 0, 0.045 * S))
        out.append(add_object("BuckleHorn", tapered_world("BuckleHorn", [(b0, b0 + Vector((0, 0, 0.03 * S))
                                                                          + side * s * 0.01 * S,
                                                                          b0 + Vector((0, 0, 0.05 * S))
                                                                          + side * s * 0.03 * S, 0.012 * S)],
                                                          taper=1.0), [gold]))
    fang = []
    for s in (-1, 0, 1):
        b0 = at + fwd * 0.03 * S + side * s * 0.02 * S - Vector((0, 0, 0.025 * S))
        fang.append((b0, b0 - Vector((0, 0, 0.012 * S)), b0 - Vector((0, 0, 0.022 * S)), 0.006 * S))
    out.append(add_object("BuckleFangs", tapered_world("BuckleFangs", fang, taper=1.0), [gold]))
    for o in out:
        parent_to_bone(o, rig, "spine_01")
    return out


def build():
    body, rig, parts = boss_human(1.0, muscle=1.0, weight=1.0, height=1.0, age=0.62, proportions=0.55, scale=S,
                                  details=safe_details(ONI_BODY), eyebrows=None)
    skin = painted_skin("OniSkin", "#B83A2C", "#8A2820", tattoo="#64140F", sss=0.12, rough=0.72)
    body.data.materials.clear()
    body.data.materials.append(skin)
    # Mắt hổ phách phát sáng (cả nhãn cầu — nhìn dữ như mặt nạ Nō).
    if "eyes" in parts:
        parts["eyes"].data.materials.clear()
        parts["eyes"].data.materials.append(glow_material("OniEye", "#FFB830", strength=2.5, base="#E09020"))
    bl = rig.data.bones
    # Bụng phệ tròn căng (đắp thêm, target MPFB chỉ nhô nhẹ trên người cơ bắp).
    co0 = rest_coords(body)
    nav = Vector((0, min(p.y for p in co0) * 0.6, bl["spine_01"].tail_local.z))
    inflate(body, co0, nav, (0.2, 0.22, 0.19), 0.13, name="Belly")
    co = rest_coords(body)
    head_c, up, fwd, right = head_frame(rig)

    iron = skin_material("Iron", "#202026", rough=0.35, metallic=0.85, noise_scale=40)
    gold = gold_material("OniGold", "#E0AE48", rough=0.3)
    black = skin_material("Lacquer", "#0E0C10", rough=0.15)
    claw_m = skin_material("Claw", "#121010", rough=0.2)
    bead_m = skin_material("Bead", "#16141A", rough=0.12)
    rope_m = skin_material("Rope", "#E6DCC4", rough=0.85, noise_scale=120)
    navy = silk_material("Hakama", "#22284A", pattern="#3A3860", trim="#B08A3C", sheen=0.5)
    apron_m = silk_material("ApronCloth", "#1A1E3A", pattern="#2C3058", sheen=0.4)
    tassel = skin_material("Tassel", "#A01C1C", rough=0.7)
    fire = flame_material("Onibi", "#FF3A10", "#9A0806", strength=1.6)
    eye_purple = glow_material("BuckleEyeGlow", "#C060FF", strength=6, base="#6020A0")

    # ---- sừng: mọc trên trán hai bên, cong ra sau và ra ngoài
    horn_m = painted_skin("Horn", "#7A1A16", "#2A0808", sss=0.0, rough=0.35)
    for s in (-1, 1):
        root = head_c + up * 0.075 * S + fwd * 0.055 * S + right * s * 0.042 * S
        horn(f"Horn{s}", root, up * 1.0 + right * s * 0.35 + fwd * 0.15, 0.2 * S, 0.026 * S,
             -fwd * 0.9 + right * s * 0.4 - up * 0.2, horn_m, rig)

    mane(rig, head_c, up, fwd, right)
    brows(body, co, rig, up, fwd, right)
    tusks(body, co, rig, up, fwd, right)

    # ---- chuỗi hạt đen to quanh cổ, mặt đồng vàng phía trước
    neck_base = bone_point(rig, "neck_01", 0.0) - up * 0.03 * S
    beads("Bead", neck_base + fwd * 0.03 * S, 0.17 * S, 0.14 * S, 0.12 * S, 26, 0.03 * S, bead_m, rig, "spine_03",
          big={19: (0.05 * S, gold)})

    # ---- đai thừng shimenawa + khoá mặt quỷ
    waist_z = bl["pelvis"].head_local.z + 0.03  # đai thấp dưới bụng phệ
    c, rx, ry = body_ring(body, co, waist_z, ("pelvis", "spine_01", "spine_02"), pad=0.035)
    ring = ellipse_ring(c, rx, ry, n=72)
    for o in twisted_rope("Shimenawa", ring, 0.04 * S, rope_m):
        parent_to_bone(o, rig, "spine_01")
    buckle(rig, c - Vector((0, ry + 0.035 * S, 0)), fwd, gold, iron, eye_purple)
    knee_z = bl["calf_l"].head_local.z * S + 0.05 * S
    apron(rig, c, rx * 0.55, ry, c.z - 0.06 * S, knee_z, fwd, apron_m, gold)

    # ---- quần hakama chàm, gấu viền vàng
    hakama(body, co, rig, "Hakama", navy, flare=0.13 * S)

    # ---- giáp tay vàng–đen, vòng cổ tay
    for s in ("l", "r"):
        limb_band(rig, f"lowerarm_{s}", 0.42, 0.92, 0.062 * S, 0.05 * S, black, f"Bracer{s}")
        for t in (0.45, 0.9):
            limb_band(rig, f"lowerarm_{s}", t - 0.02, t + 0.02, 0.066 * S, 0.066 * S, gold, f"BracerBand{s}")
        limb_band(rig, f"upperarm_{s}", 0.12, 0.22, 0.085 * S, 0.083 * S, gold, f"Armlet{s}")
        claws(rig, s, claw_m, length=0.035 * S, radius=0.007 * S)
        claws(rig, s, claw_m, length=0.04 * S, radius=0.01 * S, toes=True)
        # Cổ chân quấn vải đỏ.
        limb_band(rig, f"calf_{s}", 0.86, 0.98, 0.06 * S, 0.055 * S, tassel, f"Anklet{s}")
    return body, rig, {"iron": iron, "gold": gold, "tassel": tassel, "fire": fire}


def pose_and_props(rig, mats):
    poser = StandPoser(rig, facing_deg=-48, scale=S)
    poser.place(stance=math.radians(14), crouch=math.radians(10))
    fwd, left, up = poser.frame()
    right = -left
    # Tay phải vác chuỳ trên vai phải.
    sh_r = poser.world("upperarm_r", 0.0)
    grip = sh_r + fwd * 0.12 * S + right * 0.06 * S
    poser.arm("r", grip, sh_r + right * 0.6 - up * 0.5)
    # Tay trái chìa ra trước, ngửa bàn tay nâng lửa ma.
    sh_l = poser.world("upperarm_l", 0.0)
    reach = poser.a + poser.b
    hand = sh_l + left * reach * 0.6 + fwd * reach * 0.45 - up * reach * 0.38
    poser.arm("l", hand, sh_l + left * 0.3 - up * 0.8 - fwd * 0.1)
    club_dir = (-fwd * 0.8 + up * 0.5 + right * 0.3).normalized()
    kanabo(poser.world("hand_r", 1.0), club_dir, 1.7 * S, (mats["iron"], mats["gold"], mats["tassel"]))
    palm = poser.world("hand_l", 0.6) + up * 0.06 * S
    flame("Onibi", palm, 0.26 * S, 0.12 * S, mats["fire"], lean=-fwd * 0.05 * S + up * 0.02, tongues=4, seed=1)
    flame("OnibiFloat", sh_r + right * 0.35 * S + up * 0.35 * S, 0.18 * S, 0.08 * S, mats["fire"], tongues=3, seed=5)
    flame("OnibiFloat2", sh_l + left * 0.25 * S + up * 0.55 * S - fwd * 0.2 * S, 0.14 * S, 0.06 * S, mats["fire"],
          tongues=3, seed=9)
    return poser


def lights(scene):
    add_sun(scene, "Key", (0.35, 0.75, -0.55), 3.6, "#FFE2C2", angle=3)
    add_sun(scene, "Rim", (-0.75, -0.3, -0.25), 3.2, "#9EC0FF", angle=4)
    add_sun(scene, "Fill", (0.2, 0.9, 0.2), 0.6, "#FFB0A0", angle=20)


def main():
    scene = reset_scene(samples=96, world_hex="#C9C4C0", world_strength=0.7, keep_prefs=True)
    body, rig, mats = build()
    pose_and_props(rig, mats)
    lights(scene)
    shadow_catcher()
    out = os.path.join(ROOT, "build", "blender", "oni")
    os.makedirs(out, exist_ok=True)
    pb = rig.pose.bones["head"]
    head = rig.matrix_world @ pb.head.lerp(pb.tail, 0.5)
    camera(scene, -0.1 * S, 1.3 * S, 2.6 * S, 2.9 * S, 260, yaw=-8, pitch=6)
    render_to(scene, os.path.join(out, "still_full.png"))
    camera(scene, head.x, head.z - 0.05 * S, 0.6 * S, 0.6 * S, 900, yaw=-8, pitch=4)
    render_to(scene, os.path.join(out, "still_face.png"))
    from boss_kit import save_blend
    save_blend("oni_boss")


main()
