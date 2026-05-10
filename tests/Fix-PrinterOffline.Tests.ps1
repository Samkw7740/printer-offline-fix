# =============================================================================
# Fix-PrinterOffline.Tests.ps1 - Pester tests
# =============================================================================
# Run with:
#   Install-Module Pester -Scope CurrentUser -Force
#   Invoke-Pester .\tests\
# =============================================================================

BeforeAll {
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $script:ProjectRoot "src\lib\Common.ps1")
}

Describe "Common library" {

    Context "Test-IsAdmin" {
        It "returns a boolean" {
            $result = Test-IsAdmin
            $result | Should -BeOfType [bool]
        }
    }

    Context "Logging" {
        It "writes log entries without error" {
            { Add-LogEntry -Level "TEST" -Message "unit test entry" } | Should -Not -Throw
        }

        It "Initialize-Log creates the log file" {
            Initialize-Log
            Test-Path (Get-LogPath) | Should -Be $true
        }

        It "Get-LogPath returns a non-empty string" {
            (Get-LogPath) | Should -Not -BeNullOrEmpty
        }
    }

    Context "Test-Command" {
        It "returns true for an existing command" {
            Test-Command "Get-Process" | Should -Be $true
        }
        It "returns false for a non-existent command" {
            Test-Command "Get-DoesNotExistAnywhere-XYZ" | Should -Be $false
        }
    }
}

Describe "Module loading" {
    It "loads Diagnostics.ps1 without parse errors" {
        $path = Join-Path $script:ProjectRoot "src\modules\Diagnostics.ps1"
        Test-Path $path | Should -Be $true
        { . $path } | Should -Not -Throw
    }

    It "loads SpoolerFix.ps1 without parse errors" {
        $path = Join-Path $script:ProjectRoot "src\modules\SpoolerFix.ps1"
        { . $path } | Should -Not -Throw
    }

    It "loads OfflineFlagFix.ps1 without parse errors" {
        $path = Join-Path $script:ProjectRoot "src\modules\OfflineFlagFix.ps1"
        { . $path } | Should -Not -Throw
    }

    It "loads SnmpFix.ps1 without parse errors" {
        $path = Join-Path $script:ProjectRoot "src\modules\SnmpFix.ps1"
        { . $path } | Should -Not -Throw
    }

    It "loads PortFix.ps1 without parse errors" {
        $path = Join-Path $script:ProjectRoot "src\modules\PortFix.ps1"
        { . $path } | Should -Not -Throw
    }

    It "loads ServicesFix.ps1 without parse errors" {
        $path = Join-Path $script:ProjectRoot "src\modules\ServicesFix.ps1"
        { . $path } | Should -Not -Throw
    }

    It "loads DriverFix.ps1 without parse errors" {
        $path = Join-Path $script:ProjectRoot "src\modules\DriverFix.ps1"
        { . $path } | Should -Not -Throw
    }
}

Describe "Main script" {
    It "Fix-PrinterOffline.ps1 parses cleanly" {
        $path = Join-Path $script:ProjectRoot "src\Fix-PrinterOffline.ps1"
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    It "install.ps1 parses cleanly" {
        $path = Join-Path $script:ProjectRoot "install.ps1"
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }
}
