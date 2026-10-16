"""Addon Blender "SPU Tripo": đưa model Tripo AI vào repo (rules/dohoa.md mục 12).

- Tự động: Tripo Bridge ghi file nhận về vào thư mục tạm rồi XOÁ ngay sau khi
  nhập — addon bọc `ModelImporter.import_model` của Tripo, chép file gốc vào
  `art_src/tripo/_inbox/` trước khi Tripo nhập. Không lần sinh nào bị mất.
- Nút "Gửi vào repo" (thanh bên 3D View › SPU): xuất vật đang chọn (cả con,
  xương, hoạt hình, chỗ sửa tay) → `art_src/tripo/<tên>/model.glb` +
  `meta.json` + `thumb.png`. Script `tool/blender/tripo_kit.py` dựng tiếp.

Cài một lần (Blender đang đóng):  blender -b -P tool/blender/install_tripo_inbox.py
Addon nạp file này thẳng từ repo — sửa ở đây, khởi động lại Blender là có.
"""

import datetime
import json
import os
import re
import shutil
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[3]
TRIPO = ROOT / "art_src" / "tripo"
INBOX = TRIPO / "_inbox"
TRIPO_LOADER = "Tripo3d_Blender_Bridge.core.model_loader"
HOOK_S = 5.0  # Tripo có thể bật sau addon này / được nạp lại → kiểm móc định kỳ

_state = {"last": "", "count": 0}


def slug(text):
    return re.sub(r"[^a-z0-9_]+", "_", text.strip().lower()).strip("_")


def _stamp():
    return datetime.datetime.now().strftime("%Y%m%d-%H%M%S")


# ---------------------------------------------------------------- chép tự động


def _capture(file_path, model_name):
    src = Path(file_path)
    if not src.is_file():
        return
    INBOX.mkdir(parents=True, exist_ok=True)
    tag = slug(model_name) if isinstance(model_name, str) and slug(model_name) else src.stem[:12]
    dst = INBOX / f"{_stamp()}_{tag}{src.suffix.lower()}"
    try:
        shutil.copy2(src, dst)
    except OSError as e:
        print(f"[SPU Tripo] không chép được {src.name}: {e}")
        return
    _state["last"] = dst.name
    _state["count"] += 1
    print(f"[SPU Tripo] đã giữ {src.name} → {dst.relative_to(ROOT)}")


def _hook():
    """Bọc ModelImporter.import_model của Tripo (mọi đường nhập đều qua đây)."""
    mod = sys.modules.get(TRIPO_LOADER)
    if mod is None:
        return HOOK_S
    imp = mod.ModelImporter
    if getattr(imp.import_model, "_spu", False):
        return HOOK_S
    original = imp.import_model.__func__

    def import_model(cls, file_path, file_format, model_name=None):
        try:
            _capture(file_path, model_name)
        except Exception as e:  # không bao giờ làm hỏng việc nhập của Tripo
            print(f"[SPU Tripo] lỗi khi chép: {e}")
        return original(cls, file_path, file_format, model_name)

    import_model._spu = True
    import_model._spu_original = original
    imp.import_model = classmethod(import_model)
    print("[SPU Tripo] đã móc vào Tripo Bridge — model nhận về sẽ được giữ trong art_src/tripo/_inbox/")
    return HOOK_S


def _unhook():
    mod = sys.modules.get(TRIPO_LOADER)
    if mod is None:
        return
    fn = mod.ModelImporter.import_model
    if getattr(fn, "_spu", False):
        mod.ModelImporter.import_model = classmethod(fn._spu_original)


# ---------------------------------------------------------------- gửi vào repo


def _gather(objs):
    """Vật chọn + mọi con cháu + xương điều khiển lưới."""
    out = set()

    def add(o):
        if o in out:
            return
        out.add(o)
        for c in o.children:
            add(c)
        for m in getattr(o, "modifiers", ()):
            if m.type == "ARMATURE" and m.object:
                add(m.object)

    for o in objs:
        add(o)
    return out


def _bbox(objs, dg):
    pts = []
    for o in objs:
        if o.type == "MESH":
            ev = o.evaluated_get(dg)
            pts += [ev.matrix_world @ v.co for v in ev.data.vertices]
    if not pts:
        return None
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return {"min": [round(x, 4) for x in lo], "max": [round(x, 4) for x in hi],
            "size": [round(h - l, 4) for l, h in zip(lo, hi)]}


def _meta(name, objs, note, old):
    dg = bpy.context.evaluated_depsgraph_get()
    tris = 0
    for o in objs:
        if o.type == "MESH":
            me = o.evaluated_get(dg).to_mesh()
            me.calc_loop_triangles()
            tris += len(me.loop_triangles)
            o.evaluated_get(dg).to_mesh_clear()
    rigs = [o for o in objs if o.type == "ARMATURE"]
    images = {}
    for o in objs:
        for slot in getattr(o, "material_slots", ()):
            m = slot.material
            if m and m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image:
                        images[n.image.name] = list(n.image.size)
    now = datetime.datetime.now().isoformat(timespec="seconds")
    return {
        "name": name,
        "source": "tripo",
        "created": old.get("created", now),
        "updated": now,
        "note": note or old.get("note", ""),
        "inbox": _state["last"] or old.get("inbox", ""),
        "objects": sorted(o.name for o in objs),
        "triangles": tris,
        "bbox_m": _bbox(objs, dg),
        "armature": [{"name": r.name, "bones": [b.name for b in r.data.bones]} for r in rigs],
        "actions": [{"name": a.name, "frames": [round(f) for f in a.frame_range]} for a in bpy.data.actions],
        "images": images,
    }


def _thumb(ctx, path):
    """Ảnh nhỏ: tạm phóng khung nhìn 3D tới vật đang chọn, tắt lớp phủ, chụp
    OpenGL, rồi trả khung nhìn về như cũ."""
    scene = ctx.scene
    r = scene.render
    keep = (r.resolution_x, r.resolution_y, r.resolution_percentage, r.filepath)
    area = ctx.area if ctx.area and ctx.area.type == "VIEW_3D" else None
    region = next((g for g in area.regions if g.type == "WINDOW"), None) if area else None
    space = area.spaces.active if area else None
    r3d = space.region_3d if space else None
    view = (r3d.view_location.copy(), r3d.view_rotation.copy(), r3d.view_distance) if r3d else None
    overlays = space.overlay.show_overlays if space else None
    try:
        if region is None:
            raise RuntimeError("không có khung nhìn 3D")
        k = 512 / max(region.width, region.height)
        r.resolution_x, r.resolution_y = max(1, round(region.width * k)), max(1, round(region.height * k))
        r.resolution_percentage = 100
        with ctx.temp_override(area=area, region=region):
            bpy.ops.view3d.view_selected(use_all_regions=False)
            space.overlay.show_overlays = False
            bpy.ops.render.opengl(write_still=False, view_context=True)
        bpy.data.images["Render Result"].save_render(str(path))
        return True
    except Exception as e:
        print(f"[SPU Tripo] không chụp được ảnh nhỏ: {e}")
        return False
    finally:
        r.resolution_x, r.resolution_y, r.resolution_percentage, r.filepath = keep
        if view:
            r3d.view_location, r3d.view_rotation, r3d.view_distance = view
        if space:
            space.overlay.show_overlays = overlays


class SPU_PG_tripo(bpy.types.PropertyGroup):
    name: bpy.props.StringProperty(name="Tên", description="Tên thư mục trong art_src/tripo/ (chữ thường, gạch dưới). "
                                   "Để trống = tên vật đang chọn")
    note: bpy.props.StringProperty(name="Ghi chú", description="Prompt Tripo / dùng cho quái nào — ghi vào meta.json")


class SPU_OT_tripo_send(bpy.types.Operator):
    bl_idname = "spu.tripo_send"
    bl_label = "Gửi vào repo"
    bl_description = "Xuất vật đang chọn (cả con, xương, hoạt hình) sang art_src/tripo/<tên>/model.glb + meta.json + thumb.png"

    @classmethod
    def poll(cls, ctx):
        return bool(ctx.selected_objects)

    def execute(self, ctx):
        props = ctx.scene.spu_tripo
        active = ctx.active_object or ctx.selected_objects[0]
        name = slug(props.name) or slug(active.name)
        if not name:
            self.report({"ERROR"}, "Cần đặt tên (chữ thường, số, gạch dưới)")
            return {"CANCELLED"}
        objs = _gather(ctx.selected_objects)
        if not any(o.type == "MESH" for o in objs):
            self.report({"ERROR"}, "Vùng chọn không có lưới nào")
            return {"CANCELLED"}
        out = TRIPO / name
        out.mkdir(parents=True, exist_ok=True)
        meta_path = out / "meta.json"
        old = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}

        if ctx.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        keep_sel = list(ctx.selected_objects)
        for o in ctx.view_layer.objects:
            o.select_set(o in objs)
        try:
            bpy.ops.export_scene.gltf(filepath=str(out / "model.glb"), export_format="GLB", use_selection=True,
                                      export_apply=True, export_animations=True, export_yup=True)
        finally:
            for o in ctx.view_layer.objects:
                o.select_set(o in keep_sel)
        meta = _meta(name, objs, props.note, old)
        meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
        _thumb(ctx, out / "thumb.png")
        self.report({"INFO"}, f"Đã gửi art_src/tripo/{name}/ ({meta['triangles']:,} tam giác) — báo Claude: \"{name} đã vào\"")
        return {"FINISHED"}


class SPU_OT_tripo_open(bpy.types.Operator):
    bl_idname = "spu.tripo_open"
    bl_label = "Mở thư mục"
    bl_description = "Mở art_src/tripo/ trong trình duyệt file"

    def execute(self, ctx):
        TRIPO.mkdir(parents=True, exist_ok=True)
        if hasattr(os, "startfile"):
            os.startfile(TRIPO)
        return {"FINISHED"}


class SPU_PT_tripo(bpy.types.Panel):
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "SPU"
    bl_label = "Tripo → repo"

    def draw(self, ctx):
        lay = self.layout
        props = ctx.scene.spu_tripo
        mod = sys.modules.get(TRIPO_LOADER)
        hooked = mod is not None and getattr(mod.ModelImporter.import_model, "_spu", False)
        lay.label(text="Tự giữ model Tripo: " + ("BẬT" if hooked else "chưa thấy Tripo Bridge"),
                  icon="CHECKMARK" if hooked else "ERROR")
        if _state["count"]:
            lay.label(text=f"Phiên này đã giữ {_state['count']}: {_state['last']}")
        lay.separator()
        lay.prop(props, "name")
        lay.prop(props, "note")
        lay.operator("spu.tripo_send", icon="EXPORT")
        lay.operator("spu.tripo_open", icon="FILE_FOLDER")


CLASSES = (SPU_PG_tripo, SPU_OT_tripo_send, SPU_OT_tripo_open, SPU_PT_tripo)


def register():
    for c in CLASSES:
        bpy.utils.register_class(c)
    bpy.types.Scene.spu_tripo = bpy.props.PointerProperty(type=SPU_PG_tripo)
    if not bpy.app.timers.is_registered(_hook):
        bpy.app.timers.register(_hook, first_interval=1.0, persistent=True)


def unregister():
    if bpy.app.timers.is_registered(_hook):
        bpy.app.timers.unregister(_hook)
    _unhook()
    del bpy.types.Scene.spu_tripo
    for c in reversed(CLASSES):
        bpy.utils.unregister_class(c)
