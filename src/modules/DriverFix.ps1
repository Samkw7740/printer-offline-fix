# =============================================================================
# DriverFix.ps1 - Driver-related fixes
# =============================================================================
# When a printer driver is corrupted, no amount of service restarting will
# fix the problem. This module offers two options:
#   1. Reset the printer (re-detect via Plug-and-Play)
#   2. Remove and re-add the printer using its current configuration
# Full driver reinstall from manufacturer is left as a manual step (linked
# in docs) since each vendor uses its own installer.
# =============================================================================

function Reset-Printer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Printer
    )

    Write-Banner "Fix: Reset printer registration"

    Write-Warn "This removes the printer from Windows and re-adds it with the same settings."
    Write-Info "The printer will be unavailable for a few seconds."

    if (-not (Read-YesNo -Question "Continue?" -DefaultYes $false)) {
        Write-Info "Skipped"
        return $true
    }

    $name       = $Printer.Name
    $driverName = $Printer.DriverName
    $portName   = $Printer.PortName
    $shared     = $Printer.Shared
    $shareName  = $Printer.ShareName

    Write-Step "Removing printer '$name'..."
    try {
        Remove-Printer -Name $name -ErrorAction Stop
        Write-Success "Removed"
    } catch {
        Write-Fail "Could not remove: $($_.Exception.Message)"
        return $false
    }

    Start-Sleep -Seconds 2

    Write-Step "Re-adding printer with same configuration..."
    try {
        $params = @{
            Name       = $name
            DriverName = $driverName
            PortName   = $portName
        }
        if ($shared -and $shareName) {
            $params['Shared']    = $true
            $params['ShareName'] = $shareName
        }
        Add-Printer @params -ErrorAction Stop
        Write-Success "Printer re-registered"
        return $true
    } catch {
        Write-Fail "Could not re-add: $($_.Exception.Message)"
        Write-Warn "The printer was removed. You may need to re-add it manually from Settings → Bluetooth & devices → Printers."
        return $false
    }
}

function Show-DriverReinstallGuide {
    param(
        [Parameter(Mandatory = $true)]
        $Printer
    )

    Write-Banner "Driver reinstall guide"

    Write-Info "Current driver: $($Printer.DriverName)"
    Write-Host ""
    Write-Host "  To fully reinstall the driver:"
    Write-Host ""
    Write-Host "    1. " -NoNewline -ForegroundColor Cyan
    Write-Host "Note your printer's exact model number"
    Write-Host "    2. " -NoNewline -ForegroundColor Cyan
    Write-Host "Visit the manufacturer's support site:"
    Write-Host "         HP     → https://support.hp.com/drivers" -ForegroundColor Gray
    Write-Host "         Canon  → https://www.canon.com/support" -ForegroundColor Gray
    Write-Host "         Epson  → https://epson.com/Support" -ForegroundColor Gray
    Write-Host "         Brother→ https://support.brother.com" -ForegroundColor Gray
    Write-Host "         Xerox  → https://www.support.xerox.com" -ForegroundColor Gray
    Write-Host "    3. " -NoNewline -ForegroundColor Cyan
    Write-Host "Download the latest Windows 11 / Windows 10 driver"
    Write-Host "    4. " -NoNewline -ForegroundColor Cyan
    Write-Host "Run the installer as Administrator"
    Write-Host "    5. " -NoNewline -ForegroundColor Cyan
    Write-Host "Reboot when prompted"
    Write-Host ""
}
