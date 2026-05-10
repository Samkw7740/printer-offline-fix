# =============================================================================
# PortFix.ps1 - Converts unreliable WSD ports to Standard TCP/IP
# =============================================================================
# WSD (Web Services for Devices) is Microsoft's auto-discovery protocol for
# network printers. It's convenient but notoriously unreliable — printers
# using WSD frequently report as offline because of failed discovery
# broadcasts. Converting to a Standard TCP/IP port using the printer's IP
# address is dramatically more stable.
# =============================================================================

function Convert-WsdToTcpIp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Printer
    )

    Write-Banner "Fix: Convert WSD port to TCP/IP"

    $port = Get-PrinterPort -Name $Printer.PortName -ErrorAction SilentlyContinue
    if (-not $port) {
        Write-Fail "Could not find current port"
        return $false
    }

    if ($port.Description -notmatch 'WSD') {
        Write-Info "Printer is not on a WSD port — skipping"
        return $true
    }

    Write-Warn "Printer is on a WSD port. Converting to TCP/IP requires the printer's IP address."
    Write-Info "Find the IP on the printer's display, or print a network config page."

    Write-Host ""
    Write-Host "  ? " -NoNewline -ForegroundColor Magenta
    Write-Host "Enter the printer's IP address (or blank to skip): " -NoNewline -ForegroundColor White
    $ip = Read-Host

    if ([string]::IsNullOrWhiteSpace($ip)) {
        Write-Info "Skipped — keeping WSD port"
        return $true
    }

    if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
        Write-Fail "That doesn't look like a valid IPv4 address"
        return $false
    }

    # Test connectivity before doing anything destructive
    Write-Step "Pinging $ip..."
    if (-not (Test-Connection -ComputerName $ip -Count 2 -Quiet -ErrorAction SilentlyContinue)) {
        Write-Fail "$ip is not reachable. Aborting to avoid breaking the printer setup."
        return $false
    }
    Write-Success "Printer reachable at $ip"

    $newPortName = "IP_$ip"

    # Create the new port if it doesn't already exist
    if (-not (Get-PrinterPort -Name $newPortName -ErrorAction SilentlyContinue)) {
        Write-Step "Creating Standard TCP/IP port '$newPortName'..."
        try {
            Add-PrinterPort -Name $newPortName -PrinterHostAddress $ip -ErrorAction Stop
            Write-Success "Port created"
        } catch {
            Write-Fail "Could not create port: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-Info "Port '$newPortName' already exists; reusing it"
    }

    # Move the printer to the new port
    Write-Step "Moving printer to new port..."
    try {
        Set-Printer -Name $Printer.Name -PortName $newPortName -ErrorAction Stop
        Write-Success "Printer is now on TCP/IP port $newPortName"

        # Disable SNMP on the new port immediately — best-practice default
        try {
            Set-PrinterPort -Name $newPortName -SNMP 0 -ErrorAction SilentlyContinue
            Write-Info "SNMP also disabled on the new port"
        } catch { }

        return $true
    } catch {
        Write-Fail "Could not switch port: $($_.Exception.Message)"
        return $false
    }
}
