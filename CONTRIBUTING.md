# Contributing

Thanks for thinking about contributing. The most useful things you can do are:

## Report a printer that works (or doesn't)

This is genuinely valuable — we add tested printer models to the README so others know it'll work for them. Open an issue with the title "Tested with: <make> <model>" and include:

- Make and model
- Connection type (USB / Wi-Fi / Ethernet / print server)
- What problem you had
- Whether the tool fixed it
- Windows version

## Report a bug

Open an issue with:

1. What you expected to happen
2. What actually happened
3. The contents of `%TEMP%\printer-offline-fix.log` from the failing run
4. Output of:
   ```powershell
   $PSVersionTable
   Get-Printer | Format-List Name, PrinterStatus, PortName, DriverName
   ```

Strip any IPs or printer names you don't want public.

## Add a new fix module

The pattern is:

1. Create a `.ps1` file in `src/modules/`.
2. Export one or more functions following the `Verb-Noun` PowerShell convention.
3. Use `Write-Banner`, `Write-Step`, `Write-Success`, `Write-Warn`, `Write-Fail`, `Write-Info` from `lib/Common.ps1` for output.
4. Return `$true` on success, `$false` on failure — the caller decides what to do.
5. Add a dot-source line in `src/Fix-PrinterOffline.ps1` and wire up a menu entry.
6. Add a brief description to `docs/HOW_IT_WORKS.md`.

Keep modules focused — one fix per file. Diagnostics belong in `Diagnostics.ps1`, not in each fix module.

## Code style

- 4-space indent.
- One blank line between functions.
- Comment-based help (`<# .SYNOPSIS ... #>`) for any function called by other modules.
- No aliases in committed code (`Get-ChildItem`, not `gci`).
- `$ErrorActionPreference = 'Stop'` for code that needs to fail loudly; explicit `-ErrorAction SilentlyContinue` for code that should keep going.
- No external dependencies. Everything must run on a clean Windows 10/11 install with built-in PowerShell 5.1.

## Pull request checklist

- [ ] Tested locally on at least one Windows machine
- [ ] No new external dependencies
- [ ] No telemetry, no network calls outside the install download
- [ ] No code that requires signing
- [ ] Docs updated if you changed behavior
- [ ] CHANGELOG.md updated under the next-version section

## Development setup

```powershell
# Clone
git clone https://github.com/Rhythmplocutter/printer-offline-fix.git
cd printer-offline-fix

# Run from source
powershell.exe -ExecutionPolicy Bypass -File .\src\Fix-PrinterOffline.ps1

# Run tests (requires Pester)
Install-Module Pester -Scope CurrentUser -Force
Invoke-Pester .\tests\
```

## Code of conduct

Be kind. Don't be a jerk. We're all trying to print stuff.
