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
# Bộ soát (--review, review_kit) → ghép một tấm sheet.png có nhãn + cảnh báo.
# tripo_view luôn ra bộ ảnh soát, đặt theo tên model (tham số đầu).
if [ "$name" = tripo_view ]; then
  python -I tool/blender/review_sheet.py "build/blender/review/$1"
else
  case " $* " in
    *" --review "*) python -I tool/blender/review_sheet.py "build/blender/review/$name" ;;
  esac
fi
# Trang atlas / tầng phông nền mới → nén WebP vào assets/.
if [ -d build/blender/sprites/pages ] || [ -d build/blender/backdrops ]; then
  python -I tool/sprites_webp.py
fi
