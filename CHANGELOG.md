# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-05-10

### Added
- One-line installer (`install.ps1`) with self-elevation
- Interactive fix wizard with menu-driven UI
- `-Auto` flag for unattended fixing
- `-DiagnoseOnly` flag for read-only health checks
- `-Printer` flag to target a specific printer
- Print Spooler service restart with queue clear
- "Use Printer Offline" flag clearing via WMI
- SNMP disable for Standard TCP/IP ports
- WSD-to-TCP/IP port conversion with reachability check
- Restart of all printer-related services (Spooler, PrintNotify, FDResPub, FDPHost, SSDPSRV)
- Printer reset (remove + re-add with same configuration)
- Comprehensive logging to `%TEMP%\printer-offline-fix.log`
- Pester test suite for parse-cleanliness and library functions
- GitHub Actions CI with PSScriptAnalyzer linting and syntax check
- Three issue templates (bug, feature request, tested-printer)
- Full documentation: README, HOW_IT_WORKS, TROUBLESHOOTING, FAQ
- Contributing guide

[Unreleased]: https://github.com/Rhythmplocutter/printer-offline-fix/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Rhythmplocutter/printer-offline-fix/releases/tag/v1.0.0
