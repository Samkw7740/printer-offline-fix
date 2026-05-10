# Security Policy

## Reporting a vulnerability

If you find a security issue in this tool — for example, a way to abuse the install command, an injection through printer names, or a privilege escalation path — please report it privately rather than opening a public issue.

**Open a security advisory on GitHub:**
https://github.com/Rhythmplocutter/printer-offline-fix/security/advisories/new

We'll respond within a few days. Once a fix is shipped, we'll publicly credit you (or keep you anonymous, your choice).

## Scope

In scope:

- Code execution via the `irm | iex` install command
- Privilege escalation via the elevated PowerShell session
- Injection through printer names, port names, or driver names
- Any way to make the tool delete files outside the printer spool directory or registry keys outside the printer-related paths

Out of scope:

- The Windows Print Spooler itself (report those to MSRC)
- Vulnerabilities in third-party printer drivers
- Issues that require already-elevated attacker access

## Supported versions

Only the latest `main` branch receives security updates. Pin to a tag if you need stability.
