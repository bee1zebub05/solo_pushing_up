"""Render hoạt hình thành sprite cho sân khấu Flutter (lib/art/sprite_atlas.dart).

Mỗi quái: vài chuỗi khung ([anims] = {tên: [hàm đặt dáng]}), render nền trong
rồi cắt sát theo alpha, xếp vào các trang 2048×2048 (giới hạn an toàn cho GPU
điện thoại) → trang PNG gốc `build/blender/sprites/pages/<tên>_<trang>.png`
(tool/render/sprites_webp.py nén thành `assets/sprites/<tên>_<trang>.webp`, render.sh
tự chạy) + `assets/sprites/<tên>.json`.

Toạ độ trong json tính bằng ĐƠN VỊ SÂN KHẤU (400×260) so với điểm neo
[anchor] (chân quái trên mặt đất, hoặc tâm thân với quái bay): sân khấu chỉ
việc vẽ khung tại điểm neo, không phải phóng thêm. [units_per_m] = số đơn vị
sân khấu cho 1 m trong Blender — chọn để quái cao đúng như bản vector.
"""

import json
import os

import bpy
import numpy as np
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

from boss_kit import ROOT, render_to



def _px(scene, cam, p):
    v = world_to_camera_view(scene, cam, p)
    return Vector((v.x * scene.render.resolution_x, (1 - v.y) * scene.render.resolution_y))


def frame_scale(scene, cam, anchor, units_per_m):
    """(điểm neo trên ảnh, số điểm ảnh mỗi đơn vị sân khấu)."""
    bpy.context.view_layer.update()
    right = cam.matrix_world.to_3x3().col[0].normalized()
    a = _px(scene, cam, Vector(anchor))
    ppm = (_px(scene, cam, Vector(anchor) + right) - a).length
    return a, ppm / units_per_m


def _load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[::-1]


def _save(arr, path):
    h, w = arr.shape[:2]
    img = bpy.data.images.new("page", w, h, alpha=True)
    img.pixels.foreach_set(arr[::-1].astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def export_sprites(scene, cam, name, anims, anchor, units_per_m, extra=None, scratch=None):
    """Render [anims] rồi đóng atlas (atlas_pack.py). [extra]: thông số thêm
    ghi vào json (chu kỳ idle…). Ghi kèm `_atlas.json` trong thư mục khung để
    tool/render/repack_sprites.py đóng lại atlas (cắt, thu nhỏ) mà không render lại.
    Trả về đường dẫn json."""
    from atlas_pack import crop, pack
    scratch = scratch or os.path.join(ROOT, "build", "blender", "sprites", name)
    os.makedirs(scratch, exist_ok=True)
    anchor_px, ppu = frame_scale(scene, cam, anchor, units_per_m)
    frames, files = [], []
    for anim, setups in anims.items():
        for k, setup in enumerate(setups):
            setup()
            fname = f"{anim}_{k:02d}.png"
            path = render_to(scene, os.path.join(scratch, fname))
            c, x0, y0 = crop(_load(path))
            frames.append((anim, c, x0, y0))
            files.append((anim, fname))
    with open(os.path.join(scratch, "_atlas.json"), "w", encoding="utf-8") as f:
        json.dump({"anchor": [anchor_px.x, anchor_px.y], "ppu": ppu, "extra": extra or {}, "frames": files}, f)
    path, n = pack(name, frames, (anchor_px.x, anchor_px.y), ppu, extra,
                   os.path.join(ROOT, "build", "blender", "sprites", "pages"),
                   os.path.join(ROOT, "assets", "sprites"), _save)
    print(f"[sprite] {name}: {len(frames)} khung, {n} trang, {ppu:.2f} px/đơn vị")
    return path
