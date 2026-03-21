# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |

We only provide security fixes for the latest release on `main`.

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Instead, report vulnerabilities privately:

1. **Email:** Send details to the maintainer via the email listed on the [GitHub profile](https://github.com/umutkeltek)
2. **GitHub Private Advisory:** Use [GitHub's private vulnerability reporting](https://github.com/umutkeltek/OpenShot/security/advisories/new)

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if you have one)

### What to Expect

- **Acknowledgment** within 48 hours
- **Status update** within 7 days
- **Fix timeline** depends on severity, but we aim for critical fixes within 14 days

## Scope

OpenShot runs locally on macOS with the following permission-sensitive areas:

- **Screen Recording** — Required for core functionality (ScreenCaptureKit)
- **Accessibility** — Used for global hotkeys
- **File System** — Saving captures to user-selected directories

The app has **no network access**, **no analytics**, **no telemetry**, and **no external dependencies**. All processing is on-device.

## Security Design Principles

- Zero external dependencies — reduces supply chain risk
- No network calls — no data leaves the device
- Sandboxed where possible via macOS entitlements
- Screen recording permission is gated by macOS system prompt
