# =============================================================================
# Diagnostics.ps1 - Detects the cause of printer offline issues
# =============================================================================
# Runs a series of read-only checks and reports findings. No changes are made
# in this module. The main script uses these results to decide which fixes
# to apply.
# =============================================================================

function Invoke-PrinterDiagnostics {
    param(
        [Parameter(Mandatory = $true)]
        $Printer
    )

    Write-Banner "Diagnostics: $($Printer.Name)"

    $report = [ordered]@{
        PrinterName     = $Printer.Name
        Status          = $null
        IsOffline       = $false
        SpoolerRunning  = $false
        StuckJobs       = 0
        OfflineFlag     = $false
        PortName        = $null
        PortType        = $null
        SnmpEnabled     = $null
        Reachable       = $null
        DriverName      = $null
        Recommendations = @()
    }

    # --- Status check ---
    Write-Step "Checking printer status..."
    $report.Status = $Printer.PrinterStatus
    if ($Printer.PrinterStatus -ne 'Normal') {
        Write-Warn "Status reports as: $($Printer.PrinterStatus)"
        $report.IsOffline = $true
    } else {
        Write-Success "Status: Normal"
    }

    # --- Print Spooler service ---
    Write-Step "Checking Print Spooler service..."
    $spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    if ($spooler -and $spooler.Status -eq 'Running') {
        Write-Success "Print Spooler is running"
        $report.SpoolerRunning = $true
    } else {
        Write-Fail "Print Spooler is not running"
        $report.Recommendations += "RestartSpooler"
    }

    # --- Stuck print jobs ---
    Write-Step "Checking print queue..."
    try {
        $jobs = Get-PrintJob -PrinterName $Printer.Name -ErrorAction SilentlyContinue
        $report.StuckJobs = ($jobs | Measure-Object).Count
        if ($report.StuckJobs -gt 0) {
            Write-Warn "$($report.StuckJobs) job(s) stuck in queue"
            $report.Recommendations += "ClearQueue"
        } else {
            Write-Success "Queue is empty"
        }
    } catch {
        Write-Info "Queue check skipped: $($_.Exception.Message)"
    }

    # --- "Use Printer Offline" flag ---
    Write-Step "Checking 'Use Printer Offline' flag..."
    try {
        $escapedName = $Printer.Name -replace "'", "''"
        $wmiPrinter = Get-CimInstance -ClassName Win32_Printer -Filter "Name='$escapedName'" -ErrorAction SilentlyContinue
        if ($wmiPrinter -and $wmiPrinter.WorkOffline) {
            Write-Warn "'Use Printer Offline' is enabled"
            $report.OfflineFlag = $true
            $report.Recommendations += "ClearOfflineFlag"
        } else {
            Write-Success "'Use Printer Offline' is disabled"
        }
    } catch {
        Write-Info "Flag check skipped"
    }

    # --- Port info ---
    Write-Step "Checking printer port..."
    try {
        $port = Get-PrinterPort -Name $Printer.PortName -ErrorAction SilentlyContinue
        if ($port) {
            $report.PortName = $port.Name
            if ($port.Description -match 'WSD') {
                $report.PortType = 'WSD'
                Write-Warn "Using WSD port (less reliable than TCP/IP)"
                $report.Recommendations += "ConvertToTcpIp"
            } elseif ($port.Description -match 'Standard TCP') {
                $report.PortType = 'TCP/IP'
                Write-Success "Using Standard TCP/IP port"
            } else {
                $report.PortType = 'Local'
                Write-Info "Local/USB port: $($port.Name)"
            }

            # SNMP check for TCP/IP ports
            if ($null -ne $port.SNMPEnabled) {
                $report.SnmpEnabled = $port.SNMPEnabled
                if ($port.SNMPEnabled) {
                    Write-Info "SNMP monitoring is enabled (can cause false offline reports)"
                    $report.Recommendations += "DisableSnmp"
                }
            }

            # Reachability check for network printers
            if ($port.PrinterHostAddress) {
                Write-Step "Pinging printer at $($port.PrinterHostAddress)..."
                $reachable = Test-Connection -ComputerName $port.PrinterHostAddress -Count 2 -Quiet -ErrorAction SilentlyContinue
                $report.Reachable = $reachable
                if ($reachable) {
                    Write-Success "Printer is reachable on the network"
                } else {
                    Write-Fail "Printer is NOT reachable at $($port.PrinterHostAddress)"
                    $report.Recommendations += "CheckNetwork"
                }
            }
        }
    } catch {
        Write-Info "Port check skipped: $($_.Exception.Message)"
    }

    # --- Driver ---
    $report.DriverName = $Printer.DriverName
    Write-Info "Driver: $($Printer.DriverName)"

    # --- Summary ---
    Write-Host ""
    if ($report.Recommendations.Count -eq 0) {
        Write-Success "No problems detected. The printer looks healthy."
    } else {
        Write-Warn "Detected $($report.Recommendations.Count) issue(s) that can be fixed."
    }

    return $report
}
