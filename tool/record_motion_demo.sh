#!/usr/bin/env bash
# Quay video báo cáo chuyển động trên máy Android thật:
# build màn demo có kịch bản (lib/dev/motion_demo_main.dart) bản profile, quay
# màn hình + tiếng bằng scrcpy, lấy log thời điểm âm thanh, rồi cắt clip bằng
# tool/mix_motion_demo.py (trộn tiếng từ log nếu bản ghi bị câm). Kết quả: demo/motion/*.mp4 (+ GIF xem nhanh).
# Cách dùng: bash tool/record_motion_demo.sh [--no-build]
set -euo pipefail
# Git Bash (Windows) tự đổi /sdcard/… thành đường dẫn Windows: tắt đi.
export MSYS_NO_PATHCONV=1
DEV=${DEVICE:-4eb992cf}
PKG=com.solopushingup.solo_pushing_up
ADB="${LOCALAPPDATA:-}/Android/Sdk/platform-tools/adb.exe"
[ -x "$ADB" ] || ADB=adb
A="$ADB -s $DEV"
cd "$(dirname "$0")/.."
OUT=demo/motion
mkdir -p "$OUT"
if [ "${1:-}" != "--no-build" ]; then
  flutter build apk --profile -t lib/dev/motion_demo_main.dart 2>&1 | tail -1
  $A install -r build/app/outputs/flutter-apk/app-profile.apk | tail -1
fi
$A shell am force-stop $PKG
$A logcat -c
# Quay bằng scrcpy (ColorOS chặn `screenrecord` của adb). scrcpy ghi cả tiếng
# của app (Android 11+). Cài: winget install Genymobile.scrcpy
SCRCPY=$(command -v scrcpy || ls "${LOCALAPPDATA:-}"/Microsoft/WinGet/Packages/Genymobile.scrcpy_*/scrcpy-win64-*/scrcpy.exe | head -1)
export ADB
"$SCRCPY" -s "$DEV" --no-window --no-playback --video-bit-rate=12M   --time-limit=88 --record="$OUT/raw.mp4" > "$OUT/scrcpy.log" 2>&1 &
REC=$!
# Đọc log liên tục (ColorOS xả log rất nhiều, đọc cuối phiên thì mất dòng DEMO).
$A logcat -v raw -s flutter:I > "$OUT/flutter.log" 2>/dev/null &
LOG=$!
sleep 3
$A shell am start -n $PKG/.MainActivity >/dev/null
# Chờ scrcpy tự dừng theo --time-limit (đóng file mp4 đúng cách).
wait $REC || true
kill $LOG 2>/dev/null || true
grep -o "DEMO .*" "$OUT/flutter.log" > "$OUT/cues.log" || true
$A shell am force-stop $PKG
python tool/mix_motion_demo.py "$OUT"
