"""Render hoạt hình thành sprite cho sân khấu Flutter (lib/art/sprite_atlas.dart).

Mỗi quái: vài chuỗi khung ([anims] = {tên: [hàm đặt dáng]}), render nền trong
rồi cắt sát theo alpha, xếp vào các trang 2048×2048 (giới hạn an toàn cho GPU
điện thoại) → `assets/sprites/<tên>_<trang>.png` + `assets/sprites/<tên>.json`.

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

PAGE = 2048


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
    """Render [anims] rồi đóng atlas. [extra]: thông số thêm ghi vào json
    (chu kỳ idle…). Trả về đường dẫn json."""
    scratch = scratch or os.path.join(ROOT, "build", "blender", "sprites", name)
    os.makedirs(scratch, exist_ok=True)
    anchor_px, ppu = frame_scale(scene, cam, anchor, units_per_m)
    frames = []
    for anim, setups in anims.items():
        for k, setup in enumerate(setups):
            setup()
            path = render_to(scene, os.path.join(scratch, f"{anim}_{k:02d}.png"))
            px = _load(path)
            ys, xs = np.nonzero(px[:, :, 3] > 0.004)
            if len(xs) == 0:
                xs, ys = np.array([0]), np.array([0])
            h, w = px.shape[:2]
            x0, x1 = max(xs.min() - 1, 0), min(xs.max() + 2, w)
            y0, y1 = max(ys.min() - 1, 0), min(ys.max() + 2, h)
            frames.append((anim, px[y0:y1, x0:x1], x0, y0))

    # Xếp kệ (shelf) theo chiều cao giảm dần cho đỡ phí chỗ.
    order = sorted(range(len(frames)), key=lambda i: -frames[i][1].shape[0])
    pad = 2
    pages = [[]]
    x = y = shelf = 0
    place = {}
    for i in order:
        h, w = frames[i][1].shape[:2]
        if w > PAGE or h > PAGE:
            raise SystemExit(f"Khung {frames[i][0]} {w}×{h} lớn hơn trang {PAGE}: giảm units_per_m hoặc ppm")
        if x + w > PAGE:
            x, y, shelf = 0, y + shelf + pad, 0
        if y + h > PAGE:
            pages.append([])
            x = y = shelf = 0
        place[i] = (len(pages) - 1, x, y)
        pages[-1].append(i)
        x += w + pad
        shelf = max(shelf, h)

    out_dir = os.path.join(ROOT, "assets", "sprites")
    os.makedirs(out_dir, exist_ok=True)
    for p, idx in enumerate(pages):
        height = max(place[i][2] + frames[i][1].shape[0] for i in idx)
        height = 1 << (int(height - 1).bit_length())  # luỹ thừa 2
        sheet = np.zeros((height, PAGE, 4), dtype=np.float32)
        for i in idx:
            _, crop, _, _ = frames[i]
            _, ax, ay = place[i]
            sheet[ay : ay + crop.shape[0], ax : ax + crop.shape[1]] = crop
        _save(sheet, os.path.join(out_dir, f"{name}_{p}.png"))
    meta = {"unitsPerPixel": round(1 / ppu, 5), "pages": len(pages), "anims": {}}
    if extra:
        meta.update(extra)
    for i, (anim, crop, x0, y0) in enumerate(frames):
        p, ax, ay = place[i]
        meta["anims"].setdefault(anim, []).append({
            "p": p, "x": int(ax), "y": int(ay), "w": int(crop.shape[1]), "h": int(crop.shape[0]),
            "dx": round((x0 - anchor_px.x) / ppu, 2), "dy": round((y0 - anchor_px.y) / ppu, 2),
        })
    path = os.path.join(out_dir, f"{name}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(meta, f, separators=(",", ":"))
    print(f"[sprite] {name}: {len(frames)} khung, {len(pages)} trang, {ppu:.2f} px/đơn vị")
    return path
