<#
.SYNOPSIS
    printer-offline-fix — One-stop tool to fix the "Printer Offline" issue on Windows.

.DESCRIPTION
    Diagnoses why your printer shows as offline and applies the right fix
    automatically. Handles the most common causes:
      - Stuck Print Spooler service
      - Frozen jobs in the print queue
      - "Use Printer Offline" flag stuck on
      - SNMP false-offline reports on TCP/IP ports
      - WSD ports flapping between online/offline
      - Stopped printer-related services
      - Corrupted printer registration

.PARAMETER Auto
    Run in automatic mode — applies all safe fixes without prompting.

.PARAMETER Printer
    Target a specific printer by name. If omitted, you'll be asked to choose.

.PARAMETER DiagnoseOnly
    Run diagnostics only — make no changes.

.EXAMPLE
    .\Fix-PrinterOffline.ps1
    Interactive mode — pick the printer, choose which fixes to apply.

.EXAMPLE
    .\Fix-PrinterOffline.ps1 -Auto
    Apply all safe fixes to the default printer with no prompts.

.EXAMPLE
    .\Fix-PrinterOffline.ps1 -Printer "HP LaserJet" -DiagnoseOnly
    Just check what's wrong with the named printer.

.LINK
    https://github.com/Rhythmplocutter/printer-offline-fix
#>

[CmdletBinding()]
param(
    [switch]$Auto,
    [string]$Printer,
    [switch]$DiagnoseOnly
)

# --- Resolve script root ---
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# --- Load library and modules ---
. (Join-Path $scriptRoot "lib\Common.ps1")
. (Join-Path $scriptRoot "modules\Diagnostics.ps1")
. (Join-Path $scriptRoot "modules\SpoolerFix.ps1")
. (Join-Path $scriptRoot "modules\OfflineFlagFix.ps1")
. (Join-Path $scriptRoot "modules\SnmpFix.ps1")
. (Join-Path $scriptRoot "modules\PortFix.ps1")
. (Join-Path $scriptRoot "modules\ServicesFix.ps1")
. (Join-Path $scriptRoot "modules\DriverFix.ps1")

# --- Banner -------------------------------------------------------------
function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                               ║" -ForegroundColor Cyan
    Write-Host "  ║       " -NoNewline -ForegroundColor Cyan
    Write-Host "🖨   PRINTER OFFLINE FIX  " -NoNewline -ForegroundColor White
    Write-Host "v1.0.0                       ║" -ForegroundColor Cyan
    Write-Host "  ║       " -NoNewline -ForegroundColor Cyan
    Write-Host "Bring your Windows printer back online — fast." -NoNewline -ForegroundColor Gray
    Write-Host "        ║" -ForegroundColor Cyan
    Write-Host "  ║                                                               ║" -ForegroundColor Cyan
    Write-Host "  ║       " -NoNewline -ForegroundColor Cyan
    Write-Host "github.com/Rhythmplocutter/printer-offline-fix" -NoNewline -ForegroundColor DarkGray
    Write-Host "         ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# --- Apply recommended fixes based on diagnostics ---------------------
function Invoke-RecommendedFixes {
    param(
        $Report,
        $Printer,
        [bool]$AutoApply
    )

    $recs = $Report.Recommendations
    if ($recs.Count -eq 0) {
        Write-Success "Nothing to fix — printer is healthy."
        return
    }

    Write-Banner "Applying $($recs.Count) recommended fix(es)"

    foreach ($rec in $recs) {
        switch ($rec) {
            'RestartSpooler' {
                if ($AutoApply -or (Read-YesNo "Restart the Print Spooler?" $true)) {
                    Repair-PrintSpooler -ClearQueue:$false | Out-Null
                }
            }
            'ClearQueue' {
                if ($AutoApply -or (Read-YesNo "Clear stuck print jobs?" $true)) {
                    Repair-PrintSpooler -ClearQueue | Out-Null
                }
            }
            'ClearOfflineFlag' {
                if ($AutoApply -or (Read-YesNo "Clear 'Use Printer Offline' flag?" $true)) {
                    Clear-OfflineFlag -PrinterName $Printer.Name | Out-Null
                }
            }
            'DisableSnmp' {
                if ($AutoApply -or (Read-YesNo "Disable SNMP monitoring?" $true)) {
                    Disable-PrinterSnmp -PortName $Printer.PortName | Out-Null
                }
            }
            'ConvertToTcpIp' {
                if (-not $AutoApply) {
                    # Always interactive — needs the printer's IP
                    if (Read-YesNo "Convert WSD port to TCP/IP? (more reliable)" $true) {
                        Convert-WsdToTcpIp -Printer $Printer | Out-Null
                    }
                }
                # In auto mode we skip this — needs user input for IP
            }
            'CheckNetwork' {
                Write-Banner "Network unreachable"
                Write-Warn "The printer's IP did not respond to ping."
                Write-Info "Check that:"
                Write-Info "  - the printer is powered on"
                Write-Info "  - it's on the same network as this PC"
                Write-Info "  - no firewall is blocking it"
                Write-Info "  - the IP address hasn't changed (DHCP renewals can do this)"
            }
        }
    }
}

# --- Interactive menu --------------------------------------------------
function Show-Menu {
    param($Printer)

    while ($true) {
        Write-Host ""
        Write-Banner "What would you like to do for '$($Printer.Name)'?"
        $choice = Read-Choice -Prompt "Pick an option:" -Options @(
            "Run diagnostics only (no changes)",
            "Apply all recommended fixes (auto)",
            "Restart Print Spooler + clear queue",
            "Clear 'Use Printer Offline' flag",
            "Disable SNMP monitoring",
            "Convert WSD port to TCP/IP",
            "Restart all printer-related services",
            "Reset printer registration",
            "Show driver reinstall guide",
            "Quit"
        )

        switch ($choice) {
            0 { Invoke-PrinterDiagnostics -Printer $Printer | Out-Null }
            1 {
                $report = Invoke-PrinterDiagnostics -Printer $Printer
                Invoke-RecommendedFixes -Report $report -Printer $Printer -AutoApply $true
            }
            2 { Repair-PrintSpooler -ClearQueue | Out-Null }
            3 { Clear-OfflineFlag -PrinterName $Printer.Name | Out-Null }
            4 { Disable-PrinterSnmp -PortName $Printer.PortName | Out-Null }
            5 { Convert-WsdToTcpIp -Printer $Printer | Out-Null }
            6 { Repair-PrinterServices | Out-Null }
            7 {
                Reset-Printer -Printer $Printer | Out-Null
                # Refresh printer object after potential rename/recreate
                $Printer = Get-Printer -Name $Printer.Name -ErrorAction SilentlyContinue
                if (-not $Printer) {
                    Write-Warn "Printer was removed and could not be re-acquired. Exiting."
                    return
                }
            }
            8 { Show-DriverReinstallGuide -Printer $Printer }
            9 { return }
        }
    }
}

# ============================================================================
# MAIN
# ============================================================================

Show-Header
Initialize-Log
Assert-Admin

Write-Info "Log file: $(Get-LogPath)"

# Resolve target printer
$target = $null
if ($Printer) {
    $target = Get-Printer -Name $Printer -ErrorAction SilentlyContinue
    if (-not $target) {
        Write-Fail "Printer '$Printer' not found."
        Write-Info "Available printers:"
        Get-PrinterList | ForEach-Object { Write-Info "  - $($_.Name)" }
        exit 1
    }
} else {
    $target = Select-PrinterInteractive
    if (-not $target) {
        Write-Fail "No printer selected. Exiting."
        exit 1
    }
}

# Execute the chosen path
$report = Invoke-PrinterDiagnostics -Printer $target

if ($DiagnoseOnly) {
    Write-Host ""
    Write-Info "Diagnose-only mode — no changes were made."
    exit 0
}

if ($Auto) {
    Invoke-RecommendedFixes -Report $report -Printer $target -AutoApply $true
    Write-Host ""
    Write-Banner "Done"
    Write-Success "All safe fixes applied. Try printing now."
    Write-Info "If the issue persists, run without -Auto to use the interactive menu."
} else {
    Show-Menu -Printer $target
    Write-Host ""
    Write-Success "Goodbye! 🖨"
}
