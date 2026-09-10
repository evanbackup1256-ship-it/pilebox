# One-time toolchain setup for building the Flutter app as a Windows .exe.
#
# Installs: Visual Studio 2022 Build Tools (C++ workload) + the Flutter SDK.
# Safe to re-run: each step is skipped if already present.
#
# Run in a NORMAL PowerShell window (it will prompt for admin only for VS).

$ErrorActionPreference = 'Stop'
$FlutterVersion = '3.47.3'
$FlutterRoot    = 'C:\src\flutter'

Write-Host "`n=== 1/3  Visual Studio Build Tools (C++) ===" -ForegroundColor Cyan

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$hasCpp = $false
if (Test-Path $vswhere) {
    $found = & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName
    if ($found) { $hasCpp = $true }
}

if ($hasCpp) {
    Write-Host "Already installed: $found" -ForegroundColor Green
} else {
    Write-Host "Installing (several GB, this takes a while)..." -ForegroundColor Yellow
    winget install --id Microsoft.VisualStudio.2022.BuildTools --accept-source-agreements --accept-package-agreements `
        --override "--quiet --wait --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended"
    Write-Host "Visual Studio Build Tools installed." -ForegroundColor Green
}

Write-Host "`n=== 2/3  Flutter SDK ===" -ForegroundColor Cyan

if (Test-Path "$FlutterRoot\bin\flutter.bat") {
    Write-Host "Already present at $FlutterRoot" -ForegroundColor Green
} else {
    $zip = "$env:TEMP\flutter_windows_$FlutterVersion-stable.zip"
    $url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FlutterVersion-stable.zip"

    Write-Host "Downloading Flutter $FlutterVersion (~1 GB)..." -ForegroundColor Yellow
    # Progress rendering makes Invoke-WebRequest dramatically slower on big files.
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $url -OutFile $zip

    Write-Host "Extracting to $FlutterRoot..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path (Split-Path $FlutterRoot) | Out-Null
    Expand-Archive -Path $zip -DestinationPath (Split-Path $FlutterRoot) -Force
    Remove-Item $zip -Force
    Write-Host "Flutter extracted." -ForegroundColor Green
}

# Add to the user PATH permanently, and to this session so the next step works.
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$FlutterRoot\bin*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$FlutterRoot\bin", 'User')
    Write-Host "Added $FlutterRoot\bin to your user PATH." -ForegroundColor Green
}
$env:Path = "$env:Path;$FlutterRoot\bin"

Write-Host "`n=== 3/3  Verifying ===" -ForegroundColor Cyan
& "$FlutterRoot\bin\flutter.bat" config --enable-windows-desktop
& "$FlutterRoot\bin\flutter.bat" doctor -v

Write-Host "`nSetup finished. Open a NEW terminal, then run: .\build_exe.ps1" -ForegroundColor Cyan
