#!/usr/bin/env bash
# Chạy một script Blender ngầm (không mở giao diện):
#   bash tool/blender/render.sh lion_nemea [--still]
# Đường dẫn Blender lấy từ $BLENDER, mặc định bản cài bằng winget trên Windows.
set -euo pipefail
cd "$(dirname "$0")/../.."
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
name="$1"; shift
# Script tìm theo tên trong characters/, scenes/ rồi tool/blender/ (rules/dohoa/README.md).
script=""
for d in characters scenes .; do
  if [ -f "tool/blender/$d/$name.py" ]; then script="tool/blender/$d/$name.py"; break; fi
done
[ -n "$script" ] || { echo "không thấy script Blender: $name" >&2; exit 1; }
# Script cần tiện ích người dùng (MPFB) ghi "# blender: user-prefs" ở đầu file.
if grep -q "^# blender: user-prefs" "$script"; then
  "$BLENDER" -b -P "$script" -- "$@"
else
  "$BLENDER" -b --factory-startup -P "$script" -- "$@"
fi
# Bộ soát (--review, review_kit) → ghép một tấm sheet.png có nhãn + cảnh báo.
# tripo_view luôn ra bộ ảnh soát, đặt theo tên model (tham số đầu).
if [ "$name" = tripo_view ]; then
  python -I tool/blender/kits/review_sheet.py "build/blender/review/$1"
else
  case " $* " in
    *" --review "*) python -I tool/blender/kits/review_sheet.py "build/blender/review/$name" ;;
  esac
fi
# Trang atlas / tầng phông nền mới → nén WebP vào assets/.
if [ -d build/blender/sprites/pages ] || [ -d build/blender/backdrops ]; then
  python -I tool/render/sprites_webp.py
fi
