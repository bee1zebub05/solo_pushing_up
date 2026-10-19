"""Đường dẫn import cho mọi script Blender (Blender bỏ qua PYTHONPATH).

Script trong characters/ và scenes/ mở đầu bằng:
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    import paths  # noqa: E402,F401
rồi import thẳng tên module của phòng nào cũng được (rules/dohoa/README.md):
kits/ (Dựng hình), characters/, scenes/, tool/motion/ (Chuyển động),
tool/render/ (Render & xuất).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DIRS = [os.path.join(HERE, "kits"), os.path.join(HERE, "characters"), os.path.join(HERE, "scenes"), HERE,
        os.path.join(ROOT, "tool", "motion"), os.path.join(ROOT, "tool", "render")]
for d in reversed(DIRS):
    if d not in sys.path:
        sys.path.insert(0, d)
