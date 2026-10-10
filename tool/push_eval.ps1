# Đẩy ảnh đánh giá (tool/export_frames.py) sang điện thoại để app chạy qua ML Kit.
#
#   powershell -ExecutionPolicy Bypass -File tool/push_eval.ps1
# Sau đó trong app: 🤖 → "Đánh giá ML Kit trên ảnh mẫu", rồi lấy kết quả về:
#   powershell -ExecutionPolicy Bypass -File tool/pull_recordings.ps1 -Folder recordings_eval -Out dataset/mlkit_eval
param(
    [string]$Source = "dataset/eval_frames",
    [string]$Device = "",
    # Android 14+: app không đọc được file do adb tạo trong bộ nhớ ngoài.
    # Chép vào bộ nhớ trong của app bằng run-as (chỉ được với bản debug).
    [switch]$Internal,
    # Chỉ đẩy các clip có tên khớp mẫu, nhiều mẫu cách nhau bằng dấu phẩy
    # (ví dụ "stu*,*push up*").
    [string]$Filter = "*"
)

$ErrorActionPreference = "Stop"
$package = "com.solopushingup.solo_pushing_up"
$remote = "/sdcard/Android/data/$package/files/eval_frames"

$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
    $adb = Join-Path $sdk "platform-tools\adb.exe"
}
$deviceArgs = @()
if ($Device) { $deviceArgs = @("-s", $Device) }

if ($Internal) {
    $tmp = "/data/local/tmp/eval_frames"
    & $adb @deviceArgs shell "mkdir -p $tmp"
    foreach ($clip in Get-ChildItem -Directory $Source | Where-Object { $n = $_.Name; @($Filter.Split(",") | Where-Object { $n -like $_.Trim() }).Count -gt 0 }) {
        & $adb @deviceArgs push $clip.FullName "$tmp/" | Select-Object -Last 1
    }
    & $adb @deviceArgs shell "run-as $package mkdir -p files/eval_frames && run-as $package cp -r $tmp/. files/eval_frames/ && rm -r $tmp"
} else {
    & $adb @deviceArgs shell "mkdir -p $remote"
    foreach ($clip in Get-ChildItem -Directory $Source | Where-Object { $n = $_.Name; @($Filter.Split(",") | Where-Object { $n -like $_.Trim() }).Count -gt 0 }) {
        & $adb @deviceArgs push $clip.FullName "$remote/" | Select-Object -Last 1
    }
}
Write-Host "Xong. Mở app → 🤖 → Đánh giá ML Kit trên ảnh mẫu."
