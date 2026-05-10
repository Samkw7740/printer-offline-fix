# =============================================================================
# OfflineFlagFix.ps1 - Clears the "Use Printer Offline" flag
# =============================================================================
# Each printer has a WorkOffline boolean in WMI/CIM. When it's set, Windows
# queues jobs locally instead of sending them to the printer, and the printer
# shows "Offline" in the UI. The flag can be toggled by:
#   - User accidentally clicking "Use Printer Offline" in the print queue
#   - Buggy vendor printer software
#   - Windows itself, after a failed print job
# This module clears the flag. If the WMI write fails (rare, usually due to
# locked-down systems), it falls back to a spooler restart, which clears
# the flag as a side effect.
# =============================================================================

function Clear-OfflineFlag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName
    )

    Write-Banner "Fix: Use Printer Offline flag"

    # Escape single quotes for WMI's WQL filter syntax
    $escapedName = $PrinterName -replace "'", "''"

    Write-Step "Looking up '$PrinterName' in WMI..."
    $printer = Get-CimInstance -ClassName Win32_Printer `
        -Filter "Name='$escapedName'" `
        -ErrorAction SilentlyContinue

    if (-not $printer) {
        Write-Fail "Printer not found in WMI"
        return $false
    }

    if (-not $printer.WorkOffline) {
        Write-Success "Flag was already cleared"
        return $true
    }

    Write-Step "Clearing 'Use Printer Offline' flag..."
    try {
        # Set-CimInstance is the modern replacement for the legacy .Put() method
        # and works on both Windows PowerShell 5.1 and PowerShell 7+
        Set-CimInstance -InputObject $printer `
            -Property @{ WorkOffline = $false } `
            -ErrorAction Stop

        Write-Success "'Use Printer Offline' flag cleared"
        return $true
    }
    catch {
        Write-Warn "WMI write failed: $($_.Exception.Message)"
        Write-Step "Trying spooler restart as a fallback..."

        # Restarting the spooler usually clears the flag as a side effect,
        # because the WorkOffline state is held in spooler memory.
        try {
            Restart-Service -Name Spooler -Force -ErrorAction Stop
            Start-Sleep -Seconds 2

            # Re-query to verify
            $printer = Get-CimInstance -ClassName Win32_Printer `
                -Filter "Name='$escapedName'" `
                -ErrorAction SilentlyContinue

            if ($printer -and -not $printer.WorkOffline) {
                Write-Success "Spooler restart cleared the flag"
                return $true
            }
            else {
                Write-Warn "Spooler restarted, but the flag may still be set"
                Write-Info "You may need to manually uncheck 'Use Printer Offline' in the print queue:"
                Write-Info "  Settings -> Bluetooth & devices -> Printers -> '$PrinterName' -> Open print queue -> Printer menu"
                return $false
            }
        }
        catch {
            Write-Fail "Spooler restart failed: $($_.Exception.Message)"
            return $false
        }
    }
}
