#!/usr/bin/env bash
# Render một (hay vài) nhân vật bằng Blender — bản 3D rồi bản 2.5D (--toon) —
# rồi đóng atlas ở tỉ lệ lớn nhất giữ được số trang cho phép (thử tối đa
# [trang], không vừa thì [trang]+1). Chạy TỪNG con một (mỗi con 10–40 phút).
#
#   bash tool/render/render_sprites.sh <script>:<atlas>:<trang> [...]
#   bash tool/render/render_sprites.sh harpy_tripo:harpy:2
#   NO_TOON=1 bash tool/render/render_sprites.sh lion_tripo:nemea_lion:7
#
# Log từng bản: build/<atlas>[_toon]_export.log. Dừng giữa chừng trên Windows:
# dừng cả tiến trình bash lẫn blender.exe; trang atlas dở dang thì chạy lại
# tool/repack_sprites.py từ khung trong build/blender/sprites/<atlas>/.
set -uo pipefail
cd "$(dirname "$0")/../.."
SCALES="${SCALES:-1.0 0.9 0.85 0.8 0.75 0.7 0.65}"
for spec in "$@"; do
  IFS=: read -r script atlas maxp <<< "$spec"
  versions=("" "--toon")
  [ -n "${NO_TOON:-}" ] && versions=("")
  for t in "${versions[@]}"; do
    name="$atlas"; [ -n "$t" ] && name="${atlas}_toon"
    bash tool/blender/render.sh "$script" $t > "build/${name}_export.log" 2>&1
    grep -hE "\[sprite\]|Traceback" "build/${name}_export.log"
    done_ok=""
    for cap in "$maxp" "$((maxp + 1))"; do
      for s in $SCALES; do
        out=$(python tool/repack_sprites.py "$name" --scale "$s" 2>&1 | grep "\[repack\]")
        pages=$(echo "$out" | sed -E 's/.* ([0-9]+) trang.*/\1/')
        if [ -n "$pages" ] && [ "$pages" -le "$cap" ]; then echo "$out (scale $s)"; done_ok=1; break; fi
      done
      [ -n "$done_ok" ] && break
    done
    [ -z "$done_ok" ] && echo "[render_sprites] $name: không vừa $((maxp + 1)) trang ở tỉ lệ nhỏ nhất"
  done
done
echo ALLDONE
