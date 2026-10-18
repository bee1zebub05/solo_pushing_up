"""Dựng model Tripo AI (art_src/tripo/<tên>/model.glb) vào cảnh game — rules/dohoa.md mục 12.

model.glb là file gốc (không sinh lại được, Git LFS); script dùng nó là công
thức (chỉnh tỉ lệ, hướng, chất liệu, dáng, xuất sprite), như mọi script khác
trong tool/blender/. Xem nhanh không cần viết script:

    bash tool/blender/render.sh tripo_view <tên> [--height 2.2] [--yaw 0] [--review] [--quick]

Xương: Tripo (và Mixamo…) đặt tên khác MPFB. `load()` đổi tên xương sang tên
MPFB game_engine (pelvis, spine_01…, thigh_l, hand_r…) mà japan_kit /
review_kit / sprite dùng — nhờ vậy `--review` chạy được trên model Tripo.
Xương đoán không ra in vào bones.txt; truyền [bones]={tên_cũ: tên_mới} để chỉ định.
"""

import json
import math
import os
import re
from dataclasses import dataclass, field

import bpy
from mathutils import Vector

from boss_kit import ROOT, add_sun

TRIPO = os.path.join(ROOT, "art_src", "tripo")

# Xương MPFB game_engine mà bộ công cụ đọc theo tên.
CANON = ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head"] + [
    f"{p}_{s}" for s in "lr" for p in ("clavicle", "upperarm", "lowerarm", "hand", "thigh", "calf", "foot", "ball")]
REVIEW_NEEDS = ["pelvis", "head", "clavicle_l", "upperarm_l", "upperarm_r", "hand_l", "hand_r",
                "thigh_l", "thigh_r", "foot_l", "foot_r"]

# (mẫu trên tên đã bỏ bên/ký tự lạ, bộ phận) — theo thứ tự, mẫu đầu khớp thắng.
# Tên Mixamo: Hips Spine Spine1 Spine2 Neck Head LeftShoulder LeftArm LeftForeArm
# LeftHand LeftUpLeg LeftLeg LeftFoot LeftToeBase; Tripo/UE/Rigify tương tự.
_SKIP = re.compile(r"end|nub|tip|top|thumb|index|middle|ring|pinky|finger|twist|roll|ik|pole|eye|jaw|tongue|toe\d")
_SIDED = [
    (r"toe|ball", "ball"),
    (r"foot|ankle", "foot"),
    (r"calf|shin|lowerleg|knee|^leg\d*$", "calf"),
    (r"thigh|upleg|upperleg|^hip\d*$", "thigh"),
    (r"hand|wrist|palm", "hand"),
    (r"forearm|lowerarm|elbow", "lowerarm"),
    (r"upperarm|^arm\d*$", "upperarm"),
    (r"shoulder|clavicle|collar", "clavicle"),
]
_CENTER = [
    (r"hips?$|pelvis", "pelvis"),
    (r"head$", "head"),
    (r"neck", "neck"),
    (r"spine|chest|torso|abdomen", "spine"),
]


def _side(low):
    if re.search(r"(^|[_.\s-])(l|left)([_.\s-]|$)", low) or low.startswith("left") or re.search(r"left|_l\d*$|\.l$", low):
        return "l"
    if re.search(r"(^|[_.\s-])(r|right)([_.\s-]|$)", low) or low.startswith("right") or re.search(r"right|_r\d*$|\.r$", low):
        return "r"
    return None


def guess_bone_map(rig):
    """{tên Tripo: tên MPFB} đoán theo tên + thứ bậc xương. Xương trùng bộ phận
    (Spine, Spine1, Spine2, Chest) xếp theo độ sâu → spine_01, 02, 03."""
    found = {}  # bộ phận → [xương theo độ sâu]

    def depth(b):
        return len(b.parent_recursive)

    for b in sorted(rig.data.bones, key=depth):
        low = b.name.split(":")[-1].lower()
        side = _side(low)
        core = re.sub(r"left|right", "", low)
        core = re.sub(r"(^|[_.\s-])[lr](?=[_.\s-]|\d*$)|[_.\s-][lr]\d*$", "", core)
        core = re.sub(r"[^a-z0-9]", "", core)
        if _SKIP.search(core) and not re.fullmatch(r"toebase|toe|toe0?1", core):
            continue
        for pat, part in (_SIDED if side else _CENTER):
            if re.search(pat, core):
                found.setdefault(f"{part}_{side}" if side else part, []).append(b.name)
                break
    out = {}
    for part, names in found.items():
        if part == "spine":
            for k, n in enumerate(names[:3]):
                out[n] = f"spine_{k + 1:02d}"
        elif part == "neck":
            out[names[0]] = "neck_01"
        else:
            out[names[0]] = part
    return out


def rename_bones(rig, mapping):
    """Đổi tên xương (Blender tự đổi theo nhóm đỉnh của lưới và đường dẫn hoạt hình)."""
    tmp = {}
    for old in mapping:
        b = rig.data.bones.get(old)
        if b:
            b.name = f"__spu_{len(tmp)}"
            tmp[b.name] = mapping[old]
    for t, new in tmp.items():
        clash = rig.data.bones.get(new)
        if clash:
            clash.name = new + "_orig"
        rig.data.bones[t].name = new


@dataclass
class Model:
    name: str
    root: object
    meshes: list
    rig: object = None
    meta: dict = field(default_factory=dict)
    bone_map: dict = field(default_factory=dict)

    @property
    def body(self):
        """Lưới lớn nhất (Tripo thường ra một lưới duy nhất)."""
        return max(self.meshes, key=lambda o: len(o.data.vertices))

    def points(self):
        dg = bpy.context.evaluated_depsgraph_get()
        pts = []
        for o in self.meshes:
            ev = o.evaluated_get(dg)
            pts += [ev.matrix_world @ v.co for v in ev.data.vertices]
        return pts


def load(name, bones=None, report_dir=None):
    """Nhập art_src/tripo/<name>/model.glb vào cảnh, gom dưới một vật rỗng
    "<name>_root", đổi tên xương sang MPFB. [bones]: chỉ định thêm/ghi đè."""
    path = os.path.join(TRIPO, name, "model.glb")
    if not os.path.exists(path):
        raise SystemExit(f"Chưa có {os.path.relpath(path, ROOT)} — bấm 'Gửi vào repo' trong Blender (tab SPU)")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    # Bộ nhập glTF tạo hình hiển thị xương (Icosphere) — không phải lưới model.
    shapes = {pb.custom_shape for o in new if o.type == "ARMATURE" for pb in o.pose.bones if pb.custom_shape}
    for o in new:
        if o.type == "ARMATURE":
            for pb in o.pose.bones:
                pb.custom_shape = None
    new = [o for o in new if o not in shapes]
    for s in shapes:
        bpy.data.objects.remove(s)
    root = bpy.data.objects.new(f"{name}_root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in new:
        if o.parent is None:
            o.parent = root
    meshes = [o for o in new if o.type == "MESH"]
    rigs = [o for o in new if o.type == "ARMATURE"]
    meta_path = os.path.join(TRIPO, name, "meta.json")
    meta = json.load(open(meta_path, encoding="utf-8")) if os.path.exists(meta_path) else {}
    m = Model(name, root, meshes, rigs[0] if rigs else None, meta)
    if m.rig:
        mapping = guess_bone_map(m.rig)
        mapping.update(bones or {})
        rename_bones(m.rig, mapping)
        m.bone_map = mapping
        _bone_report(m, report_dir or os.path.join(ROOT, "build", "blender", "tripo", name))
    return m


def _bone_report(m, out):
    os.makedirs(out, exist_ok=True)
    have = {b.name for b in m.rig.data.bones}
    lines = ["== Đổi tên xương Tripo → MPFB =="]
    lines += [f"{a} → {b}" for a, b in sorted(m.bone_map.items(), key=lambda kv: CANON.index(kv[1]) if kv[1] in CANON else 99)]
    miss = [c for c in CANON if c not in have]
    lines.append("Thiếu (MPFB): " + (", ".join(miss) if miss else "không"))
    lines.append("Giữ tên gốc: " + ", ".join(sorted(have - set(CANON))))
    with open(os.path.join(out, "bones.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    if miss:
        print(f"[tripo] {m.name}: thiếu xương {miss} — xem build/blender/tripo/{m.name}/bones.txt")


def normalize(m, height=None, yaw=0.0):
    """Xoay [yaw]° quanh trục đứng (mặc định model quay mặt về -Y, phía máy
    quay), co giãn đều cho cao [height] m (None = giữ), chân chạm z=0, tâm x/y về 0."""
    r = m.root
    r.rotation_euler = (0, 0, math.radians(yaw))
    r.scale = (1, 1, 1)
    r.location = (0, 0, 0)
    bpy.context.view_layer.update()
    if height:
        zs = [p.z for p in m.points()]
        k = height / max(1e-6, max(zs) - min(zs))
        r.scale = (k, k, k)
        bpy.context.view_layer.update()
    pts = m.points()
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    r.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
    bpy.context.view_layer.update()
    return hi - lo


def forward(yaw=0.0):
    """Hướng model quay mặt sau normalize(yaw)."""
    a = math.radians(yaw)
    return Vector((math.sin(a), -math.cos(a), 0))


def decimate(m, max_tris):
    """Giảm lưới (sửa đổi Decimate đặt trước xương, không áp vĩnh viễn)."""
    total = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in m.meshes)
    if total <= max_tris:
        return total
    for o in m.meshes:
        mod = o.modifiers.new("SPU_Decimate", "DECIMATE")
        mod.ratio = max_tris / total
        o.modifiers.move(len(o.modifiers) - 1, 0)
    return max_tris


def densify(m, levels=1, render_levels=2):
    """Lưới dày hơn. GLB chỉ chứa tam giác (quad "Smart Mesh" của Tripo đã bị
    xẻ đôi) và đỉnh bị tách dọc đường nối UV — làm mịn thẳng thì nứt theo
    đường nối, gợn mặt tam giác. Nên: hàn đỉnh trùng → ghép tam giác lại thành
    quad (giữ đường nối UV) → Subdivision Surface (build_rig dời nó ra SAU
    xương để mịn cả khi cử động). Gọi TRƯỚC build_rig. Không thêm chi tiết —
    chi tiết nằm ở texture; chỉ mượt viền và chỗ gập khớp.
    Trả (số mặt trước, số quad sau ghép)."""
    import bmesh
    before = after = 0
    for o in m.meshes:
        me = o.data
        bm = bmesh.new()
        bm.from_mesh(me)
        before += len(bm.faces)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.join_triangles(bm, faces=bm.faces, cmp_uvs=True, cmp_seam=True, cmp_sharp=False,
                                 angle_face_threshold=math.radians(40), angle_shape_threshold=math.radians(40))
        after += len(bm.faces)
        bm.to_mesh(me)
        bm.free()
        if me.has_custom_normals:  # pháp tuyến glTF theo lưới cũ — để subsurf tự tính
            with bpy.context.temp_override(object=o, active_object=o):
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
        for p in me.polygons:
            p.use_smooth = True
        sub = o.modifiers.new("SPU_Subsurf", "SUBSURF")
        sub.levels, sub.render_levels = levels, render_levels
    return before, after


def _hsv(rgb):
    """rgb (..., 3) sRGB 0–1 → (hue độ, sat, val)."""
    import numpy as np
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, (g - b) / d % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, d / (mx + 1e-6), mx


def _texture(m):
    import numpy as np
    o = m.body
    node = next(n for s in o.material_slots for n in s.material.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    W, Hh = node.image.size
    px = np.empty(W * Hh * 4, np.float32)
    node.image.pixels.foreach_get(px)
    return node, px.reshape(Hh, W, 4)  # hàng 0 = đáy ảnh = v 0


def _bary(p, a, b, c):
    v0, v1 = b - a, c - a
    v2 = p - a
    den = v0[0] * v1[1] - v1[0] * v0[1]
    if abs(den) < 1e-12:
        return None
    l1 = (v2[..., 0] * v1[1] - v1[0] * v2[..., 1]) / den
    l2 = (v0[0] * v2[..., 1] - v2[..., 0] * v0[1]) / den
    return 1 - l1 - l2, l1, l2


def _tris(m):
    import numpy as np
    o = m.body
    me = o.data
    me.calc_loop_triangles()
    uvl = me.uv_layers.active.data
    mw = o.matrix_world
    n3 = mw.to_3x3().inverted().transposed()
    co = np.array([tuple(mw @ v.co) for v in me.vertices])
    return co, [(t.vertices[:], [tuple(uvl[i].uv) for i in t.loops], (n3 @ t.normal).normalized().y) for t in me.loop_triangles]


def front_map(m, res=0.002):
    """Chiếu thẳng từ trước (−Y), dáng chữ T gốc: ảnh màu (nz, nx, 3) theo
    (x, z) của bề mặt trước nhất (hàng 0 = z thấp) + (x0, z0, res). Dùng để
    chọn khuôn hoạ tiết (front_crop) và soát."""
    import numpy as np
    node, px = _texture(m)
    Hh, W = px.shape[:2]
    co, tris = _tris(m)
    x0, z0 = co[:, 0].min(), co[:, 2].min()
    nx, nz = int((co[:, 0].max() - x0) / res) + 2, int((co[:, 2].max() - z0) / res) + 2
    depth = np.full((nz, nx), np.inf)
    fuv = np.zeros((nz, nx, 2))
    for vs, uv, _ in tris:
        P = co[list(vs)]
        q = np.stack([(P[:, 0] - x0) / res, (P[:, 2] - z0) / res], 1)
        lo, hi = np.floor(q.min(0)).astype(int), np.ceil(q.max(0)).astype(int) + 1
        gx, gz = np.meshgrid(np.arange(lo[0], hi[0]), np.arange(lo[1], hi[1]))
        b = _bary(np.stack([gx + 0.5, gz + 0.5], -1), q[0], q[1], q[2])
        if b is None:
            continue
        inside = (b[0] >= 0) & (b[1] >= 0) & (b[2] >= 0)
        if not inside.any():
            continue
        y = b[0] * P[0, 1] + b[1] * P[1, 1] + b[2] * P[2, 1]
        U = np.array(uv)
        u = b[0] * U[0, 0] + b[1] * U[1, 0] + b[2] * U[2, 0]
        v = b[0] * U[0, 1] + b[1] * U[1, 1] + b[2] * U[2, 1]
        sel = inside & (y < depth[gz, gx])
        depth[gz[sel], gx[sel]] = y[sel]
        fuv[gz[sel], gx[sel]] = np.stack([u[sel], v[sel]], -1)
    sx = np.clip((fuv[..., 0] * W).astype(int), 0, W - 1)
    sy = np.clip((fuv[..., 1] * Hh).astype(int), 0, Hh - 1)
    img = px[sy, sx, :3].copy()
    img[~np.isfinite(depth)] = 0
    return img, (x0, z0, res)


def stamp_back(m, template, centers, pattern, target, min_back=0.3, out_png=None):
    """Đóng khuôn hoạ tiết lên mặt sau (Tripo hay chỉ vẽ hoạ tiết mặt trước).

    [template]: ảnh vuông (n, n, 3) một hoạ tiết trọn vẹn, cắt từ front_map
    (hàng 0 = dưới); bán kính = n/2 × [res] lúc cắt → truyền qua centers.
    [centers]: [(x, z, r)] tâm + bán kính (m) mỗi con dấu ở mặt sau. Mỗi điểm
    ảnh texture thuộc tam giác quay ra sau (pháp tuyến y > [min_back]) nằm
    trong một con dấu: hoà màu khuôn theo [pattern](màu khuôn) ×
    [target](màu trung bình tam giác sau — vải Tripo hay có đốm khác màu, xét
    từng điểm thì khuôn khuyết). Thay ảnh texture trong vật liệu (model.glb giữ
    nguyên). Trả số điểm ảnh đổi."""
    import numpy as np
    node, px = _texture(m)
    Hh, W = px.shape[:2]
    co, tris = _tris(m)
    n = template.shape[0]
    C = np.array(centers, float)
    out = px.copy()
    changed = 0
    for vs, uv, ny in tris:
        if ny < min_back:
            continue
        P = co[list(vs)]
        T = np.array(uv) * (W, Hh)
        lo, hi = np.floor(T.min(0)).astype(int), np.ceil(T.max(0)).astype(int) + 1
        gx, gy = np.meshgrid(np.arange(max(lo[0], 0), min(hi[0], W)), np.arange(max(lo[1], 0), min(hi[1], Hh)))
        if gx.size == 0:
            continue
        b = _bary(np.stack([gx + 0.5, gy + 0.5], -1), T[0], T[1], T[2])
        if b is None:
            continue
        inside = (b[0] >= -0.01) & (b[1] >= -0.01) & (b[2] >= -0.01)
        if not inside.any():
            continue
        back = px[gy[inside], gx[inside], :3]
        t = target(back.mean(0, keepdims=True))[0]
        if t <= 0:
            continue
        X = (b[0] * P[0, 0] + b[1] * P[1, 0] + b[2] * P[2, 0])[inside]
        Z = (b[0] * P[0, 2] + b[1] * P[1, 2] + b[2] * P[2, 2])[inside]
        d = np.hypot(X[:, None] - C[:, 0], Z[:, None] - C[:, 1]) / C[:, 2]
        k = d.argmin(1)
        ok = d[np.arange(len(k)), k] < 1
        if not ok.any():
            continue
        # Nhìn từ sau x lật → lấy khuôn lật ngang để hoa văn đọc đúng chiều từ sau lưng.
        u = (-(X - C[k, 0]) / C[k, 2] + 1) / 2
        v = ((Z - C[k, 1]) / C[k, 2] + 1) / 2
        tc = template[np.clip((v * n).astype(int), 0, n - 1), np.clip((u * n).astype(int), 0, n - 1)]
        a = (np.clip(pattern(tc), 0, 1) * t * ok)[:, None]
        gi, gj = gy[inside], gx[inside]
        out[gi, gj, :3] = back * (1 - a) + tc * a
        changed += int((a > 0.5).sum())
    img = node.image
    new = bpy.data.images.new(img.name + "_back", W, Hh, alpha=True)
    new.colorspace_settings.name = img.colorspace_settings.name
    new.pixels.foreach_set(out.ravel())
    new.pack()
    node.image = new
    if out_png:
        new.filepath_raw = out_png
        new.file_format = "PNG"
        new.save()
    return changed


def tone(m, sat=1.0, val=1.0, rough=None):
    """Chỉnh màu texture Tripo cho hợp chương: bão hoà [sat], sáng [val]
    (Hue/Sat chèn trước Base Color), độ nhám cố định [rough] (texture Tripo
    nướng sẵn ánh bóng — cố định nhám thường đỡ loáng nhựa)."""
    seen = set()
    for o in m.meshes:
        for slot in o.material_slots:
            mat = slot.material
            if not mat or not mat.use_nodes or mat in seen:
                continue
            seen.add(mat)
            nt = mat.node_tree
            for n in [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"]:
                bc = n.inputs["Base Color"]
                if (sat != 1.0 or val != 1.0) and bc.is_linked:
                    src = bc.links[0].from_socket
                    hsv = nt.nodes.new("ShaderNodeHueSaturation")
                    hsv.inputs["Saturation"].default_value = sat
                    hsv.inputs["Value"].default_value = val
                    nt.links.new(src, hsv.inputs["Color"])
                    nt.links.new(hsv.outputs["Color"], bc)
                if rough is not None:
                    rs = n.inputs["Roughness"]
                    for lk in list(rs.links):
                        nt.links.remove(lk)
                    rs.default_value = rough


def actions(m):
    return [a.name for a in bpy.data.actions]


def action_frames(m, action, n):
    """[n] hàm đặt dáng rải đều trên hoạt hình [action] của Tripo — đưa thẳng
    vào sprite_kit.export_sprites(anims={"idle": action_frames(...)})."""
    act = bpy.data.actions[action]
    ad = m.rig.animation_data or m.rig.animation_data_create()
    f0, f1 = act.frame_range
    scene = bpy.context.scene

    def at(f):
        def setup():
            ad.action = act
            scene.frame_set(int(f), subframe=f - int(f))
        return setup

    loop = n if n > 1 else 1
    return [at(f0 + (f1 - f0) * k / loop) for k in range(n)]


def build_rig(m, bones, voxel=None):
    """Gắn xương cho model Tripo chưa rig (nên sinh dáng chữ T/A).

    [bones]: [(tên, đầu, đuôi, cha)] toạ độ thế giới SAU normalize, đọc trên
    ảnh có lưới toạ độ. Tên kết thúc `_l` (bên +x) tự sinh `_r` đối xứng.
    Dùng tên MPFB (pelvis, spine_01, thigh_l…) để review_kit/sprite đọc được;
    xương thêm (cánh, đuôi) đặt tên tuỳ ý. Trọng số: tự động (bone heat).
    Trả về (rig, số đỉnh không có trọng số)."""
    def mirror(p):
        return (-p[0], p[1], p[2])

    full = []
    for n, h, t, par in bones:
        full.append((n, h, t, par))
        if n.endswith("_l"):
            full.append((n[:-2] + "_r", mirror(h), mirror(t), par[:-2] + "_r" if par and par.endswith("_l") else par))
    data = bpy.data.armatures.new(f"{m.name}_rig")
    rig = bpy.data.objects.new(f"{m.name}_rig", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for n, h, t, par in full:
        b = data.edit_bones.new(n)
        b.head, b.tail = Vector(h), Vector(t)
        b.roll = 0.0
    for n, h, t, par in full:
        if par:
            data.edit_bones[n].parent = data.edit_bones[par]
    bpy.ops.object.mode_set(mode="OBJECT")
    # Lưới Tripo: đỉnh tách theo đường nối UV, vải nhiều lớp chồng → bone heat
    # trên lưới thật thất bại. Tính trên bản phụ kín (voxel remesh) rồi chép
    # trọng số về theo đỉnh gần nhất — UV/texture lưới thật giữ nguyên.
    if voxel is None:  # ô nhỏ hơn thì vải hở/lông cánh vỡ vụn, thân không còn là một khối
        zs = [p.z for p in m.points()]
        voxel = 0.015 * (max(zs) - min(zs))
    for o in m.meshes:
        proxy = _voxel_proxy(o, voxel)
        for p in bpy.context.view_layer.objects:
            p.select_set(p is proxy or p is rig)
        bpy.context.view_layer.objects.active = rig
        # Bone heat ở cỡ thật (~2 m, có cánh) thiếu chính xác → hỏng cả lưới;
        # phóng ×10 quanh gốc lúc giải thì được (trọng số không phụ thuộc tỉ lệ).
        rig.scale = proxy.scale = (10, 10, 10)
        bpy.context.view_layer.update()
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        rig.scale = (1, 1, 1)
        proxy.parent = None
        proxy.scale = (1, 1, 1)
        proxy.matrix_world = proxy.matrix_basis = proxy.matrix_basis.Identity(4)
        bpy.context.view_layer.update()
        _copy_weights(proxy, o, [b.name for b in data.bones])
        bpy.data.objects.remove(proxy)
        mw = o.matrix_world.copy()
        o.parent = rig
        o.matrix_world = mw
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
        o.modifiers.move(len(o.modifiers) - 1, 0)  # xương trước, subsurf (densify) sau
    unweighted = 0
    for o in m.meshes:
        unweighted += sum(1 for v in o.data.vertices if not any(g.weight > 1e-4 for g in v.groups))
    m.rig = rig
    if unweighted:
        print(f"[tripo] {m.name}: {unweighted} đỉnh không có trọng số")
    return rig, unweighted


def _voxel_proxy(o, voxel):
    """Bản sao kín một khối của [o] (thế giới), voxel [voxel] m."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    me.transform(o.matrix_world)
    tmp = bpy.data.objects.new(o.name + "_proxysrc", me)
    bpy.context.scene.collection.objects.link(tmp)
    rm = tmp.modifiers.new("Remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = voxel
    dg = bpy.context.evaluated_depsgraph_get()
    pm = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    # Chỉ giữ khối liền lớn nhất: lông cánh, sợi tóc, mép vải mỏng vỡ thành
    # hàng trăm mảnh; một mảnh không "thấy" xương là bone heat hỏng cả lưới.
    # Mảnh lẻ vẫn nhận trọng số khi chép theo đỉnh gần nhất.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(pm)
    bm.verts.ensure_lookup_table()
    seen, best = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        isl, stack = [], [v]
        while stack:
            x = stack.pop()
            if x.index in seen:
                continue
            seen.add(x.index)
            isl.append(x)
            stack += [e.other_vert(x) for e in x.link_edges]
        if len(isl) > len(best):
            best = isl
    keep = {v.index for v in best}
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
    bm.to_mesh(pm)
    bm.free()
    proxy = bpy.data.objects.new(o.name + "_proxy", pm)
    bpy.context.scene.collection.objects.link(proxy)
    return proxy


def _copy_weights(src, dst, names, k=4):
    """Trọng số đỉnh [dst] = trung bình nghịch khoảng cách của [k] đỉnh gần nhất trên [src]."""
    from mathutils.kdtree import KDTree
    sv = src.data.vertices
    tree = KDTree(len(sv))
    for i, v in enumerate(sv):
        tree.insert(src.matrix_world @ v.co, i)
    tree.balance()
    gidx = {g.index: g.name for g in src.vertex_groups}
    sw = [{gidx[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in sv]
    for n in names:
        if n not in dst.vertex_groups:
            dst.vertex_groups.new(name=n)
    groups = {n: dst.vertex_groups[n] for n in names}
    mw = dst.matrix_world
    for v in dst.data.vertices:
        acc, tot = {}, 0.0
        for _, i, d in tree.find_n(mw @ v.co, k):
            w = 1.0 / max(d, 1e-5)
            tot += w
            for n, x in sw[i].items():
                acc[n] = acc.get(n, 0.0) + x * w
        for n, x in acc.items():
            if n in groups and x / tot > 1e-3:
                groups[n].add([v.index], x / tot, "REPLACE")


def default_lights(scene):
    """Ba đèn như bộ boss chương Nhật (oni): nắng chính ấm, viền lam nhạt, hắt hồng."""
    add_sun(scene, "Key", (0.35, 0.75, -0.55), 3.6, "#FFE2C2", angle=3)
    add_sun(scene, "Rim", (-0.75, -0.3, -0.25), 2.6, "#C4D2F2", angle=4)
    add_sun(scene, "Fill", (0.2, 0.9, 0.2), 0.6, "#FFB0A0", angle=20)


def can_review(m):
    if not m.rig:
        return ["(không có xương)"]
    have = {b.name for b in m.rig.data.bones}
    return [b for b in REVIEW_NEEDS if b not in have]


def add_fingers(m, rig, side, min_size=10, palm=None):
    """Tự dựng xương ngón cho bàn tay lưới Tripo (model chỉ có xương hand_*).

    Tách ngón theo lưới: đỉnh thuộc bàn tay (trọng số hand_[side] > 0,3), cắt
    dần theo độ sâu dọc trục bàn tay — mức sâu đầu tiên tách ra ≥ 4 cụm là bốn
    ngón; cụm tách sớm hơn, không chứa đỉnh ngón nào là ngón cái. Mỗi ngón 3 đốt
    (45/30/25 % chiều dài, gốc lùi vào lòng bàn tay 15 % — khớp đốt bàn), trục
    Z xương quay về lòng bàn tay nên xoay +X = gập ngón (như MPFB, dùng chung
    mocap_drive.fingers). Trọng số: chia theo vị trí dọc trục ngón, chuyển mềm
    từ bàn tay sang đốt gốc. [palm]: hướng lòng bàn tay (thế giới, dáng nghỉ);
    None = −Z (dáng chữ T của Tripo, lòng bàn tay úp). Trả về tên các xương mới."""
    import numpy as np
    from mathutils.kdtree import KDTree

    o = m.body
    mw = o.matrix_world
    hb = rig.data.bones[f"hand_{side}"]
    h0, h1 = rig.matrix_world @ hb.head_local, rig.matrix_world @ hb.tail_local
    ax = (h1 - h0).normalized()
    gi = {g.name: g.index for g in o.vertex_groups}
    hg = gi[f"hand_{side}"]
    P = np.array([list(mw @ v.co) for v in o.data.vertices])
    w = np.zeros(len(P))
    for v in o.data.vertices:
        for g in v.groups:
            if g.group == hg:
                w[v.index] = g.weight
    sel = np.where(w > 0.3)[0]
    t = (P[sel] - np.array(h0)) @ np.array(ax)
    edges = [tuple(e.vertices) for e in o.data.edges]
    kd = KDTree(len(sel))
    for k, i in enumerate(sel):
        kd.insert(P[i], k)
    kd.balance()
    near = {}
    for k, i in enumerate(sel):
        near[i] = [sel[j] for _, j, _ in kd.find_range(P[i], 0.002)]

    def comps(idx):
        ids = set(int(i) for i in idx)
        par = {i: i for i in ids}

        def f(i):
            while par[i] != i:
                par[i] = par[par[i]]
                i = par[i]
            return i
        for a, b in edges:
            if a in ids and b in ids:
                par[f(a)] = f(b)
        for i in ids:
            for j in near[i]:
                if j in ids:
                    par[f(i)] = f(int(j))
        groups = {}
        for i in ids:
            groups.setdefault(f(i), []).append(i)
        return sorted((g for g in groups.values() if len(g) >= min_size), key=len, reverse=True)

    L = (h1 - h0).length
    fingers, tk = None, None
    for x in np.linspace(0.3, 1.05, 31):
        cs = comps(sel[t > x * L])
        if len(cs) >= 4:
            fingers, tk = cs[:4], x * L
            break
    if fingers is None:
        print(f"[tripo] add_fingers {side}: không tách được 4 ngón")
        return []
    fset = set(i for g in fingers for i in g)
    thumb = None
    for x in np.linspace(tk / L, 0.0, 25):
        cs = comps(sel[t > x * L])
        cand = [g for g in cs if not (set(g) & fset)]
        if cand:
            thumb = max(cand, key=len)
        elif thumb is not None:
            break
    pal = Vector(palm) if palm is not None else Vector((0, 0, -1))
    # Thứ tự trỏ → út: gần ngón cái nhất là trỏ; không có ngón cái thì theo phía lòng bàn tay.
    lat = ax.cross(pal).normalized()
    ref = Vector(P[thumb].mean(0)) if thumb else h0 + lat * (1 if side == "l" else -1)

    def centroid(g):
        return Vector(P[g].mean(0))

    fingers.sort(key=lambda g: (centroid(g) - ref).length)
    names = ["index", "middle", "ring", "pinky"]
    chains = list(zip(names, fingers)) + ([("thumb", thumb)] if thumb else [])
    bpy.context.view_layer.objects.active = rig
    for ob in bpy.context.view_layer.objects:
        ob.select_set(ob is rig)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    inv = rig.matrix_world.inverted()
    made, spans = [], {}
    for name, g in chains:
        Q = P[g]
        c = Q.mean(0)
        u, sv, vt = np.linalg.svd(Q - c)
        d = Vector(vt[0])
        if d.dot(Vector(c) - h0) < 0:
            d = -d
        s = (Q - c) @ np.array(d)
        base = Vector(c) + d * float(np.percentile(s, 5))
        tip = Vector(c) + d * float(s.max())
        length = (tip - base).length
        if name != "thumb":
            base = base - d * 0.15 * length  # khớp đốt bàn nằm trong lòng bàn tay
            length *= 1.15
        cuts = [0.0, 0.45, 0.75, 1.0]
        parent = eb[f"hand_{side}"]
        for k in range(3):
            b = eb.new(f"{name}_0{k + 1}_{side}")
            b.head = inv @ (base + d * cuts[k] * length)
            b.tail = inv @ (base + d * cuts[k + 1] * length)
            b.align_roll(inv.to_3x3() @ pal)  # trục Z về lòng bàn tay: +X = gập
            b.parent = parent
            b.use_connect = k > 0
            parent = b
            made.append(b.name)
        spans[name] = (base, d, length, set(g))
    bpy.ops.object.mode_set(mode="OBJECT")
    # Trọng số: đỉnh trong ngón + vùng chuyển trong lòng bàn tay quanh gốc ngón.
    for n in made:
        if n not in o.vertex_groups:
            o.vertex_groups.new(name=n)
    hand_vg = o.vertex_groups[f"hand_{side}"]
    for name, (base, d, length, g) in spans.items():
        cuts = [0.0, 0.45, 0.75, 1.0]
        vg = [o.vertex_groups[f"{name}_0{k + 1}_{side}"] for k in range(3)]
        rad = 0.35 * length
        for i in sel:
            p = Vector(P[i])
            s = (p - base).dot(d) / length
            perp = ((p - base) - d * (p - base).dot(d)).length
            in_f = i in g
            if not in_f and not (s > -0.05 and s < 0.3 and perp < rad):
                continue
            # Vùng chuyển: gốc ngón (s ≈ 0–0,2) chia dần từ bàn tay.
            f = 1.0 if in_f and s > 0.2 else max(0.0, min(1.0, (s + 0.05) / 0.25))
            if not in_f:
                f *= max(0.0, 1 - perp / rad) * 0.6
            if f <= 0:
                continue
            ww = [0.0, 0.0, 0.0]
            for k in range(3):
                a, b = cuts[k], cuts[k + 1]
                wdt = 0.08
                ww[k] = max(0.0, min(1.0, (s - a + wdt) / (2 * wdt))) * max(0.0, min(1.0, (b - s + wdt) / (2 * wdt)))
            tot = sum(ww) or 1.0
            hw = w[i]
            for k in range(3):
                if ww[k] > 0:
                    vg[k].add([int(i)], hw * f * ww[k] / tot, "REPLACE")
            hand_vg.add([int(i)], hw * (1 - f), "REPLACE")
    print(f"[tripo] add_fingers {side}: {len(fingers)} ngón + {'ngón cái' if thumb else 'không ngón cái'}, "
          f"cắt ở {tk / L:.2f} dài bàn tay")
    return made
