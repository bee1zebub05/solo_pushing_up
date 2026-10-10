# Lấy các bản ghi từ điện thoại Android (cắm USB, bật gỡ lỗi USB) về dataset/recordings.
#
#   powershell -ExecutionPolicy Bypass -File tool/pull_recordings.ps1
#   powershell -ExecutionPolicy Bypass -File tool/pull_recordings.ps1 -Out dataset/recordings -Device 4eb992cf
#   powershell -ExecutionPolicy Bypass -File tool/pull_recordings.ps1 -Folder recordings_eval -Out dataset/mlkit_eval
param(
    [string]$Out = "dataset/recordings",
    [string]$Device = "",
    [string]$Folder = "recordings"
)

$ErrorActionPreference = "Stop"
$package = "com.solopushingup.solo_pushing_up"
$remote = "/sdcard/Android/data/$package/files/$Folder"

$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
    $adb = Join-Path $sdk "platform-tools\adb.exe"
}
if (-not (Test-Path $adb)) {
    Write-Error "Không tìm thấy adb. Cài Android SDK platform-tools hoặc đặt ANDROID_HOME."
}

$deviceArgs = @()
if ($Device) { $deviceArgs = @("-s", $Device) }

$files = & $adb @deviceArgs shell "ls $remote 2>/dev/null" | Where-Object { $_ -like "*.json" }
if (-not $files) {
    Write-Host "Chưa có bản ghi nào trên điện thoại ($remote)."
    exit 0
}

New-Item -ItemType Directory -Force $Out | Out-Null
$new = 0
foreach ($name in $files) {
    $name = $name.Trim()
    $target = Join-Path $Out $name
    if (Test-Path $target) { continue }
    & $adb @deviceArgs pull "$remote/$name" $target | Out-Null
    Write-Host "Đã lấy $name"
    $new++
}
Write-Host "Xong: $new bản ghi mới, tổng $($files.Count) trên điện thoại → $Out"
