"""Hàm dùng chung cho nhân vật người dựng bằng MPFB (hero.py, quái hình người).
Toạ độ tính bằng mét; `co` là toạ độ cục bộ các đỉnh lúc nghỉ (rest_coords
trong hero.py) — đừng đọc lưới đã áp modifier, vì mask "Hide helpers" của MPFB
bỏ bớt đỉnh làm lệch chỉ số."""

import math

import bpy
import bmesh
from mathutils import Matrix, Vector

from boss_kit import add_object, parent_to_bone, srgb


def weights_by_group(obj):
    """[{tên nhóm: trọng số}] cho từng đỉnh."""
    names = {g.index: g.name for g in obj.vertex_groups}
    return [{names[g.group]: g.weight for g in v.groups} for v in obj.data.vertices]


def group_center(body, name, co):
    """Tâm thế giới của nhóm đỉnh [name] theo toạ độ nghỉ [co]."""
    gi = body.vertex_groups[name].index
    pts = [co[v.index] for v in body.data.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups)]
    c = sum(pts, Vector()) / len(pts)
    return body.matrix_world @ c


def bone_world(rig, name, at=0.0):
    """Điểm trên xương (0 = gốc, 1 = ngọn) theo toạ độ thế giới lúc nghỉ."""
    b = rig.data.bones[name]
    return rig.matrix_world @ (b.head_local.lerp(b.tail_local, at))


def raw_ellipsoid(name, center, radii, rot_z=0.0, segments=24, rings=14):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1)
    R = Matrix.Rotation(rot_z, 3, "Z")
    for v in bm.verts:
        v.co = R @ Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + center
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    return mesh


def tapered_world(name, strands, sides=8, steps=8, flat=1.0, taper=0.8):
    """Ống thon dọc Bézier bậc hai (gốc, điểm uốn, ngọn, bán kính gốc) — mét."""
    verts, faces = [], []
    for a, b, c, r in strands:
        base = len(verts)
        for i in range(steps + 1):
            t = i / steps
            pt = a * (1 - t) ** 2 + b * 2 * t * (1 - t) + c * t * t
            tan = ((b - a) * 2 * (1 - t) + (c - b) * 2 * t).normalized()
            sd = tan.cross(Vector((0, 0, 1)))
            if sd.length < 1e-4:
                sd = tan.cross(Vector((1, 0, 0)))
            sd.normalize()
            u = sd.cross(tan).normalized()
            rad = r * (1 - t) ** taper + 0.0004
            for k in range(sides):
                ang = 2 * math.pi * k / sides
                verts.append(pt + (sd * math.cos(ang) * flat + u * math.sin(ang) / flat) * rad)
        for i in range(steps):
            for k in range(sides):
                k2 = (k + 1) % sides
                o = base + i * sides
                faces.append((o + k, o + k2, o + sides + k2, o + sides + k))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    return mesh


def raw_tube(name, pts, radii, sides=24, closed=False):
    """Ống qua các điểm (mét) với bán kính tại từng điểm; [closed] nối vòng."""
    verts, faces = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        nxt = pts[(i + 1) % n] if closed else pts[min(i + 1, n - 1)]
        prv = pts[(i - 1) % n] if closed else pts[max(i - 1, 0)]
        tan = (nxt - prv).normalized()
        sd = tan.cross(Vector((0, 0, 1)))
        if sd.length < 1e-4:
            sd = tan.cross(Vector((1, 0, 0)))
        sd.normalize()
        u = sd.cross(tan).normalized()
        r = radii[i]
        rx, rz = (r, r) if not isinstance(r, tuple) else r
        for k in range(sides):
            a = 2 * math.pi * k / sides
            verts.append(p + sd * math.cos(a) * rx + u * math.sin(a) * rz)
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append((i * sides + k, i * sides + k2, j * sides + k2, j * sides + k))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    return mesh


def ring_around(body, rig, co, name, z, bone, mat, pad=0.01, r=0.01, flat=0.5, tilt=0.0, side=None,
                near=None, band=0.006, groups=None):
    """Vòng ôm quanh thân ở độ cao [z] (toạ độ nghỉ cục bộ): thắt lưng, băng
    đầu, dây sandal. Lấy các đỉnh trong dải ±[band] quanh z ([side] 'l'/'r'
    lọc theo bên, [near] lọc quanh một điểm, [groups] chỉ lấy đỉnh thuộc các
    nhóm xương này; luôn bỏ lưới phụ của MPFB), dựng elip bao + [pad], tiết
    diện dẹt (dày r·flat, cao r), gắn vào xương [bone]."""
    w = weights_by_group(body)
    pts = []
    for i, p in enumerate(co):
        if abs(p.z - z) > band or w[i].get("HelperGeometry", 0) > 0.5:
            continue
        if groups and sum(w[i].get(g, 0) for g in groups) < 0.3:
            continue
        if side == "l" and p.x <= 0.02 or side == "r" and p.x >= -0.02:
            continue
        if near is not None and (Vector((p.x, p.y)) - Vector((near.x, near.y))).length > 0.09:
            continue
        pts.append(p)
    if not pts:
        return None
    cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
    cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
    rx = max(abs(p.x - cx) for p in pts) + pad
    ry = max(abs(p.y - cy) for p in pts) + pad
    ring = []
    for k in range(48):
        a = 2 * math.pi * k / 48
        x, y = cx + rx * math.cos(a), cy + ry * math.sin(a)
        ring.append(body.matrix_world @ Vector((x, y, z + tilt * (y - cy))))
    s = body.matrix_world.to_scale().x
    o = add_object(name, raw_tube(name, ring, [(r * flat * s, r * s)] * 48, sides=10, closed=True), [mat])
    parent_to_bone(o, rig, bone)
    return o

def store_point_attr(obj, name, values):
    a = obj.data.attributes.get(name) or obj.data.attributes.new(name, "FLOAT", "POINT")
    a.data.foreach_set("value", values)

def shell_copy(body, name, group, offset, thickness, mats, smooth=0):
    """Lớp vỏ ôm theo thân (áo, tóc gốc): bản sao lưới thân, chỉ giữ nhóm
    đỉnh [group], đẩy ra theo pháp tuyến SAU khi áp xương (nên ôm đúng dáng
    mọi tư thế) và làm dày."""
    o = body.copy()
    o.data = body.data.copy()
    o.name = name
    bpy.context.scene.collection.objects.link(o)
    for m in list(o.modifiers):
        if m.type != "ARMATURE":
            o.modifiers.remove(m)
    mask = o.modifiers.new("Keep", "MASK")
    mask.vertex_group = group
    mask.threshold = 0.5
    if smooth:
        # Xoá chi tiết nhỏ của thân (tai, mũi, núm) để vỏ cứng như kim loại đúc.
        sm = o.modifiers.new("Blob", "SMOOTH")
        sm.factor = 1.0
        sm.iterations = smooth
    if offset:
        d = o.modifiers.new("Out", "DISPLACE")
        d.direction = "NORMAL"
        d.mid_level = 0.0
        d.strength = offset
    if thickness:
        s = o.modifiers.new("Thick", "SOLIDIFY")
        s.thickness = thickness
        s.offset = 1.0
    sub = o.modifiers.new("Smooth", "SUBSURF")
    sub.levels = sub.render_levels = 1
    o.data.materials.clear()
    for m in mats:
        o.data.materials.append(m)
    return o

def rest_coords(body):
    """Toạ độ cục bộ từng đỉnh ở dáng nghỉ, đã áp shape key (dáng thật)."""
    for m in body.modifiers:
        m.show_viewport = False
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    mesh = ev.to_mesh()
    co = [v.co.copy() for v in mesh.vertices]
    ev.to_mesh_clear()
    for m in body.modifiers:
        m.show_viewport = True
    return co


def make_human(gender, muscle=0.5, weight=0.5, height=0.5, age=0.5, proportions=0.9, race=None, scale=1.0,
               details=None):
    """Người MPFB + khung xương game_engine (tên xương kiểu Unreal: pelvis,
    spine_01…, upperarm_l…), làm mịn một bậc; [scale] phóng cả người.
    [details]: {tên target MPFB: độ mạnh}, ví dụ {"torso-vshape-incr": 1}
    (thư mục data/targets của MPFB) — áp TRƯỚC khi gắn xương để xương khớp
    dáng mới."""
    from bl_ext.blender_org.mpfb.services.humanservice import HumanService
    from bl_ext.blender_org.mpfb.services.targetservice import TargetService
    macro = TargetService.get_default_macro_info_dict()
    macro.update(gender=gender, age=age, muscle=muscle, weight=weight, height=height, proportions=proportions)
    macro["race"] = race or {"asian": 0.45, "caucasian": 0.45, "african": 0.1}
    body = HumanService.create_human(macro_detail_dict=macro)
    for name, value in (details or {}).items():
        path = TargetService.target_full_path(name)
        if path is None:
            raise ValueError(f"không có target MPFB {name}")
        TargetService.load_target(body, path, weight=value, name=name)
    bpy.context.view_layer.update()
    rig = HumanService.add_builtin_rig(body, "game_engine")
    rig.scale = (scale, scale, scale)
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
    sub = body.modifiers.new("Smooth", "SUBSURF")
    sub.levels = sub.render_levels = 1
    bpy.context.view_layer.update()
    return body, rig


def arm_ik(rig, sides=("l", "r"), pole_angle=-90):
    """IK hai đoạn cho tay: {bên: (đích, đích cực, đích xoay bàn tay)}."""
    out = {}
    for s in sides:
        t = bpy.data.objects.new(f"IK_{s}", None)
        p = bpy.data.objects.new(f"Pole_{s}", None)
        h = bpy.data.objects.new(f"Palm_{s}", None)
        for o in (t, p, h):
            bpy.context.scene.collection.objects.link(o)
        c = rig.pose.bones[f"lowerarm_{s}"].constraints.new("IK")
        c.target, c.pole_target, c.chain_count = t, p, 2
        c.pole_angle = math.radians(pole_angle)
        cr = rig.pose.bones[f"hand_{s}"].constraints.new("COPY_ROTATION")
        cr.target = h
        cr.influence = 0.0
        out[s] = (t, p, h, c, cr)
    return out

def shadow_catcher():
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=8)
    mesh = bpy.data.meshes.new("Floor")
    bm.to_mesh(mesh)
    bm.free()
    floor = add_object("Floor", mesh, [], smooth_shade=False)
    floor.is_shadow_catcher = True
    return floor

def camera(scene, cx, cz, width, height, ppm, yaw=-10, pitch=7):
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    data.ortho_scale = max(width, height)
    cam = bpy.data.objects.new("Cam", data)
    scene.collection.objects.link(cam)
    cam.rotation_euler = (math.radians(90 - pitch), 0, math.radians(yaw))
    fwd = cam.rotation_euler.to_matrix() @ Vector((0, 0, -1))
    cam.location = Vector((cx, 0, cz)) - fwd * 20
    data.clip_end = 60
    scene.camera = cam
    scene.render.resolution_x = round(width * ppm)
    scene.render.resolution_y = round(height * ppm)
    return cam


def add_face_parts(body, eyes="high-poly", eyebrows="eyebrow001", eyelashes="eyelashes01", teeth="teeth_base",
                   tongue="tongue01", eye_material="MAKESKIN"):
    """Mắt, lông mày, lông mi, răng, lưỡi từ gói tài nguyên hệ thống MakeHuman
    (CC0, cài vào %APPDATA%/Blender Foundation/Blender/<bản>/mpfb/data — xem
    rules/dohoa.md mục 10). Gọi SAU make_human (đã có xương): MPFB tự gắn trọng
    số theo thân. Bỏ một phần bằng cách truyền None. Trả {loại: object}."""
    from bl_ext.blender_org.mpfb.services.assetservice import AssetService
    from bl_ext.blender_org.mpfb.services.humanservice import HumanService
    before = set(bpy.data.objects)
    out = {}
    for kind, name in (("eyes", eyes), ("eyebrows", eyebrows), ("eyelashes", eyelashes), ("teeth", teeth),
                       ("tongue", tongue)):
        if not name:
            continue
        path = AssetService.find_asset_absolute_path(f"{name}/{name}.mhclo", asset_subdir=kind)
        if path is None:
            raise FileNotFoundError(f"chưa cài tài nguyên MPFB {kind}/{name} (gói makehuman_system_assets)")
        HumanService.add_mhclo_asset(path, body, asset_type=kind, subdiv_levels=1,
                                     material_type=eye_material if kind == "eyes" else "MAKESKIN")
        new = [o for o in bpy.data.objects if o not in before]
        before |= set(new)
        if new:
            out[kind] = new[0]
    return out
