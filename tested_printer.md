---
name: Tested with printer
about: Confirm the tool works (or doesn't) with your printer
title: '[TESTED] <make> <model>'
labels: tested-printers
assignees: ''
---

<!-- These reports are gold — they help others know the tool will work for their setup. Even one-line reports help. -->

## Printer

- **Make and model:**
- **Connection:** USB / Wi-Fi / Ethernet / print server
- **Driver:** (see `Get-Printer | Select Name, DriverName`)

## Did it work?

- [ ] Yes — fixed the offline issue
- [ ] Partially — fixed it for now, came back later
- [ ] No — still offline

## Original problem

<!-- What was wrong before you ran the tool? -->

## Which fixes were applied

- [ ] Spooler restart
- [ ] Queue clear
- [ ] "Use Printer Offline" flag
- [ ] SNMP disable
- [ ] WSD → TCP/IP conversion
- [ ] Services restart
- [ ] Printer reset

## OS

- Windows version (`winver`):

## Notes

<!-- Anything else worth knowing — quirks, workarounds, surprises. -->
