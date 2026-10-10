# Kiểm tra hồi quy toàn bộ lõi đếm: phân tích code, test, rồi chấm điểm trên
# mọi bộ dữ liệu đang có trên máy với ngưỡng tối thiểu. Chạy trước khi giữ
# bất kỳ thay đổi nào ở lib/rep/.
#
#   powershell -ExecutionPolicy Bypass -File tool/check_all.ps1
#
# Ngưỡng là mức hiện đạt trừ một chút biên; nâng lên khi bộ đếm tốt hơn.
$ErrorActionPreference = "Continue"
$failed = @()

function Step($name, [scriptblock]$block) {
    Write-Host "`n== $name" -ForegroundColor Cyan
    & $block
    if ($LASTEXITCODE -ne 0) { $script:failed += $name }
}

Step "flutter analyze" { flutter analyze }
Step "flutter test" { flutter test }

# (thư mục, tham số thêm, ngưỡng độ chính xác)
$checks = @(
    @("dataset/public/pushupbench/recordings", @(), 0.95),
    @("dataset/public/repcount/recordings", @("--mode", "knee"), 0.84),
    @("dataset/public/repcount/recordings", @("--where", "split=test", "--mode", "knee"), 0.76),
    @("dataset/mlkit_eval", @("--where", "split=test", "--mode", "knee"), 0.77),
    # Máy đặt trước mặt (kiểu người chơi xem được màn hình): 12 clip Mendeley đếm tay.
    @("dataset/public/mendeley_form/recordings", @("--where", "label=dem-tay-tren-do-thi", "--mode", "knee"), 0.93),
    @("dataset/recordings", @(), 0.0)
)
foreach ($c in $checks) {
    $dir, $extra, $min = $c
    if (-not (Test-Path $dir) -or -not (Get-ChildItem "$dir/*.json" -ErrorAction SilentlyContinue)) {
        Write-Host "`n== bỏ qua $dir (chưa có dữ liệu)" -ForegroundColor DarkGray
        continue
    }
    Step "replay $dir $($extra -join ' ') (≥ $min)" {
        dart run tool/replay.dart $dir @extra --min-accuracy $min | Select-Object -Last 6
    }
}

if (Test-Path "dataset/public/mendeley_form/recordings") {
    Step "chống gian lận (Mendeley)" { dart run tool/form_check.dart | Select-Object -Last 7 }
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "TẤT CẢ ĐẠT" -ForegroundColor Green
    exit 0
}
Write-Host "KHÔNG ĐẠT: $($failed -join '; ')" -ForegroundColor Red
exit 1
