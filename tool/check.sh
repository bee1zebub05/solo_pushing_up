#!/usr/bin/env bash
# Kiểm tra trước khi commit: analyze + test app + test các thư viện trong
# packages/. Dừng và trả mã lỗi ngay khi có bước hỏng (không để `| tail` che).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter analyze > /tmp/check_analyze.log 2>&1 || { tail -20 /tmp/check_analyze.log; exit 1; }
flutter test > /tmp/check_test.log 2>&1 || { grep -E "\[E\]|Error|Expected|Actual" /tmp/check_test.log | head -20; tail -3 /tmp/check_test.log; exit 1; }
tail -1 /tmp/check_test.log
for pkg in packages/*/; do
  (cd "$pkg" && flutter test > /tmp/check_pkg.log 2>&1) || { echo "HỎNG: $pkg"; tail -5 /tmp/check_pkg.log; exit 1; }
  echo "$pkg: $(tail -1 /tmp/check_pkg.log)"
done
echo "CHECK OK"
