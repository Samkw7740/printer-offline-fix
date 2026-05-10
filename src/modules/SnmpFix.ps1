# =============================================================================
# SnmpFix.ps1 - Disables SNMP status monitoring on printer ports
# =============================================================================
# Windows uses SNMP to query network printer status. When SNMP is enabled but
# the printer doesn't respond fast enough (or at all), Windows decides the
# printer is "offline" — even though it's actually fine and ready to print.
# Disabling SNMP is one of the most reliable long-term fixes for printers
# that randomly go offline after every print job.
# =============================================================================

function Disable-PrinterSnmp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PortName
    )

    Write-Banner "Fix: Disable SNMP monitoring"

    Write-Step "Looking up port '$PortName'..."
    $port = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue

    if (-not $port) {
        Write-Fail "Port not found"
        return $false
    }

    if ($port.Description -notmatch 'Standard TCP') {
        Write-Info "SNMP only applies to Standard TCP/IP ports — skipping"
        return $true
    }

    if ($null -eq $port.SNMPEnabled -or -not $port.SNMPEnabled) {
        Write-Success "SNMP was already disabled"
        return $true
    }

    Write-Step "Disabling SNMP for '$PortName'..."
    try {
        Set-PrinterPort -Name $PortName -SNMP 0 -ErrorAction Stop
        Write-Success "SNMP disabled — printer should stop reporting false offline status"
        return $true
    } catch {
        # Set-PrinterPort sometimes fails on older Windows; fall back to registry
        Write-Warn "Cmdlet failed, trying registry edit..."
        try {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP/IP Port\Ports\$PortName"
            if (Test-Path $regPath) {
                Set-ItemProperty -Path $regPath -Name "SNMP" -Value 0 -Type DWord -ErrorAction Stop
                Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue
                Write-Success "SNMP disabled via registry"
                return $true
            } else {
                Write-Fail "Registry key not found: $regPath"
                return $false
            }
        } catch {
            Write-Fail "Could not disable SNMP: $($_.Exception.Message)"
            return $false
        }
    }
}
