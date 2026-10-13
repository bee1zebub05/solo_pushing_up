#!/usr/bin/env bash
# Chạy một script Blender ngầm (không mở giao diện):
#   bash tool/blender/render.sh lion_nemea [--still]
# Đường dẫn Blender lấy từ $BLENDER, mặc định bản cài bằng winget trên Windows.
set -euo pipefail
cd "$(dirname "$0")/../.."
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
name="$1"; shift
# Script cần tiện ích người dùng (MPFB) ghi "# blender: user-prefs" ở đầu file.
if grep -q "^# blender: user-prefs" "tool/blender/$name.py"; then
  "$BLENDER" -b -P "tool/blender/$name.py" -- "$@"
else
  "$BLENDER" -b --factory-startup -P "tool/blender/$name.py" -- "$@"
fi
# Trang atlas / tầng phông nền mới → nén WebP vào assets/.
if [ -d build/blender/sprites/pages ] || [ -d build/blender/backdrops ]; then
  python -I tool/sprites_webp.py
fi
