# Package a release staging folder into a portable zip and write its SHA256
# checksum file (for the in-app update feed). Pass the version staging folder
# via -StageDir (e.g. release\v1.1.0); defaults to release.
param(
    [string]$StageDir = "release"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$stage = Join-Path $repoRoot $StageDir
if (-not (Test-Path -LiteralPath $stage -PathType Container)) {
    Write-Error "Staging directory not found: $stage"
    exit 1
}
# 自动更新已按内容校验，发行包文件名不再带版本号（避免每个版本都要
# 重命名资产）；压缩包与发布内容一起放在版本目录 release\v<版本>\ 内。
$zipName = "SparkDesktop-portable-x64.zip"
$zipPath = Join-Path $stage $zipName
$shaPath = "$zipPath.sha256"

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
if (Test-Path -LiteralPath $shaPath) {
    Remove-Item -LiteralPath $shaPath -Force
}

# Package only the staged payload; exclude the zip itself so it is never
# nested into itself.
$items = @(Get-ChildItem -LiteralPath $stage -Force |
    Where-Object { $_.Name -ne $zipName })
Compress-Archive -Path $items.FullName -DestinationPath $zipPath `
    -CompressionLevel Optimal -Force

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLower()
"$hash  $zipName" | Set-Content -LiteralPath $shaPath -Encoding ascii

Write-Host "Portable zip:  $zipPath"
Write-Host "SHA256 file:   $shaPath"
