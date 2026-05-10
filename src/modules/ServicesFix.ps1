# =============================================================================
# ServicesFix.ps1 - Restart all printer-related Windows services
# =============================================================================
# Several Windows services need to be running for printing to work properly.
# When any of them is stopped or stuck, the printer can appear offline.
# This module ensures they're all running and set to start automatically.
# =============================================================================

function Repair-PrinterServices {
    [CmdletBinding()]
    param()

    Write-Banner "Fix: Printer-related services"

    # Services required (or strongly recommended) for printing:
    #   Spooler                — the print spooler itself
    #   PrintNotify            — handles printer notifications
    #   FDResPub              — Function Discovery Resource Publication (WSD)
    #   FDPHost               — Function Discovery Provider Host (WSD)
    #   SSDPSRV               — SSDP discovery (WSD)
    #   upnphost              — UPnP device host (WSD)
    $services = @(
        @{ Name = 'Spooler';        Required = $true;  Description = 'Print Spooler' },
        @{ Name = 'PrintNotify';    Required = $false; Description = 'Printer Extensions and Notifications' },
        @{ Name = 'FDResPub';       Required = $false; Description = 'Function Discovery (network printers)' },
        @{ Name = 'FDPHost';        Required = $false; Description = 'Function Discovery Host (network printers)' },
        @{ Name = 'SSDPSRV';        Required = $false; Description = 'SSDP Discovery (network printers)' }
    )

    $results = @()

    foreach ($svc in $services) {
        $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if (-not $service) {
            if ($svc.Required) {
                Write-Fail "$($svc.Description) ($($svc.Name)) not found — this is unusual"
            } else {
                Write-Info "$($svc.Description) not present (OK on this system)"
            }
            continue
        }

        Write-Step "$($svc.Description)..."

        try {
            # Set startup type to Automatic (or Manual for optional ones)
            $startupType = if ($svc.Required) { 'Automatic' } else { 'Manual' }
            Set-Service -Name $svc.Name -StartupType $startupType -ErrorAction SilentlyContinue

            if ($service.Status -eq 'Running') {
                if ($svc.Required) {
                    # Restart required services to clear any stuck state
                    Restart-Service -Name $svc.Name -Force -ErrorAction Stop
                    Write-Success "Restarted"
                } else {
                    Write-Success "Already running"
                }
            } else {
                Start-Service -Name $svc.Name -ErrorAction Stop
                Write-Success "Started"
            }
            $results += $true
        } catch {
            Write-Fail "Failed: $($_.Exception.Message)"
            $results += $false
        }
    }

    $okCount = ($results | Where-Object { $_ }).Count
    Write-Host ""
    Write-Info "$okCount of $($results.Count) services healthy"

    return ($results -notcontains $false)
}
