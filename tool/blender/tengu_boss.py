# blender: user-prefs  (cần tiện ích MPFB + gói tài nguyên hệ thống — xem rules/dohoa.md mục 10)
"""Thiên hoàng Sutoku hoá đại tengu (Kỳ công Heian). Theo tranh tham khảo
người dùng chọn (tengu ukiyo-e trên cành thông) và tranh Kuniyoshi / vở Nō
Matsuyama Tengu: mặt đỏ mũi dài, mắt trợn, mày đen rậm hất ngược, ria rủ,
tóc đen dài tung theo gió, mũ tokin đen nhỏ trên trán; đôi cánh đại bàng nâu;
kimono xanh lá in hoa tròn vàng, cổ áo xanh nhạt, tay áo rộng, đai obi; quần
hakama xanh lam in hoa tròn; quạt lông vũ (hauchiwa) tay phải; chân trần đỏ
móng vuốt chim.

    bash tool/blender/render.sh tengu_boss --still     # ảnh duyệt
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
from bird_kit import Wing, feather_material  # noqa: E402
from boss_kit import ROOT, add_object, add_sun, gold_material, parent_to_bone, render_to, reset_scene, \
    skin_material  # noqa: E402
from hair_kit import hair_material, ribbon_locks, strand_locks  # noqa: E402
from human_kit import camera, group_center, raw_ellipsoid, raw_tube, rest_coords, shadow_catcher, \
    tapered_world, weights_by_group  # noqa: E402
from japan_kit import StandPoser, body_ring, boss_human, bone_point, claws, ellipse_ring, feather_fan, garment, \
    hakama, head_frame, kamon_material, painted_skin, sleeve_bag  # noqa: E402

S = 1.15

TENGU_BODY = {
    "measure-shoulder-dist-incr": 0.6,
    "torso-vshape-incr": 0.5,
    "neck-scale-horiz-incr": 0.4,
    "chin-prominent-incr": 0.6,
    "chin-width-incr": 0.4,
    "eyebrows-trans-down": 0.15,
    "eyebrows-angle-down": 1.0,
    "mouth-angles-down": 1.0,
    "head-square": 0.5,
}


def flat_band(name, pts, outs, width, thick):
    """Dải vải dẹt dọc [pts]: rộng [width] theo mặt thân, dày [thick] theo
    hướng ra ngoài [outs] — không xoắn như ống dẹt khi đi gần thẳng đứng."""
    verts, faces = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        tan = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        o = outs[i] - tan * outs[i].dot(tan)
        o.normalize()
        w = o.cross(tan).normalized()
        for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            verts.append(p + w * a * width + o * b * thick)
    for i in range(n - 1):
        for k in range(4):
            k2 = (k + 1) % 4
            faces.append((i * 4 + k, i * 4 + k2, (i + 1) * 4 + k2, (i + 1) * 4 + k))
    faces += [(3, 2, 1, 0), tuple((n - 1) * 4 + k for k in range(4))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    return mesh


def nose(body, co, rig, up, fwd, mat):
    """Mũi dài đỏ đặc trưng của tengu: mọc từ sống mũi, thẳng ra trước, hơi
    vểnh lên ở chóp tròn."""
    w = weights_by_group(body)
    head_pts = [(i, p) for i, p in enumerate(co) if w[i].get("head", 0) > 0.8 and w[i].get("HelperGeometry", 0) < 0.5]
    zs = sorted(p.z for _, p in head_pts)
    zmid = zs[int(len(zs) * 0.45)]
    # Chóp mũi thật = đỉnh xa nhất phía trước (−y) quanh giữa mặt.
    cand = [p for _, p in head_pts if abs(p.z - zmid) < 0.04]
    tip0 = body.matrix_world @ min(cand, key=lambda p: p.y)
    base = tip0 - fwd * 0.012 * S + up * 0.012 * S
    pts = [base + fwd * t * 0.17 * S + up * (0.02 * S * t * t) for t in (0.0, 0.25, 0.5, 0.75, 0.92, 1.0)]
    radii = [(0.022 * S,) * 2, (0.019 * S,) * 2, (0.017 * S,) * 2, (0.016 * S,) * 2, (0.015 * S,) * 2,
             (0.004 * S,) * 2]
    o = add_object("Nose", raw_tube("Nose", pts, radii, sides=18), [mat])
    tipc = pts[-2]
    o2 = add_object("NoseTip", raw_ellipsoid("NoseTip", tipc, (0.017 * S, 0.017 * S, 0.016 * S)), [mat])
    for x in (o, o2):
        parent_to_bone(x, rig, "head")
    return tip0


def face_hair(body, co, rig, up, fwd, right, ink):
    """Mày đen rậm hất ngược lên thái dương, ria mép rủ hai bên, chòm râu cằm."""
    out = []
    for g, s in (("helper-l-eye", 1), ("helper-r-eye", -1)):
        c = group_center(body, g, co)
        side = -right if s > 0 else right
        locks = []
        for k in range(8):
            t = k / 7
            a = c + up * (0.02 + 0.004 * t) * S + fwd * 0.012 * S + side * (0.002 + 0.03 * t) * S
            tip = a + side * 0.035 * S + up * (0.035 - 0.012 * t) * S - fwd * 0.012 * S
            locks.append((a, a.lerp(tip, 0.5) + up * 0.01 * S, tip, 0.008 * S))
        o = ribbon_locks(f"Brow{s}", locks, ink, flat=1.8, taper=1.0)
        parent_to_bone(o, rig, "head")
        out.append(o)
    w = weights_by_group(body)
    lips = [co[i] for i in range(len(co)) if w[i].get("lips", 0) > 0.5]
    m = body.matrix_world @ (sum(lips, Vector()) / len(lips))
    stache = []
    for s in (-1, 1):
        for k in range(5):
            a = m + up * 0.016 * S + fwd * 0.012 * S + right * s * (0.004 + 0.004 * k) * S
            tip = a + right * s * 0.05 * S - up * (0.05 + 0.006 * k) * S + fwd * 0.004 * S
            stache.append((a, a + right * s * 0.03 * S - up * 0.005 * S, tip, 0.006 * S))
    for k in range(5):
        a = m - up * 0.035 * S + fwd * 0.01 * S + right * (k - 2) * 0.006 * S
        stache.append((a, a - up * 0.03 * S + fwd * 0.01 * S, a - up * 0.06 * S + fwd * 0.006 * S, 0.006 * S))
    o = ribbon_locks("Stache", stache, ink, flat=1.6, taper=1.0)
    parent_to_bone(o, rig, "head")
    out.append(o)
    return out


def wild_hair(rig, head_c, up, fwd, right):
    """Tóc đen dài rối tung ra sau theo gió (từng lọn)."""
    rng = random.Random(11)
    ink_lock = skin_material("HairLock", "#141010", rough=0.5)
    strands = hair_material("TenguHair", "#2A2420", "#121010", "#3A3632", rough=0.35)
    locks, guides = [], []
    R = 0.105 * S
    back = -fwd
    for k in range(120):
        az = rng.uniform(-math.pi * 0.9, math.pi * 0.9)
        el = rng.uniform(-0.3, 1.2)
        d = (back * math.cos(az) + right * math.sin(az)) * math.cos(el) + up * math.sin(el)
        if d.dot(fwd) > (0.6 if el > 0.5 else 0.25):
            continue
        root = head_c + d * R
        length = rng.uniform(0.28, 0.6) * S
        tip = root + (back * 0.85 + d * 0.3 + up * rng.uniform(-0.45, 0.35)).normalized() * length
        mid = root.lerp(tip, 0.45) + up * rng.uniform(0.0, 0.08) * S + d * 0.04 * S
        locks.append((root, mid, tip, rng.uniform(0.008, 0.014) * S))
        guides.append([root.lerp(mid, t * 2) if t < 0.5 else mid.lerp(tip, (t - 0.5) * 2)
                       for t in [i / 7 for i in range(8)]])
    ro = ribbon_locks("HairLocks", locks, ink_lock, flat=1.8, taper=1.2)
    so = strand_locks("HairStrands", guides, strands, per_lock=45, spread=0.025 * S, clump=0.4, frizz=0.008 * S,
                      root_radius=0.0012 * S, seed=5)
    for o in (ro, so):
        parent_to_bone(o, rig, "head")


def tokin(rig, head_c, up, fwd, right, black):
    """Mũ tokin: hộp tròn nhỏ có nếp xếp trên trán, dây đen buộc cằm."""
    at = head_c + up * 0.1 * S + fwd * 0.055 * S
    out = [add_object("Tokin", raw_ellipsoid("Tokin", at, (0.034 * S, 0.03 * S, 0.026 * S)), [black])]
    pleats = []
    for k in range(12):
        a = 2 * math.pi * k / 12
        p0 = at + (right * math.cos(a) + fwd * math.sin(a)) * 0.03 * S - up * 0.012 * S
        pleats.append((p0, p0 + up * 0.02 * S, p0 + up * 0.034 * S + (at - p0) * 0.6, 0.006 * S))
    out.append(add_object("TokinPleats", tapered_world("TokinPleats", pleats, taper=0.6), [black]))
    for o in out:
        parent_to_bone(o, rig, "head")


def wings(rig, mat, arm_mat):
    """Đôi cánh đại bàng mọc từ bả vai, xoè lên và ra hai bên."""
    out = []
    for side, far in (("l", False), ("r", True)):
        sx = 1 if side == "l" else -1  # bên trái nhân vật là +X lúc nghỉ
        root = bone_point(rig, "spine_03", 0.6) + Vector((sx * 0.07 * S, 0.11 * S, 0.0))
        X = Vector((0, 0.45, -1)).normalized()  # lông chĩa xuống, hơi ra sau
        span = Vector((sx * 0.75, -0.15, 0.95)).normalized()  # xoè chữ V lên trên, thấy cả hai cánh khi đứng ¾
        Y = span if far else -span
        Y = (Y - X * Y.dot(X)).normalized()
        Z = X.cross(Y)
        mount = bpy.data.objects.new(f"WingMount{side}", None)
        bpy.context.scene.collection.objects.link(mount)
        mount.matrix_world = Matrix.Translation(root) @ Matrix((X, Y, Z)).transposed().to_4x4()
        w = Wing(f"Wing{side}", (0, 0, 0), mat, arm_mat, far=far, span=(0.3 * S, 0.42 * S, 0.32 * S),
                 scale=1.5 * S, seed=3 if far else 4, primaries=11, secondaries=13)
        w.joints[0].parent = mount
        w.joints[0].location = (0, 0, 0)
        w.pose(math.radians(10), fold=0.15)
        parent_to_bone(mount, rig, "spine_03")
        out.append(w)
    return out


def build():
    body, rig, parts = boss_human(1.0, muscle=0.7, weight=0.45, height=0.8, age=0.75, proportions=0.8, scale=S,
                                  details=TENGU_BODY, eyebrows=None)
    skin = painted_skin("TenguSkin", "#C8483A", "#A0362C", sss=0.15, rough=0.65)
    body.data.materials.clear()
    body.data.materials.append(skin)
    co = rest_coords(body)
    bl = rig.data.bones
    head_c, up, fwd, right = head_frame(rig)
    ink = skin_material("Ink", "#121010", rough=0.5)
    black = skin_material("Lacquer", "#0C0A0C", rough=0.25)
    gold = gold_material("TenguGold", "#D8A848", rough=0.3)
    claw_m = skin_material("Talon", "#1A1614", rough=0.25)

    nose(body, co, rig, up, fwd, skin)
    face_hair(body, co, rig, up, fwd, right, ink)
    wild_hair(rig, head_c, up, fwd, right)
    tokin(rig, head_c, up, fwd, right, black)

    # ---- kimono xanh lá hoa tròn vàng, tay áo rộng
    robe = kamon_material("Kimono", "#2E6A3C", "#C9A64A", scale=13, size=1.6)
    lining = kamon_material("Lining", "#7EAED0", "#9CC4E0", scale=14)
    torso = ("pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "neck_01",
             "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r")
    waist = bl["pelvis"].head_local.z
    neck_top = bl["neck_01"].head_local.z + 0.03
    garment(body, rig, co, "Kimono", torso, robe, 0.02 * S, z_min=waist - 0.08, z_max=neck_top,
            extra=lambda i, p, g: g.get("hand_l", 0) + g.get("hand_r", 0) < 0.3,
            flare=(0.05 * S, lambda p, g: (g.get("lowerarm_l", 0) + g.get("lowerarm_r", 0)) * 0.8))
    for s in ("l", "r"):
        sleeve_bag(rig, s, robe, length=0.3 * S, width=0.26 * S)
    # Cổ áo chữ V xanh nhạt: hai vạt chéo từ gáy xuống đai.
    # Mỗi vạt bám mặt ngoài áo theo từng tầng cao (trước đây đường cong Bézier
    # cắt xuyên ngực nên chìm trong áo).
    nb = bone_point(rig, "neck_01", 0.2)
    z_top, z_bot = bl["neck_01"].head_local.z - 0.02, waist + 0.12
    for s in (-1, 1):
        rail, outs = [nb - fwd * 0.04 * S + right * s * 0.065 * S + up * 0.02 * S], [-fwd + right * s]
        for k in range(15):
            u = k / 14
            z = z_top + (z_bot - z_top) * u
            c, rx, ry = body_ring(body, co, z, ("spine_01", "spine_02", "spine_03", "neck_01"), pad=0.04 * S)
            dx = (0.07 * (1 - u) ** 1.3 + 0.012) * S  # hai vạt khép dần, gặp nhau ở đai (chữ V)
            p = c + right * s * dx + fwd * ry * math.sqrt(max(0.0, 1 - (dx / rx) ** 2))
            rail.append(p)
            outs.append(Vector((p.x - c.x, p.y - c.y, 0.0)))
        for _ in range(2):  # làm mượt đường vạt
            rail = [rail[0]] + [(rail[i - 1] + rail[i] * 2 + rail[i + 1]) / 4 for i in range(1, len(rail) - 1)] \
                + [rail[-1]]
        co_o = add_object(f"Collar{s}", flat_band(f"Collar{s}", rail, outs, 0.03 * S, 0.008 * S), [lining])
        parent_to_bone(co_o, rig, "spine_03")
    # Đai obi xanh nhạt + dây buộc.
    from japan_kit import twisted_rope
    c2, rx2, ry2 = body_ring(body, co, waist + 0.04, ("pelvis", "spine_01"), pad=0.045)
    obi = add_object("Obi", raw_tube("Obi", ellipse_ring(c2, rx2, ry2, n=48), [(0.02 * S, 0.05 * S)] * 48,
                                     sides=10, closed=True), [lining])
    parent_to_bone(obi, rig, "pelvis")
    for o in twisted_rope("ObiCord", ellipse_ring(c2 + Vector((0, 0, -0.01 * S)), rx2 + 0.012, ry2 + 0.012, n=48),
                          0.008 * S, gold, twists=30):
        parent_to_bone(o, rig, "pelvis")

    # ---- hakama xanh lam hoa tròn vàng
    pants = kamon_material("TenguHakama", "#2B4886", "#C9A64A", scale=10, trim="#162850", size=1.5)
    hakama(body, co, rig, "Hakama", pants, flare=0.1 * S)

    # ---- móng vuốt chim
    for s in ("l", "r"):
        claws(rig, s, claw_m, length=0.028 * S, radius=0.006 * S)
        claws(rig, s, claw_m, length=0.06 * S, radius=0.01 * S, toes=True)

    feather = feather_material("Eagle", "#2E2012", "#9A7448", sheen="#C89A60", metallic=0.1, rough=0.5)
    arm_mat = skin_material("WingArm", "#3A2818", rough=0.7)
    wings(rig, feather, arm_mat)
    fan_f = feather_material("FanFeather", "#5A3A18", "#C8A060", sheen="#E8C880", metallic=0.15, rough=0.5)
    return body, rig, {"fan": (fan_f, black, gold)}


def pose(rig, mats):
    poser = StandPoser(rig, facing_deg=-45, scale=S)
    poser.place(stance=math.radians(16), crouch=math.radians(22))
    fwd, left, up = poser.frame()
    right = -left
    reach = poser.a + poser.b
    sh_r = poser.world("upperarm_r", 0.0)
    grip = sh_r + fwd * reach * 0.62 + right * reach * 0.05 - up * reach * 0.42
    poser.arm("r", grip, sh_r + right * 0.5 - up * 0.5)
    sh_l = poser.world("upperarm_l", 0.0)
    poser.arm("l", sh_l + left * reach * 0.3 + fwd * reach * 0.45 - up * reach * 0.62, sh_l + left * 0.5 - up * 0.3)
    hand = poser.world("hand_r", 0.8)
    feather_fan("Fan", hand, (up * 0.9 + left * 0.25 - fwd * 0.1).normalized(), (fwd - left * 0.4).normalized(),
                mats["fan"], scale=S)
    return poser


def lights(scene):
    add_sun(scene, "Key", (0.35, 0.75, -0.55), 3.6, "#FFF0D8", angle=3)
    add_sun(scene, "Rim", (-0.75, -0.3, -0.25), 3.0, "#A8C8FF", angle=4)
    add_sun(scene, "Fill", (0.2, 0.9, 0.2), 0.5, "#D8E8FF", angle=20)


def main():
    scene = reset_scene(samples=96, world_hex="#C9C4C0", world_strength=0.7, keep_prefs=True)
    body, rig, mats = build()
    pose(rig, mats)
    lights(scene)
    shadow_catcher()
    out = os.path.join(ROOT, "build", "blender", "tengu")
    os.makedirs(out, exist_ok=True)
    camera(scene, 0.0, 1.15 * S, 3.0 * S, 2.7 * S, 240, yaw=-8, pitch=6)
    render_to(scene, os.path.join(out, "still_full.png"))
    pb = rig.pose.bones["head"]
    head = rig.matrix_world @ pb.head.lerp(pb.tail, 0.5)
    camera(scene, head.x - 0.05, head.z, 0.6 * S, 0.6 * S, 900, yaw=-8, pitch=4)
    render_to(scene, os.path.join(out, "still_face.png"))
    from boss_kit import save_blend
    save_blend("tengu_boss")


main()
