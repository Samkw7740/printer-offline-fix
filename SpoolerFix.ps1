# =============================================================================
# SpoolerFix.ps1 - Print Spooler service restart and queue cleanup
# =============================================================================
# This is the single most effective fix for the "printer offline" issue:
# stop the spooler, delete stuck jobs, restart it. Roughly 60-70% of cases
# are resolved by this alone.
# =============================================================================

function Repair-PrintSpooler {
    [CmdletBinding()]
    param(
        [switch]$ClearQueue
    )

    Write-Banner "Fix: Print Spooler"

    # Stop the service
    Write-Step "Stopping Print Spooler service..."
    try {
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        Write-Success "Spooler stopped"
    } catch {
        Write-Fail "Could not stop Spooler: $($_.Exception.Message)"
        return $false
    }

    # Wait for the service to fully stop (it can be slow)
    $maxWait = 15
    $waited = 0
    while ((Get-Service Spooler).Status -ne 'Stopped' -and $waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
    }

    # Clear stuck jobs from the spool folder
    if ($ClearQueue) {
        Write-Step "Clearing stuck print jobs..."
        $spoolDir = Join-Path $env:SystemRoot "System32\spool\PRINTERS"
        if (Test-Path $spoolDir) {
            try {
                $files = Get-ChildItem -Path $spoolDir -File -ErrorAction Stop
                $count = $files.Count
                if ($count -eq 0) {
                    Write-Info "Spool folder was already empty"
                } else {
                    $files | Remove-Item -Force -ErrorAction Stop
                    Write-Success "Removed $count stuck job file(s)"
                }
            } catch {
                Write-Fail "Could not clear queue: $($_.Exception.Message)"
            }
        } else {
            Write-Info "Spool folder not found (unusual but not fatal)"
        }
    }

    # Start the service back up
    Write-Step "Starting Print Spooler service..."
    try {
        Start-Service -Name Spooler -ErrorAction Stop

        # Make sure the spooler is set to start automatically
        Set-Service -Name Spooler -StartupType Automatic -ErrorAction SilentlyContinue

        Write-Success "Spooler started and set to Automatic"
        return $true
    } catch {
        Write-Fail "Could not start Spooler: $($_.Exception.Message)"
        return $false
    }
}

function Clear-PrinterQueue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName
    )

    Write-Step "Clearing queue for '$PrinterName'..."
    try {
        $jobs = Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue
        if (-not $jobs) {
            Write-Info "No active jobs"
            return $true
        }
        $count = ($jobs | Measure-Object).Count
        $jobs | Remove-PrintJob -ErrorAction SilentlyContinue
        Write-Success "Removed $count job(s)"
        return $true
    } catch {
        Write-Fail "Queue clear failed: $($_.Exception.Message)"
        return $false
    }
}
