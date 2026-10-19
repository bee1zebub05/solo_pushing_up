"""Xuất sprite từ file chuyển động đã nướng (tool/motion/bake.py), không tính lại dáng.

    bash tool/render/render_baked.sh <script> [--quick]     # vd. oni_boss

Mở art_src/blender/<atlas>_anim.blend (đã sửa khoá bằng tay cũng được), đọc
scene["spu_bake"] (hoạt ảnh → số khung, điểm neo, đơn vị/m, phases…) rồi render từng
khung bằng máy quay đã lưu → atlas như xuất thường.
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "blender"))
import paths  # noqa: E402,F401

import bpy  # noqa: E402

from bake import setups_from  # noqa: E402
from sprite_kit import export_sprites  # noqa: E402

scene = bpy.context.scene
meta = json.loads(scene["spu_bake"])
scene.cycles.samples = 16 if "--quick" in sys.argv else 64
export_sprites(scene, scene.camera, meta["atlas"], setups_from(meta["anims"]), tuple(meta["anchor"]),
               meta["units_per_m"], extra=meta.get("extra") or None)
