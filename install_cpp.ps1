# Installs the C++ toolchain into the existing Visual Studio Build Tools 2022.
#
# Build Tools is registered but has no MSVC compiler: the earlier
# `winget --override` did not apply, which is common when the product is
# already installed. `setup.exe modify` is the reliable path.
#
# MUST run elevated. Re-run is safe.

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Elevation required - relaunching as administrator..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', "`"$PSCommandPath`""
    )
    Write-Host "Approve the UAC prompt. This window can be closed."
    return
}

$installer = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer"
$setup   = Join-Path $installer 'setup.exe'
$vswhere = Join-Path $installer 'vswhere.exe'

if (-not (Test-Path $setup)) {
    throw "Visual Studio Installer not found. Install Build Tools 2022 first."
}

$vsPath = & $vswhere -products * -property installationPath | Select-Object -First 1
if (-not $vsPath) { throw "No Visual Studio product found." }

Write-Host "Modifying: $vsPath" -ForegroundColor Cyan
Write-Host "Installing C++ workload (several GB, please wait)..." -ForegroundColor Yellow

# NOTE: `setup.exe modify` does NOT accept --wait (that flag belongs to the
# vs_installer bootstrapper). Passing it fails immediately with exit code 87.
# Start-Process -Wait handles the blocking instead.
$args = @(
    'modify'
    '--installPath', $vsPath
    '--add', 'Microsoft.VisualStudio.Workload.VCTools'
    '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
    '--add', 'Microsoft.VisualStudio.Component.VC.CMake.Project'
    '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621'
    '--includeRecommended'
    # --passive shows a progress bar. A multi-GB --quiet install looks
    # indistinguishable from a hang.
    '--passive'
    '--norestart'
)

$proc = Start-Process -FilePath $setup -ArgumentList $args -Wait -PassThru
# 3010 = success, reboot recommended.
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    $hint = if ($proc.ExitCode -eq 87) {
        " (invalid argument - check the newest %TEMP%\dd_installer_*.log)"
    } else { '' }
    throw "Installer exited with code $($proc.ExitCode)$hint."
}

Write-Host "`nVerifying..." -ForegroundColor Cyan
$ok = & $vswhere -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath

if ($ok) {
    $toolsets = Get-ChildItem "$ok\VC\Tools\MSVC" -Directory -ErrorAction SilentlyContinue
    Write-Host "C++ tools installed. MSVC toolset: $($toolsets.Name -join ', ')" -ForegroundColor Green
    Write-Host "`nNext: .\build_exe.ps1" -ForegroundColor Cyan
} else {
    throw "Install reported success but VC tools are still missing."
}

Write-Host "`nPress Enter to close."
[void][Console]::ReadLine()
