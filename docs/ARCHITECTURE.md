# Architecture

OpenShot is a macOS menu bar app built entirely with Apple frameworks. This document describes the high-level architecture, module responsibilities, and key design decisions.

## Overview

```
┌─────────────────────────────────────────────────┐
│                    App Shell                     │
│         Menu Bar Agent · Global Hotkeys          │
│         Permissions · URL Scheme · Onboarding    │
├──────────┬──────────┬──────────┬────────────────┤
│ Capture  │Recording │Annotation│   Overlay      │
│          │          │          │                │
│ Area     │ MP4      │ 17 Tools │ Quick Access   │
│ Window   │ GIF      │ Canvas   │ Floating Pins  │
│ Full     │ Webcam   │ Styles   │ Drag Source    │
│ Scroll   │ Audio    │ Smart    │                │
│ Timer    │ Viz      │ Blur     │                │
├──────────┴──────────┴──────────┴────────────────┤
│  OCR  │  History  │  Settings  │   Utilities    │
└───────┴───────────┴────────────┴────────────────┘
```

**48 Swift files · ~11,000 LOC · Zero external dependencies**

## Module Breakdown

### App (`App/`)

The entry point and shell. Manages:

- **AppDelegate** — `NSApplicationDelegate`, configures the app as a menu bar agent (no dock icon)
- **StatusBarManager** — Creates and manages the `NSStatusItem` with capture/recording menus
- **HotkeyBootstrap** — Registers global keyboard shortcuts via `CGEvent` tap
- **PermissionManager** — Checks and requests Screen Recording + Accessibility permissions
- **URLSchemeHandler** — Handles `openshot://` deep links for automation
- **OnboardingWindow** — First-run permission flow and shortcut overview

### Capture (`Capture/`)

The core screenshot engine:

- **CaptureEngine** — Orchestrates all capture modes, manages `SCShareableContent` and `SCScreenshotManager`
- **AreaSelector** — Transparent fullscreen `NSWindow` with crosshair, magnifier loupe, and dimension labels
- **WindowSelector** — Highlight-on-hover window picker using ScreenCaptureKit window list
- **ScrollingCapture** — Iterative scroll-and-capture with vertical image stitching
- **SelfTimerCapture** — Countdown overlay before delegating to selected capture mode
- **FreezeScreen** — Captures and displays a static fullscreen overlay for capturing transient UI
- **AllInOnePanel** — Floating `NSPanel` showing all capture modes in one UI
- **WindowBackgroundRenderer** — Adds shadows, gradients, and solid backgrounds to window captures

### Annotation (`Annotation/`)

Post-capture editing:

- **AnnotationCanvas** — `NSView` subclass handling all drawing via `NSBezierPath` and `CoreImage`
- **AnnotationTool** (enum) — 17 tool types, each with its own rendering logic
- **AnnotationToolbar** — Scrollable tool picker with contextual property controls
- **AnnotationEditorWindow** — Hosts the canvas with Image menu (rotate/flip/resize)
- **SmartBlur** — Uses Vision framework to detect text regions, applies blur only to text
- **HandDrawnRenderer** — Adds jitter/roughness to shapes for sketch-style appearance

### Recording (`Recording/`)

Screen recording engine:

- **ScreenRecorder** — `SCStream`-based capture → `AVAssetWriter` for MP4 output
- **GIFExporter** — Real-time frame capture with `CGImageDestination` GIF encoding
- **WebcamOverlay** — Circular `AVCaptureVideoPreviewLayer` in a floating panel
- **ClickVisualizer** — Monitors `CGEvent` for mouse clicks, draws expanding circles
- **KeystrokeVisualizer** — Floating pill overlay showing pressed key combinations
- **RecordingControls** — Pause/resume/restart/stop UI with elapsed time display
- **MenuBarTimer** — Shows MM:SS in the status bar during active recording

### Overlay (`Overlay/`)

Post-capture UI:

- **QuickAccessOverlay** — Floating panel with copy/save/annotate/pin actions
- **FloatingScreenshot** — Always-on-top `NSPanel` with opacity, resize, and lock controls
- **DragSource** — `NSPasteboardWriting` implementation for dragging captures to other apps

### OCR (`OCR/`)

- **TextRecognizer** — `VNRecognizeTextRequest` with `.accurate` level, language correction, and line-break preservation

### History (`History/`)

- **CaptureRecord** — `@Model` (SwiftData) for persisting capture metadata
- **HistoryView** — SwiftUI grid with type filters and thumbnail previews

### Settings (`Settings/`)

- **Preferences** — `@Observable` singleton storing all user preferences
- **HotkeyManager** — Global shortcut registration and conflict resolution
- **SettingsWindow** — 6-tab SwiftUI settings (General, Capture, Recording, Shortcuts, History, Advanced)

### Utilities (`Utilities/`)

Shared helpers:

- **NSImage+Extensions** — Resize, crop, format conversion, thumbnail generation
- **ScreenInfo** — Multi-display geometry, cursor-to-display mapping
- **SoundEffects** — System sound playback for capture/recording events
- **DesktopManager** — Show/hide desktop icons via `NSWorkspace`
- **ColorInspector** — Pixel color sampling with HEX/RGB/OKLCH output and WCAG contrast
- **FileNamer** — Template-based file naming (`{date}`, `{time}`, `{mode}`, `{counter}`)
- **DNDManager** — Do Not Disturb toggle during recording

## Key Design Decisions

### No External Dependencies

Every feature is built on Apple frameworks only. This means:
- No CocoaPods, SPM packages, or Carthage
- No supply chain risk
- App size stays minimal
- No version conflicts or compatibility issues

### Menu Bar Agent

The app runs as `LSUIElement = true` (no dock icon). Users interact via:
1. Global keyboard shortcuts
2. Menu bar status item
3. URL scheme

### Threading Model

- All UI and capture code runs on `@MainActor`
- Recording uses `SCStream` delegate callbacks on a dedicated queue
- Image processing (blur, pixelate, smart blur) uses `CIContext` on background threads
- SwiftData access is `@MainActor` confined

### Data Flow

```
User Input (Hotkey / Menu / URL Scheme)
    │
    ▼
CaptureEngine (orchestrates mode selection)
    │
    ▼
Mode-specific capture (Area/Window/Full/Scroll/Timer/Freeze)
    │
    ▼
NSImage result
    │
    ├─▶ QuickAccessOverlay (copy/save/annotate/pin)
    ├─▶ AnnotationEditor (if user chooses to annotate)
    ├─▶ Clipboard (if auto-copy enabled)
    ├─▶ File system (if auto-save enabled)
    └─▶ CaptureRecord (SwiftData history)
```

## Frameworks Used

| Framework | Purpose |
|-----------|---------|
| ScreenCaptureKit | Screen capture and recording streams |
| AVFoundation | Video encoding, webcam preview, audio capture |
| Vision | OCR text recognition, smart text-region detection |
| CoreImage | Gaussian blur, pixelation, image filtering |
| CoreGraphics | Annotation drawing, image composition, event taps |
| AppKit | Windows, panels, menus, status bar, pasteboard |
| SwiftUI | Settings UI, toolbar, overlay views, history grid |
| SwiftData | Capture history persistence |
| ServiceManagement | Launch at login via SMAppService |
