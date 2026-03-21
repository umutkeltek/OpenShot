# Changelog

All notable changes to OpenShot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- GitHub issue templates, PR template, and CI workflow
- CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md
- Project documentation in `docs/`

### Fixed
- 7 bugs from deep audit: crash prevention, timer leaks, continuation safety
- Settings window not opening on macOS
- macOS stability improvements

## [0.1.0] - 2025-03-20

Initial release.

### Added

#### Capture
- Area capture with crosshair, magnifier loupe, and dimension labels
- Window capture with automatic transparency, shadow, and custom backgrounds
- Fullscreen capture with multi-monitor support
- Scrolling capture (experimental vertical stitching)
- Self-timer capture (3/5/10 second countdown)
- Freeze screen for tooltips, menus, and hover states
- Capture previous area with one shortcut
- All-in-One panel for all capture modes

#### Annotation Editor
- 17 annotation tools: Arrow, Rectangle, Ellipse, Line, Text, Counter, Pencil, Highlighter, Blur, Pixelate, Smart Blur, Spotlight, Black Out, Crop, Pixel Ruler, Color Picker, Magnifier
- Hand-drawn style toggle
- Undo/redo support
- Drag images in to combine screenshots
- Rotate, flip, and resize via Image menu

#### Screen Recording
- MP4 recording (H.264, 30/60 FPS)
- GIF recording with automatic downsampling
- System audio and microphone capture
- Webcam overlay with circular preview
- Click and keystroke visualization
- Pause, resume, restart controls
- Menu bar elapsed timer
- Auto Do Not Disturb during recording

#### Quick Access Overlay
- Copy, save, annotate, and pin actions
- Drag & drop thumbnail into any app
- Auto-close with configurable delay
- Restore recently closed captures

#### Other
- On-device OCR via Vision framework
- Floating always-on-top screenshots with opacity control
- Desktop icon hiding (toggle or auto-hide)
- Custom file naming templates
- SwiftData capture history with filters
- URL scheme for automation (`openshot://`)
- Launch at login via SMAppService
- First-run onboarding with permission setup
- WCAG contrast checker (AA/AAA + APCA)
- Customizable keyboard shortcuts
- 5 export formats: PNG, JPEG, TIFF, WebP, HEIC

[Unreleased]: https://github.com/umutkeltek/OpenShot/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/umutkeltek/OpenShot/releases/tag/v0.1.0
