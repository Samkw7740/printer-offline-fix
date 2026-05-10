# How it works

This document explains what each fix actually does to your system, and why the underlying problem causes the "Printer Offline" status.

## TL;DR

Windows decides a printer is "offline" based on a handful of signals:

1. The Print Spooler service can talk to the printer driver.
2. The "Use Printer Offline" flag (`WorkOffline` in WMI) is not set.
3. Network printers respond to SNMP queries (if SNMP is enabled).
4. WSD (Web Services for Devices) discovery succeeds for WSD-port printers.

Any one of these going wrong flips the status to "Offline" — even if the printer is fine. This tool checks each signal and addresses the broken one.

---

## Fix 1: Restart the Print Spooler

**What's broken:** the Spooler service hangs. It still runs, but it stops responding to printer driver calls. This is by far the most common cause of "Offline" status.

**What we do:**
```powershell
Stop-Service Spooler -Force
# wait until Status -eq 'Stopped'
Start-Service Spooler
Set-Service Spooler -StartupType Automatic
```

The `-Force` is needed because the spooler often has dependent processes that prevent a clean stop.

## Fix 2: Clear the print queue

**What's broken:** A print job that failed mid-flight leaves a `.SHD` (shadow) and `.SPL` (spool) file in `C:\Windows\System32\spool\PRINTERS\`. The spooler tries to send it on every spooler restart, fails, and marks the printer offline again.

**What we do:** Stop the spooler (you can't delete files while it's locking them), wipe the directory, restart the spooler.

```powershell
Stop-Service Spooler -Force
Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force
Start-Service Spooler
```

## Fix 3: Clear the "Use Printer Offline" flag

**What's broken:** Each printer has a `WorkOffline` boolean in WMI. When set, Windows queues jobs locally instead of sending them, and the printer shows as Offline. This flag can flip on by accident, by buggy printer software, or by a failed print job.

**What we do:**
```powershell
$printer = Get-WmiObject Win32_Printer -Filter "Name='HP LaserJet'"
$printer.WorkOffline = $false
$printer.Put()
```

If the WMI write fails (which happens on locked-down systems), we fall back to a spooler restart, which usually clears the flag as a side effect.

## Fix 4: Disable SNMP monitoring

**What's broken:** For Standard TCP/IP ports, Windows uses SNMP (port 161) to query the printer's status. If the printer doesn't respond fast enough, doesn't speak SNMP, or is on a network that drops UDP packets, Windows assumes it's offline.

**Real-world example:** Many Wi-Fi printers go to sleep after a few minutes. Waking them takes 5-10 seconds. SNMP times out at 2 seconds. Result: printer shows offline until you wake it manually.

**What we do:** Disable SNMP for the port. Windows then only checks status when actually printing.

```powershell
Set-PrinterPort -Name "IP_192.168.1.42" -SNMP 0
```

If the cmdlet fails (older Windows or restricted permissions), we fall back to a registry edit:
```
HKLM\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP/IP Port\Ports\<PortName>
SNMP = 0 (DWORD)
```

## Fix 5: Convert WSD to TCP/IP

**What's broken:** WSD (Web Services for Devices) is Microsoft's discovery protocol — printers announce themselves via UDP multicast on port 3702, and Windows finds them automatically. Convenient, but multicast is fragile: it breaks across VLANs, subnets, and most enterprise Wi-Fi setups. WSD-port printers frequently go offline because the periodic re-discovery probe times out.

**What we do:** Create a Standard TCP/IP port pointing directly at the printer's IP, then move the printer to use it. Standard TCP/IP just opens a TCP connection on port 9100 — no multicast, no discovery, vastly more reliable.

```powershell
Add-PrinterPort -Name "IP_192.168.1.42" -PrinterHostAddress "192.168.1.42"
Set-Printer -Name "HP LaserJet" -PortName "IP_192.168.1.42"
```

We also disable SNMP on the new port by default (see Fix 4).

## Fix 6: Restart printer-related services

**What's broken:** Several services participate in printing. If any are stopped, things misbehave:

| Service | What it does |
|---|---|
| `Spooler` | Print Spooler — required, no spooler = no printing at all |
| `PrintNotify` | Printer Extensions and Notifications — pop-ups for low ink, paper jams |
| `FDResPub` | Function Discovery Resource Publication — used by WSD |
| `FDPHost` | Function Discovery Provider Host — used by WSD |
| `SSDPSRV` | SSDP Discovery — used by WSD/UPnP |

**What we do:** Set required services to Automatic, optional ones to Manual, restart all the running ones.

## Fix 7: Reset printer registration

**What's broken:** The printer's entry in Windows is corrupted — wrong driver registration, mismatched port binding, garbage in the registry under `HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers\<Name>`.

**What we do:** Capture the current configuration (driver, port, share settings), remove the printer, re-add it with the same configuration.

```powershell
Remove-Printer -Name "HP LaserJet"
Add-Printer -Name "HP LaserJet" -DriverName "HP LaserJet Pro" -PortName "IP_192.168.1.42"
```

This is destructive enough that it always asks for confirmation, even in `-Auto` mode.

---

## Why doesn't the Windows troubleshooter just do all of this?

Mostly it does — but it runs each fix in isolation, asks for confirmation after each step, requires multiple wizard pages, and skips SNMP and WSD entirely. This tool runs the whole pipeline in a few seconds with one command. That's the only difference.

## What this tool deliberately doesn't do

- **It doesn't download drivers.** Driver vendors don't all sign their installers, and we won't ship code that pulls executables from third-party sites. If you need a fresh driver, the tool points you to the manufacturer's site.
- **It doesn't disable Windows Defender or any security product.** Some "fix it" tools do this. We don't.
- **It doesn't modify firewall rules.** SNMP changes are local-host only. Network reachability problems get reported to you, not auto-fixed.
- **It doesn't persist.** Run it, fix the printer, walk away. No services, no scheduled tasks, no leftovers.
