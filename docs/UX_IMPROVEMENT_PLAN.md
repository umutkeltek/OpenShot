# OpenShot UX Improvement Plan

Prioritized roadmap for polishing menu, settings, usability, and accessibility. Organized by priority tier with concrete implementation guidance.

## Current State

- 48 Swift files, ~11K LOC, zero external dependencies
- Strong core functionality: 12 capture modes, 17 annotation tools, recording, OCR
- UX gaps: zero accessibility labels, silent operations, no error dialogs, inconsistent window behavior

---

## P0 — Feedback Loop (Highest Impact, Do First)

> Every user action must produce visible acknowledgment.

### 1. Toast Notification Component

**Problem:** Copy, save, and OCR operations complete silently. Users don't know if their action worked.

**Solution:** Create a lightweight `ToastView` (SwiftUI) that briefly appears and auto-dismisses.

**File to create:** `OpenShot/Utilities/ToastView.swift`

```swift
// Concept — floating notification that auto-dismisses
struct ToastView: View {
    let icon: String      // SF Symbol name
    let message: String   // e.g., "Copied to clipboard"
    let detail: String?   // e.g., file path (optional)

    // Position: top-center of screen, above Quick Access Overlay
    // Duration: 2 seconds, fade out over 0.3s
    // Style: NSVisualEffectView material, rounded, shadow
}
```

**Where to call it:**
| Action | Toast Message |
|--------|---------------|
| Copy to clipboard | "Copied to clipboard" (checkmark icon) |
| Save to file | "Saved to ~/Screenshots/file.png" (folder icon) |
| OCR complete | "Text copied to clipboard" (doc.text icon) |
| Pin created | "Pinned to screen" (pin icon) |

**Effort:** ~2 hours | **Impact:** Transforms every capture from "did that work?" to "yes, done"

### 2. Error Alerts for Users

**Problem:** All errors go to `os.Logger` — users see nothing when captures fail.

**Solution:** Create a `showError()` helper that wraps `NSAlert`.

**File to create:** `OpenShot/Utilities/AlertHelper.swift`

```swift
@MainActor
enum AlertHelper {
    static func showError(_ error: OpenShotError) {
        let alert = NSAlert()
        alert.messageText = error.title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning

        // For permission errors, add "Open System Settings" button
        if case .captureNotPermitted = error {
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn {
                // Deep link to Screen Recording privacy pane
                NSWorkspace.shared.open(URL(string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
        }
        alert.runModal()
    }
}
```

**Where to call it:** Every `catch` block in `CaptureEngine` that currently only calls `Logger`.

**Effort:** ~1 hour | **Impact:** Eliminates "app does nothing when I press the shortcut" confusion

### 3. Recording State Sounds

**Problem:** Starting, pausing, and stopping recording have no auditory feedback.

**Solution:** Add system sounds to `SoundEffects.swift` for recording transitions.

```swift
// Add to SoundEffects.swift
static func playRecordingStart() { NSSound(named: "Blow")?.play() }
static func playRecordingStop()  { NSSound(named: "Bottle")?.play() }
static func playRecordingPause() { NSSound(named: "Pop")?.play() }
```

**Add preference toggle:** `Preferences.playRecordingSounds: Bool = true`

**Effort:** ~30 minutes | **Impact:** Users know recording state changed without looking at screen

---

## P1 — Accessibility (Non-Negotiable Baseline)

> Not a feature — the floor. Apple HIG requires this.

### 4. Accessibility Labels on All Interactive Elements

**Problem:** Zero `accessibilityLabel` usage across entire codebase.

**Approach:** Systematic sweep through each module:

**Quick Access Overlay** (`QuickAccessOverlay.swift`):
```swift
Button(action: copyAction) {
    // existing content
}
.accessibilityLabel("Copy screenshot to clipboard")
.accessibilityHint("Copies the captured image and file URL")
```

**Annotation Toolbar** (`AnnotationToolbar.swift`):
```swift
ForEach(tools) { tool in
    Button(action: { selectTool(tool) }) {
        // existing content
    }
    .accessibilityLabel(tool.accessibilityName)  // "Arrow tool", "Blur tool"
    .accessibilityHint(tool.accessibilityHint)   // "Draw arrows between elements"
}
```

**Settings** (`SettingsView.swift`) — every Toggle, Picker, Slider:
```swift
Toggle("Play capture sound", isOn: $prefs.playCaptureSound)
    .accessibilityHint("Plays a shutter sound when a screenshot is captured")

Slider(value: $prefs.jpegQuality, in: 0.1...1.0)
    .accessibilityLabel("JPEG quality")
    .accessibilityValue("\(Int(prefs.jpegQuality * 100)) percent")
```

**Files to modify** (priority order):
1. `Overlay/QuickAccessOverlay.swift` — 5 buttons
2. `Annotation/AnnotationToolbar.swift` — 17 tools + color swatches
3. `Settings/SettingsView.swift` — all 6 tabs
4. `App/AppDelegate.swift` — menu items
5. `App/OnboardingWindow.swift` — buttons and page content
6. `Recording/RecordingControls.swift` — pause/stop/restart
7. `History/HistoryView.swift` — filter picker, cards
8. `Overlay/FloatingScreenshot.swift` — context menu items

**Effort:** ~3 hours (mechanical but thorough) | **Impact:** VoiceOver users can actually use the app

### 5. Keyboard Navigation in Quick Access Overlay

**Problem:** Overlay buttons are mouse-only — can't Tab through them.

**Solution:** Make the overlay a proper `NSPanel` that accepts keyboard focus:

```swift
// In QuickAccessOverlay panel setup
panel.becomesKeyOnOverOrder = true

// Each button needs focusable style
Button(action: copyAction) { ... }
    .focusable()
    .onKeyPress(.return) { copyAction(); return .handled }
```

**Also add keyboard shortcuts:**
- `⌘C` — Copy
- `⌘S` — Save
- `⌘E` — Annotate (Edit)
- `⌘P` — Pin
- `Esc` — Dismiss

**Effort:** ~2 hours | **Impact:** Power users never touch the mouse for post-capture actions

### 6. VoiceOver Announcements for State Changes

**Problem:** VoiceOver users get no feedback when captures complete or recording state changes.

**Solution:** Post `NSAccessibility` notifications:

```swift
// After capture completes
NSAccessibility.post(element: NSApp, notification: .announcementRequested,
    userInfo: [.announcement: "Screenshot captured", .priority: .high])

// After recording state changes
NSAccessibility.post(element: NSApp, notification: .announcementRequested,
    userInfo: [.announcement: "Recording started", .priority: .high])
```

**Effort:** ~1 hour | **Impact:** Screen reader users know what's happening

---

## P2 — Menu & Window Polish

> Standard macOS behaviors that users expect.

### 7. Menu Item State Management

**Problem:** "Restore Recently Closed" is always enabled even with nothing to restore. "Stop Recording" shows when not recording.

**Solution:** Track app state and update menu items:

```swift
// In AppDelegate, add state tracking
private var hasRecentlyClosed: Bool = false
private var isRecording: Bool = false

// When building menu, set isEnabled:
restoreItem.isEnabled = hasRecentlyClosed
stopRecordingItem.isEnabled = isRecording

// Update state when events happen:
func didDismissOverlay() { hasRecentlyClosed = true; updateMenuState() }
func didStartRecording() { isRecording = true; updateMenuState() }
func didStopRecording()  { isRecording = false; updateMenuState() }
```

**Effort:** ~1 hour | **Impact:** Menu looks professional, not amateur

### 8. Window Minimum Sizes

**Problem:** Settings and Onboarding can be resized to unreadable dimensions.

**Solution:** Add min sizes in window setup:

```swift
// Settings
window.minSize = NSSize(width: 500, height: 400)

// Onboarding
window.minSize = NSSize(width: 520, height: 420)

// History
window.minSize = NSSize(width: 400, height: 300)
```

**Effort:** ~15 minutes | **Impact:** Prevents broken layouts

### 9. Window Position Persistence

**Problem:** Windows don't remember their position between sessions.

**Solution:** Use `setFrameAutosaveName`:

```swift
settingsWindow.setFrameAutosaveName("OpenShot.Settings")
historyWindow.setFrameAutosaveName("OpenShot.History")
annotationWindow.setFrameAutosaveName("OpenShot.Annotation")
```

**Effort:** ~15 minutes | **Impact:** Windows stay where users put them

### 10. Descriptive Window Titles

**Problem:** All-in-One panel title is just "OpenShot" — meaningless.

**Fix:**

| Window | Current Title | Better Title |
|--------|---------------|--------------|
| All-in-One | "OpenShot" | "OpenShot — Capture Modes" |
| Floating Screenshot | "OpenShot — Pinned" | "OpenShot — Pinned (Locked)" when locked |
| Annotation | "OpenShot — Annotate (WxH)" | Good as-is |

**Effort:** ~10 minutes | **Impact:** VoiceOver and Mission Control show useful info

---

## P3 — Usability & Interaction

> Power-user optimizations that reduce friction.

### 11. Annotation Tool Keyboard Shortcuts

**Problem:** 17 tools require mouse clicks to switch — no keyboard shortcuts.

**Solution:** Add single-key shortcuts (standard across annotation tools like Figma, Photoshop):

| Key | Tool | Key | Tool |
|-----|------|-----|------|
| `A` | Arrow | `H` | Highlighter |
| `R` | Rectangle | `B` | Blur |
| `E` | Ellipse | `X` | Pixelate |
| `L` | Line | `S` | Spotlight |
| `T` | Text | `K` | Black Out |
| `N` | Counter | `C` | Crop |
| `P` | Pencil | `M` | Magnifier |

**Implementation:** In `AnnotationCanvas.keyDown()`, map key codes to tool selection. Disable when text tool is active (to avoid conflicts with typing).

**Show in tooltips:** Update `.help()` to include shortcut, e.g., "Arrow Tool (A)"

**Effort:** ~2 hours | **Impact:** 10x faster tool switching for power users

### 12. History "Annotate" Action

**Problem:** History context menu has Open, Copy, Reveal, Delete — but no Annotate.

**Solution:** Add to context menu in `HistoryView.swift`:

```swift
Button("Annotate") {
    if let image = NSImage(contentsOf: record.fileURL) {
        AnnotationEditorWindow.open(with: image)
    }
}
```

**Effort:** ~30 minutes | **Impact:** Direct workflow from history to editing

### 13. Overlay Auto-Close Countdown

**Problem:** Overlay auto-closes after configurable delay, but user doesn't see when.

**Solution:** Add a thin progress bar at bottom of overlay that shrinks over the delay duration:

```swift
// In QuickAccessOverlay
Rectangle()
    .fill(.secondary.opacity(0.3))
    .frame(height: 3)
    .scaleEffect(x: remainingFraction, y: 1, anchor: .leading)
    .animation(.linear(duration: autoCloseDelay), value: remainingFraction)
```

**Effort:** ~1 hour | **Impact:** Users know exactly when overlay will disappear

### 14. Floating Screenshot Lock Shortcut

**Problem:** Locking/unlocking floating screenshot (click-through mode) requires right-click → menu.

**Solution:** Add `⌘L` shortcut when floating window is focused.

**Effort:** ~30 minutes | **Impact:** Faster workflow for reference image use

---

## P4 — Visual Polish

> The final 10% that makes it feel premium.

### 15. State Transition Animations

**Where to add:**

| Element | Current | Target |
|---------|---------|--------|
| Annotation tool selection | Instant highlight swap | 0.15s background color transition |
| Window picker highlight | Instant blue border | 0.1s fade-in for border + title label |
| History card hover | Nothing | 0.2s subtle scale(1.02) + shadow increase |
| Overlay button focus | No ring | 2px blue focus ring, 0.15s fade |

**Implementation pattern:**
```swift
// SwiftUI
.animation(.easeOut(duration: 0.15), value: isSelected)

// AppKit (window picker)
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.1
    highlightView.animator().alphaValue = 1.0
}
```

**Effort:** ~2 hours | **Impact:** App feels native-quality instead of prototype-quality

### 16. Focus Rings on Overlay Buttons

**Problem:** If we make overlay keyboard-navigable (P1-5), focused buttons need visible rings.

**Solution:** SwiftUI's `.focusEffectDisabled(false)` + custom ring:

```swift
.overlay(
    RoundedRectangle(cornerRadius: 8)
        .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 2)
)
```

**Effort:** ~30 minutes | **Impact:** Keyboard navigation is actually usable

---

## Implementation Order (Recommended)

| Sprint | Items | Effort | Theme |
|--------|-------|--------|-------|
| **Sprint 1** | #1 Toast, #2 Error Alerts, #3 Recording Sounds | ~3.5h | Feedback loop |
| **Sprint 2** | #4 A11y Labels (all files), #6 VoiceOver | ~4h | Accessibility |
| **Sprint 3** | #7 Menu States, #8 Min Sizes, #9 Autosave, #10 Titles | ~1.5h | Window polish |
| **Sprint 4** | #5 Keyboard Nav, #11 Tool Shortcuts, #14 Lock Shortcut | ~4.5h | Keyboard-first |
| **Sprint 5** | #12 History Annotate, #13 Countdown, #15 Animations, #16 Focus | ~4h | Polish |

**Total estimated effort: ~17.5 hours across 5 sprints**

---

## What NOT to Do (Anti-Patterns)

- **Don't add external dependencies** for toasts or alerts — keep zero-dep principle
- **Don't reorganize the 17 annotation tools** into categories yet — that's a bigger redesign
- **Don't add custom animation framework** — use built-in SwiftUI `.animation()` and `NSAnimationContext`
- **Don't add new preferences** for every visual change — animations should just work
- **Don't rewrite windows** — surgical additions to existing code only
