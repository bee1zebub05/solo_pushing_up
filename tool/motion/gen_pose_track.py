"""Sinh lib/art/bosses/pose_track_data.dart từ track tư thế (tool/motion/bake.py →
build/blender/pose_track/<atlas>.json) — bản vector 2.5D đi theo cùng chuyển động
với sprite (thân từ mocap), không chỉ theo biên đạo.

    python tool/motion/gen_pose_track.py

Mỗi khớp một cặp (x, y) đơn vị sân khấu quanh chân boss (y xuống), theo tiến độ
`phases` của sprite; `ready` = dáng chờ; `weaponLen` = độ dài vũ khí lớn nhất trên
màn hình (vũ khí ngắn hơn = đang chĩa về máy quay).
"""
import glob
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "build", "blender", "pose_track")
OUT = os.path.join(ROOT, "lib", "art", "bosses", "pose_track_data.dart")
NAMES = ["pelvis", "chest", "head", "shoulder_r", "hand_r", "hand_l", "foot_l", "foot_r", "weapon_tip"]


def flat(pts):
    out = []
    for n in NAMES:
        x, y = pts.get(n, pts.get("hand_r"))
        out += [round(x, 2), round(y, 2)]
    return out


def dart_list(xs):
    return "[" + ", ".join(repr(float(x)) for x in xs) + "]"


lines = ["// SINH TỰ ĐỘNG bởi tool/motion/gen_pose_track.py từ build/blender/pose_track/*.json — đừng sửa tay.",
         "", "import 'pose_track.dart';", "",
         "/// Track tư thế theo id sprite boss (rules/dohoa/chuyendong.md, mục Phạm vi).",
         "const poseTrackData = <String, PoseTrack>{"]
for path in sorted(glob.glob(os.path.join(SRC, "*.json"))):
    name = os.path.splitext(os.path.basename(path))[0]
    if name.startswith("bakecheck"):
        continue
    d = json.load(open(path, encoding="utf-8"))
    wl = 0.0
    for a in d["anims"].values():
        for f in a["frames"]:
            if "weapon_tip" in f:
                dx, dy = f["weapon_tip"][0] - f["hand_r"][0], f["weapon_tip"][1] - f["hand_r"][1]
                wl = max(wl, (dx * dx + dy * dy) ** 0.5)
    lines.append(f"  '{name}': PoseTrack(")
    lines.append(f"    weaponLen: {round(wl, 2)!r},")
    lines.append(f"    ready: {dart_list(flat(d['ready']))},")
    lines.append("    anims: {")
    for a, v in d["anims"].items():
        lines.append(f"      '{a}': PoseAnim({dart_list(v['phases'])}, [")
        for f in v["frames"]:
            lines.append(f"        {dart_list(flat(f))},")
        lines.append("      ]),")
    lines.append("    },")
    lines.append("  ),")
    print(f"{name}: {len(d['anims'])} đòn, vũ khí dài {wl:.1f} đơn vị")
lines.append("};")
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print(os.path.relpath(OUT, ROOT))
