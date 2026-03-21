# Contributing to OpenShot

Thanks for your interest in contributing! OpenShot is a community-driven macOS screenshot and screen recording tool. Here's how to get involved.

## Quick Start

```bash
git clone https://github.com/umutkeltek/OpenShot.git
cd OpenShot
open OpenShot.xcodeproj
# Press Cmd+R to build and run
```

**Requirements:** macOS 14.0+ (Sonoma), Xcode 15+

On first launch, grant **Screen Recording** permission in System Settings > Privacy & Security.

## How to Contribute

### Reporting Bugs

1. Search [existing issues](https://github.com/umutkeltek/OpenShot/issues) first
2. Use the [Bug Report template](https://github.com/umutkeltek/OpenShot/issues/new?template=bug_report.yml)
3. Include macOS version, OpenShot version, and steps to reproduce

### Suggesting Features

1. Check [existing feature requests](https://github.com/umutkeltek/OpenShot/issues?q=label%3Aenhancement)
2. Use the [Feature Request template](https://github.com/umutkeltek/OpenShot/issues/new?template=feature_request.yml)
3. Explain the problem you're trying to solve, not just the solution

### Submitting Code

1. **Open an issue first** for anything non-trivial — discuss before coding
2. Fork the repository
3. Create a feature branch from `main`: `git checkout -b feature/my-feature`
4. Make your changes
5. Test thoroughly on macOS 14+
6. Submit a pull request to `main`

## Code Guidelines

### Architecture

The project is organized into functional modules:

```
OpenShot/
├── App/          # App lifecycle, menu bar, permissions
├── Capture/      # Screen capture engine and modes
├── Annotation/   # Drawing canvas and 17 annotation tools
├── Recording/    # Screen recording, GIF, webcam
├── Overlay/      # Quick access overlay, floating screenshots
├── OCR/          # Vision framework text recognition
├── History/      # SwiftData capture history
├── Settings/     # Preferences and hotkey management
├── Utilities/    # Extensions and helpers
└── Resources/    # Plist, entitlements, assets
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture documentation.

### Style

- **Swift conventions** — follow standard Swift naming and formatting
- **No external dependencies** — use only Apple frameworks. This is a core design principle
- **Keep modules focused** — each directory has a clear responsibility
- **Use `@MainActor`** — for all UI and capture code
- **Prefer `async/await`** — over completion handlers
- **Use Swift Testing** — not XCTest, for new tests

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add circular crop tool to annotation editor
fix: area selector not appearing on secondary display
docs: update URL scheme reference
refactor: extract timer logic from CaptureEngine
test: add tests for WindowBackgroundRenderer
```

### What We Look For in PRs

- Solves a real problem (linked to an issue)
- Minimal, focused changes — one concern per PR
- Works on macOS 14+ without deprecation warnings
- No new external dependencies
- Tests for non-trivial logic
- Screenshots/recordings for UI changes

## Development Tips

### Build from Command Line

```bash
# Build
make build

# Run tests
make test

# Clean build artifacts
make clean
```

### Debugging

- Use Console.app filtered to "OpenShot" for runtime logs
- The app uses `os.Logger` throughout — search for `Logger` in source
- Screen Recording permission must be granted for capture to work

### Testing

Tests are in `OpenShotTests/` using Swift Testing framework:

```bash
make test
```

When adding new features, add tests in the corresponding test file or create a new one following the existing pattern.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold a welcoming and inclusive environment.

## Questions?

- Open a [Discussion](https://github.com/umutkeltek/OpenShot/discussions) for general questions
- Check existing issues and docs before asking

Thank you for helping make OpenShot better!
