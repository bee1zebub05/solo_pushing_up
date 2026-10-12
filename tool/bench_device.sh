#!/usr/bin/env bash
# Đo trận Nemea trên máy Android thật (bản profile, lib/dev/perf_bench_main.dart).
# Cách dùng: tool/bench_device.sh [--no-build]
# App tự đo dọc rồi tự xoay ngang; mỗi pha script lấy bộ nhớ (dumpsys
# meminfo) giữa lúc trận đang chạy. In thời gian ghi lệnh/tô mỗi khung.
set -u
DEV=${DEVICE:-4eb992cf}
PKG=com.solopushingup.solo_pushing_up
ADB="${LOCALAPPDATA:-}/Android/Sdk/platform-tools/adb.exe"
[ -x "$ADB" ] || ADB=adb
A="$ADB -s $DEV"
cd "$(dirname "$0")/.."
if [ "${1:-}" != "--no-build" ]; then
  flutter build apk --profile -t lib/dev/perf_bench_main.dart 2>&1 | tail -1
  $A install -r build/app/outputs/flutter-apk/app-profile.apk | tail -1
fi
$A logcat -c
$A shell am force-stop $PKG
$A shell am start -n $PKG/.MainActivity >/dev/null
wait_for() {
  for _ in $(seq 1 180); do
    $A logcat -d | grep -q "$1" && return 0
    sleep 1
  done
  echo "Hết giờ chờ: $1"
}
for phase in full full-landscape orochi fafnir thuy_tinh swarm hydra harpy boar spartoi stone pack; do
  wait_for "BENCH phase $phase\$"
  sleep 3
  echo "MEM $phase:"
  $A shell dumpsys meminfo $PKG | grep -E "^ +(Native Heap|Graphics|GL mtrack|EGL mtrack|TOTAL PSS|TOTAL:)" | sed 's/^ */  /'
done
wait_for 'BENCH .pack. raster'
$A logcat -d | grep 'BENCH' | grep -E "record|\] (frames|build|raster|cpu-parts)" | sed 's/.*BENCH/BENCH/'
$A shell am force-stop $PKG
