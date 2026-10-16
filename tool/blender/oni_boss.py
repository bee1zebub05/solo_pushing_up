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
    flame_material, hakama, head_frame, horn, inflate, belly_ball, hero_muscles, kanji_plate, limb_band, muscle_bulge, painted_skin, \
    silk_material, twisted_rope  # noqa: E402
from japan_kit import conform_outside, densify, hitodama, limb_fat, ridge, skin_snapper, snap_rest  # noqa: E402
from boss_kit import srgb  # noqa: E402

S = 1.45  # khổng lồ béo phì, chân dài như người thường, ~2,6 m

ONI_BODY = {
    "stomach-pregnant-incr": 1.0,
    "stomach-navel-out": 0.6,
    "torso-scale-horiz-incr": 1.0,
    "torso-scale-depth-incr": 0.8,
    # Chân dài như người thường (ảnh tham khảo người béo phì): chân cụt làm
    # thân dưới phình thành cái chuông úp; cao lên thì khối mỡ mới ra tỉ lệ.
    "lowerlegs-height-decr": 0.15,
    "measure-shoulder-dist-incr": 1.0,
    "torso-muscle-pectoral-incr": 1.0,
    "neck-scale-horiz-incr": 1.0,
    "neck-scale-depth-incr": 0.8,
    "measure-neck-height-decr": 0.7,
    "chin-width-incr": 0.9,
    "chin-prominent-incr": 0.6,
    "head-square": 0.5,
    "head-fat-incr": 0.4,
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
    "expression/units/asian/nose-left-elevation": 0.8,
    "expression/units/asian/nose-right-elevation": 0.8,
    "expression/units/asian/nose-compression": 0.6,
    # Mắt gườm: mày sụp đè mí trên, mí dưới nheo — không trợn tròn.
    "expression/units/asian/eye-left-opened-up": 0.3,
    "expression/units/asian/eye-right-opened-up": 0.3,
    "expression/units/asian/eye-left-slit": 0.35,
    "expression/units/asian/eye-right-slit": 0.35,
    "expression/units/asian/eyebrows-left-down": 0.9,
    "expression/units/asian/eyebrows-right-down": 0.9,
    "eyebrows-trans-down": 0.7,
    "eyebrows-angle-down": 0.8,
    "eyebrows-trans-forward": 1.0,
    "forehead-trans-forward": 0.5,
    "head-age-incr": 0.6,
    "nose-hump-incr": 0.5,
    "nose-nostrils-width-incr": 1.0,
    # Thân võ sĩ sumo: ngực nặng xệ, eo – hông – cổ to, mỡ trùm bắp tay.
    "measure-bust-circ-incr": 1.0,
    "measure-frontchest-dist-incr": 0.7,
    "measure-underbust-circ-incr": 1.0,
    "breast-volume-vert-down": 1.0,
    "breast-trans-down": 0.6,
    "breast-dist-incr": 0.5,
    "measure-waist-circ-incr": 1.0,
    "measure-hips-circ-incr": 0.7,
    "measure-neck-circ-incr": 1.0,
    "neck-back-scale-depth-incr": 0.8,
    "measure-upperarm-circ-incr": 1.0,
    "measure-thigh-circ-incr": 1.0,
    "measure-calf-circ-incr": 0.8,
    "measure-ankle-circ-incr": 0.6,
}
for s_ in ("l", "r"):
    ONI_BODY.update({
        f"{s_}-cheek-volume-incr": 0.2,
        f"{s_}-eye-scale-incr": 1.0,  # mắt to trợn như mặt nạ Hannya
        f"{s_}-eye-height2-incr": 0.8,
        f"{s_}-eye-corner2-up": 0.6,
        f"{s_}-cheek-bones-incr": 1.0,
        f"{s_}-upperarm-shoulder-muscle-incr": 1.0,
        f"{s_}-upperarm-muscle-incr": 1.0,
        f"{s_}-upperarm-scale-horiz-incr": 1.0,
        f"{s_}-upperarm-scale-depth-incr": 1.0,
        f"{s_}-lowerarm-muscle-incr": 1.0,
        f"{s_}-lowerarm-scale-horiz-incr": 1.0,
        f"{s_}-lowerarm-scale-depth-incr": 0.8,
        f"{s_}-hand-scale-incr": 0.8,
        f"{s_}-upperleg-scale-horiz-incr": 0.8,
        f"{s_}-lowerleg-scale-horiz-incr": 0.6,
        f"{s_}-foot-scale-incr": 0.6,
        f"{s_}-foot-scale-horiz-incr": 0.8,  # bàn chân bè đỡ khối nặng
        f"{s_}-upperarm-fat-incr": 0.6,
        f"{s_}-lowerarm-fat-incr": 0.25,
        f"{s_}-eye-bag-incr": 0.6,
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
    on_skin = skin_snapper(body, co, fwd, S)
    out = []
    for g, s in (("helper-l-eye", 1), ("helper-r-eye", -1)):
        c = group_center(body, g, co)
        side = -right if s > 0 else right  # helper-l-eye là mắt trái nhân vật
        locks = []
        for k in range(8):
            t = k / 7
            # Gốc bám gờ mày: đầu trong thấp chau, đuôi hất lên thái dương như lửa.
            a = on_skin(c + up * (0.018 + 0.014 * t) * S + side * (0.002 + 0.032 * t) * S, lift=0.002)
            tip = a + side * (0.02 + 0.015 * t) * S + up * (0.012 + 0.03 * t) * S + fwd * 0.006 * S
            locks.append((a, a.lerp(tip, 0.5) + fwd * 0.006 * S, tip, (0.012 - 0.003 * t) * S))
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
    out += fusa(butt - d * 0.012 * S, d, (gold, tassel))
    return out


def fusa(hang, d, mats):
    """Tua kiểu Nhật (fusa) treo đuôi chuỳ: vòng dây bện vàng–đỏ, nút thắt tròn
    quấn dây vàng chữ thập, chóp đồng loe, đai buộc cổ tua, chùm sợi đỏ hai
    tông xoè nhẹ rồi rủ theo trọng lực. [hang] = điểm treo, [d] = trục chuỳ."""
    gold, red = mats
    dark = skin_material("TasselDark", "#6A0C10", rough=0.55)
    red_s = skin_material("TasselSilk", "#B4161C", rough=0.35, noise_scale=300)
    down = Vector((0, 0, -1))
    sd = d.cross(down).normalized()  # mặt phẳng vòng dây: dọc trục chuỳ
    if sd.length < 1e-3:
        sd = Vector((1, 0, 0))
    lean = (d - down * d.dot(down)).normalized() * 0.18  # tua đung đưa nhẹ về phía đầu chuỳ
    out = []
    # Vòng dây bện: hai sợi xoắn quanh một vòng elip đứng.
    loop_h, loop_w = 0.04 * S, 0.012 * S
    lc = hang + down * loop_h * 0.5
    fd = sd.cross(down).normalized()
    for k, mat in enumerate((gold, red)):
        pts = []
        for i in range(96):
            t = 2 * math.pi * i / 96
            c = lc + fd * loop_w * math.sin(t) - down * loop_h * 0.5 * math.cos(t)
            tan = (fd * loop_w * math.cos(t) + down * loop_h * 0.5 * math.sin(t)).normalized()
            n1 = tan.cross(sd).normalized()
            ang = 14 * t + math.pi * k
            pts.append(c + (n1 * math.cos(ang) + sd * math.sin(ang)) * 0.0022 * S)
        out.append(add_object(f"FusaCord{k}", raw_tube(f"FusaCord{k}", pts, [(0.0024 * S,) * 2] * 96, sides=8,
                                                       closed=True), [mat]))
    # Nút thắt tròn bọc dây vàng chữ thập.
    kc = hang + down * (loop_h + 0.016 * S)
    kr = 0.017 * S
    out.append(add_object("FusaKnot", raw_ellipsoid("FusaKnot", kc, (kr, kr, kr * 1.1), segments=20, rings=12), [red]))
    for k, (a1, a2) in enumerate(((sd, fd), (sd, down), (fd, down))):
        ring = [kc + (a1 * math.cos(2 * math.pi * j / 40) + a2 * math.sin(2 * math.pi * j / 40)) * kr * 1.02
                for j in range(40)]
        out.append(add_object(f"FusaWrap{k}", raw_tube(f"FusaWrap{k}", ring, [(0.0022 * S,) * 2] * 40, sides=8,
                                                       closed=True), [gold]))
    # Chóp đồng loe hình chuông + đai buộc cổ tua.
    top = kc + down * kr * 1.05
    cap = [top + down * h * 0.024 * S for h in (0.0, 0.25, 0.6, 1.0)]
    out.append(add_object("FusaCap", raw_tube("FusaCap", cap, [(r * S,) * 2 for r in (0.006, 0.011, 0.015, 0.017)],
                                              sides=16), [gold]))
    neck = cap[-1] + down * 0.016 * S
    ring = [neck + (sd * math.cos(2 * math.pi * j / 40) + fd * math.sin(2 * math.pi * j / 40)) * 0.0175 * S
            for j in range(40)]
    out.append(add_object("FusaBand", raw_tube("FusaBand", ring, [(0.0035 * S, 0.006 * S)] * 40, sides=8,
                                               closed=True), [gold]))
    # Chùm sợi: gốc trong chóp, bó lại ở đai rồi xoè, ngọn so le.
    rng = random.Random(7)
    threads = {red_s: [], dark: []}
    for k in range(150):
        a = rng.uniform(0, 2 * math.pi)
        rr = math.sqrt(rng.uniform(0.05, 1.0))
        rad = sd * math.cos(a) + fd * math.sin(a)
        p0 = cap[-1] - down * 0.004 * S + rad * rr * 0.014 * S
        p1 = neck + rad * rr * 0.017 * S + down * 0.03 * S
        L = rng.uniform(0.165, 0.18) * S
        p2 = neck + rad * (0.022 + 0.022 * rr) * S + (down + lean + rad * rng.uniform(-0.05, 0.05)) * L
        threads[red_s if rng.random() < 0.7 else dark].append((p0, p1, p2, 0.0019 * S))
    for mat, strands in threads.items():
        out.append(add_object(f"FusaThreads{mat.name}", tapered_world(f"FusaThreads{mat.name}", strands, sides=5,
                                                                    steps=10, taper=0.04), [mat]))
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
    # Chữ dán đúng mặt tạp dề ở giữa (cùng công thức với lưới trên, u = 0).
    zk = (waist_z + knee_z) / 2 + 0.04 * S
    kk = 1 - (waist_z - zk) / (waist_z - knee_z)
    yk = -(ry + 0.03 * S) * (0.7 + 0.3 * kk) - 0.17 * S * (1 - kk) ** 0.8
    front = center + Vector((0, yk - 0.008 * S - 0.006 * S, zk - center.z))
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


def tiger_material(name):
    """Da hổ: nền cam, vằn đen méo (sóng dải + nhiễu), lông ngắn có bump."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links.new
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    tc = N.new("ShaderNodeTexCoord")
    wave = N.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 3.2
    wave.inputs["Distortion"].default_value = 9
    wave.inputs["Detail"].default_value = 3
    L(tc.outputs["Object"], wave.inputs["Vector"])
    stripe = N.new("ShaderNodeMapRange")
    stripe.inputs["From Min"].default_value = 0.78
    stripe.inputs["From Max"].default_value = 0.84
    L(wave.outputs["Fac"], stripe.inputs["Value"])
    blot = N.new("ShaderNodeTexNoise")
    blot.inputs["Scale"].default_value = 8
    L(tc.outputs["Object"], blot.inputs["Vector"])
    base = N.new("ShaderNodeMix")
    base.data_type = "RGBA"
    L(blot.outputs["Fac"], base.inputs["Factor"])
    base.inputs[6].default_value = srgb("#E0912E")
    base.inputs[7].default_value = srgb("#B8641C")
    col = N.new("ShaderNodeMix")
    col.data_type = "RGBA"
    L(stripe.outputs[0], col.inputs["Factor"])
    L(base.outputs[2], col.inputs[6])
    col.inputs[7].default_value = srgb("#1A1210")
    L(col.outputs[2], bsdf.inputs["Base Color"])
    fur = N.new("ShaderNodeTexNoise")
    fur.inputs["Scale"].default_value = 400
    L(tc.outputs["Object"], fur.inputs["Vector"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    L(fur.outputs["Fac"], bump.inputs["Height"])
    L(bump.outputs[0], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Sheen Weight"].default_value = 0.4
    L(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def pelt(body, co, rig, mat, tuck_z):
    """Tấm da hổ khoác vai trái: dải rộng bám mặt thân từ ngực trên, vòng
    qua đỉnh vai, rủ xuống lưng (tránh vùng bụng biến dạng mạnh khi tạo dáng). Toạ độ nghỉ
    cục bộ (người nhìn −Y, trái +X), đổi sang thế giới khi dựng lưới."""
    w = weights_by_group(body)
    bl = rig.data.bones
    groups = ("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "neck_01", "pelvis")
    torso = [co[i] for i in range(len(co))
             if w[i].get("HelperGeometry", 0) < 0.5 and sum(w[i].get(g, 0) for g in groups) > 0.5]
    pad = 0.025

    def around(z, theta):
        d = Vector((math.sin(math.radians(theta)), -math.cos(math.radians(theta)), 0))
        band = [q for q in torso if abs(q.z - z) < 0.012]
        cx = (min(q.x for q in band) + max(q.x for q in band)) / 2
        cy = (min(q.y for q in band) + max(q.y for q in band)) / 2
        c = Vector((cx, cy, z))
        cand = [q for q in band if (q - c).normalized().dot(d) > 0.99]
        best = max(cand or band, key=lambda q: (q - c).dot(d))
        return best + d * pad, d

    def top(x, y):
        near = [q for q in torso if abs(q.x - x) < 0.02 and abs(q.y - y) < 0.02]
        return max(q.z for q in near) if near else None

    z_sh = bl["clavicle_l"].head_local.z
    n = 12
    front = [around(z_sh - 0.24 + 0.2 * i / (n - 1), 22 + 30 * i / (n - 1)) for i in range(n)]
    back = [around(z_sh - 0.04 - 0.28 * i / (n - 1), 128 + 25 * i / (n - 1)) for i in range(n)]
    # Cung qua đỉnh vai: nội suy hai đầu, nâng lên trên mặt cơ thang.
    a, b = front[-1][0], back[0][0]
    arc = []
    for k in range(1, 6):
        t = k / 6
        q = a.lerp(b, t)
        zt = top(q.x, q.y)
        lift = max(q.z, (zt or q.z) + pad) + 0.02 * math.sin(math.pi * t)
        arc.append((Vector((q.x, q.y, lift)), Vector((0, 0, 1))))
    path = front + arc + back
    pts = [p_ for p_, _ in path]
    outs = [o_ for _, o_ in path]
    for _ in range(3):  # làm mượt đường, giữ hai đầu
        pts = [pts[0]] + [(pts[i - 1] + pts[i] * 2 + pts[i + 1]) / 4 for i in range(1, len(pts) - 1)] + [pts[-1]]
    # Hai đầu thuôn như chân hổ buông thõng.
    nn = len(pts)
    taper = [min(1.0, 0.3 + 0.7 * min(i, nn - 1 - i) / (nn * 0.22)) for i in range(nn)]
    m = body.matrix_world
    m3 = m.to_3x3().normalized()
    sc = m.to_scale().x
    # Dày đường gấp ba (tấm da ôm cong theo vai), mỗi hàng chia 9 đỉnh theo
    # bề ngang: sau khi tạo dáng conform_outside ép từng đỉnh bám mặt da,
    # tấm dẹt một dải cứng thì hai mép cắm vào ngực.
    wp, wo, wt = [], [], []
    for i in range(nn - 1):
        for k in range(3):
            t = k / 3
            wp.append(m @ pts[i].lerp(pts[i + 1], t))
            wo.append((m3 @ outs[i].lerp(outs[i + 1], t)).normalized())
            wt.append(taper[i] + (taper[i + 1] - taper[i]) * t)
    wp.append(m @ pts[-1])
    wo.append((m3 @ outs[-1]).normalized())
    wt.append(taper[-1])
    cols = 9
    verts, faces = [], []
    n = len(wp)
    for i in range(n):
        tan = (wp[min(i + 1, n - 1)] - wp[max(i - 1, 0)]).normalized()
        o_ = (wo[i] - tan * wo[i].dot(tan)).normalized()
        side = o_.cross(tan).normalized()
        for c in range(cols):
            u = c / (cols - 1) * 2 - 1
            verts.append(wp[i] + side * u * 0.11 * sc * wt[i])
    for i in range(n - 1):
        for c in range(cols - 1):
            faces.append((i * cols + c, i * cols + c + 1, (i + 1) * cols + c + 1, (i + 1) * cols + c))
    mesh = bpy.data.meshes.new("TigerPelt")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    # Pháp tuyến quay ra ngoài thân (Solidify đắp dày ra phía ngoài).
    if mesh.polygons[len(faces) // 2].normal.dot(wo[n // 2]) < 0:
        mesh.flip_normals()
    o = add_object("TigerPelt", mesh, [mat])
    o["cols"] = cols
    sol = o.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.008 * sc
    sol.offset = 1.0
    o.modifiers.new("Smooth", "SUBSURF").levels = 1
    parent_to_bone(o, rig, "spine_03")
    return o


def pelt_fur(o, rig):
    """Viền lông tua ra hai mép tấm da (da thú, không phải vải): lọn ngắn chĩa
    ra ngoài mép rồi rủ theo trọng lực. Gọi SAU conform_outside — dựng theo
    mép đã bám da trong dáng thật, đổi về toạ độ nghỉ rồi gắn xương."""
    cols = o["cols"]
    mw = o.matrix_world
    vs = [mw @ v.co for v in o.data.vertices]
    rows = len(vs) // cols
    sc = rig.matrix_world.to_scale().x
    rng = random.Random(12)
    fur = hair_material("PeltFur", "#9A5A1A", "#D88A30", "#F0C080", rough=0.5)
    guides = []
    for i in range(rows):
        for c, nb in ((0, 1), (cols - 1, cols - 2)):
            edge = vs[i * cols + c]
            out_d = (edge - vs[i * cols + nb]).normalized()
            ln = rng.uniform(0.022, 0.04) * sc
            g = [edge - out_d * 0.006 * sc]
            for j in range(1, 5):
                t = j / 4
                g.append(edge + out_d * ln * t + Vector((0, 0, -1)) * ln * 0.6 * t * t)
            guides.append(g)
    fo = strand_locks("PeltFur", guides, fur, per_lock=30, spread=0.012 * sc, clump=0.3, frizz=0.004 * sc,
                      root_radius=0.0012 * sc, seed=14)
    # Lông dựng theo toạ độ thế giới của dáng hiện tại: gắn xương theo ma
    # trận xương ĐANG tạo dáng (parent_to_bone tính theo dáng nghỉ).
    from mathutils import Matrix
    pb = rig.pose.bones["spine_03"]
    fo.parent = rig
    fo.parent_type = "BONE"
    fo.parent_bone = "spine_03"
    fo.matrix_parent_inverse = (rig.matrix_world @ pb.matrix @ Matrix.Translation((0, pb.length, 0))).inverted()
    return fo


def local_center(body, co, group):
    w = weights_by_group(body)
    pts = [co[i] for i in range(len(co)) if w[i].get(group, 0) > 0.5]
    return sum(pts, Vector()) / len(pts), pts


def face_front(body, co):
    """Hàm fy(x, z): y mặt da trước nhất của đầu tại (x, z) — toạ độ nghỉ cục bộ."""
    w = weights_by_group(body)
    head = [co[i] for i in range(len(co)) if w[i].get("head", 0) > 0.5 and w[i].get("HelperGeometry", 0) < 0.5
            and w[i].get("JointCubes", 0) < 0.5]

    def fy(x, z, r=0.004):
        ys = [p.y for p in head if abs(p.x - x) < r and abs(p.z - z) < r]
        return min(ys) if ys else None

    def on(x, z):
        y = fy(x, z) or fy(x, z, 0.008)
        return Vector((x, y, z))

    return on


def sculpt_face(body, co):
    """Mặt riêng của Shuten-dōji, khắc thẳng lên da (shape key): gờ mày nhô
    thành mái che hốc mắt sâu, hai rãnh cau dọc giữa mày, ba nếp nhăn ngang
    trán, sống mũi nhăn kiểu gầm gừ, rãnh mũi–má sâu, gò má và cơ hàm bạnh,
    nếp chân chim — phá nét mặt người mẫu chung của MPFB."""
    on = face_front(body, co)
    eye, _ = local_center(body, co, "helper-l-eye")
    xe, ze = abs(eye.x), eye.z
    lips, lip_pts = local_center(body, co, "lips")
    zm = lips.z
    xm = max(abs(p.x) for p in lip_pts)
    for s in (-1, 1):
        # Mái mày: khối nhô trên hốc mắt, đầu trong thấp sát sống mũi.
        inflate(body, co, on(s * xe * 0.95, ze + 0.02), (0.028, 0.03, 0.012), 0.014, name=f"BrowShelf{s}",
                front_only=False)
        inflate(body, co, on(s * xe * 0.45, ze + 0.012), (0.012, 0.03, 0.01), 0.008, name=f"BrowKnot{s}",
                front_only=False)
        # Hốc mắt sâu dưới mái mày.
        inflate(body, co, on(s * xe, ze + 0.006), (0.018, 0.02, 0.007), -0.007, name=f"Socket{s}",
                front_only=False)
        # Rãnh cau dọc giữa hai mày.
        ridge(body, co, [on(s * 0.006, ze - 0.002), on(s * 0.007, ze + 0.016), on(s * 0.005, ze + 0.034)],
              0.003, -0.0045, f"Frown{s}")
        # Rãnh mũi–má: từ cánh mũi vòng xuống ngoài khoé miệng.
        ridge(body, co, [on(s * (xm * 0.62), zm + 0.03), on(s * (xm * 0.95), zm + 0.014),
                         on(s * (xm * 1.12), zm - 0.004), on(s * (xm * 1.08), zm - 0.024)],
              0.006, -0.01, f"Nasolabial{s}")
        inflate(body, co, on(s * (xm * 1.35), zm + 0.012), (0.018, 0.03, 0.02), 0.007, name=f"CheekMass{s}",
                front_only=False)
        inflate(body, co, on(s * (xe * 1.35), ze - 0.022), (0.018, 0.03, 0.011), 0.009, name=f"Zygoma{s}",
                front_only=False)
        # Nếp dưới mí dưới và chân chim đuôi mắt.
        ridge(body, co, [on(s * (xe - 0.013), ze - 0.013), on(s * xe, ze - 0.019), on(s * (xe + 0.015), ze - 0.014)],
              0.003, -0.0035, f"UnderEye{s}")
        for k, dz in enumerate((-0.006, 0.0, 0.007)):
            ridge(body, co, [on(s * (xe + 0.02), ze + dz * 0.4), on(s * (xe + 0.032), ze + dz * 1.3)],
                  0.002, -0.0025, f"Crow{s}{k}")
        # Cơ hàm bạnh dưới gò má.
        inflate(body, co, Vector((s * (xm * 1.9), on(s * xm * 1.9, zm - 0.012).y, zm - 0.012)), (0.02, 0.04, 0.03),
                0.007, name=f"Masseter{s}", front_only=False)
    inflate(body, co, on(0.0, ze + 0.008), (0.006, 0.02, 0.008), 0.003, name="Procerus", front_only=False)
    # Mũi củ của gã nghiện rượu (Shuten-dōji = "đồng tử say"): đầu mũi tròn
    # to, hai cánh mũi phồng.
    tip = min((p for p in co if abs(p.x) < 0.004 and zm < p.z < ze), key=lambda p: p.y)
    inflate(body, co, tip + Vector((0, 0.004, -0.002)), (0.013, 0.014, 0.012), 0.009, name="NoseBulb",
            front_only=False)
    for s in (-1, 1):
        inflate(body, co, tip + Vector((s * 0.016, 0.012, -0.008)), (0.009, 0.012, 0.008), 0.005,
                name=f"NoseWing{s}", front_only=False)
    # Sẹo chém dọc qua mắt trái (nửa mặt hướng về người chơi): gờ thịt lồi.
    scar = [on(xe * 0.8, ze + 0.05), on(xe * 1.0, ze + 0.022), on(xe * 1.15, ze - 0.02), on(xe * 1.3, ze - 0.05)]
    ridge(body, co, scar, 0.005, 0.004, "Scar", ends=0.15)
    # Ba nếp nhăn ngang trán, cong võng xuống giữa.
    for k in range(3):
        z0 = ze + 0.036 + k * 0.011
        ridge(body, co, [on(x, z0 - 0.007 * (x / 0.045) ** 2 * (-1) - 0.004) for x in
                         (-0.045, -0.03, -0.015, 0.0, 0.015, 0.03, 0.045)], 0.003, -0.0035, f"Forehead{k}")
    # Sống mũi nhăn ngang khi gầm.
    for k in range(3):
        z0 = ze - 0.006 - k * 0.006
        ridge(body, co, [on(-0.011, z0 + 0.002), on(0.0, z0 - 0.001), on(0.011, z0 + 0.002)], 0.0022, -0.003,
              f"NoseWrinkle{k}")
    return xe, ze


def face_paint(body, co):
    """Thuộc tính `flush` (đỏ rượu ửng mũi, gò má) và `scar` (sẹo nhạt màu
    thịt non, theo đúng đường gờ sẹo của sculpt_face)."""
    on = face_front(body, co)
    eye, _ = local_center(body, co, "helper-l-eye")
    xe, ze = abs(eye.x), eye.z
    lips, _ = local_center(body, co, "lips")
    w = weights_by_group(body)
    tip = min((p for p in co if abs(p.x) < 0.004 and lips.z < p.z < ze), key=lambda p: p.y)
    scar = [on(xe * 0.8, ze + 0.05), on(xe * 1.0, ze + 0.022), on(xe * 1.15, ze - 0.02), on(xe * 1.3, ze - 0.05)]
    flush, sc = [], []
    for i, p in enumerate(co):
        if w[i].get("head", 0) < 0.5 or p.y > tip.y + 0.06:
            flush.append(0.0)
            sc.append(0.0)
            continue
        f = math.exp(-((p - tip).length / 0.02) ** 2)
        for s in (-1, 1):
            c = Vector((s * xe * 1.4, p.y, ze - 0.03))
            f = max(f, 0.6 * math.exp(-((p.x - c.x) ** 2 + (p.z - c.z) ** 2) / 0.022 ** 2))
        flush.append(f)
        d = min(((p - a) - (b - a) * max(0.0, min(1.0, (p - a).dot(b - a) / (b - a).length_squared))).length
                for a, b in zip(scar, scar[1:]))
        sc.append(math.exp(-(d / 0.0038) ** 2))
    store_point_attr(body, "flush", flush)
    store_point_attr(body, "scar", sc)


def kumadori(body, co):
    """Thuộc tính `kuma` 0…1: quầng sơn đỏ thẫm quanh hốc mắt, vệt đuôi mắt
    hất lên thái dương (vẽ mặt kumadori vai ác) — ánh mắt sắc, có khung."""
    w = weights_by_group(body)
    vals = [0.0] * len(co)
    for g, s in (("helper-l-eye", 1), ("helper-r-eye", -1)):
        c, _ = local_center(body, co, g)
        for i, p in enumerate(co):
            gw = w[i]
            if gw.get("head", 0) < 0.5 or gw.get("HelperGeometry", 0) > 0.5 or p.y > c.y + 0.004:
                continue
            dx, dz = (p.x - c.x) * s, p.z - (c.z + 0.002)
            ring = math.exp(-((dx / 0.026) ** 2 + (dz / 0.017) ** 2) ** 2 * 1.0)
            # Vệt hất từ đuôi mắt lên thái dương, thuôn nhọn.
            t = (dx - 0.012) / 0.03
            flick = 0.0
            if 0 <= t <= 1:
                zl = 0.002 + t * 0.022
                flick = math.exp(-((dz - zl) / (0.007 * (1 - t) + 0.0015)) ** 2)
            vals[i] = max(vals[i], min(1.0, ring * 1.1), flick)
    store_point_attr(body, "kuma", [v * 0.95 for v in vals])


TORSO = ("pelvis", "spine_01", "spine_02", "spine_03")


def body_detail(body, co, rig):
    """Thớ cơ, gân xanh, khối mỡ và cổ chân – bàn chân (shape key, toạ độ
    nghỉ cục bộ): ngực võ sĩ sumo nặng xệ có nếp dưới, ngấn hông, gân xanh
    cẳng tay – bắp tay – mu bàn tay, thớ cơ delta, bắp chân hai đầu, gân
    Achilles, mắt cá, gân mu bàn chân, khớp ngón chân."""
    bl = rig.data.bones
    w = weights_by_group(body)

    def pt(bone, u, ang, out=0.2):
        """Điểm da quanh xương [bone] ở tỉ lệ [u], góc [ang]° (0 trước, 90 ngoài thân)."""
        b = bl[bone]
        h, t = b.head_local, b.tail_local
        a = (t - h).normalized()
        f = Vector((0, -1, 0))
        f = (f - a * f.dot(a)).normalized()
        o = Vector((1 if h.x >= 0 else -1, 0, 0))
        lat = a.cross(f)
        if lat.dot(o) < 0:
            lat = -lat
        r = math.radians(ang)
        return snap_rest(body, co, h.lerp(t, u) + (f * math.cos(r) + lat * math.sin(r)) * out)

    zc = bl["spine_03"].head_local.z + 0.02
    # Eo béo liền khối với bụng: mỡ phủ kín hai sườn và lưng dưới từ dưới
    # ngực xuống đai (bỏ dáng chữ V cơ lưng xô), ngấn mỡ chờm trên đai.
    z_lo = bl["pelvis"].head_local.z + 0.05
    z_hi = zc - 0.02
    torso_pts = [(i, p) for i, p in enumerate(co)
                 if sum(w[i].get(k, 0) for k in TORSO) > 0.5 and w[i].get("HelperGeometry", 0) < 0.5]
    for k in range(5):
        z = z_lo + (z_hi - z_lo) * k / 4
        band = [p for _, p in torso_pts if abs(p.z - z) < 0.015]
        if not band:
            continue
        cy = (min(p.y for p in band) + max(p.y for p in band)) / 2
        amt = 0.08 * (1 - 0.4 * k / 4)  # dày nhất ở eo, mỏng dần lên ngực
        for sx in (-1, 1):
            xs = max(p.x * sx for p in band)
            inflate(body, co, Vector((sx * xs, cy + 0.01, z)), (0.09, 0.16, 0.08), amt, name=f"FlankFat{k}{sx}",
                    front_only=False, groups=TORSO)
        yb = max(p.y for p in band)
        yf = min(p.y for p in band)
        if k >= 2:  # bụng trên dưới ngực: mỡ phủ mất múi cơ, nối ngực xuống bụng
            inflate(body, co, Vector((0, yf, z)), (0.16, 0.08, 0.06), amt * 0.8, name=f"UpperGut{k}",
                    front_only=False, groups=TORSO)
        inflate(body, co, Vector((0, yb, z)), (0.14, 0.07, 0.07), amt * 0.7, name=f"BackFat{k}",
                front_only=False, groups=TORSO)
    # Ngấn mỡ chờm qua đai: cuộn lồi ở sườn – lưng, rãnh gấp ngay dưới.
    zr = z_lo + 0.03
    band = [p for _, p in torso_pts if abs(p.z - zr) < 0.015]
    cx = 0.0
    cy = (min(p.y for p in band) + max(p.y for p in band)) / 2
    roll, crease = [], []
    for a in range(-110, 111, 10):  # 0° = sau lưng, ±90° = hai sườn
        d = Vector((math.sin(math.radians(a)), math.cos(math.radians(a)), 0))
        q = max(band, key=lambda p: (p - Vector((cx, cy, p.z))).normalized().dot(d))
        roll.append(snap_rest(body, co, Vector((q.x, q.y, zr + 0.02))))
        crease.append(snap_rest(body, co, Vector((q.x, q.y, zr - 0.012))))
    ridge(body, co, roll, 0.028, 0.03, "WaistRoll", groups=TORSO, ends=0.1)
    ridge(body, co, crease, 0.008, -0.014, "WaistCrease", groups=TORSO, ends=0.1)
    for sx in (-1, 1):
        s_ = "l" if sx > 0 else "r"
        x = 0.1 * sx
        fy = min(p.y for p in co if abs(p.x - x) < 0.03 and abs(p.z - zc) < 0.03)
        # Ngực nặng xệ: khối lớn thấp, nếp gấp dưới ngực sâu.
        inflate(body, co, Vector((x, fy, zc - 0.04)), (0.12, 0.1, 0.1), 0.075, name=f"PecMass{sx}",
                front_only=False, groups=TORSO)
        fold = [snap_rest(body, co, Vector((sx * xx, fy, zc - 0.1 - 0.03 * (xx - 0.09) ** 2 / 0.01)))
                for xx in (0.02, 0.06, 0.1, 0.14, 0.17)]
        ridge(body, co, fold, 0.008, -0.012, f"PecFoldDeep{sx}", groups=TORSO)
        # Gân xanh cẳng tay (mặt trong) và bắp tay trước, rẽ nhánh.
        ridge(body, co, [pt(f"lowerarm_{s_}", u, -35 + 25 * u) for u in (0.08, 0.3, 0.55, 0.8, 0.95)],
              0.005, 0.0035, f"VeinFore{s_}", groups=(f"lowerarm_{s_}", f"hand_{s_}"), ends=0.1)
        ridge(body, co, [pt(f"lowerarm_{s_}", u, -35 + 60 * (u - 0.3)) for u in (0.3, 0.5, 0.7)],
              0.004, 0.0028, f"VeinFore2{s_}", groups=(f"lowerarm_{s_}",))
        ridge(body, co, [pt(f"upperarm_{s_}", u, 15) for u in (0.35, 0.6, 0.85, 1.0)],
              0.005, 0.003, f"VeinBicep{s_}", groups=(f"upperarm_{s_}", f"lowerarm_{s_}"))
        # Thớ cơ delta: rãnh mảnh toả từ điểm bám giữa bắp tay lên mỏm vai.
        for k, ang in enumerate((25, 60, 95, 130)):
            ridge(body, co, [pt(f"upperarm_{s_}", 0.42, 70), pt(f"upperarm_{s_}", 0.2, ang),
                             pt(f"upperarm_{s_}", 0.04, ang)], 0.0035, -0.0025, f"DeltFiber{s_}{k}",
                  groups=(f"upperarm_{s_}", f"clavicle_{s_}"))
        # Gân mu bàn tay.
        for k, f in enumerate(("index", "middle", "ring", "pinky")):
            a = snap_rest(body, co, bl[f"hand_{s_}"].head_local.lerp(bl[f"{f}_01_{s_}"].head_local, 0.15)
                          + Vector((0, 0, 0.02)))
            b = snap_rest(body, co, bl[f"{f}_01_{s_}"].head_local + Vector((0, 0, 0.012)))
            ridge(body, co, [a, b], 0.003, 0.0018, f"HandTendon{s_}{k}", groups=(f"hand_{s_}",))
        # Bắp chân: hai đầu cơ sinh đôi, cơ chày trước, gân Achilles, mắt cá.
        muscle_bulge(body, co, rig, f"calf_{s_}", [
            (0.28, 0.17, 145, 38, 0.03),     # đầu ngoài cơ sinh đôi
            (0.3, 0.17, -150, 38, 0.034),    # đầu trong, thấp hơn chút
            (0.3, 0.3, 180, 8, -0.008),      # rãnh giữa hai đầu
            (0.35, 0.28, 25, 22, 0.012),     # cơ chày trước
            (0.4, 0.3, 0, 8, -0.006),        # sống ống chân
            (0.86, 0.1, 180, 16, 0.013),     # gân Achilles
            (0.84, 0.1, 140, 18, -0.008),    # hõm hai bên gân
            (0.84, 0.1, -140, 18, -0.008),
            (0.96, 0.05, 95, 28, 0.016),     # mắt cá ngoài
            (0.93, 0.05, -95, 28, 0.014),    # mắt cá trong, cao hơn
        ], f"Calf{s_}", min_w=0.25)
        # Gân mu bàn chân từ cổ chân xoè tới gốc từng ngón; khớp ngón nổi.
        ank = local_center(body, co, f"joint-{s_}-ankle")[0]
        top = snap_rest(body, co, ank + Vector((0, -0.05, 0.0)))
        for k in range(1, 6):
            tb = local_center(body, co, f"joint-{s_}-toe-{k}-1")[0]
            tb = snap_rest(body, co, tb + Vector((0, 0, 0.02)))
            mid = snap_rest(body, co, top.lerp(tb, 0.5) + Vector((0, 0, 0.03)))
            ridge(body, co, [top, mid, tb], 0.0045 if k > 1 else 0.006, 0.0038 if k > 1 else 0.005,
                  f"FootTendon{s_}{k}", groups=(f"foot_{s_}", f"ball_{s_}", f"calf_{s_}"), ends=0.15)
            for j in (2, 3):
                g = f"joint-{s_}-toe-{k}-{j}"
                if g in body.vertex_groups:
                    kn = snap_rest(body, co, local_center(body, co, g)[0] + Vector((0, 0, 0.02)))
                    inflate(body, co, kn, (0.007, 0.007, 0.006), 0.005, name=f"Knuckle{s_}{k}{j}",
                            front_only=False)
        # Gót chân dày, đệm gan bàn chân.
        heel = snap_rest(body, co, ank + Vector((0, 0.04, -0.06)))
        inflate(body, co, heel, (0.03, 0.03, 0.025), 0.008, name=f"Heel{s_}", front_only=False)


def lower_fat(body, co, rig):
    """Thân dưới người béo phì (shape key, toạ độ nghỉ): hông bè gần bằng bụng,
    mông và bụng dưới trễ dưới đai, đùi to liền khối thon dần xuống gối có
    đệm mỡ, bắp chân dày. Hakama sao từ thân nên phồng theo — không còn dáng
    ống thắt dưới đai."""
    bl = rig.data.bones
    w = weights_by_group(body)
    hips = TORSO + ("thigh_l", "thigh_r")
    pz = bl["pelvis"].head_local.z
    pts = [p for i, p in enumerate(co)
           if sum(w[i].get(k, 0) for k in hips) > 0.5 and w[i].get("HelperGeometry", 0) < 0.5]
    for z, amt, rad in ((pz - 0.07, 0.1, (0.12, 0.17, 0.12)), (pz + 0.02, 0.06, (0.1, 0.16, 0.09))):
        band = [p for p in pts if abs(p.z - z) < 0.015]
        cy = (min(p.y for p in band) + max(p.y for p in band)) / 2
        for sx in (-1, 1):
            xs = max(p.x * sx for p in band)
            inflate(body, co, Vector((sx * xs, cy + 0.01, z)), rad, amt, name=f"HipFat{z:.2f}{sx}",
                    front_only=False, groups=hips)
    # Mông nặng xệ và bụng dưới trễ dưới đai (che trong hakama nhưng đẩy quần phồng).
    band = [p for p in pts if abs(p.z - (pz - 0.08)) < 0.015]
    yb, yf = max(p.y for p in band), min(p.y for p in band)
    # Vòng eo liền khối: đẩy hai sườn và lưng dưới ra xa trục thân (mặt trước đã
    # có bụng) để lưng chảy liền xuống mông, không thắt eo giữa bụng và hông.
    band = [p for p in pts if abs(p.z - (pz + 0.04)) < 0.015]
    cy = (min(p.y for p in band) + max(p.y for p in band)) / 2
    prof = [(pz - 0.09, 0.0), (pz - 0.02, 0.07), (pz + 0.06, 0.1), (pz + 0.15, 0.08), (pz + 0.26, 0.0)]
    if body.data.shape_keys is None:
        body.shape_key_add(name="Basis")
    key = body.shape_key_add(name="WaistFill", from_mix=False)
    for i, p in enumerate(co):
        g = w[i]
        if g.get("HelperGeometry", 0) > 0.5 or not prof[0][0] < p.z < prof[-1][0]:
            continue
        gw = min(1.0, sum(g.get(k, 0) for k in hips))
        for (z0, a0), (z1, a1) in zip(prof, prof[1:]):
            if z0 <= p.z <= z1:
                k = (p.z - z0) / (z1 - z0)
                amt = a0 + (a1 - a0) * k * k * (3 - 2 * k)
                break
        r = Vector((p.x, p.y - cy, 0))
        if r.length < 1e-4:
            continue
        r.normalize()
        f = 1 - 0.65 * max(0.0, -r.y)  # mặt trước nhẹ tay
        key.data[i].co = key.data[i].co + r * amt * f * gw
    key.value = 1.0
    # Mông là điểm nhô ra sau xa nhất (ảnh tham khảo người béo phì nhìn nghiêng),
    # lưng dưới lồi liền xuống mông; bụng dưới rơi gần thẳng đứng dưới đai.
    for sx in (-1, 1):
        inflate(body, co, Vector((sx * 0.08, yb, pz - 0.12)), (0.13, 0.12, 0.14), 0.13, name=f"Glute{sx}",
                front_only=False, groups=hips)
    inflate(body, co, Vector((0, yb, pz + 0.07)), (0.17, 0.08, 0.1), 0.05, name="LowBackFat", front_only=False,
            groups=hips)
    inflate(body, co, Vector((0, yf, pz - 0.07)), (0.2, 0.1, 0.11), 0.11, name="LowerGut", front_only=False,
            groups=hips)
    for s in ("l", "r"):
        # Đùi trên dày gần bằng thân, hai đùi áp sát, thon đều xuống gối.
        limb_fat(body, co, rig, f"thigh_{s}", [(-0.2, 0.0), (0.0, 0.11), (0.4, 0.09), (0.8, 0.05), (1.0, 0.025),
                                               (1.12, 0.0)], f"ThighFat{s}", (f"thigh_{s}",), inner=0.75, back=1.2)
        limb_fat(body, co, rig, f"calf_{s}", [(-0.1, 0.0), (0.02, 0.02), (0.3, 0.035), (0.75, 0.015), (0.95, 0.0)],
                 f"CalfFat{s}", (f"calf_{s}",), inner=0.6)


def sole_paint(body, co):
    """Thuộc tính `sole`: gan bàn chân và mép gót sạm chai."""
    w = weights_by_group(body)
    normals = [v.normal for v in body.data.vertices]
    z0 = min(p.z for p in co)
    vals = []
    for i, p in enumerate(co):
        g = w[i]
        f = g.get("foot_l", 0) + g.get("foot_r", 0) + g.get("ball_l", 0) + g.get("ball_r", 0)
        down = max(0.0, -normals[i].z)
        low = max(0.0, 1 - (p.z - z0) / 0.03)
        vals.append(min(1.0, f) * min(1.0, down * 1.5 * low + low * 0.4))
    store_point_attr(body, "sole", vals)


def pupils(body, co, rig, fwd):
    """Mống mắt hổ phách sẫm + đồng tử đen trên lòng mắt vàng. Dựng ở gốc
    toạ độ rồi đặt bằng aim_pupils (nhìn thẳng máy quay sau khi tạo dáng)."""
    black = skin_material("Pupil", "#030202", rough=0.08)
    iris_m = skin_material("Iris", "#5A1E04", rough=0.15)
    w = weights_by_group(body)
    m = body.matrix_world
    out = []
    for g in ("helper-l-eye", "helper-r-eye"):
        pts = [m @ co[i] for i in range(len(co)) if w[i].get(g, 0) > 0.5]
        c = sum(pts, Vector()) / len(pts)
        r = max((p - c).dot(fwd) for p in pts)
        for name, rad, flat, mat, lift in (("Iris", 0.0095, 0.25, iris_m, 0.0), ("Pupil", 0.0042, 0.35, black, 0.0006)):
            o = add_object(f"{name}{g}", raw_ellipsoid(f"{name}{g}", Vector(), (rad * S, rad * S, rad * S * flat)), [mat])
            parent_to_bone(o, rig, "head")
            o["eye_c"] = c
            o["eye_r"] = r + lift * S
            o["eye_fwd"] = fwd
            out.append(o)
    return out


def aim_pupils(objs, cam, limit_deg=28):
    """Đồng tử nhìn về máy quay (người chơi), lệch tối đa [limit_deg] so với
    hướng mặt — ánh mắt khoá vào người xem, không nhìn lạc ra ngoài."""
    bpy.context.view_layer.update()  # máy quay vừa tạo: matrix_world chưa tính
    view = (cam.matrix_world.to_3x3() @ Vector((0, 0, 1))).normalized()
    for o in objs:
        M = o.matrix_world @ o.matrix_basis.inverted()
        Mi = M.inverted()
        c = Vector(o["eye_c"])
        f = Vector(o["eye_fwd"])
        f_w = (M.to_3x3() @ f).normalized()
        ang = f_w.angle(view)
        d_w = f_w.slerp(view, min(1.0, math.radians(limit_deg) / ang)) if ang > 1e-4 else f_w
        d = (Mi.to_3x3() @ d_w).normalized()
        o.location = c + d * o["eye_r"]
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    bpy.context.view_layer.update()


def build():
    # Võ sĩ sumo: mỡ dày trùm khối cơ (ngực, eo, cổ), cơ – gân vẫn khắc riêng
    # ở phần da lộ; bụng và mặt đắp riêng.
    body, rig, parts = boss_human(1.0, muscle=0.7, weight=0.9, height=1.0, age=0.62, proportions=0.55, scale=S,
                                  details=safe_details(ONI_BODY), eyebrows=None)
    densify(body)
    w0 = weights_by_group(body)
    store_point_attr(body, "lips", [min(1.0, w0[i].get("lips", 0)) for i in range(len(w0))])
    clay = "--clay" in sys.argv  # soát hình khối: bỏ hoa văn xăm
    skin = painted_skin("OniSkin", "#B83A2C", "#8A2820", tattoo=None if clay else "#7A2016", sss=0.12, rough=0.72, lips="#4A0C0A",
                        cavity=("#3A0806", 0.1 * S, 0.9), tattoo_band=0.935,
                        paints=[("sole", "#5A1A14"), ("flush", "#D8483A"), ("kuma", "#140202"),
                                ("scar", "#F2B8A4")])
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
    tuck_z = bl["pelvis"].head_local.z + 0.01  # bụng trễ thấp, chờm qua đai như người béo phì thật
    zc = tuck_z + (z_chest - tuck_z) * 0.32
    band = [p for p in co0 if abs(p.z - zc) < 0.02 and abs(p.x) < 0.25]
    half_w = max(abs(p.x) for p in band)
    y_front = min(p.y for p in band)
    ry = 0.3
    center = Vector((0, y_front + ry - 0.23, zc))  # nhô 0,23 m trước bụng gốc
    belly_ball(body, co0, center, half_w + 0.11, ry, z_chest - zc + 0.1, zc - tuck_z + 0.1, tuck_z, soft=0.3)
    # Rốn lõm sâu giữa khối bụng.
    co1 = rest_coords(body)
    nz = zc - 0.02
    navel = min((p for p in co1 if abs(p.x) < 0.015 and abs(p.z - nz) < 0.015), key=lambda p: p.y)
    inflate(body, co1, navel, (0.022, 0.04, 0.03), -0.03, name="Navel", front_only=False)
    hero_muscles(body, co0, rig)
    co2 = rest_coords(body)
    sculpt_face(body, co2)
    body_detail(body, co2, rig)
    lower_fat(body, co2, rig)
    co = rest_coords(body)
    kumadori(body, co)
    face_paint(body, co)
    sole_paint(body, co)
    head_c, up, fwd, right = head_frame(rig)
    eyes = pupils(body, co, rig, fwd)

    iron = skin_material("Iron", "#202026", rough=0.35, metallic=0.85, noise_scale=40)
    gold = gold_material("OniGold", "#E0AE48", rough=0.3)
    black = skin_material("Lacquer", "#0E0C10", rough=0.15)
    claw_m = skin_material("Claw", "#121010", rough=0.2)
    bead_m = skin_material("Bead", "#16141A", rough=0.12)
    rope_m = skin_material("Rope", "#E6DCC4", rough=0.85, noise_scale=120)
    navy = silk_material("Hakama", "#22284A", pattern="#3A3860", trim="#B08A3C", sheen=0.5)
    apron_m = silk_material("ApronCloth", "#1A1E3A", pattern="#2C3058", sheen=0.4)
    tassel = skin_material("Tassel", "#A01C1C", rough=0.7)
    fire = flame_material("Onibi", "#FFD27A", "#E0200A", strength=1.8)  # lõi vàng nóng, rìa đỏ
    halo = flame_material("OnibiHalo", "#FF5A20", "#8A0804", strength=1.2, opacity=0.07)
    spark = glow_material("OnibiSpark", "#FFB040", strength=4, base="#FF6010")
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
    waist_z = bl["pelvis"].head_local.z - 0.02  # đai thấp, nằm dưới nếp bụng chờm
    c, rx, ry = body_ring(body, co, waist_z, ("pelvis", "spine_01", "spine_02"), pad=0.035)
    ring = ellipse_ring(c, rx, ry, n=72)
    for o in twisted_rope("Shimenawa", ring, 0.04 * S, rope_m):
        parent_to_bone(o, rig, "spine_01")
    buckle(rig, c - Vector((0, ry + 0.035 * S, 0)), fwd, gold, iron, eye_purple)
    knee_z = bl["calf_l"].head_local.z * S + 0.05 * S
    apron(rig, c, rx * 0.55, ry, c.z - 0.06 * S, knee_z, fwd, apron_m, gold)

    # ---- da hổ vắt vai trái (trang phục kinh điển của oni)
    pelt_o = pelt(body, co, rig, tiger_material("TigerPelt"), tuck_z)

    # ---- quần hakama chàm, gấu viền vàng
    hakama(body, co, rig, "Hakama", navy, flare=0.13 * S, top_pad=0.05, drape=24, top=-0.01)

    # ---- giáp tay vàng–đen, vòng cổ tay
    for s in ("l", "r"):
        limb_band(rig, f"lowerarm_{s}", 0.42, 0.92, 0.062 * S, 0.05 * S, black, f"Bracer{s}")
        for t in (0.45, 0.9):
            limb_band(rig, f"lowerarm_{s}", t - 0.02, t + 0.02, 0.066 * S, 0.066 * S, gold, f"BracerBand{s}")
        limb_band(rig, f"upperarm_{s}", 0.2, 0.3, 0.104 * S, 0.1 * S, gold, f"Armlet{s}")  # trùm bắp tay béo
        claws(rig, s, claw_m, length=0.035 * S, radius=0.007 * S)
        claws(rig, s, claw_m, length=0.04 * S, radius=0.01 * S, toes=True)
    return body, rig, {"iron": iron, "gold": gold, "tassel": tassel, "fire": fire, "halo": halo, "spark": spark, "eyes": eyes, "pelt": pelt_o}


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
    # Ngửa lòng bàn tay, ngón vuốt quặp nhẹ ôm lửa.
    fa_l = (poser.world("hand_l", 0.0) - poser.world("lowerarm_l", 0.0)).normalized()
    flat_l = (fa_l - up * fa_l.dot(up)).normalized()
    poser.palm("l", (flat_l - up * 0.1).normalized(), up)
    fist(rig, "l", curl=0.45)
    palm = (poser.world("hand_l", 0.0) + poser.world("middle_01_l", 0.0)) / 2 + up * 0.06 * S
    flame("Onibi", palm, 0.26 * S, 0.12 * S, mats["fire"], lean=-fwd * 0.05 * S + up * 0.02, tongues=5, seed=1)
    add_object("OnibiHalo", raw_ellipsoid("OnibiHalo", palm + up * 0.1 * S, (0.1 * S, 0.1 * S, 0.14 * S)),
               [mats["halo"]])
    rng = random.Random(4)
    for k in range(8):  # tàn lửa bốc lên từ lòng bàn tay
        p = palm + up * rng.uniform(0.2, 0.42) * S + (fwd * rng.uniform(-1, 1) + left * rng.uniform(-1, 1)) * 0.07 * S
        r = rng.uniform(0.005, 0.009) * S
        add_object(f"OnibiEmber{k}", raw_ellipsoid(f"OnibiEmber{k}", p, (r, r, r * 1.6), segments=8, rings=6),
                   [mats["spark"]])
    wisps(poser, mats)
    return poser


def wisps(poser, mats, n=8):
    """Vòng lửa ma trơi bay xoắn ốc quanh thân (ngược chiều kim đồng hồ nhìn từ
    trên), đuôi kéo ngược hướng bay và hơi bốc lên. Bỏ ngọn nào rơi trước
    bụng/mặt nhìn từ máy quay ảnh duyệt để không che boss."""
    from mathutils import Euler
    fwd, left, up = poser.frame()
    c0 = poser.world("spine_02", 0.0)
    cam = Euler((math.radians(84), 0, math.radians(-8))).to_matrix() @ Vector((0, 0, -1))
    cam_h = Vector((cam.x, cam.y, 0)).normalized()
    rng = random.Random(11)
    for k in range(n):
        a = 2 * math.pi * k / n + 0.3
        radial = fwd * math.cos(a) + left * math.sin(a)
        tangent = -fwd * math.sin(a) + left * math.cos(a)
        h = (-0.55 + 1.5 * k / (n - 1)) * S + rng.uniform(-0.08, 0.08) * S
        p = c0 + radial * rng.uniform(0.82, 1.0) * S + up * h
        lateral = (p - c0) - cam_h * (p - c0).dot(cam_h)
        lateral.z = 0
        if (p - c0).dot(cam_h) < 0 and lateral.length < 0.55 * S:
            continue  # trước thân nhìn từ máy quay
        size = rng.uniform(0.04, 0.06) * S
        hitodama(f"Wisp{k}", p, size, -tangent * 0.6 + up * 0.8, (mats["fire"], mats["halo"], mats["spark"]),
                 seed=20 + k)


def look_at(scene, p, width, height, ppm, yaw, pitch):
    """Máy quay trực giao có tâm khung đúng điểm [p] (human_kit.camera đặt
    tâm ở mặt phẳng y = 0 nên lệch khi quay góc lớn)."""
    rot = Vector((math.radians(90 - pitch), 0, math.radians(yaw)))
    from mathutils import Euler
    fwd = Euler(rot).to_matrix() @ Vector((0, 0, -1))
    t = -p.y / fwd.y
    q = p + fwd * t
    return camera(scene, q.x, q.z, width, height, ppm, yaw=yaw, pitch=pitch)


def lights(scene):
    add_sun(scene, "Key", (0.35, 0.75, -0.55), 3.6, "#FFE2C2", angle=3)
    add_sun(scene, "Rim", (-0.75, -0.3, -0.25), 3.2, "#9EC0FF", angle=4)
    add_sun(scene, "Fill", (0.2, 0.9, 0.2), 0.6, "#FFB0A0", angle=20)


def main():
    scene = reset_scene(samples=32 if "--quick" in sys.argv else 96, world_hex="#C9C4C0", world_strength=0.7, keep_prefs=True)
    body, rig, mats = build()
    pose_and_props(rig, mats)
    # Tấm da hổ bám da trong dáng thật (vai trái nâng tay làm cơ delta nhô).
    conform_outside(mats["pelt"], body, 0.006 * S, 0.02 * S)
    pelt_fur(mats["pelt"], rig)
    lights(scene)
    shadow_catcher()
    out = os.path.join(ROOT, "build", "blender", "oni")
    os.makedirs(out, exist_ok=True)
    pb = rig.pose.bones["head"]
    head = rig.matrix_world @ pb.head.lerp(pb.tail, 0.5)
    if "--dry" in sys.argv:  # dựng cảnh không render; ONI_DEBUG = script soát chạy thêm
        aim_pupils(mats["eyes"], camera(scene, head.x, head.z, 0.4 * S, 0.4 * S, 100, yaw=-44, pitch=3))
        if os.environ.get("ONI_DEBUG"):
            exec(open(os.environ["ONI_DEBUG"], encoding="utf-8").read())
        return
    if "--grip-only" not in sys.argv and "--checks" not in sys.argv:
        cam = camera(scene, -0.1 * S, 1.3 * S, 2.6 * S, 2.9 * S, 260, yaw=-8, pitch=6)
        aim_pupils(mats["eyes"], cam)
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
        hl = rig.matrix_world @ rig.pose.bones["hand_l"].head
        camera(scene, hl.x, hl.z, 0.5 * S, 0.5 * S, 900, yaw=-8, pitch=4)
        render_to(scene, os.path.join(out, "check_hand_l.png"))
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
    if "--face" in sys.argv:  # soát mặt chính diện (khắc nếp, hốc mắt, đồng tử) và bàn chân cận
        cam = look_at(scene, head - Vector((0, 0, 0.03 * S)), 0.42 * S, 0.42 * S, 1600, yaw=-44, pitch=3)
        aim_pupils(mats["eyes"], cam)
        render_to(scene, os.path.join(out, "check_face_front.png"))
        ft = rig.matrix_world @ (rig.pose.bones["ball_l"].head + rig.pose.bones["ball_r"].head) / 2
        ft.z = 0.08 * S
        look_at(scene, ft, 0.85 * S, 0.3 * S, 1100, yaw=-8, pitch=10)
        render_to(scene, os.path.join(out, "check_foot.png"))
    from boss_kit import save_blend
    save_blend("oni_boss")


main()
