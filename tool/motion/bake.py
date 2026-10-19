"""Nướng chuyển động tính bằng code thành khoá Blender (phòng Chuyển động, rules/dohoa/chuyendong.md).

Code (`<boss>_motion.py`: biên đạo + mocap) vẫn là nguồn; `bake` gọi từng setup MỘT lần
rồi ghi kết quả thành dữ liệu Blender bình thường:
- **xương:** dáng SAU ràng buộc (IK đã giải) → khoá location/rotation/scale; sau đó tắt
  ràng buộc → mở file là đúng dáng, kéo timeline xem / sửa khoá bằng tay được;
- **object rig + vật đổi chỗ / ẩn hiện theo khung** (lửa ma, vò rượu, khói): khoá;
- **vải dựng lại mỗi khung** (hakama, tạp dề, khoá đai, chữ nổi…): chép mỗi khung một
  bản; vật có topology + thuộc tính (UV, `hem`…) KHÔNG đổi qua các khung gộp thành một
  bản + shape key mỗi khung (sửa tay được); vật đổi (hakama tô viền gấu `hem` theo dáng,
  khoá đai dựng bằng thao tác lưới đổi thứ tự mặt) giữ bản sao từng khung, bật đúng khung.
Hoạt ảnh nối tiếp trên một timeline (marker = tên hoạt ảnh). Sprite xuất TỪ timeline này
(`frame_set`), nên file nướng chính là nguồn render — sửa tay xong chạy
`bash tool/render/render_baked.sh <script>` là ra sprite mới.

Cùng lúc ghi **track tư thế** (khớp chính chiếu qua máy quay sân khấu, đơn vị sân khấu)
cho bản vector 2.5D: tool/motion/gen_pose_track.py → lib/art/bosses/pose_track_data.dart.
"""
import json
import os
import re

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view

from boss_kit import ROOT

GAP = 10  # khung trống giữa hai hoạt ảnh trên timeline
TRACK = {"pelvis": "pelvis", "chest": "spine_03", "head": "head", "shoulder_r": "upperarm_r",
         "hand_r": "hand_r", "hand_l": "hand_l", "foot_l": "foot_l", "foot_r": "foot_r"}


def _depth(pb):
    d = 0
    while pb.parent:
        d, pb = d + 1, pb.parent
    return d


def _base(name):
    return re.sub(r"\.\d{3}$", "", name)


def _signature(o):
    """Topology + thuộc tính không phải vị trí (UV, `hem`…) — giống nhau ở mọi khung thì
    shape key đủ thay bản sao từng khung."""
    import hashlib
    h = hashlib.sha1()
    me = o.data
    lv = np.empty(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", lv)
    h.update(lv.tobytes())
    for at in sorted(me.attributes, key=lambda a: a.name):
        if at.name == "position" or at.name.startswith("."):
            continue
        key = {"FLOAT": "value", "INT": "value", "BOOLEAN": "value", "INT8": "value", "FLOAT2": "vector",
               "FLOAT_VECTOR": "vector", "FLOAT_COLOR": "color", "BYTE_COLOR": "color"}.get(at.data_type)
        width = {"FLOAT2": 2, "FLOAT_VECTOR": 3, "FLOAT_COLOR": 4, "BYTE_COLOR": 4}.get(at.data_type, 1)
        if key is None:
            continue
        arr = np.empty(len(at.data) * width, dtype=np.float64)
        try:
            at.data.foreach_get(key, arr)
        except (TypeError, RuntimeError):
            continue
        h.update(at.name.encode())
        h.update(np.round(arr, 5).tobytes())
    return h.hexdigest()


def _base_coords(o):
    """Đỉnh lưới GỐC (trước modifier) theo toạ độ thế giới — shape key của bản giữ lại;
    modifier (subsurf…) của nó vẫn áp lên trên như lúc dựng."""
    co = np.empty(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", co)
    mw = np.array(o.matrix_world)
    return co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]


def _world_coords(o):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    mw = np.array(o.matrix_world)
    return co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]


class _Projector:
    """Thế giới → đơn vị sân khấu quanh điểm neo (cùng phép chiếu với sprite_kit)."""

    def __init__(self, scene, cam, anchor, units_per_m):
        from sprite_kit import frame_scale
        self.scene, self.cam = scene, cam
        self.anchor_px, self.ppu = frame_scale(scene, cam, anchor, units_per_m)
        r = scene.render
        self.w = r.resolution_x * r.resolution_percentage / 100
        self.h = r.resolution_y * r.resolution_percentage / 100

    def __call__(self, p):
        from mathutils import Vector
        v = world_to_camera_view(self.scene, self.cam, Vector(p))
        x, y = v.x * self.w, (1 - v.y) * self.h
        return [round((x - self.anchor_px.x) / self.ppu, 2), round((y - self.anchor_px.y) / self.ppu, 2)]


def bake(rig, anims, name, cam, anchor, units_per_m, dress=None, weapons=(), grip="hand_r", extra=None):
    """[anims] {tên: [setup()]} → nướng vào timeline; trả {tên: [số khung]}.
    [dress]() → object vải dựng lại theo khung (đọc sau mỗi setup). [weapons]: regex tên
    vũ khí (đầu vũ khí cho track). Lưu art_src/blender/<name>_anim.blend +
    build/blender/pose_track/<name>.json. [extra]: ghi kèm (phases, idlePeriod…) cho
    tool/render/export_baked.py."""
    scene = bpy.context.scene
    proj = _Projector(scene, cam, anchor, units_per_m)
    frames, f = {}, 1
    for a, setups in anims.items():
        frames[a] = list(range(f, f + len(setups)))
        f += len(setups) + GAP
    bones = sorted(rig.pose.bones, key=_depth)
    rig_children = {o for o in bpy.data.objects if o.parent == rig}
    dress_now = set(dress() if dress else [])
    # Vật theo dõi: con của rig chỉ đổi ẩn/hiện (vị trí theo xương đã nướng), vật khác cả hai.
    watch = [o for o in scene.objects if o is not rig and o.type not in ("CAMERA", "LIGHT", "EMPTY")
             and o not in dress_now]
    wobj = [o for o in bpy.data.objects if o.type == "MESH" and any(re.match(r, o.name) for r in weapons)]
    rec_b, rec_rig, rec_w, track = {}, {}, {}, {}
    copies = {}  # tên gốc vải → [(khung, bản sao khung đó (bỏ cha, giữ vị trí thế giới), chữ ký)]
    for a, setups in anims.items():
        track[a] = []
        for fr, setup in zip(frames[a], setups):
            setup()
            bpy.context.view_layer.update()
            rec_b[fr] = {pb.name: pb.matrix.copy() for pb in bones}
            rec_rig[fr] = rig.matrix_world.copy()
            rec_w[fr] = {o.name: (o.matrix_world.copy(), o.hide_render) for o in watch}
            if dress:
                for o in dress():
                    b = _base(o.name)
                    c = o.copy()
                    c.data = o.data.copy()
                    c.name = f"{b}_f{fr:04d}"
                    scene.collection.objects.link(c)
                    mwc = o.matrix_world.copy()
                    c.parent = None
                    c.matrix_world = mwc
                    for mod in [m for m in c.modifiers if m.type == "ARMATURE"]:
                        c.modifiers.remove(mod)  # đã ở dáng của khung → không biến dạng lần nữa
                    c.hide_render = c.hide_viewport = True  # bản sao không được lẫn vào các khung sau
                    sig = (_signature(c), len(c.data.vertices)) if c.type == "MESH" else None
                    copies.setdefault(b, []).append((fr, c, sig))
            mw = rig.matrix_world
            pts = {k: proj(mw @ rig.pose.bones[b].head) for k, b in TRACK.items() if b in rig.pose.bones}
            if wobj:
                g = np.array(mw @ rig.pose.bones[grip].head)
                wp = np.concatenate([_world_coords(o) for o in wobj])
                pts["weapon_tip"] = proj(wp[np.argmax(np.linalg.norm(wp - g, axis=1))])
            track[a].append(pts)
    # Vải dựng theo khung: bỏ bản đang có (của khung cuối), giữ bản nướng.
    if dress:
        for o in dress():
            bpy.data.objects.remove(o, do_unlink=True)
    # Sprite = khung rời: khoá mới nội suy CONSTANT (đặt qua tuỳ chọn — Blender 5 bỏ Action.fcurves).
    edit = bpy.context.preferences.edit
    interp_before = edit.keyframe_new_interpolation_type
    edit.keyframe_new_interpolation_type = "CONSTANT"
    # --- xương: khoá dáng (basis tính từ ma trận pose đã ghi, theo thứ bậc), tắt ràng buộc
    for pb in bones:
        pb.rotation_mode = "QUATERNION"
        for c in pb.constraints:
            c.mute = True
    rig.animation_data_create()
    for fr, mats in rec_b.items():
        for pb in bones:
            m = mats[pb.name]
            if pb.parent:
                rel = pb.parent.bone.matrix_local.inverted() @ pb.bone.matrix_local
                pb.matrix_basis = (mats[pb.parent.name] @ rel).inverted() @ m
            else:
                pb.matrix_basis = pb.bone.matrix_local.inverted() @ m
            for path in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(path, frame=fr, group=pb.name)
        rig.matrix_world = rec_rig[fr]
        for path in ("location", "rotation_euler", "scale"):
            rig.keyframe_insert(path, frame=fr)
    # --- vật đổi chỗ / ẩn hiện: chỉ khoá vật thật sự đổi
    for o in watch:
        vals = [rec_w[fr][o.name] for fr in rec_w if o.name in rec_w[fr]]
        m0 = vals[0][0]
        moved = o not in rig_children and any(
            abs(a - b) > 1e-6 for v in vals for ra, rb in zip(v[0], m0) for a, b in zip(ra, rb))
        toggles = len({v[1] for v in vals}) > 1
        if not (moved or toggles):
            continue
        for fr in rec_w:
            mwo, hide = rec_w[fr][o.name]
            if moved:
                o.matrix_world = mwo
                for path in ("location", "rotation_euler", "scale"):
                    o.keyframe_insert(path, frame=fr)
            if toggles:
                o.hide_render = hide
                o.keyframe_insert("hide_render", frame=fr)
    # --- vải: chữ ký giống nhau ở mọi khung → một bản + shape key; khác → bản sao từng khung
    all_frames = sorted(rec_b)
    n_shape = n_copy = 0
    for b, items in copies.items():
        sigs = {sig for _, _, sig in items}
        if len(items) == len(all_frames) and len(sigs) == 1 and None not in sigs:
            n_shape += 1
            keep = items[0][1]
            keep.name = f"{b}_baked"
            keep.hide_render = keep.hide_viewport = False
            world = {fr: _base_coords(c) for fr, c, _ in items}
            keep.matrix_world = keep.matrix_world.Identity(4)
            keep.data.vertices.foreach_set("co", world[items[0][0]].ravel())
            keep.shape_key_add(name="basis")
            for fr, co in world.items():
                k = keep.shape_key_add(name=f"f{fr:04d}")
                k.data.foreach_set("co", co.ravel())
                for t, v in ((fr - 1, 0.0), (fr, 1.0), (fr + 1, 0.0)):
                    k.value = v
                    k.keyframe_insert("value", frame=t)
            for _, c, _ in items[1:]:
                data = c.data
                bpy.data.objects.remove(c, do_unlink=True)
                bpy.data.meshes.remove(data)
            continue
        n_copy += 1
        for fr, c, _ in items:
            # Khoá CONSTANT: ẩn từ đầu timeline, hiện đúng khung fr, ẩn lại từ fr+1.
            for t, hide in {all_frames[0]: True, fr: False, fr + 1: True}.items():
                c.hide_render = hide
                c.hide_viewport = hide
                c.keyframe_insert("hide_render", frame=t)
                c.keyframe_insert("hide_viewport", frame=t)
    edit.keyframe_new_interpolation_type = interp_before
    for a, frs in frames.items():
        scene.timeline_markers.new(a, frame=frs[0])
    scene.frame_start, scene.frame_end = 1, max(max(v) for v in frames.values())
    meta = {"atlas": name, "anims": frames, "anchor": list(anchor), "units_per_m": units_per_m, "extra": extra or {}}
    scene["spu_bake"] = json.dumps(meta)
    scene.camera = cam
    # Track tư thế cho 2.5D (đơn vị sân khấu, y xuống; khung 0 của idle = dáng chờ).
    d = os.path.join(ROOT, "build", "blender", "pose_track")
    os.makedirs(d, exist_ok=True)
    phases = (extra or {}).get("phases", {})
    out = {"ready": track[next(iter(track))][0], "anims": {}}
    for a, fs in track.items():
        if a in phases:
            out["anims"][a] = {"phases": phases[a], "frames": fs}
    json.dump(out, open(os.path.join(d, f"{name}.json"), "w", encoding="utf-8"))
    from boss_kit import save_blend
    save_blend(f"{name}_anim")
    print(f"[bake] {name}: {sum(len(v) for v in frames.values())} khung, {n_shape} vải shape key, "
          f"{n_copy} vải bản sao từng khung → "
          f"art_src/blender/{name}_anim.blend")
    return frames


def setups_from(frames):
    """{tên: [số khung]} → {tên: [setup()]} đặt timeline tới khung đó (xuất sprite từ bản nướng)."""
    scene = bpy.context.scene
    return {a: [lambda f=f: scene.frame_set(f) for f in frs] for a, frs in frames.items()}
