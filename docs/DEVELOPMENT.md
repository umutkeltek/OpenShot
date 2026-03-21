# Development Guide

## Prerequisites

- **macOS 14.0+** (Sonoma)
- **Xcode 15+** with Swift 5.9
- No additional tools or package managers required

## Getting Started

```bash
# Clone the repository
git clone https://github.com/umutkeltek/OpenShot.git
cd OpenShot

# Open in Xcode
open OpenShot.xcodeproj

# Or build from command line
make build
```

### First Run

1. Build and run (Cmd+R in Xcode)
2. macOS will prompt for **Screen Recording** permission — grant it
3. The app appears in the **menu bar** (camera icon) — there is no dock icon
4. If you don't see the menu bar icon, check System Settings > Privacy & Security > Screen Recording

## Project Structure

```
OpenShot/
├── OpenShot/                # Main app source
│   ├── App/                 # Entry point, menu bar, permissions
│   ├── Capture/             # Screenshot engine and modes
│   ├── Annotation/          # Drawing canvas and tools
│   ├── Recording/           # Screen recording, GIF, webcam
│   ├── Overlay/             # Quick access overlay, floating pins
│   ├── OCR/                 # Vision text recognition
│   ├── History/             # SwiftData capture log
│   ├── Settings/            # Preferences and hotkeys
│   ├── Utilities/           # Shared helpers and extensions
│   └── Resources/           # Plist, entitlements, assets
├── OpenShotTests/           # Unit tests
├── OpenShot.xcodeproj/      # Xcode project
├── project.yml              # XcodeGen config (optional)
└── docs/                    # Documentation
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed module descriptions.

## Building

### Xcode

Open `OpenShot.xcodeproj`, select the `OpenShot` scheme, and press Cmd+R.

### Command Line

```bash
# Build debug
make build

# Build release
make release

# Clean build artifacts
make clean
```

### XcodeGen (Optional)

The `project.yml` file can regenerate the Xcode project if needed:

```bash
brew install xcodegen
xcodegen generate
```

## Testing

```bash
# Run all tests
make test

# Run tests in Xcode
# Cmd+U or Product > Test
```

Tests use the **Swift Testing** framework (not XCTest). Test files are in `OpenShotTests/`.

### Writing Tests

- Place tests in `OpenShotTests/` following the naming pattern `*Tests.swift`
- Use `@Test` and `#expect()` from Swift Testing
- Focus on testable logic (preferences, file naming, image processing)
- UI and capture code requires Screen Recording permission and is harder to unit test

## Debugging

### Logs

OpenShot uses `os.Logger` for structured logging. View logs in:

1. **Console.app** — Filter by process "OpenShot" or subsystem
2. **Xcode console** — Logs appear during debug sessions

### Common Issues

**"Screen Recording permission not granted"**
- System Settings > Privacy & Security > Screen Recording > Enable OpenShot
- You may need to restart the app after granting permission

**"Menu bar icon doesn't appear"**
- The app is an `LSUIElement` agent — it only shows in the menu bar, not the dock
- Check if another menu bar app is hiding it (Bartender, Hidden Bar, etc.)

**"Hotkeys don't work"**
- System Settings > Privacy & Security > Accessibility > Enable OpenShot
- Check for conflicts with other apps using the same shortcuts

**"Build fails with signing errors"**
- Open Xcode project settings, set Team to your Apple Developer account
- For local development, "Sign to Run Locally" works fine

## Code Conventions

- **Swift naming** — Follow standard Swift API Design Guidelines
- **`@MainActor`** — All UI and capture code
- **`async/await`** — Preferred over completion handlers
- **No external dependencies** — Use only Apple frameworks
- **Modules are self-contained** — Each directory handles one concern

## Making Changes

1. Create a feature branch: `git checkout -b feature/my-change`
2. Make focused changes — one concern per branch
3. Test on macOS 14+
4. Follow [Conventional Commits](https://www.conventionalcommits.org/) for messages
5. Open a PR against `main`

See [CONTRIBUTING.md](../CONTRIBUTING.md) for full contribution guidelines.
