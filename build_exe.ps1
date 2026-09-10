# Builds the Flutter app into a distributable Windows .exe.
#
# Run AFTER setup_flutter.ps1, in a NEW terminal (so PATH is picked up).
# Safe to re-run.

$ErrorActionPreference = 'Stop'
$AppDir = Join-Path $PSScriptRoot 'flutter_app'

# Locate Flutter without depending on this shell's PATH.
#
# A terminal opened before the SDK was installed keeps a stale copy of PATH,
# so `flutter` can be installed and still be invisible here. Re-read the
# persisted PATH and check the usual install locations before giving up.
function Resolve-Flutter {
    $cmd = Get-Command flutter.bat -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $persisted = @(
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
    ) -join ';'

    $candidates = @()
    $candidates += ($persisted -split ';' |
        Where-Object { $_ -like '*flutter*bin*' } |
        ForEach-Object { Join-Path $_ 'flutter.bat' })
    $candidates += 'C:\src\flutter\bin\flutter.bat'
    $candidates += "$env:LOCALAPPDATA\flutter\bin\flutter.bat"
    $candidates += "$env:USERPROFILE\flutter\bin\flutter.bat"

    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path }
    }
    return $null
}

$Flutter = Resolve-Flutter
if (-not $Flutter) {
    throw "Flutter SDK not found. Run .\setup_flutter.ps1 first."
}

# Put it on PATH for this session so the Flutter tool's own subprocesses work.
$env:Path = "$(Split-Path $Flutter);$env:Path"
Write-Host "Using Flutter: $Flutter" -ForegroundColor DarkGray

# --- Preflight: fail early with actionable messages ------------------------
$problems = @()

$devKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
$devMode = 0
if (Test-Path $devKey) {
    $devMode = (Get-ItemProperty $devKey -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
}
if ($devMode -ne 1) {
    $problems += @"
Developer Mode is OFF (Flutter needs it for plugin symlinks).
    Fix: run  start ms-settings:developers   and switch Developer Mode on.
"@
}

$vswhereExe = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$hasCpp = $false
if (Test-Path $vswhereExe) {
    $hasCpp = [bool](& $vswhereExe -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -requires Microsoft.VisualStudio.Component.Windows11SDK.22621 `
        -property installationPath)
    if (-not $hasCpp) {
        # Accept a Windows 10 SDK as an equivalent.
        $hasCpp = [bool](& $vswhereExe -products * `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
            -requires Microsoft.VisualStudio.Component.Windows10SDK.19041 `
            -property installationPath)
    }
}
if (-not $hasCpp) {
    $problems += @"
Visual Studio C++ workload is incomplete (needs C++ CMake tools + Windows SDK).
    Fix: winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--quiet --wait --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended"
"@
}

if ($problems.Count -gt 0) {
    Write-Host "`nCannot build yet:`n" -ForegroundColor Red
    foreach ($p in $problems) { Write-Host "  - $p" -ForegroundColor Yellow }
    throw "Resolve the item(s) above, then re-run this script."
}

Push-Location $AppDir
try {
    # --- 1. Generate the windows/ runner if it does not exist yet ----------
    # `flutter create` on an existing directory adds the missing platform
    # scaffolding without touching lib/ or pubspec.yaml.
    if (-not (Test-Path 'windows')) {
        Write-Host "`n=== Generating Windows runner ===" -ForegroundColor Cyan
        & $Flutter create --platforms=windows --project-name pilebox .
    }

    Write-Host "`n=== Fetching packages ===" -ForegroundColor Cyan
    & $Flutter pub get

    # --- 2. Build the Flutter release exe -----------------------------------
    # Pilebox is pure Dart/Flutter - no native bridge DLL to compile. The
    # C++ toolchain checked above is only what flutter build windows itself
    # needs for its own CMake step.
    Write-Host "`n=== Building Flutter release ===" -ForegroundColor Cyan
    & $Flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "Flutter build failed (exit $LASTEXITCODE)." }

    $release = Join-Path $AppDir 'build\windows\x64\runner\Release'
    if (-not (Test-Path $release)) {
        $release = Join-Path $AppDir 'build\windows\runner\Release'
    }

    Write-Host "`n=== Done ===" -ForegroundColor Green
    Write-Host "Folder: $release"
    $exe = Get-ChildItem $release -Filter '*.exe' | Select-Object -First 1
    if ($exe) { Write-Host "Exe   : $($exe.FullName)" }
    Write-Host "`nDistribute the WHOLE Release folder - the exe needs its DLLs beside it."
}
finally {
    Pop-Location
}
