# OpenShot

A free, open-source screenshot and screen recording tool for macOS. A powerful alternative to CleanShot X and Shottr — built for the community.

![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

### Capture Modes
- **Area Capture** — Rubber-band selection with crosshair, magnifier loupe, and dimension labels
- **Window Capture** — Click any window; automatic transparency, shadow, and custom backgrounds (8 gradient presets, solid colors)
- **Fullscreen Capture** — Captures the display under your cursor (multi-monitor support)
- **Scrolling Capture** — Experimental vertical stitching for long pages
- **Self-Timer** — 3/5/10 second countdown before any capture
- **Freeze Screen** — Freeze the display to capture tooltips, menus, and hover states
- **Capture Previous Area** — Re-capture the exact same region with one shortcut
- **All-in-One Panel** — Single shortcut opens a floating panel with every capture mode

### Annotation Editor
17 tools in a scrollable toolbar:

| Tool | Description |
|------|-------------|
| Arrow | 4 styles including curved, with optional hand-drawn look |
| Rectangle | Outline or filled, optional hand-drawn style |
| Ellipse | Outline or filled, optional hand-drawn style |
| Line | Straight line with configurable dash pattern |
| Text | 7 preset styles (pill, highlight, shadow, monospace, etc.) |
| Counter | Auto-incrementing numbered circles for step-by-step guides |
| Pencil | Freehand drawing with Catmull-Rom smoothing |
| Highlighter | Semi-transparent marker (multiply blend, 40% opacity) |
| Blur | CIGaussianBlur on selected region |
| Pixelate | CIPixellate with randomized offset (prevents de-pixelation) |
| Smart Blur | Vision-powered text-only blur — blurs text, preserves images |
| Spotlight | Dims everything except selected region |
| Black Out | Solid fill redaction |
| Crop | Crop to selection |
| Pixel Ruler | Measure distances in pixels with imprint support |
| Color Picker | Pick colors with HEX/RGB/OKLCH values + WCAG contrast checking |
| Magnifier | Circular zoom callout annotation |

Plus: **Rotate/Flip/Resize** via Image menu, **undo/redo**, **drag images in** to combine screenshots, and **hand-drawn style toggle**.

### Screen Recording
- **MP4 Recording** — H.264 via SCStream + AVAssetWriter, 30/60 FPS
- **GIF Recording** — Real-time capture with automatic downsampling to 640px
- **Audio** — System audio + microphone
- **Webcam Overlay** — Circular camera preview in floating panel
- **Click Visualization** — Expanding colored circles on mouse clicks
- **Keystroke Visualization** — Floating pill showing pressed keys
- **Recording Controls** — Pause, resume, restart, stop with elapsed timer
- **Menu Bar Timer** — Shows MM:SS elapsed time during recording
- **Do Not Disturb** — Auto-enabled during recording

### Quick Access Overlay
Floating panel appears after every capture with:
- **Copy** — Image data + temp file URL to clipboard
- **Save** — To configured folder in PNG/JPEG/TIFF/WebP/HEIC
- **Annotate** — Opens full annotation editor
- **Pin** — Creates always-on-top floating screenshot
- **Drag & Drop** — Drag thumbnail directly into any app
- **Auto-close** — Configurable delay (3s/5s/10s/never), pauses on hover
- **Restore Recently Closed** — Bring back accidentally dismissed captures

### OCR
- On-device text recognition via Vision framework
- `.accurate` recognition level with language correction
- Preserves line breaks from bounding box positions
- Result copied directly to clipboard

### Floating Screenshots
- Always-on-top display
- Resizable with aspect ratio lock
- Adjustable opacity (20-100%)
- Lock mode (click-through)
- Arrow keys for pixel-precise positioning
- Double-click to open in annotation editor

### Additional Features
- **Desktop Icon Hiding** — Toggle or auto-hide during capture
- **Custom File Naming** — Templates with `{date}`, `{time}`, `{mode}`, `{counter}` tokens
- **Capture History** — SwiftData-backed grid with type filters
- **URL Scheme** — `openshot://capture-area`, `openshot://record-screen`, etc.
- **Launch at Login** — Via SMAppService
- **First-Run Onboarding** — Permission request + shortcut overview
- **WCAG Contrast Checker** — AA/AAA pass/fail + APCA values

## Keyboard Shortcuts

All shortcuts are customizable in Settings.

| Action | Default Shortcut |
|--------|-----------------|
| Capture Area | `Shift+Cmd+4` |
| Capture Window | `Shift+Cmd+5` |
| Capture Fullscreen | `Shift+Cmd+3` |
| Scrolling Capture | `Shift+Cmd+6` |
| Capture Previous Area | `Shift+Cmd+7` |
| Self-Timer Capture | `Shift+Cmd+8` |
| All-in-One | `Shift+Cmd+A` |
| Record Screen | `Shift+Cmd+R` |
| Record GIF | `Shift+Cmd+G` |
| OCR — Capture Text | `Shift+Cmd+T` |
| Restore Recently Closed | `Shift+Cmd+Z` |
| Toggle Desktop Icons | `Shift+Cmd+D` |

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+ (to build from source)
- No external dependencies — pure Apple frameworks

## Building

```bash
# Clone
git clone https://github.com/umutkeltek/OpenShot.git
cd OpenShot

# Option 1: Xcode
open OpenShot.xcodeproj
# Press Cmd+R to build and run

# Option 2: Command line
xcodebuild -project OpenShot.xcodeproj -scheme OpenShot -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/OpenShot-*/Build/Products/Debug/OpenShot.app
```

On first launch, grant **Screen Recording** permission when prompted (System Settings > Privacy & Security > Screen Recording).

The app lives in your **menu bar** — look for the camera icon. There is no dock icon.

## Architecture

```
OpenShot/
├── App/              # App lifecycle, menu bar, permissions, URL scheme, onboarding
├── Capture/          # ScreenCaptureKit engine, area/window/fullscreen selectors,
│                       self-timer, All-in-One panel, window backgrounds
├── Annotation/       # NSView canvas, 17 tool types, hand-drawn styles,
│                       smart blur, pixel ruler, toolbar, editor window
├── Overlay/          # Quick Access Overlay, floating screenshots, drag source
├── Recording/        # SCStream recorder, GIF exporter, video editor,
│                       click/keystroke visualizers, webcam overlay
├── OCR/              # Vision framework text recognition
├── History/          # SwiftData capture log with grid view
├── Settings/         # Preferences, hotkey manager, 6-tab Settings UI
├── Utilities/        # NSImage extensions, screen info, sound effects,
│                       desktop manager, color inspector, file namer, DND
└── Resources/        # Info.plist, entitlements, asset catalogs
```

**48 Swift files, ~11,000 lines of code.** Zero external dependencies.

| Framework | Usage |
|-----------|-------|
| ScreenCaptureKit | Screen capture and recording |
| AVFoundation | Video encoding, webcam, audio |
| Vision | OCR text recognition, smart text blur |
| CoreImage | Blur, pixelate, image filters |
| CoreGraphics | Annotation drawing, image composition |
| AppKit | Windows, panels, overlays, menus |
| SwiftUI | Settings, toolbar, overlay, history |
| SwiftData | Capture history persistence |
| ServiceManagement | Launch at login |

## URL Scheme

Automate OpenShot from Alfred, Raycast, Shortcuts, or scripts:

```
openshot://capture-area
openshot://capture-window
openshot://capture-fullscreen
openshot://scrolling-capture
openshot://record-screen
openshot://record-gif
openshot://capture-text
openshot://open-history
openshot://toggle-desktop-icons
openshot://restore-recently-closed
```

## Export Formats

| Format | Extension |
|--------|-----------|
| PNG | `.png` (default) |
| JPEG | `.jpeg` (quality configurable) |
| TIFF | `.tiff` |
| WebP | `.webp` |
| HEIC | `.heic` |
| MP4 | `.mp4` (recordings) |
| GIF | `.gif` (GIF recordings) |

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | Module breakdown, data flow, design decisions |
| [Development Guide](docs/DEVELOPMENT.md) | Setup, building, testing, debugging |
| [Contributing](CONTRIBUTING.md) | How to report bugs, suggest features, submit PRs |
| [Code of Conduct](CODE_OF_CONDUCT.md) | Community standards |
| [Security Policy](SECURITY.md) | Reporting vulnerabilities |
| [Changelog](CHANGELOG.md) | Release history |

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

```bash
# Quick start
git clone https://github.com/umutkeltek/OpenShot.git
cd OpenShot
make build    # Build
make test     # Run tests
make run      # Build and launch
```

## License

[MIT](LICENSE) — do whatever you want with it.

Built with Swift and Apple frameworks. No subscriptions, no cloud, no tracking.
