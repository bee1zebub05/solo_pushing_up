# blender: user-prefs  (cần tiện ích MPFB + gói tài nguyên hệ thống — xem rules/dohoa.md mục 10)
"""Tamamo-no-Mae, hồ ly chín đuôi (Kỳ công Heian) — HAI DẠNG theo tranh tham
khảo người dùng chọn:

- `fox`: cáo trắng khổng lồ ngồi thanh tao, lông trắng ánh tím hồng ở ngọn,
  vạch đỏ quanh mắt hạnh nhân (kitsune), tai trong hồng, CHÍN ĐUÔI to bồng
  bềnh như mây xoè sau lưng, ngọn đuôi uốn như lửa (tranh Hokusai "Cáo vàng
  chín đuôi", tranh cáo trắng trên cây hoa).
- `human`: mỹ nhân cung đình (dạng giả): tóc đen búi cao cài trâm vàng và hoa
  trà đỏ, mũ hoa vàng đính đá đỏ, hoa điểm đỏ giữa trán, mạng che mặt bằng
  chuỗi vàng, vai và cánh tay đeo trang sức vàng, áo trắng ngà thắt lụa lam,
  dải lụa đỏ bay (hagoromo), tay nâng chén rượu vàng; bóng chín đuôi mờ sau
  lưng (lộ dần khi bị vạch mặt).

    bash tool/blender/render.sh tamamo_boss --still --form fox
    bash tool/blender/render.sh tamamo_boss --still --form human
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from boss_kit import ARGS, ROOT, add_object, add_sun, fur_material, glow_material, gold_material, \
    parent_to_bone, render_to, reset_scene, skin_material, with_fur  # noqa: E402
from human_kit import camera, raw_ellipsoid, raw_tube, shadow_catcher, tapered_world  # noqa: E402
from japan_kit import bezier_pts, blob, capsule_items  # noqa: E402

FORM = ARGS[ARGS.index("--form") + 1] if "--form" in ARGS else "fox"
K = 1.0  # cáo ngồi cao ~1,7 m

# ---------------------------------------------------------------- dạng cáo

FUR_STOPS = [(0.0, "#FFFFFF"), (0.45, "#F4F0F6"), (0.8, "#E2D6EE"), (1.0, "#CDB8E4")]
TAIL_STOPS = [(0.0, "#FFFFFF"), (0.5, "#F0EAF4"), (0.85, "#DCCCEC"), (1.0, "#C8A8DC")]


def fox_body(skin):
    """Thân cáo ngồi, nhìn về −X (phía người chơi): mông to tròn, ngực ưỡn,
    cổ thanh, đầu nhỏ mõm nhọn; hai chân trước thẳng, chân sau gập."""
    f = Vector((-1, 0, 0))
    items = [
        ((0.16, 0, 0.32), (0.32, 0.27, 0.3)),          # mông (ngồi)
        ((-0.02, 0, 0.58), (0.2, 0.2, 0.3)),           # bụng–lưng
        ((-0.14, 0, 0.84), (0.2, 0.19, 0.24)),         # ngực
        ((-0.19, 0, 1.0), (0.14, 0.14, 0.16)),         # cổ (ngắn, dày — bờm cổ)
        ((-0.25, 0, 1.17), (0.145, 0.13, 0.12)),       # sọ
        ((-0.38, 0, 1.13), (0.1, 0.07, 0.065)),        # mõm
        ((-0.46, 0, 1.115), (0.05, 0.04, 0.038)),      # chóp mõm
        ((-0.22, 0.09, 1.1), (0.09, 0.07, 0.09)),      # bờm má
        ((-0.22, -0.09, 1.1), (0.09, 0.07, 0.09)),
        ((-0.05, 0.19, 0.07), (0.17, 0.065, 0.06)),    # bàn chân sau
        ((-0.05, -0.19, 0.07), (0.17, 0.065, 0.06)),
    ]
    for s in (-1, 1):
        items += capsule_items((-0.2, s * 0.1, 0.76), (-0.3, s * 0.1, 0.06), 0.075, 0.045, n=22)
        items.append(((-0.33, s * 0.1, 0.035), (0.07, 0.05, 0.035)))  # bàn chân trước
    return blob("FoxBody", items, [skin], voxel=0.012, smooth_iter=10)


def fox_face(mats, fur_m=None):
    """Tai nhọn (trong hồng), mắt hạnh nhân đỏ thẫm, vạch đỏ kitsune, mũi đen."""
    white, pink, red_glow, black, eye = mats
    out = []
    for s in (-1, 1):
        base = Vector((-0.22, s * 0.075, 1.25))
        tip = Vector((-0.19, s * 0.12, 1.47))
        pts = [base.lerp(tip, t) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
        rad = [(0.05 * (1 - t) ** 0.8 + 0.002, 0.018 * (1 - t) + 0.002) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
        ear = add_object(f"Ear{s}", raw_tube(f"Ear{s}", pts, rad, sides=16), [white])
        out.append(ear)
        if fur_m:
            out.append(with_fur(ear, fur_m, density=90000, length=(0.008, 0.016), radius=0.0007, comb=(0, 0, 1),
                                lift=0.4, gravity=0.0, jitter=0.3, seed=60 + s, resolution=3))
        pin = [p + Vector((-0.012, 0, 0)) for p in pts[:4]]
        out.append(add_object(f"EarIn{s}", raw_tube(f"EarIn{s}", pin, [(r[0] * 0.75, 0.008) for r in rad[:4]],
                                                     sides=12), [pink]))
        # Mắt hạnh nhân xếch, khép hờ.
        e = Vector((-0.345, s * 0.075, 1.2))
        out.append(add_object(f"Eye{s}", raw_ellipsoid(f"Eye{s}", e, (0.026, 0.012, 0.011), rot_z=0.0), [eye]))
        # Vạch đỏ kitsune: từ khoé mắt vút lên thái dương + chấm dưới mắt.
        out.append(add_object(f"Mark{s}", tapered_world(f"Mark{s}", [
            (e + Vector((0.01, s * 0.008, 0.008)), e + Vector((0.05, s * 0.02, 0.035)),
             e + Vector((0.1, s * 0.03, 0.06)), 0.009),
            (e + Vector((-0.01, s * 0.01, -0.015)), e + Vector((0.02, s * 0.016, -0.03)),
             e + Vector((0.05, s * 0.02, -0.035)), 0.006)], flat=2.0, taper=1.0), [red_glow]))
    out.append(add_object("Nose", raw_ellipsoid("Nose", Vector((-0.505, 0, 1.125)), (0.018, 0.022, 0.016)), [black]))
    # Hoa văn đỏ giữa trán (giọt lửa).
    out.append(add_object("Brow", tapered_world("Brow", [
        (Vector((-0.33, 0, 1.25)), Vector((-0.31, 0, 1.28)), Vector((-0.28, 0, 1.32)), 0.012)], flat=2.2,
        taper=1.0), [red_glow]))
    return out


def tails(fur_m, skin):
    """Chín đuôi bồng bềnh xoè quạt sau lưng (y–z), mỗi đuôi cong chữ S, phình
    giữa, ngọn uốn ngược như ngọn lửa; lông dài chải dọc đuôi."""
    rng = random.Random(9)
    base = Vector((0.42, 0, 0.24))
    out = []
    for k in range(9):
        a = math.radians(-78 + 156 * k / 8)  # quanh trục x: −78° (gần) … +78° (xa)
        side = Vector((0, math.sin(a), math.cos(a)))  # trong mặt phẳng y–z
        back = Vector((1, 0, 0))
        L = rng.uniform(1.15, 1.45)
        p0 = base
        p1 = base + back * 0.35 + side * 0.15
        p2 = base + back * 0.55 + side * 0.85 * L
        p3 = p2 + side * 0.35 + back * rng.uniform(-0.25, 0.1) + Vector((0, 0, 0.15))
        pts = bezier_pts(p0, p1, p2, p3, 16)
        n = len(pts)
        radii = []
        for i in range(n):
            t = i / (n - 1)
            r = 0.06 + 0.13 * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7
            radii.append((r * (1 - t ** 4), r * (1 - t ** 4)))
        radii[-1] = (0.004, 0.004)
        o = add_object(f"Tail{k}", raw_tube(f"Tail{k}", pts, radii, sides=18), [skin])
        out.append(o)
        comb = (p3 - p0).normalized()
        out.append(with_fur(o, fur_m, density=26000, length=(0.08, 0.16), radius=0.0016, comb=tuple(comb),
                            lift=0.25, gravity=0.01, jitter=0.45, seed=40 + k, resolution=7))
    return out


def build_fox():
    skin = skin_material("FoxSkin", "#F2EEF2", rough=0.8)
    fur_m = fur_material("FoxFur", FUR_STOPS, sheen=0.05)
    tail_m = fur_material("TailFur", TAIL_STOPS, sheen=0.08)
    pink = skin_material("EarPink", "#E8A8B8", rough=0.6)
    red = glow_material("KitsuneRed", "#E02838", strength=0.8, base="#C01828")
    black = skin_material("NoseBlack", "#1A1418", rough=0.2)
    eye = glow_material("FoxEye", "#C8203A", strength=1.2, base="#801020")
    body = fox_body(skin)
    with_fur(body, fur_m, density=60000, length=(0.03, 0.07), radius=0.0011, comb=(0.6, 0, -0.8), lift=0.25,
             gravity=0.006, jitter=0.35, seed=31, resolution=5)
    fox_face((skin, pink, red, black, eye), fur_m)
    tails(tail_m, skin)
    # Cành hoa nhỏ dưới chân? (phông lo) — không dựng ở đây.


def fox_lights(scene):
    add_sun(scene, "Key", (0.3, 0.7, -0.6), 3.4, "#FFF0F4", angle=4)
    add_sun(scene, "Rim", (-0.8, -0.2, -0.3), 3.2, "#C8B8FF", angle=6)
    add_sun(scene, "Fill", (0.2, 0.9, 0.3), 0.8, "#FFD8E4", angle=25)


# ---------------------------------------------------------------- dạng người

H = 1.1  # cao hơn người thường một chút (dáng thần tiên)


def flower(name, at, normal, r, petal, center, n=5):
    """Hoa trà / hoa mận: [n] cánh tròn quanh nhuỵ vàng, quay mặt theo [normal]."""
    nrm = normal.normalized()
    a = nrm.orthogonal().normalized()
    b = nrm.cross(a)
    out = []
    for k in range(n):
        ang = 2 * math.pi * k / n
        d = a * math.cos(ang) + b * math.sin(ang)
        c = at + d * r * 0.55 + nrm * r * 0.1
        rot = Matrix((d, nrm.cross(d), nrm)).transposed()
        mesh = raw_ellipsoid(f"{name}P{k}", Vector(), (r * 0.55, r * 0.45, r * 0.12))
        for v in mesh.vertices:
            v.co = rot @ v.co + c
        out.append(add_object(f"{name}P{k}", mesh, [petal]))
    out.append(add_object(f"{name}C", raw_ellipsoid(f"{name}C", at + nrm * r * 0.18, (r * 0.22,) * 3), [center]))
    return out


def chain(name, pts, r, mat, step=None):
    """Chuỗi hạt vàng nhỏ dọc đường [pts]."""
    out = []
    acc = []
    for a, b in zip(pts, pts[1:]):
        L = (b - a).length
        n = max(1, int(L / (step or r * 2.2)))
        acc += [a.lerp(b, i / n) for i in range(n)]
    acc.append(pts[-1])
    for i, p in enumerate(acc):
        out.append(add_object(f"{name}{i}", raw_ellipsoid(f"{name}{i}", p, (r, r, r)), [mat]))
    return out


def ghost_material(name, hex_, transparency):
    """Bề mặt mờ ảo: trộn trong suốt [transparency] với phát sáng nhẹ."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    from boss_kit import srgb
    em.inputs["Color"].default_value = srgb(hex_)
    em.inputs["Strength"].default_value = 0.8
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = transparency
    nt.links.new(em.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def ghost_fur(name):
    """Lông đuôi ma: lông trắng ánh tím, trong suốt một nửa."""
    mat = fur_material(name, TAIL_STOPS, sheen=0.1)
    nt = mat.node_tree
    out = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
    src = out.inputs["Surface"].links[0].from_socket
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = 0.5
    nt.links.new(src, mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def ghost_tails(base, back, mat):
    """Bóng chín đuôi mờ sau lưng mỹ nhân (lộ dần khi bị vạch mặt)."""
    rng = random.Random(4)
    out = []
    for k in range(9):
        a = math.radians(-70 + 140 * k / 8)
        side = Vector((0, 0, 1)) * math.cos(a) + back.cross(Vector((0, 0, 1))).normalized() * math.sin(a)
        L = rng.uniform(0.9, 1.2) * H
        p0 = base
        p1 = base + back * 0.2 + side * 0.2
        p2 = base + back * 0.35 + side * 0.75 * L
        p3 = p2 + side * 0.3 + Vector((0, 0, 0.1))
        pts = bezier_pts(p0, p1, p2, p3, 14)
        n = len(pts)
        radii = [((0.04 + 0.1 * math.sin(math.pi * min(1, t * 1.15)) ** 0.7) * (1 - t ** 4) + 0.002,) * 2
                 for t in [i / (n - 1) for i in range(n)]]
        o = add_object(f"Ghost{k}", raw_tube(f"Ghost{k}", pts, [(r[0] * 0.6, r[1] * 0.6) for r in radii], sides=16),
                       [mat[0]])
        out.append(o)
        out.append(with_fur(o, mat[1], density=14000, length=(0.06, 0.12), radius=0.0014,
                            comb=tuple((p3 - p0).normalized()), lift=0.25, gravity=0.008, jitter=0.45, seed=70 + k,
                            resolution=6))
    return out


def build_human():
    from hair_kit import hair_material, ribbon_locks, strand_locks
    from human_kit import group_center, rest_coords, shell_copy, store_point_attr, weights_by_group
    from japan_kit import StandPoser, beads, body_ring, boss_human, bone_point, ellipse_ring, flame_material, \
        garment, hakama, head_frame, limb_band, painted_skin, silk_material

    body, rig, parts = boss_human(0.0, muscle=0.35, weight=0.35, height=0.75, age=0.4, proportions=1.0, scale=H,
                                  details={"eyebrows-angle-up": 0.4, "chin-prominent-decr": 0.3}
                                  if False else None, eyebrows=None)
    skin = painted_skin("PorcelainSkin", "#F4DCCA", "#E4C0AC", sss=0.35, rough=0.5, lips="#B8142A")
    body.data.materials.clear()
    body.data.materials.append(skin)
    co = rest_coords(body)
    w = weights_by_group(body)
    store_point_attr(body, "lips", [min(1.0, w[i].get("lips", 0)) for i in range(len(co))])
    bl = rig.data.bones
    head_c, up, fwd, right = head_frame(rig)
    gold = gold_material("CourtGold", "#E4B65A", rough=0.22)
    ruby = glow_material("Ruby", "#E0203A", strength=0.4, base="#A01020")
    sapphire = glow_material("Sapphire", "#4A6AE0", strength=0.3, base="#22389A")
    camellia = skin_material("Camellia", "#C4182A", rough=0.45)
    stamen = gold_material("Stamen", "#F2CC50", rough=0.4)
    hair_dark = skin_material("HairMassDark", "#1E1410", rough=0.45)
    hair_m = hair_material("CourtHair", "#3A2418", "#1E1410", "#4A3020", rough=0.3)

    # ---- tóc: khối ôm da đầu chải ngược lên búi cao + sợi; hai lọn mái rủ
    mass = shell_copy(body, "HairMass", "scalp", 0.008 * H, 0.0, [hair_dark])
    mass.add_rest_position_attribute = True
    from boss_kit import with_fur
    with_fur(mass, hair_m, density=60000, length=(0.02 * H, 0.035 * H), radius=0.0008 * H,
             comb=tuple(up * 0.8 - fwd * 0.4), lift=0.05, gravity=0.0, jitter=0.12, seed=3, resolution=5)
    top = head_c + up * 0.11 * H - fwd * 0.03 * H
    buns = []
    for s in (-1, 1):  # búi hai vòng (kiểu tóc cung đình)
        c = top + right * s * 0.055 * H + up * 0.04 * H
        buns.append(add_object(f"Bun{s}", raw_ellipsoid(f"Bun{s}", c, (0.065 * H, 0.05 * H, 0.06 * H)), [hair_dark]))
    buns.append(add_object("BunCore", raw_ellipsoid("BunCore", top + up * 0.02 * H, (0.05 * H,) * 3), [hair_dark]))
    for o in buns:
        parent_to_bone(o, rig, "head")
        with_fur(o, hair_m, density=150000, length=(0.012 * H, 0.02 * H), radius=0.0007 * H,
                 comb=tuple(right), lift=0.02, gravity=0.0, jitter=0.15, seed=hash(o.name) % 97, resolution=4)
    rng = random.Random(7)
    guides = []
    for k in range(70):
        az = rng.uniform(-math.pi, math.pi)
        el = rng.uniform(-0.1, 1.1)
        d = (-fwd * math.cos(az) + right * math.sin(az)) * math.cos(el) + up * math.sin(el)
        root = head_c + d * 0.1 * H
        tip = top + (root - top).normalized() * 0.02 * H
        mid = root.lerp(tip, 0.5) + d * 0.02 * H
        guides.append([root.lerp(mid, t * 2) if t < 0.5 else mid.lerp(tip, (t - 0.5) * 2) for t in [i / 7 for i in range(8)]])
    # Lọn tóc dài xoã sau gáy + hai lọn mái rủ trước tai.
    for k in range(30):
        root = top + Vector((rng.uniform(-0.04, 0.04), rng.uniform(-0.02, 0.04), 0)) * H - fwd * 0.04 * H
        tip = root - fwd * rng.uniform(0.15, 0.3) * H - up * rng.uniform(0.5, 0.8) * H + right * rng.uniform(-0.15, 0.15) * H
        mid = root - fwd * 0.12 * H + up * 0.02 * H
        guides.append(bezier_pts(root, mid, root.lerp(tip, 0.6) - fwd * 0.05 * H, tip, 10))
    for s in (-1, 1):
        root = head_c + up * 0.06 * H + fwd * 0.07 * H + right * s * 0.065 * H
        for j in range(3):
            o = right * s * 0.006 * j * H
            guides.append(bezier_pts(root + o, root + o + right * s * 0.03 * H - up * 0.08 * H,
                                     root + o + right * s * 0.02 * H - up * 0.2 * H + fwd * 0.03 * H,
                                     root + o + right * s * 0.04 * H - up * 0.36 * H + fwd * 0.02 * H, 10))
    so = strand_locks("HairStrands", guides, hair_m, per_lock=40, spread=0.012 * H, clump=0.55, frizz=0.002 * H,
                      root_radius=0.0009 * H, seed=4)
    parent_to_bone(so, rig, "head")
    # Mày mảnh cong lá liễu, đuôi xếch lên thái dương (nét hồ ly).
    for g, s in (("helper-l-eye", 1), ("helper-r-eye", -1)):
        c = group_center(body, g, co)
        side = -right if s > 0 else right
        a = c + up * 0.017 * H + fwd * 0.024 * H - side * 0.012 * H
        b = c + up * 0.03 * H + fwd * 0.024 * H + side * 0.006 * H
        e = c + up * 0.027 * H + fwd * 0.012 * H + side * 0.026 * H
        o = add_object(f"Brow{s}", tapered_world(f"Brow{s}", [(a, b, e, 0.0032 * H)], flat=2.6, taper=0.7),
                       [hair_dark])
        parent_to_bone(o, rig, "head")

    # ---- trang sức tóc: trâm vàng có tua, hoa trà đỏ, mũ hoa vàng đá đỏ
    jew = []
    for k, (s, tilt) in enumerate(((-1, 0.4), (1, -0.3), (1, 0.6), (-1, -0.5))):
        b0 = top + right * s * 0.06 * H + up * 0.05 * H
        d = (right * s * 0.8 + up * tilt - fwd * 0.3).normalized()
        jew.append(add_object(f"Pin{k}", raw_tube(f"Pin{k}", [b0 - d * 0.05 * H, b0 + d * 0.14 * H],
                                                  [(0.004 * H,) * 2, (0.003 * H,) * 2], sides=8), [gold]))
        tipp = b0 + d * 0.14 * H
        jew.append(add_object(f"PinHead{k}", raw_ellipsoid(f"PinHead{k}", tipp, (0.012 * H,) * 3), [ruby]))
        for j in range(4):  # tua vàng rủ (bira-bira)
            jew += chain(f"PinChain{k}_{j}", [tipp + right * s * 0.006 * j * H,
                                              tipp + right * s * 0.006 * j * H - up * (0.06 + 0.015 * j) * H],
                         0.0035 * H, gold)
    for k, (s, dz, dx) in enumerate(((1, 0.02, 0.09), (1, -0.03, 0.1), (-1, 0.0, 0.1))):
        at = top + right * s * dx * H + up * dz * H + fwd * 0.02 * H
        jew += flower(f"Camellia{k}", at, (right * s + fwd * 0.5).normalized(), 0.035 * H, camellia, stamen, n=6)
    # Mũ hoa vàng ôm chân tóc trán, mặt giữa đính hồng ngọc, gai vàng toả.
    crown_c = head_c + up * 0.085 * H + fwd * 0.03 * H
    arc = [crown_c + (right * math.cos(math.pi * (0.15 + 0.7 * t)) * 0.095 + fwd * math.sin(math.pi * (0.15 + 0.7 * t))
                      * 0.1) * H for t in [i / 24 for i in range(25)]]
    jew.append(add_object("Tiara", raw_tube("Tiara", arc, [(0.004 * H, 0.009 * H)] * 25, sides=8), [gold]))
    front = crown_c + fwd * 0.1 * H
    for k in range(7):
        a = math.radians(-50 + 100 * k / 6)
        dd = (up * math.cos(a) + right * math.sin(a)).normalized()
        jew.append(add_object(f"TiaraSpike{k}", tapered_world(f"TiaraSpike{k}", [
            (front, front + dd * 0.025 * H + fwd * 0.004 * H, front + dd * (0.05 - 0.012 * abs(k - 3) / 3) * H, 0.006 * H)],
            flat=2.4, taper=1.0), [gold]))
    jew.append(add_object("TiaraGem", raw_ellipsoid("TiaraGem", front + fwd * 0.006 * H, (0.012 * H, 0.01 * H, 0.015 * H)),
                          [ruby]))
    # Hoa điểm đỏ giữa trán.
    brow = head_c + up * 0.05 * H + fwd * 0.112 * H
    jew += flower("Hanadi", brow, fwd, 0.012 * H, camellia, camellia, n=4)
    # Mạng che mặt: các vòng chuỗi vàng từ gò má vòng dưới mũi, tua rủ.
    for row in range(2):
        pts = []
        for i in range(17):
            t = i / 16
            a = math.pi * (0.1 + 0.8 * t)
            pts.append(head_c + (right * math.cos(a) * 0.072 + fwd * (0.075 + 0.045 * math.sin(a))) * H
                       - up * (0.035 + 0.02 * row + 0.012 * math.sin(a) ** 2) * H)
        jew += chain(f"Veil{row}_", pts, 0.0028 * H, gold)
    for i in range(5):
        a = math.pi * (0.3 + 0.4 * i / 4)
        p = head_c + (right * math.cos(a) * 0.072 + fwd * (0.075 + 0.045 * math.sin(a))) * H - up * (0.055 + 0.012 * math.sin(a) ** 2) * H
        jew += chain(f"VeilDrop{i}_", [p, p - up * (0.02 + 0.012 * (i % 3)) * H], 0.0028 * H, gold)
    # Hoa tai dài.
    for s in (-1, 1):
        ear = head_c + right * s * 0.075 * H - up * 0.015 * H
        jew += chain(f"Earring{s}_", [ear, ear - up * 0.06 * H], 0.003 * H, gold)
        jew.append(add_object(f"EarGem{s}", raw_ellipsoid(f"EarGem{s}", ear - up * 0.075 * H, (0.008 * H, 0.008 * H,
                                                                                               0.013 * H)), [ruby]))
    for o in jew:
        parent_to_bone(o, rig, "head")

    # ---- áo: yếm chàm viền vàng, váy trắng ngà, dải lụa đỏ
    bodice = silk_material("Bodice", "#2C3A86", pattern="#3A4CA0", sheen=0.6)
    torso = ("pelvis", "spine_01", "spine_02", "spine_03")
    chest_top = bl["spine_03"].tail_local.z - 0.02
    waist = bl["pelvis"].head_local.z
    hem_attr = [max(0.0, p.z - (waist - 0.02)) for p in co]
    garment(body, rig, co, "Bodice", torso, bodice, 0.008 * H, z_min=waist - 0.04, z_max=chest_top,
            extra=lambda i, p, g: g.get("upperarm_l", 0) + g.get("upperarm_r", 0) < 0.3)
    skirt = silk_material("Skirt", "#F2ECE2", pattern="#E6DCCE", trim="#D8AE58", sheen=0.7)
    hakama(body, co, rig, "Skirt", skirt, flare=0.16 * H)
    c, rx, ry = body_ring(body, co, waist + 0.02, ("pelvis", "spine_01"), pad=0.03)
    sash = silk_material("Sash", "#3A62C8", sheen=0.7)
    o = add_object("Sash", raw_tube("Sash", ellipse_ring(c, rx, ry, n=48), [(0.015 * H, 0.045 * H)] * 48, sides=10,
                                    closed=True), [sash])
    parent_to_bone(o, rig, "pelvis")
    # Vòng cổ vàng + mặt đá lam, trang sức vai, vòng tay.
    nb = bone_point(rig, "neck_01", 0.1)
    beads("Choker", nb + fwd * 0.012 * H, 0.06 * H, 0.055 * H, 0.03 * H, 30, 0.006 * H, gold, rig, "neck_01",
          big={22: (0.014 * H, sapphire)})
    for s, side in (("l", 1), ("r", -1)):
        sh = bone_point(rig, f"upperarm_{s}", 0.12)
        disk = add_object(f"ShoulderDisk{s}", raw_ellipsoid(f"ShoulderDisk{s}", sh + Vector((side * 0.04, 0, 0.03)) * H,
                                                            (0.05 * H, 0.05 * H, 0.015 * H)), [gold])
        gem = add_object(f"ShoulderGem{s}", raw_ellipsoid(f"ShoulderGem{s}", sh + Vector((side * 0.045, -0.02, 0.045)) * H,
                                                          (0.014 * H,) * 3), [sapphire])
        for x in (disk, gem):
            parent_to_bone(x, rig, f"upperarm_{s}")
        limb_band(rig, f"upperarm_{s}", 0.5, 0.58, 0.042 * H, 0.04 * H, gold, f"Armlet{s}")
        limb_band(rig, f"lowerarm_{s}", 0.86, 0.94, 0.03 * H, 0.03 * H, gold, f"Bangle{s}")
    ghost = (ghost_material("GhostCore", "#F4EEFF", 0.85), ghost_fur("GhostFur"))
    return body, rig, {"gold": gold, "ruby": ruby, "ghost": ghost, "ribbon": silk_material("Ribbon", "#C81E2E",
                                                                                              sheen=0.7)}


def human_pose(rig, mats):
    from japan_kit import StandPoser
    poser = StandPoser(rig, facing_deg=-35, scale=H)
    poser.place(stance=math.radians(6), crouch=math.radians(4))
    fwd, left, up = poser.frame()
    right = -left
    reach = poser.a + poser.b
    sh_r = poser.world("upperarm_r", 0.0)
    # Tay phải nâng chén rượu ngang vai, ra phía trước.
    poser.arm("r", sh_r + fwd * reach * 0.6 + right * reach * 0.2 + up * reach * 0.05, sh_r + right * 0.5 - up * 0.5)
    sh_l = poser.world("upperarm_l", 0.0)
    poser.arm("l", sh_l + left * reach * 0.45 + fwd * reach * 0.35 - up * reach * 0.55, sh_l + left * 0.5 - up * 0.2)
    gold = mats["gold"]
    cup = poser.world("hand_r", 0.9) + up * 0.04 * H
    add_object("CupBowl", raw_tube("CupBowl", [cup, cup + up * 0.02 * H, cup + up * 0.05 * H],
                                   [(0.02 * H,) * 2, (0.045 * H,) * 2, (0.055 * H,) * 2], sides=24), [gold])
    add_object("CupStem", raw_tube("CupStem", [cup - up * 0.05 * H, cup], [(0.022 * H,) * 2, (0.008 * H,) * 2],
                                   sides=12), [gold])
    add_object("Wine", raw_ellipsoid("Wine", cup + up * 0.045 * H, (0.05 * H, 0.05 * H, 0.004 * H)),
               [glow_material("Sake", "#FFE08A", strength=1.5, base="#E8B840")])
    # Dải lụa đỏ (hagoromo) vắt qua hai khuỷu, bay lượn sau lưng.
    el_r = poser.world("lowerarm_r", 0.0)
    el_l = poser.world("lowerarm_l", 0.0)
    back = -fwd
    ribbon_pts = bezier_pts(el_r + right * 0.25 * H - up * 0.3 * H, el_r + back * 0.5 * H + up * 0.2 * H,
                            el_l + back * 0.6 * H + up * 0.3 * H, el_l + left * 0.35 * H - up * 0.5 * H, 30)
    add_object("Hagoromo", raw_tube("Hagoromo", ribbon_pts, [(0.003 * H, 0.035 * H)] * 30, sides=8), [mats["ribbon"]])
    base = poser.world("pelvis", 0.0) - fwd * 0.12 * H
    ghost_tails(base, back, mats["ghost"])
    return poser


# ---------------------------------------------------------------- main


def main():
    scene = reset_scene(samples=96, world_hex="#C9C4C0", world_strength=0.7, keep_prefs=True)
    out = os.path.join(ROOT, "build", "blender", "tamamo")
    os.makedirs(out, exist_ok=True)
    if FORM == "fox":
        build_fox()
        fox_lights(scene)
        shadow_catcher()
        # Nhìn ¾: cáo quay về −X (người chơi), máy quay chếch.
        camera(scene, 0.1, 1.0, 3.0, 2.4, 260, yaw=-30, pitch=8)
        render_to(scene, os.path.join(out, "fox_full.png"))
        camera(scene, -0.32, 1.2, 0.55, 0.55, 900, yaw=-30, pitch=4)
        render_to(scene, os.path.join(out, "fox_face.png"))
        from boss_kit import save_blend
        save_blend("tamamo_fox")
        return
    body, rig, mats = build_human()
    human_pose(rig, mats)
    fox_lights(scene)
    shadow_catcher()
    camera(scene, 0.15, 1.05 * H, 2.9 * H, 2.4 * H, 260, yaw=-8, pitch=6)
    render_to(scene, os.path.join(out, "human_full.png"))
    pb = rig.pose.bones["head"]
    head = rig.matrix_world @ pb.head.lerp(pb.tail, 0.5)
    camera(scene, head.x - 0.03, head.z + 0.04, 0.5 * H, 0.5 * H, 1000, yaw=-8, pitch=4)
    render_to(scene, os.path.join(out, "human_face.png"))
    from boss_kit import save_blend
    save_blend("tamamo_human")


main()
