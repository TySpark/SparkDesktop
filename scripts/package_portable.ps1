# Pack a staged payload into the portable zip archive and write its SHA256
# checksum file (for the in-app update feed). The payload is staged into a
# temporary folder (StageDir, default .build\release-stage); the archive
# lands in the version folder release\v<version> (override with -OutputDir).
# After packing, the staging payload is removed: the version folder keeps
# only the zip and its .sha256 as a local archive.
param(
    [string]$StageDir = ".build\release-stage",
    [string]$OutputDir = ""
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
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $repoRoot "release\v$version"
}
$outputDir = [System.IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

# Version-less archive name (the in-app updater verifies by content hash);
# the version folder keeps only the zip and its checksum as a local archive.
$zipName = "SparkDesktop-portable-x64.zip"
$zipPath = Join-Path $outputDir $zipName
$shaPath = "$zipPath.sha256"

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
if (Test-Path -LiteralPath $shaPath) {
    Remove-Item -LiteralPath $shaPath -Force
}

$items = @(Get-ChildItem -LiteralPath $stage -Force)
Compress-Archive -Path $items.FullName -DestinationPath $zipPath `
    -CompressionLevel Optimal -Force

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLower()
"$hash  $zipName" | Set-Content -LiteralPath $shaPath -Encoding ascii

# Drop the staging payload: the version folder keeps only the archive.
Remove-Item -LiteralPath $stage -Recurse -Force

Write-Host "Portable zip:  $zipPath"
Write-Host "SHA256 file:   $shaPath"
