"""Cài addon "SPU Tripo" (tool/blender/addons/tripo_inbox.py) vào Blender — chạy một lần, Blender đang đóng:

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tool/blender/install_tripo_inbox.py

Ghi một file mồi `spu_tripo_inbox.py` vào thư mục addon người dùng; file mồi nạp
code thẳng từ repo (sửa repo → khởi động lại Blender là có, không cần cài lại).
Bật kèm addon Tripo Bridge và MCP for Blender (cho Claude xem cảnh đang mở), lưu Preferences.
"""

import os

import addon_utils
import bpy

REPO_ADDONS = os.path.abspath(os.path.join(os.path.dirname(__file__), "addons"))

STUB = f'''# Tự sinh bởi tool/blender/install_tripo_inbox.py — code thật nằm trong repo.
bl_info = {{
    "name": "SPU Tripo → repo",
    "author": "Solo Pushing Up",
    "version": (1, 0, 0),
    "blender": (4, 1, 0),
    "location": "View3D > Sidebar > SPU",
    "description": "Giữ mọi model Tripo nhận về + nút gửi model vào art_src/tripo/",
    "category": "Import-Export",
}}

import importlib
import sys

_DIR = {REPO_ADDONS!r}
if _DIR not in sys.path:
    sys.path.insert(0, _DIR)
import tripo_inbox as _impl  # noqa: E402


def register():
    importlib.reload(_impl)
    _impl.register()


def unregister():
    _impl.unregister()
'''

addons_dir = bpy.utils.user_resource("SCRIPTS", path="addons", create=True)
with open(os.path.join(addons_dir, "spu_tripo_inbox.py"), "w", encoding="utf-8") as f:
    f.write(STUB)
addon_utils.modules_refresh()
for mod in ("Tripo3d_Blender_Bridge", "blender_mcp", "spu_tripo_inbox"):
    try:
        addon_utils.enable(mod, default_set=True, handle_error=None)
        print(f"bật {mod}: {mod in bpy.context.preferences.addons}")
    except Exception as e:
        print(f"không bật được {mod}: {e}")
bpy.ops.wm.save_userpref()
print("Đã lưu Preferences — mở Blender, thanh bên 3D View (phím N) › tab SPU.")
