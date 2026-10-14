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
from hair_kit import combed_material, hair_material, ribbon_locks, strand_locks  # noqa: E402
from human_kit import camera, group_center, raw_ellipsoid, raw_tube, rest_coords, shadow_catcher, \
    store_point_attr, tapered_world, weights_by_group  # noqa: E402
from japan_kit import StandPoser, beads, body_ring, boss_human, bone_point, claws, ellipse_ring, fist, flame, \
    flame_material, hakama, head_frame, horn, inflate, belly_ball, kanji_plate, limb_band, muscle_bulge, painted_skin, \
    silk_material, twisted_rope  # noqa: E402

S = 1.45  # khổng lồ lùn bè, ~2,3 m

ONI_BODY = {
    "stomach-pregnant-incr": 1.0,
    "stomach-navel-out": 0.6,
    "torso-muscle-dorsi-incr": 1.0,
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
    "head-square": 0.5,
    "head-fat-incr": 1.0,
    "neck-double-incr": 1.0,
    "mouth-scale-horiz-incr": 1.0,
    "mouth-upperlip-volume-incr": 1.0,
    "mouth-lowerlip-volume-incr": 1.0,
    "mouth-lowerlip-height-incr": 0.6,
    "mouth-upperlip-height-incr": 0.3,
    "mouth-scale-depth-incr": 0.6,
    "nose-flaring-incr": 1.0,
    "nose-scale-horiz-incr": 0.8,
    "nose-volume-incr": 0.6,
    "nose-point-width-incr": 0.7,
    # Biểu cảm mặt nạ Hannya: há miệng nhe răng, khoé kéo ngược, cánh mũi nhăn.
    "expression/units/asian/mouth-open": 0.6,
    "expression/units/asian/mouth-upward-retraction": 0.9,
    "expression/units/asian/mouth-corner-puller": 0.8,
    "expression/units/asian/nose-left-elevation": 0.5,
    "expression/units/asian/nose-right-elevation": 0.5,
    "expression/units/asian/eye-left-opened-up": 0.5,
    "expression/units/asian/eye-right-opened-up": 0.5,
    "eyebrows-trans-down": 0.7,
    "eyebrows-angle-down": 0.8,
    "measure-upperarm-circ-incr": 1.0,
    "measure-thigh-circ-incr": 1.0,
    "measure-calf-circ-incr": 0.8,
}
for s_ in ("l", "r"):
    ONI_BODY.update({
        f"{s_}-cheek-volume-incr": 1.0,
        f"{s_}-cheek-bones-incr": 0.4,
        f"{s_}-upperarm-shoulder-muscle-incr": 1.0,
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
    from human_kit import target_path
    out = {}
    for k, v in d.items():
        if target_path(k) is None:
            print("ONI bỏ target không có:", k)
            continue
        out[k] = v
    return out


def mane(body, co, rig, head_c, up, fwd, right):
    """Bờm trắng dài chải ngược từ chân tóc, ôm sọ rồi rủ nặng xuống lưng và
    hai vai theo trọng lực (không dựng nhọn); gốc da đầu phủ lông ngắn."""
    from human_kit import shell_copy
    rng = random.Random(4)
    scalp_m = combed_material("ManeScalp", "#A89E90", "#EEE8DE", scale=4.5)
    strands = hair_material("ManeHair", "#D8D0C2", "#F2EEE6", "#FFFFFF", rough=0.4)
    scalp = shell_copy(body, "ManeScalp", "scalp", 0.004 * S, 0.0, [scalp_m])
    # Mặt sau thân theo từng tầng cao: tóc rủ bám lưng, không xuyên vai.
    bl = rig.data.bones
    z_hi = bl["neck_01"].head_local.z
    z_lo = bl["spine_02"].head_local.z
    rings = []
    for k in range(7):
        z = z_hi + (z_lo - z_hi) * k / 6
        rings.append(body_ring(body, co, z, ("spine_02", "spine_03", "neck_01", "clavicle_l", "clavicle_r"),
                               pad=0.0))
    R = 0.112 * S
    back = -fwd
    # Bán kính sọ thật theo từng hướng (đỉnh nhóm xương đầu): gốc tóc phải
    # nằm ngoài lớp da đầu, mặt cầu R cố định lọt vào trong làm lộ "mũ".
    w = weights_by_group(body)
    m = body.matrix_world
    skull = [(m @ co[i]) - head_c for i in range(len(co))
             if w[i].get("head", 0) > 0.5 and w[i].get("HelperGeometry", 0) < 0.5]
    skull = [(v.normalized(), v.length) for v in skull if v.length > 1e-6]

    def radius(d):
        near = [r for u, r in skull if u.dot(d) > 0.985]
        return max(near) + 0.006 * S if near else R
    guides = []
    # Gốc tóc lấy mẫu trên chính các đỉnh da đầu: phủ kín tới chân tóc.
    roots = [((m @ co[i]) - head_c).normalized() for i in range(len(co)) if w[i].get("scalp", 0) > 0.5]
    for d in rng.sample(roots, min(320, len(roots))):
        rd = radius(d)
        lat = d.dot(right)  # −1…1: bên phải/trái nhân vật
        # Rạp theo mặt sọ: quay dần hướng gốc về sau gáy, sát da đầu.
        nape = (back * 0.85 + right * lat * 0.55 - up * 0.25).normalized()
        pts = []
        for j in range(5):
            t = j / 4
            v = d.lerp(nape, t).normalized()
            pts.append(head_c + v * max(rd, radius(v)) * (1.0 + 0.08 * t))
        ang = lat * rng.uniform(0.9, 1.25)
        pad = rng.uniform(0.03, 0.07) * S
        drop = rng.uniform(0.5, 1.0)
        n = max(2, int(len(rings) * drop))
        for j, (c, rx, ry) in enumerate(rings[:n]):
            t = (j + 1) / n
            p = c + right * math.sin(ang) * (rx * 0.75 + pad) + back * math.cos(ang) * (ry + pad * (1 + t))
            pts.append(p + Vector((0, 0, rng.uniform(-0.01, 0.01) * S)))
        guides.append(pts)
    so = strand_locks("ManeStrands", guides, strands, per_lock=45, spread=0.02 * S, clump=0.4,
                      frizz=0.006 * S, curl=0.004 * S, root_radius=0.0016 * S, seed=3)
    parent_to_bone(so, rig, "head")
    return [scalp, so]


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
    radii = [(0.028,) * 2, (0.024,) * 2, (0.026,) * 2, (0.05,) * 2, (0.075,) * 2, (0.085,) * 2, (0.07,) * 2,
             (0.03,) * 2]
    radii = [(a * S, b * S) for a, b in radii]
    body = add_object("Kanabo", raw_tube("Kanabo", pts, radii, sides=8), [iron])
    body.data.polygons.foreach_set("use_smooth", [False] * len(body.data.polygons))
    out = [body]
    for t, r in ((0.04, 0.032), (0.3, 0.034), (0.47, 0.058), (0.96, 0.08)):
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


def muscles(body, co, rig):
    """Đắp khối cơ cho thớ cơ đọc rõ ở cỡ sprite (target MPFB làm cơ tròn mềm):
    ngực có gờ dưới sắc + rãnh giữa, cơ thang, và bắp dọc xương tay (vai,
    bắp tay trước/sau, cẳng tay) kèm rãnh phân cơ. Toạ độ nghỉ cục bộ; người
    nhìn về −Y, trái +X."""
    bl = rig.data.bones

    def front_y(x, z, r=0.03):
        ys = [p.y for p in co if abs(p.x - x) < r and abs(p.z - z) < r]
        return min(ys) if ys else 0.0

    zc = bl["spine_03"].head_local.z + 0.06  # tầm ngực
    for sx in (-1, 1):
        x = 0.09 * sx
        inflate(body, co, Vector((x, front_y(x, zc), zc)), (0.1, 0.1, 0.08), 0.07, name=f"Pec{sx}",
                front_only=False)
        inflate(body, co, Vector((x * 1.05, front_y(x, zc - 0.085), zc - 0.085)), (0.11, 0.1, 0.018), -0.018,
                name=f"PecFold{sx}", front_only=False)
        nk = bl["neck_01"].head_local
        inflate(body, co, Vector((0.08 * sx, nk.y + 0.03, nk.z - 0.02)), (0.07, 0.07, 0.05), 0.035,
                name=f"Trap{sx}", front_only=False)
        s_ = "l" if sx > 0 else "r"
        # (u0, độ rộng u, góc°, độ rộng góc°, biên độ m)
        muscle_bulge(body, co, rig, f"upperarm_{s_}", [
            (0.12, 0.16, 70, 110, 0.035),   # cơ delta trùm vai
            (0.3, 0.05, 40, 60, -0.012),    # rãnh delta – bắp tay
            (0.58, 0.2, 0, 55, 0.04),       # bắp tay trước (nhị đầu)
            (0.5, 0.25, 180, 60, 0.032),    # bắp tay sau (tam đầu)
            (0.55, 0.3, 90, 14, -0.012),    # rãnh giữa trước/sau phía ngoài
            (0.55, 0.3, -90, 14, -0.008),
        ], f"Arm{s_}")
        muscle_bulge(body, co, rig, f"lowerarm_{s_}", [
            (0.22, 0.18, 45, 50, 0.03),     # cơ cánh tay quay
            (0.25, 0.2, -60, 50, 0.022),    # nhóm gấp cổ tay
            (0.3, 0.3, -5, 10, -0.008),     # rãnh giữa hai nhóm
        ], f"Forearm{s_}")
    inflate(body, co, Vector((0, front_y(0, zc), zc)), (0.016, 0.1, 0.11), -0.025, name="Sternum",
            front_only=False)


def pupils(body, co, rig, fwd):
    """Đồng tử đen tròn giữa mắt vàng (điểm trước nhất của khối cầu mắt)."""
    black = skin_material("Pupil", "#050404", rough=0.1)
    w = weights_by_group(body)
    m = body.matrix_world
    for g in ("helper-l-eye", "helper-r-eye"):
        pts = [m @ co[i] for i in range(len(co)) if w[i].get(g, 0) > 0.5]
        front = max(pts, key=lambda p: p.dot(fwd))
        o = add_object(f"Pupil{g}", raw_ellipsoid(f"Pupil{g}", front + fwd * 0.001 * S,
                                                    (0.0065 * S, 0.0065 * S, 0.0065 * S)), [black])
        parent_to_bone(o, rig, "head")


def build():
    # Mỡ vừa phải để khối cơ (vai, ngực, tay, lưng) hằn rõ; bụng và mặt đắp riêng.
    body, rig, parts = boss_human(1.0, muscle=1.0, weight=0.55, height=1.0, age=0.62, proportions=0.55, scale=S,
                                  details=safe_details(ONI_BODY), eyebrows=None)
    w0 = weights_by_group(body)
    store_point_attr(body, "lips", [min(1.0, w0[i].get("lips", 0)) for i in range(len(w0))])
    clay = "--clay" in sys.argv  # soát hình khối: bỏ hoa văn xăm
    skin = painted_skin("OniSkin", "#B83A2C", "#8A2820", tattoo=None if clay else "#7A2016", sss=0.12, rough=0.72, lips="#4A0C0A",
                        cavity=("#3A0806", 0.1 * S, 0.9), tattoo_band=0.935)
    body.data.materials.clear()
    body.data.materials.append(skin)
    # Mắt vàng kim như mặt nạ Hannya (đồng tử đen đắp riêng bên dưới).
    if "eyes" in parts:
        parts["eyes"].data.materials.clear()
        parts["eyes"].data.materials.append(glow_material("OniEye", "#FFC23A", strength=1.2, base="#C88A18"))
    # Răng ngà ngả vàng, lưỡi đỏ sẫm.
    if "teeth" in parts:
        parts["teeth"].data.materials.clear()
        parts["teeth"].data.materials.append(skin_material("OniTeeth", "#E2CC92", rough=0.3))
    if "tongue" in parts:
        parts["tongue"].data.materials.clear()
        parts["tongue"].data.materials.append(skin_material("OniTongue", "#5A0E10", rough=0.4))
    bl = rig.data.bones
    # Bụng bia tròn kiểu Gragas: khối cầu từ dưới ngực, rộng gần hết thân,
    # nặng ở nửa dưới, trễ chờm qua đai thừng (nếp gấp ở mép dưới).
    co0 = rest_coords(body)
    z_chest = bl["spine_03"].head_local.z + 0.02
    tuck_z = bl["pelvis"].head_local.z + 0.05
    zc = tuck_z + (z_chest - tuck_z) * 0.36
    band = [p for p in co0 if abs(p.z - zc) < 0.02 and abs(p.x) < 0.25]
    half_w = max(abs(p.x) for p in band)
    y_front = min(p.y for p in band)
    ry = 0.3
    center = Vector((0, y_front + ry - 0.23, zc))  # nhô 0,23 m trước bụng gốc
    belly_ball(body, co0, center, half_w + 0.11, ry, z_chest - zc + 0.1, zc - tuck_z + 0.08, tuck_z, soft=0.3)
    # Rốn lõm sâu giữa khối bụng.
    co1 = rest_coords(body)
    nz = zc - 0.02
    navel = min((p for p in co1 if abs(p.x) < 0.015 and abs(p.z - nz) < 0.015), key=lambda p: p.y)
    inflate(body, co1, navel, (0.022, 0.04, 0.03), -0.03, name="Navel", front_only=False)
    muscles(body, co0, rig)
    co = rest_coords(body)
    head_c, up, fwd, right = head_frame(rig)
    pupils(body, co, rig, fwd)

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

    mane(body, co, rig, head_c, up, fwd, right)
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
    poser.place(stance=math.radians(9), crouch=math.radians(12))
    fwd, left, up = poser.frame()
    right = -left
    # Tay phải vác chuỳ trên vai phải.
    sh_r = poser.world("upperarm_r", 0.0)
    grip = sh_r + fwd * 0.16 * S + right * 0.08 * S - up * 0.04 * S
    poser.arm("r", grip, sh_r + right * 0.6 - up * 0.5)
    want = (-fwd * 0.8 + up * 0.5 + right * 0.3).normalized()  # hướng đầu chuỳ: qua vai ra sau
    fist(rig, "r")
    # Bàn tay nối thẳng cẳng tay; thử hai chiều lòng bàn tay, giữ chiều mà
    # trục đốt ngón (ngón trỏ → ngón út) chỉ về đuôi chuỳ, ngón cái về đầu chuỳ.
    fa = (poser.world("hand_r", 0.0) - poser.world("lowerarm_r", 0.0)).normalized()
    cd = (want - fa * want.dot(fa)).normalized()
    for sign in (1, -1):
        poser.palm("r", fa, fa.cross(cd) * sign)
        knuckle = poser.world("pinky_01_r", 0.0) - poser.world("index_01_r", 0.0)
        if knuckle.dot(cd) < 0:
            break
    club_dir = -knuckle.normalized()
    # Tâm lỗ nắm đấm: giữa gốc ngón giữa và các đốt đã gập.
    hole = (poser.world("middle_01_r", 0.0) + poser.world("middle_02_r", 0.0) + poser.world("middle_03_r", 0.0)
            + poser.world("middle_03_r", 1.0)) / 4
    kanabo(hole, club_dir, 1.7 * S, (mats["iron"], mats["gold"], mats["tassel"]))
    # Tay trái chìa ra trước, ngửa bàn tay nâng lửa ma.
    sh_l = poser.world("upperarm_l", 0.0)
    reach = poser.a + poser.b
    hand = sh_l + left * reach * 0.6 + fwd * reach * 0.45 - up * reach * 0.38
    poser.arm("l", hand, sh_l + left * 0.3 - up * 0.8 - fwd * 0.1)
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
    if "--grip-only" not in sys.argv:
        camera(scene, -0.1 * S, 1.3 * S, 2.6 * S, 2.9 * S, 260, yaw=-8, pitch=6)
        render_to(scene, os.path.join(out, "still_full.png"))
        camera(scene, head.x, head.z - 0.05 * S, 0.6 * S, 0.6 * S, 900, yaw=-8, pitch=4)
        render_to(scene, os.path.join(out, "still_face.png"))
    if "--belly" in sys.argv:  # soát dáng bụng: nghiêng và chính diện
        mid = rig.matrix_world @ rig.pose.bones["spine_01"].head
        for tag, yaw in (("side", -100), ("front", -48)):
            camera(scene, mid.x, mid.z, 1.1 * S, 1.1 * S, 600, yaw=yaw, pitch=2)
            render_to(scene, os.path.join(out, f"check_belly_{tag}.png"))
    if "--grip" in sys.argv or "--grip-only" in sys.argv:  # soát tay cầm chuỳ (xuyên) và chân (bắt chéo)
        hand = rig.matrix_world @ rig.pose.bones["hand_r"].head
        camera(scene, hand.x, hand.z, 0.5 * S, 0.5 * S, 900, yaw=-8, pitch=4)
        render_to(scene, os.path.join(out, "check_grip.png"))
        camera(scene, hand.x, hand.z, 0.5 * S, 0.5 * S, 900, yaw=-100, pitch=4)
        render_to(scene, os.path.join(out, "check_grip_side.png"))
        camera(scene, hand.x, hand.z, 0.5 * S, 0.5 * S, 900, yaw=-8, pitch=4)
        club = [o for o in bpy.data.objects if o.name.startswith("Kanabo")]
        for o in club:
            o.hide_render = True
        render_to(scene, os.path.join(out, "check_fist.png"))
        for o in club:
            o.hide_render = False
        camera(scene, 0.0, 0.3 * S, 1.4 * S, 0.7 * S, 400, yaw=-8, pitch=6)
        render_to(scene, os.path.join(out, "check_legs.png"))
        camera(scene, head.x, head.z - 0.45 * S, 0.8 * S, 0.8 * S, 700, yaw=-8, pitch=4)
        render_to(scene, os.path.join(out, "check_torso.png"))
    from boss_kit import save_blend
    save_blend("oni_boss")


main()
