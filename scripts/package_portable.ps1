# Package the release\ folder into a portable zip and write its SHA256
# checksum file (for the in-app update feed). Run from the repository root
# or the release staging folder.
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
$version = (Get-Content (Join-Path $repoRoot "version.json") -Raw |
    ConvertFrom-Json).version
# 自动更新已按内容校验，发行包文件名不再带版本号（避免每个版本都要
# 重命名资产）；产物统一输出到 release\v<版本>\，不污染仓库根。
$zipName = "SparkDesktop-portable-x64.zip"
$versionDir = Join-Path $stage "v$version"
New-Item -ItemType Directory -Path $versionDir -Force | Out-Null
$zipPath = Join-Path $versionDir $zipName
$shaPath = "$zipPath.sha256"

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
if (Test-Path -LiteralPath $shaPath) {
    Remove-Item -LiteralPath $shaPath -Force
}

# Package only the staged payload; exclude the version output directory so
# the zip is never nested into itself.
$items = @(Get-ChildItem -LiteralPath $stage -Force |
    Where-Object { $_.Name -ne "v$version" })
Compress-Archive -Path $items.FullName -DestinationPath $zipPath `
    -CompressionLevel Optimal -Force

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLower()
"$hash  $zipName" | Set-Content -LiteralPath $shaPath -Encoding ascii

Write-Host "Portable zip:  $zipPath"
Write-Host "SHA256 file:   $shaPath"
