#!/usr/bin/env bash
# Xuất sprite từ file chuyển động đã nướng (sửa khoá trong Blender xong thì chạy lại):
#   bash tool/render/render_baked.sh oni_boss [--quick]
# File: art_src/blender/<atlas>_anim.blend do `render.sh <script>` sinh (tool/motion/bake.py).
set -euo pipefail
cd "$(dirname "$0")/../.."
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
declare -A ATLAS=([oni_boss]=shuten_doji [tengu_boss]=tengu_sutoku)
name="$1"; shift
atlas="${ATLAS[$name]:-$name}"
blend="art_src/blender/${atlas}_anim.blend"
[ -f "$blend" ] || { echo "chưa có $blend — chạy: bash tool/blender/render.sh $name" >&2; exit 1; }
args=()
grep -q "^# blender: user-prefs" "tool/blender/characters/$name.py" 2>/dev/null || args=(--factory-startup)
"$BLENDER" -b "${args[@]}" "$blend" -P tool/render/export_baked.py -- "$@"
python -I tool/render/sprites_webp.py
