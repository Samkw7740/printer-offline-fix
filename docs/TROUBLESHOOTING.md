# Troubleshooting

When `printer-offline-fix` runs but the printer is still offline.

## Step 0 — Check the log

Every run writes to `%TEMP%\printer-offline-fix.log`. Open it and look at the last entries — failed steps are tagged `[FAIL]` and include the underlying error.

```powershell
notepad "$env:TEMP\printer-offline-fix.log"
```

## "Access is denied" on every fix

You're not running as Administrator. Close PowerShell, right-click it, choose **Run as administrator**, and try again. The installer auto-elevates, but if you're running the script directly afterwards it doesn't.

## "The Print Spooler service could not be started"

Usually means a third-party printer service is locking the spooler. Try:

```powershell
Get-Service | Where-Object { $_.Name -like "*print*" -or $_.Name -like "*HP*" -or $_.Name -like "*Canon*" -or $_.Name -like "*Epson*" -or $_.Name -like "*Brother*" } | Stop-Service -Force
Start-Service Spooler
```

Then run the tool again.

## Tool reports everything fixed but printer is still offline

Three likely causes:

1. **The printer is genuinely offline** — powered off, asleep, on the wrong Wi-Fi, IP changed. Walk to the printer, check the display.
2. **Antivirus is blocking the spooler.** Norton, McAfee, Avast, and Bitdefender have all been reported to block printer ports. Temporarily disable real-time protection, try printing, re-enable.
3. **A pending Windows update broke printing.** Microsoft has shipped multiple Patch-Tuesday updates over the years that broke specific printer drivers. Check `winver`, then search "Windows <build number> printer issues".

## "WSD port conversion" prompts for IP but I don't know it

Most printers can print a "Network Configuration Page" from their built-in menu — look for **Settings → Reports → Network Setup** or similar. The IPv4 address is on that page. Alternatively, on Windows:

```powershell
arp -a | findstr -i "<first 6 chars of printer MAC>"
```

Or check your router's admin page for the DHCP client list.

## After running the tool, the printer disappeared

This means the printer reset (Fix 7) succeeded at removal but failed at re-add. Re-add it manually:

1. **Settings → Bluetooth & devices → Printers & scanners → Add device**
2. If it doesn't appear automatically, click **Add manually** and enter the IP address.

## I ran `irm | iex` and got "Cannot bind argument to parameter 'InputObject'"

That error means the download failed (usually a network issue or GitHub being slow). Try again, or download the script directly:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Rhythmplocutter/printer-offline-fix/main/install.ps1" -OutFile "$env:TEMP\install.ps1"
& "$env:TEMP\install.ps1"
```

## "Execution of scripts is disabled on this system"

You're on a managed machine where group policy blocks PowerShell scripts. The `irm | iex` pattern bypasses this for the install command itself, but the script it downloads is still blocked. Workaround:

```powershell
powershell.exe -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Rhythmplocutter/printer-offline-fix/main/install.ps1 | iex"
```

If your IT department has fully locked this down, you'll need to ask them to whitelist it or do the manual fixes themselves.

## My antivirus quarantined the script

False positive — `irm | iex` is also used by malware, so heuristic engines flag it. The script is open source; you can read every line in this repo. Whitelist the install folder (`%LOCALAPPDATA%\printer-offline-fix`) or run from source after cloning.

## Still stuck?

Open an issue with:

1. Windows version (`winver`)
2. Printer make and model
3. Connection type (USB / network / Wi-Fi)
4. The `[FAIL]` lines from `%TEMP%\printer-offline-fix.log`
5. Output of `Get-Printer | Format-List *` for the affected printer

→ [github.com/Rhythmplocutter/printer-offline-fix/issues/new](https://github.com/Rhythmplocutter/printer-offline-fix/issues/new)
