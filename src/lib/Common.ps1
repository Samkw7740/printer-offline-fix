# =============================================================================
# Common.ps1 - Shared utilities for printer-offline-fix
# =============================================================================
# Logging, colored output, admin elevation, user prompts, and helper functions.
# This file is dot-sourced by every module and the main entry point.
# =============================================================================

# --- Global state -----------------------------------------------------------
$script:LogFile = Join-Path $env:TEMP "printer-offline-fix.log"
$script:VerboseMode = $false

# --- Colored console output -------------------------------------------------
function Write-Banner {
    param([string]$Text)
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │ $($Text.PadRight(59)) │" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "  → " -NoNewline -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor White
    Add-LogEntry -Level "STEP" -Message $Text
}

function Write-Success {
    param([string]$Text)
    Write-Host "  ✓ " -NoNewline -ForegroundColor Green
    Write-Host $Text -ForegroundColor Green
    Add-LogEntry -Level "OK" -Message $Text
}

function Write-Warn {
    param([string]$Text)
    Write-Host "  ! " -NoNewline -ForegroundColor Yellow
    Write-Host $Text -ForegroundColor Yellow
    Add-LogEntry -Level "WARN" -Message $Text
}

function Write-Fail {
    param([string]$Text)
    Write-Host "  ✗ " -NoNewline -ForegroundColor Red
    Write-Host $Text -ForegroundColor Red
    Add-LogEntry -Level "FAIL" -Message $Text
}

function Write-Info {
    param([string]$Text)
    Write-Host "    " -NoNewline
    Write-Host $Text -ForegroundColor Gray
    Add-LogEntry -Level "INFO" -Message $Text
}

# --- Logging ----------------------------------------------------------------
function Add-LogEntry {
    param(
        [string]$Level,
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -Path $script:LogFile -Value $line -ErrorAction SilentlyContinue
    } catch {
        # Silent — logging must never break the tool itself.
    }
}

function Initialize-Log {
    $header = @"
================================================================================
printer-offline-fix log
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
PowerShell: $($PSVersionTable.PSVersion)
OS: $((Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption)
================================================================================
"@
    Set-Content -Path $script:LogFile -Value $header -ErrorAction SilentlyContinue
}

function Get-LogPath { return $script:LogFile }

# --- Admin elevation --------------------------------------------------------
function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Admin {
    if (-not (Test-IsAdmin)) {
        Write-Fail "This tool must be run as Administrator."
        Write-Info "Right-click PowerShell and choose 'Run as administrator', then try again."
        exit 1
    }
}

# --- User prompts -----------------------------------------------------------
function Read-YesNo {
    param(
        [string]$Question,
        [bool]$DefaultYes = $true
    )
    $hint = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    Write-Host "  ? " -NoNewline -ForegroundColor Magenta
    Write-Host "$Question $hint " -NoNewline -ForegroundColor White
    $answer = Read-Host
    if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultYes }
    return $answer -match '^[Yy]'
}

function Read-Choice {
    param(
        [string]$Prompt,
        [string[]]$Options
    )
    Write-Host ""
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "    [$($i + 1)] " -NoNewline -ForegroundColor Cyan
        Write-Host $Options[$i] -ForegroundColor White
    }
    Write-Host ""
    while ($true) {
        Write-Host "  ? " -NoNewline -ForegroundColor Magenta
        Write-Host "$Prompt " -NoNewline -ForegroundColor White
        $answer = Read-Host
        if ($answer -match '^\d+$') {
            $idx = [int]$answer - 1
            if ($idx -ge 0 -and $idx -lt $Options.Count) {
                return $idx
            }
        }
        Write-Warn "Please enter a number between 1 and $($Options.Count)."
    }
}

# --- Helpers ----------------------------------------------------------------
function Get-PrinterList {
    try {
        return Get-Printer -ErrorAction Stop
    } catch {
        Write-Fail "Could not enumerate printers: $($_.Exception.Message)"
        return @()
    }
}

function Select-PrinterInteractive {
    $printers = Get-PrinterList
    if ($printers.Count -eq 0) {
        Write-Warn "No printers were found on this system."
        return $null
    }
    if ($printers.Count -eq 1) {
        Write-Info "Only one printer found: $($printers[0].Name)"
        return $printers[0]
    }
    $names = $printers | ForEach-Object { "$($_.Name)  ($($_.PrinterStatus))" }
    $idx = Read-Choice -Prompt "Pick a printer:" -Options $names
    return $printers[$idx]
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}
