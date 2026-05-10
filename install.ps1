<#
.SYNOPSIS
    One-line installer for printer-offline-fix.

.DESCRIPTION
    Downloads the latest version from GitHub, extracts it to
    %LOCALAPPDATA%\printer-offline-fix, and runs the main fix tool.

    Designed to be invoked with:
        irm https://raw.githubusercontent.com/Rhythmplocutter/printer-offline-fix/main/install.ps1 | iex

.NOTES
    Requires PowerShell 5.1+ (Windows 10/11 ship with this).
    Requires Administrator privileges (will self-elevate if needed).
#>

$ErrorActionPreference = 'Stop'

$RepoOwner   = 'Rhythmplocutter'
$RepoName    = 'printer-offline-fix'
$Branch      = 'main'
$InstallDir  = Join-Path $env:LOCALAPPDATA 'printer-offline-fix'
$ZipUrl      = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"
$TempZip     = Join-Path $env:TEMP "printer-offline-fix-$([guid]::NewGuid().ToString('N')).zip"
$TempExtract = Join-Path $env:TEMP "printer-offline-fix-extract-$([guid]::NewGuid().ToString('N'))"

function Write-InstallStep {
    param([string]$Message, [string]$Color = 'Cyan')
    Write-Host "  → " -NoNewline -ForegroundColor $Color
    Write-Host $Message -ForegroundColor White
}

function Write-InstallOk {
    param([string]$Message)
    Write-Host "  ✓ " -NoNewline -ForegroundColor Green
    Write-Host $Message -ForegroundColor Green
}

function Write-InstallFail {
    param([string]$Message)
    Write-Host "  ✗ " -NoNewline -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
}

# --- Banner -----------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║       🖨   PRINTER OFFLINE FIX  —  installing...              ║" -ForegroundColor Cyan
Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# --- Self-elevation ---------------------------------------------------------
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-InstallStep "Re-launching with Administrator rights..."
    # Re-run this same script (downloaded fresh) in an elevated PowerShell window
    $cmd = "irm https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/install.ps1 | iex"
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd `
        -Verb RunAs
    exit 0
}

# --- TLS for older PowerShell -----------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    # --- Download ---------------------------------------------------------
    Write-InstallStep "Downloading latest version..."
    Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing
    Write-InstallOk "Downloaded"

    # --- Extract ----------------------------------------------------------
    Write-InstallStep "Extracting..."
    if (Test-Path $TempExtract) { Remove-Item -Recurse -Force $TempExtract }
    Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
    Write-InstallOk "Extracted"

    # GitHub puts the contents inside printer-offline-fix-<branch>/
    $extractedRoot = Get-ChildItem -Path $TempExtract -Directory | Select-Object -First 1
    if (-not $extractedRoot) { throw "Extracted archive is empty." }

    # --- Install ----------------------------------------------------------
    Write-InstallStep "Installing to $InstallDir..."
    if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Copy-Item -Path (Join-Path $extractedRoot.FullName '*') -Destination $InstallDir -Recurse -Force
    Write-InstallOk "Installed"

    # --- Cleanup temp files ----------------------------------------------
    Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $TempExtract -Recurse -Force -ErrorAction SilentlyContinue

    # --- Run ----------------------------------------------------------
    $mainScript = Join-Path $InstallDir 'src\Fix-PrinterOffline.ps1'
    if (-not (Test-Path $mainScript)) {
        throw "Main script not found at $mainScript"
    }

    Write-Host ""
    Write-InstallOk "Installation complete!"
    Write-Host ""
    Write-Host "  Launching the fix tool now..." -ForegroundColor Gray
    Write-Host "  (To run again later: " -NoNewline -ForegroundColor Gray
    Write-Host "& '$mainScript'" -NoNewline -ForegroundColor Yellow
    Write-Host ")" -ForegroundColor Gray
    Write-Host ""
    Start-Sleep -Seconds 2

    & $mainScript

} catch {
    Write-Host ""
    Write-InstallFail "Installation failed: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "  Please report this at:" -ForegroundColor Gray
    Write-Host "  https://github.com/$RepoOwner/$RepoName/issues" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}
