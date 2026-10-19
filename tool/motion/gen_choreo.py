"""Sinh lib/art/bosses/choreo_data.dart từ tool/motion/choreo/*.json.

    python tool/motion/gen_choreo.py

Biên đạo đòn (rules/dohoa/chuyendong.md) là MỘT nguồn: script Blender đọc JSON
khi xuất sprite, bản vector Flutter đọc hằng sinh ở đây — hai bản cùng nhịp.
Kèm vài giá trị mẫu do bộ nội suy Python tính (`choreoChecks`) để test Dart
(test/art/choreo_test.dart) bắt chỗ hai bộ nội suy lệch nhau.
"""

import glob
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

HERE = os.path.dirname(os.path.abspath(__file__))
from choreo import Choreo  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "lib", "art", "bosses", "choreo_data.dart")


def num(x):
    return repr(float(x))


def vmap(d):
    return "{" + ", ".join(f"'{k}': {num(v)}" for k, v in d.items()) + "}"


lines = [
    "// SINH TỰ ĐỘNG bởi tool/motion/gen_choreo.py từ tool/motion/choreo/*.json — đừng sửa tay.",
    "",
    "import 'choreo.dart';",
    "",
    "/// Biên đạo đòn theo id boss (rules/dohoa/chuyendong.md).",
    "const choreoData = <String, ChoreoSpec>{",
]
checks = []
for path in sorted(glob.glob(os.path.join(HERE, "choreo", "*.json"))):
    # Mọi kênh dùng trong khoá phải có trong "ready": thiếu thì tiến độ 0 lấy giá trị khoá
    # đầu thay vì dáng chờ → boss bật khi vào đòn (oni thiếu "cant": chuỳ lệch 35 cm, 19/10).
    _spec = json.load(open(path, encoding="utf-8"))
    _miss = sorted({k for mv in _spec["attacks"].values() for key in mv["keys"] for k in key["v"]} - set(_spec["ready"]))
    if _miss:
        raise SystemExit(f"{os.path.basename(path)}: kênh {_miss} có trong khoá nhưng thiếu trong ready")
    name = os.path.splitext(os.path.basename(path))[0]
    data = json.load(open(path, encoding="utf-8"))
    lines.append(f"  '{name}': ChoreoSpec(")
    lines.append(f"    ready: {vmap(data['ready'])},")
    lines.append(f"    lag: {vmap(data.get('lag', {}))},")
    lines.append("    moves: {")
    for move, spec in data["attacks"].items():
        lines.append(f"      '{move}': MoveSpec(")
        lines.append(f"        holdEnd: {'true' if spec.get('hold_end') else 'false'},")
        lines.append(f"        events: {vmap(spec.get('events', {}))},")
        lines.append("        keys: [")
        for k in spec["keys"]:
            lines.append(f"          ({num(k['t'])}, {vmap(k['v'])}),")
        lines.append("        ],")
        lines.append("      ),")
    lines.append("    },")
    lines.append("  ),")
    ch = Choreo(name)
    for move in data["attacks"]:
        for t in (0.1, 0.37, 0.52, 0.6, 0.66, 0.9):
            v = ch[move](t)
            for c in sorted(v)[:6]:
                checks.append(f"  ('{name}', '{move}', {t}, '{c}', {num(round(v[c], 9))}),")
lines.append("};")
lines.append("")
lines.append("/// (boss, đòn, t, kênh, giá trị Python) — test/art/choreo_test.dart.")
lines.append("const choreoChecks = <(String, String, double, String, double)>[")
lines += checks
lines.append("];")
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print(f"{os.path.relpath(OUT, ROOT)}: {len(checks)} giá trị mẫu")
