# Frequently Asked Questions

## Is this safe to run?

Yes. The whole tool is in this repo — read the source. It does the same things you'd do manually in `services.msc`, `printmanagement.msc`, and `regedit`, but in 30 seconds instead of 30 minutes.

The destructive operations (clearing the queue, resetting the printer) prompt for confirmation by default and are skipped without prompts in `-Auto` mode unless they're needed.

## What is "Printer Offline" actually?

It's a status flag Windows attaches to each printer. The OS sets it whenever any of these happen:

- The Print Spooler can't reach the driver.
- The driver explicitly reports the printer as not ready.
- An SNMP probe times out (network printers).
- A WSD discovery probe times out.
- The user manually checked "Use Printer Offline" in the print queue menu.
- Windows decided to "help" because a job failed.

The flag is independent of whether the printer is actually offline — it just means Windows can't currently confirm it's online. That's why power-cycling the printer often "fixes" it: not because the printer was broken, but because the reconnection clears the flag.

## Will this fix every printer offline issue?

No tool can fix every case. This handles the ~95% caused by software state on the Windows side. It won't help if:

- The printer is actually unplugged or off.
- The printer's network module is dead.
- A driver is fundamentally incompatible with your Windows version.
- Group policy is forcing a setting back.
- A USB cable or port is failing.

## How is this different from the Windows built-in troubleshooter?

The Windows troubleshooter is a sequence of wizard pages, each asking for confirmation, each handling one cause at a time. It also doesn't touch SNMP or WSD (the two most common causes of intermittent offline issues on network printers).

This tool runs the full pipeline in seconds, in one command, with no wizard pages.

## Will it conflict with HP Smart, Canon IJ Network, Epson Print, etc.?

No. Those apps install their own drivers and helper services, but they all rely on the same underlying Windows print stack — the Spooler, the printer port, the driver. We fix the Windows side; their apps will pick up the corrected state on their next status check.

If you have a vendor app that's actively running, you might see a brief notification when the spooler restarts. That's normal.

## Why PowerShell instead of a `.exe`?

Three reasons:

1. **Transparent.** Anyone can read the source — no obfuscation, no hidden behavior.
2. **No build step.** No code-signing certificate, no installer infrastructure, no antivirus reputation problem.
3. **Native to Windows.** PowerShell ships with Windows 10/11. Zero install friction.

The `irm | iex` pattern is the same one used by Microsoft's own installers, Chocolatey, Scoop, and oh-my-posh. It's the de-facto standard for "one-command install on Windows."

## Why not Chocolatey/Scoop/winget?

Could come later. For now, the install footprint is small enough (~30 KB of scripts) that direct download is faster and has zero dependencies. If there's demand, package manager submissions are easy to add — open an issue.

## Does it work over Remote Desktop?

Yes, but you'll need admin rights on the remote box. The interactive prompts work fine over RDP — just make sure you're running PowerShell as administrator on the remote session, not your local one.

## Does it work for printers on a print server?

Partially. The fixes that target the local Windows print client (spooler, queue, "Use Printer Offline" flag) work. SNMP and WSD fixes need to be applied to the print server itself — run the tool there.

If your printer connection looks like `\\PRINTSERVER\PrinterName`, you're using a print server.

## Can I run it on a schedule?

Yes, if you want to. Create a scheduled task that runs `Fix-PrinterOffline.ps1 -Auto` daily — useful for the "printer goes offline every morning" pattern. Example:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$env:LOCALAPPDATA\printer-offline-fix\src\Fix-PrinterOffline.ps1`" -Auto"
$trigger = New-ScheduledTaskTrigger -Daily -At "8:30am"
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "Printer Offline Fix" -Action $action -Trigger $trigger -Principal $principal
```

Note that this is a band-aid — if your printer goes offline every day, fix the root cause (usually DHCP or SNMP) instead.

## Does it support Cyrillic / Chinese / non-ASCII printer names?

Yes. PowerShell handles Unicode natively, and the tool escapes single quotes properly when querying WMI. If you hit an encoding issue with a specific printer name, please open an issue with the exact name (UTF-8 copy-paste is fine).

## How do I roll back changes?

Most fixes are non-destructive — restarting the spooler, restarting services, and clearing flags don't change anything that needs to be "rolled back." For the two that do persist:

- **SNMP disable** — re-enable in Printer Properties → Ports → Configure Port → check "SNMP Status Enabled."
- **WSD → TCP/IP conversion** — re-add the printer using the WSD discovery wizard (Settings → Bluetooth & devices → Add device).

The full log at `%TEMP%\printer-offline-fix.log` records every change so you can trace exactly what was done.
