# Publishes a new version that existing installs will auto-update to.
#
#   .\publish_release.ps1 -Version 3.2.0 -Notes "Fixed X, added Y"
#
# Steps: bumps the version in code, rebuilds, zips the Release folder,
# computes its SHA-256, and creates a GitHub release with that checksum
# embedded in the notes. Running apps see it within 6 hours (or when the
# user clicks "Check now"), verify the checksum before installing, and
# update themselves. See lib/services/update_service.dart for the
# verification side of this.

param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Notes = '',
    [switch]$SkipBuild,
    # Must match AppConfig.updateRepo in lib/app_config.dart, or a published
    # release will sit in a repo the app never checks.
    [string]$Repo = 'evanbackup1256-ship-it/pilebox'
)

$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version must look like 3.2.0 (got '$Version')."
}

$root      = $PSScriptRoot
$appDir    = Join-Path $root 'flutter_app'
$configPath = Join-Path $appDir 'lib\app_config.dart'
$pubspec   = Join-Path $appDir 'pubspec.yaml'

# --- 1. Stamp the version -------------------------------------------------
Write-Host "`n=== Setting version to $Version ===" -ForegroundColor Cyan

$config = [System.IO.File]::ReadAllText($configPath)
$config = $config -replace "static const version = '[^']*';", "static const version = '$Version';"
[System.IO.File]::WriteAllText($configPath, $config, (New-Object System.Text.UTF8Encoding $false))

$spec = [System.IO.File]::ReadAllText($pubspec)
$spec = $spec -replace '(?m)^version:\s*.*$', "version: $Version"
[System.IO.File]::WriteAllText($pubspec, $spec, (New-Object System.Text.UTF8Encoding $false))

Write-Host "Stamped app_config.dart and pubspec.yaml." -ForegroundColor Green

# --- 2. Build -------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host "`n=== Building ===" -ForegroundColor Cyan
    & (Join-Path $root 'build_exe.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
}

$release = Join-Path $appDir 'build\windows\x64\runner\Release'
if (-not (Test-Path $release)) { throw "Release folder not found: $release" }

# --- 3. Package -----------------------------------------------------------
Write-Host "`n=== Packaging ===" -ForegroundColor Cyan

$distDir = Join-Path $root 'dist_release'
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$zip = Join-Path $distDir "Pilebox-windows-v$Version.zip"
Remove-Item $zip -Force -ErrorAction SilentlyContinue

# Zip the CONTENTS of Release, so extracting over an install replaces files
# in place rather than nesting a folder.
Compress-Archive -Path (Join-Path $release '*') -DestinationPath $zip -CompressionLevel Optimal
$sizeMb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "Wrote $zip ($sizeMb MB)" -ForegroundColor Green

# --- 4. Checksum ------------------------------------------------------------
# UpdateService refuses to install anything without a matching SHA-256, so
# this is not optional metadata - no hash in the notes means every client
# treats the release as unverifiable and will not offer to install it.
$hash = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
Write-Host "SHA-256: $hash" -ForegroundColor Green

# --- 5. Publish -------------------------------------------------------------
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "`ngh CLI not found - upload $zip manually, and put this line" -ForegroundColor Yellow
    Write-Host "verbatim in the release notes so the app can verify it:" -ForegroundColor Yellow
    Write-Host "  SHA256: $hash" -ForegroundColor Yellow
    return
}

Write-Host "`n=== Publishing to GitHub ($Repo) ===" -ForegroundColor Cyan

if (-not $Notes) { $Notes = "Pilebox v$Version" }
$fullNotes = "$Notes`n`nSHA256: $hash"

# The updater matches on the tag, so it must be exactly v<version>. --repo
# is explicit rather than relying on the working directory's git remote,
# which may point elsewhere.
& gh release create "v$Version" $zip --repo $Repo --title "v$Version" --notes $fullNotes
if ($LASTEXITCODE -ne 0) {
    throw "gh release create failed. Does the '$Repo' repo exist, and is 'gh auth login' done?"
}

Write-Host "`nPublished v$Version to $Repo." -ForegroundColor Green
Write-Host "Existing installs will offer the update automatically." -ForegroundColor Cyan
