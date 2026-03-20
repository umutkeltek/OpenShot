# Exhaustive Feature Inventory: Shottr & CleanShot X (2025-2026)

Research Date: 2026-03-20
Researcher: Ava Sterling (PAI ClaudeResearcher)

---

## PART 1: SHOTTR — COMPLETE FEATURE INVENTORY

### 1. Capture Modes

| Mode | Details |
|------|---------|
| **Area Capture** | Select any rectangular region of the screen. Hotkey-triggered. |
| **Window Capture** | Capture a specific application window. |
| **Fullscreen Capture** | Capture the entire display. |
| **Scrolling Capture** | Captures long web pages, chat conversations, or any vertically scrollable content by automatically scrolling and stitching. |
| **Quick Zoom Capture (Z+Drag)** | Press Z and drag to zoom into a specific area — captures a zoomed-in region instantly. |
| **Delayed/Repeat Capture** | Not natively available (no self-timer). |
| **Screen Recording** | NOT available — Shottr is screenshot-only, no video/GIF recording. |

### 2. Pixel-Perfect Measurement & Ruler Tools (UNIQUE vs CleanShot X)

This is Shottr's flagship differentiator. CleanShot X has NO equivalent.

- **Screen Ruler**: Measure pixel distances on any screenshot. Press Shift to get the outer size of an element. Click while measuring to permanently imprint the measurement onto the screenshot.
- **Pixel-Accurate Zoom**: Sub-pixel accuracy for inspecting interface elements, checking alignments, and measuring distances.
- **Shift modifier**: Toggles between inner and outer element size measurements.
- **Click-to-imprint**: Measurements become part of the screenshot annotation permanently.
- **Use case**: Developers and designers verifying spacing, padding, margins, and alignment in UI work.

### 3. Color Picker with History (UNIQUE vs CleanShot X until 4.8)

- **Activation**: Take a screenshot, zoom in, hover over any pixel, press TAB to copy the color value.
- **Supported Color Formats**: HEX, RGB, HSL, OKLCH (added v1.8), and APCA.
- **WCAG Contrast Ratio Indicator**: Displays contrast ratio above the selection marquee during area selection.
- **APCA Measurement**: Available in the color contrast checker — toggle between WCAG 2.0 and APCA by Option+Click on the contrast value.
- **Color Inspector**: Full inspector panel showing pixel color in multiple formats simultaneously.

Note: CleanShot X added a basic color picker in v4.8, but Shottr's is far more advanced with WCAG/APCA contrast checking, OKLCH support, and pixel-level precision.

### 4. Annotation Tools

| Tool | Details |
|------|---------|
| **Arrows** | Multiple styles: standard, slim, super-slim. Every arrow type can be bent into an arch (curved arrows). Longer arrows render slimmer automatically. |
| **Text Labels** | Multiple sizes available. Hand-drawn style option. |
| **Rectangles** | Standard and hand-drawn style option. |
| **Ovals/Circles** | Standard and hand-drawn style option. |
| **Highlighting** | Highlight text and regions. |
| **Numbering/Steps** | Numbered annotations for step-by-step documentation. |
| **Magnifier/Callout** | Zoomed-in callout tool — creates a magnified circle showing detail of a specific area. |
| **Image Overlay** | Paste images on top of screenshots. |
| **Cropping** | Crop screenshots within the editor. |
| **Hand-drawn Style** | Toggle for Text, Arrow, Oval, and Rectangle objects to appear hand-drawn. Added in v1.9. |
| **Custom Colors** | Enhanced custom annotation color support (v1.8+). |

### 5. Blur, Erase & Redaction (UNIQUE Smart Text Recognition)

This is a major Shottr differentiator. Four distinct modes:

| Mode | Behavior |
|------|----------|
| **Plain Blur** | Pixelates everything in the selected region. Standard blur. |
| **Blur Text Only** | Intelligently detects and blurs ONLY text within the selection — leaves photos, backgrounds, and graphics untouched. |
| **Erase Text** | Erases text and graphics but preserves the background — as if the text was never there. |
| **Erase All** | Removes everything in the selected area. |

- **Blur Strength Slider**: Adjustable pixelation intensity via pop-over menu.
- **Keyboard shortcut**: Press B to activate blur/erase mode.
- **Element Recognition**: The text-mode blur/erase uses OCR-based element recognition to distinguish text from background, enabling surgical redaction of sensitive information without corrupting surrounding visual context.

This is significantly more sophisticated than CleanShot X's standard blur tool, which simply pixelates the entire selected region.

### 6. OCR / Text Recognition

- **Hotkey-triggered OCR**: Press hotkey, select area, text is parsed and copied to clipboard instantly.
- **QR Code Reading**: OCR engine also reads QR codes visible on screen — no phone needed.
- **Approach**: Uses macOS native Vision framework for text recognition. Instant — no cloud processing, no delay.
- **Use case**: Extracting text from images, diagrams, system interfaces, error messages, or any non-selectable text on screen.

### 7. Beautify / Backdrop Tool (Added v1.8)

- **Gradient Backgrounds**: Add customizable gradient backgrounds behind screenshots.
- **Shadows**: Apply drop shadows for depth.
- **Rounded Corners**: Round the corners of the screenshot.
- **Combined effect**: Makes screenshots presentation-ready for social media, documentation, or marketing materials.

### 8. Pin Screenshots (Floating Window)

- **Pin icon**: Creates a minimalistic floating always-on-top window of just the screenshot.
- **Scroll-to-resize**: Scroll to resize the pinned window. Shows percentage (100%, 200%, etc.) and snaps to round numbers.
- **Drag corner resize**: Resize by dragging the corner of the floating window.
- **Use case**: Reference an image from one app while working in another.

### 9. Before/After GIF Creation

- Paste an "after" image on top of the "before" screenshot.
- Press "5" to enable transparency for alignment.
- Align frames, then hit the GIF icon to create a two-frame before/after animation.
- Lightweight GIF creation without any video recording.

### 10. Upload & Sharing

| Feature | Details |
|---------|---------|
| **S3 Upload** | Upload to any S3-compatible storage (AWS, Tencent, Yandex, Minio). Single-click upload, shareable link copied to clipboard. |
| **Copy to Clipboard** | Cmd+C copies selection only (doesn't close window). Optimized — no delay even on busy machines. |
| **Drag and Drop** | Drag from Shottr editor to any app. Applies same settings as regular save (PNG/JPEG, 1x downscale). |
| **Save Formats** | PNG, JPG, PDF. |
| **Print** | File > Print or Cmd+Shift+P. |
| **Upload Management** | Management page for uploaded screenshots (v1.9+). |

Note: No proprietary cloud service — you bring your own S3 bucket.

### 11. Integrations & Automation (Added v1.8)

- **Raycast Extensions**: Full Raycast integration via URL schemes.
- **Alfred Workflows**: Alfred workflow support for triggering Shottr actions.
- **URL Schemes (Deeplinks)**: Other apps and scripts can control Shottr actions programmatically.
- **Shortcuts App**: Compatible with macOS Shortcuts app via URL schemes.
- **Yoink/Dropover**: Drag-and-drop to shelf apps; files persist after new screenshots.

### 12. Performance Characteristics

| Metric | Value |
|--------|-------|
| **App Size** | 2.3 MB DMG (some versions as small as 1.2 MB) |
| **Screenshot Capture Time** | 17ms to grab a screenshot |
| **Display Time** | ~165ms to capture and show the editor |
| **Architecture** | Native macOS, optimized for Apple Silicon (M1/M2/M3/M4) |
| **Memory Usage** | Minimal — low-level macOS APIs for maximum performance |
| **Startup** | Near-instant launch |
| **Design Philosophy** | "Speed and simplicity over comprehensive features" — deliberately limited scope to maintain tiny footprint |
| **Framework** | Native Cocoa/AppKit (not Electron) |

### 13. Version History (Key Releases)

| Version | Date | Key Additions |
|---------|------|---------------|
| **v1.8** | Late 2024 | Backdrop/beautify tool, Raycast/Alfred integration, URL schemes, OKLCH/APCA color formats, custom annotation colors, moved to paid model |
| **v1.9** | 2025 | Hand-drawn style annotations, bendable/curved arrows, S3 upload support, upload management page, super-slim arrows |
| **v1.9.1** | 2025 | Latest known version. Quick zoom (Z+Drag), open files/clipboard images from main menu, bug fixes |

### 14. Pricing Model (2025-2026)

| Tier | Price | Details |
|------|-------|---------|
| **Trial** | Free | 30-day full-featured trial. After trial, app continues working but periodically asks you to purchase. |
| **Basic** | $8 one-time | Full license. All features. No subscription. |
| **Friends Club** | $30 one-time | Access to experimental features, priority support, supports the developer. |

History: Pre-v1.8, Shottr was entirely free with optional "tip jar" donations. V1.8 (late 2024) introduced the paid model.

### 15. Additional / Miscellaneous Features

- **Open files**: Open image files from main menu (Shottr icon > More > Open File).
- **Load clipboard images**: Load images from clipboard into the editor.
- **1x Downscale**: Option to save at 1x resolution (useful for Retina displays).
- **WCAG Contrast Ratio**: Displayed above selection marquee during area capture.
- **Retina-quality rendering**: Full HiDPI support.
- **Keyboard-driven workflow**: Extensive keyboard shortcuts for every action.

---

## PART 2: CLEANSHOT X — COMPLETE FEATURE INVENTORY (2025-2026)

### Capture Modes

| Mode | Details |
|------|---------|
| **Area Capture** | Select any rectangular region. |
| **Window Capture** | Capture specific window with editable background (v4.8+). |
| **Fullscreen Capture** | Full display capture. |
| **Scrolling Capture** | Vertical AND horizontal scrolling (horizontal added v4.8). |
| **Self-Timer** | Set a delay before capture for positioning. |
| **Freeze Screen** | Freeze the screen state to capture dropdown menus, hover states, tooltips. |
| **Screen Recording** | Full video recording — MP4 format. |
| **GIF Recording** | Record screen as animated GIF. |

### Annotation Tools

- Arrows, lines, shapes (rectangles, ovals)
- Text labels
- Blur/pixelate regions
- Spotlight/highlight
- **Smart Highlighter** (NEW): Automatically detects words and adjusts brush size — highlights text intelligently.
- Numbering/steps
- Emoji stamps
- Crop, rotate, flip images (rotate/flip added v4.8)
- **Editable project files**: Save annotated screenshots as .cleanshot project files for re-editing later.
- **Color Picker** (NEW in v4.8): Select and save custom colors in Annotate. Basic compared to Shottr's.

### Background / Beautify Tool

- Add backgrounds to screenshots.
- Adjustable padding, alignment, and aspect ratio.
- Designed for social media posts and presentations.

### OCR Text Recognition

- Hotkey or menu-triggered OCR.
- Select area, text copied to clipboard.
- **Auto language detection** (added v4.8) — automatically detects the language of text.
- QR code reading.

### Cloud & Sharing

- **CleanShot Cloud**: Proprietary cloud hosting integrated into the app.
- One-click upload, instant shareable link.
- 1 GB storage (one-time purchase) or unlimited (subscription).
- **Custom domain and branding** (subscription tier).
- **Self-destruct links** (subscription tier).
- **Password-protected links** (subscription tier).
- **Push notifications** when someone views/comments on your media (v4.8.4).
- **Screen recording upload** to CleanShot Cloud.

### Screen Recording Features

- MP4 and GIF output.
- Microphone and system/computer audio recording.
- **Mouse click highlighting** — visual indicator of clicks during recording.
- **Keystroke highlighting** — display keystrokes on screen during recording.
- **GIF trimming** — trim GIF recordings after capture.

### Unique CleanShot X Features (Not in Shottr)

| Feature | Details |
|---------|---------|
| **Screen Recording** | Full video capture with audio — Shottr has none. |
| **GIF Recording** | Native GIF creation from screen recording. |
| **Quick Access Overlay** | Floating thumbnail after capture for instant annotate, copy, save, pin, or upload. |
| **Hide Desktop Icons** | One-click hide all desktop icons for clean screenshots. |
| **Freeze Screen** | Freeze display state for dropdown/tooltip capture. |
| **Self-Timer** | Delayed capture. |
| **CleanShot Cloud** | Proprietary cloud with sharing, comments, views, self-destruct, passwords. |
| **Smart Highlighter** | AI-powered word detection for intelligent highlighting. |
| **Raycast AI Chat Integration** | Send screenshots to AI Chat directly from Annotate or Quick Access Overlay. |
| **Editable Project Files** | .cleanshot files for re-editing annotations later. |
| **Multi-page Printing** | Print scrolling captures across multiple pages (v4.8). |
| **WebP/HEIC Support** | Added in v4.8. |

### Recent Version History (2025-2026)

| Version | Date | Key Additions |
|---------|------|---------------|
| **v4.8** | 2025 | Color picker in Annotate, horizontal scrolling capture, editable window screenshots, rotate/flip in Annotate, auto-detect OCR language, WebP/HEIC support, improved image stitching, multi-page printing |
| **v4.8.4** | Oct 15, 2025 | Push notifications for media views/comments |
| **v4.8.5** | Dec 2, 2025 | New interface design for macOS Tahoe |
| **v4.8.7** | Dec 22, 2025 | Crash fix for screen recording |

### Pricing (2026)

| Tier | Price | Details |
|------|-------|---------|
| **One-Time Purchase** | $29 | App forever, 1 year of updates, 1 GB cloud. $19/yr optional for continued updates. |
| **Subscription** | $10/user/month (or $96/user/year) | Unlimited updates, unlimited cloud, custom domain/branding, self-destruct links, password protection. |
| **Via Setapp** | $9.99/month (Setapp subscription) | Access as part of the Setapp bundle. |

---

## PART 3: STRATEGIC COMPARISON — SHOTTR'S UNIQUE ADVANTAGES

### Features Shottr Has That CleanShot X Lacks Entirely

| Shottr Feature | CleanShot X Equivalent | Strategic Value |
|----------------|----------------------|-----------------|
| **Pixel Ruler / Measurement Tool** | NONE | Critical for developers/designers checking spacing, padding, alignment |
| **WCAG Contrast Ratio Checker** | NONE | Accessibility compliance built into the screenshot tool |
| **APCA Contrast Measurement** | NONE | Advanced perceptual contrast algorithm for modern accessibility standards |
| **OKLCH Color Format** | NONE | Modern color space support for designers |
| **Smart Text-Only Blur** | Standard blur only | Surgically redacts text while preserving backgrounds and images |
| **Smart Text Erase** | Standard blur only | Removes text as if it was never there, preserving underlying background |
| **Before/After GIF Creation** | Not available (requires recording) | Quick comparison animations without video recording |
| **Image Overlay / Paste-on-top** | Not available | Layer images on screenshots for comparison or documentation |
| **S3 Upload (BYOB)** | Proprietary cloud only | No vendor lock-in, use your own storage infrastructure |
| **Click-to-Imprint Measurements** | NONE | Permanently add measurement annotations to screenshots |
| **Sub-pixel Accuracy Inspection** | NONE | Precision beyond standard screenshot zoom |
| **Transparency Toggle (press 5)** | Not available | Enable transparency for alignment work |
| **17ms Capture Speed** | Not publicly benchmarked | Fastest known screenshot capture time |
| **2.3 MB App Size** | ~50-80 MB | 20-35x smaller footprint |
| **URL Schemes / Deeplinks** | Limited API | Full automation via URL schemes for scripts, Shortcuts, Alfred, Raycast |

### Features CleanShot X Has That Shottr Lacks Entirely

| CleanShot X Feature | Strategic Impact |
|---------------------|-----------------|
| **Screen Recording (Video)** | Major gap — Shottr is screenshot-only |
| **GIF Recording** | No screen-to-GIF workflow in Shottr |
| **Quick Access Overlay** | Shottr lacks the floating post-capture action menu |
| **Hide Desktop Icons** | Shottr has no desktop cleanup feature |
| **Freeze Screen** | Cannot capture hover states/dropdowns easily in Shottr |
| **Self-Timer** | No delayed capture in Shottr |
| **Proprietary Cloud with sharing** | Shottr requires self-hosted S3 |
| **Smart Highlighter** | Shottr's highlight is manual, not word-aware |
| **AI Chat Integration** | No AI integration in Shottr |
| **Editable Project Files** | Shottr annotations are destructive (baked in on save) |
| **Custom Domain / Password Links** | No sharing infrastructure in Shottr |
| **Audio Recording** | No audio capture at all in Shottr |
| **Keystroke/Click Visualization** | No recording = no keystroke display |

---

## PART 4: SECOND-ORDER STRATEGIC INSIGHTS (For OpenShot)

### 1. The Measurement Tool Gap Is Real
No other major screenshot app has matched Shottr's pixel ruler. This is a genuine unmet need in the market, especially for developers. If OpenShot implements measurement tools, it enters a category of ONE competitor (Shottr), not dozens.

### 2. Smart Redaction Is Underrated
Shottr's text-only blur/erase is genuinely unique. Every other tool (including CleanShot X) just pixelates a rectangle. The ability to surgically remove text while preserving backgrounds is a feature that users rave about once they discover it. This is worth implementing.

### 3. Performance Is a Feature
Shottr's 17ms capture / 165ms display time and 2.3MB footprint set the gold standard. Users who switch from CleanShot X to Shottr frequently cite speed as the reason. Building with native Swift/AppKit (not Electron) is essential.

### 4. The Pricing Sweet Spot
Shottr at $8 one-time and CleanShot X at $29 one-time (or $10/mo subscription) shows the market spans from budget to premium. CleanShot X's subscription pressure is creating demand for one-time-purchase alternatives.

### 5. Cloud Is a Differentiator — But Also a Liability
CleanShot X's cloud is a major selling point but also its biggest vendor lock-in concern. Shottr's S3 approach (bring your own bucket) appeals to privacy-conscious users and teams with existing infrastructure. OpenShot should consider supporting both models.

---

## Sources

- [Shottr Official Website](https://shottr.cc/)
- [Shottr Changelog / New Version](https://shottr.cc/newversion.html)
- [Shottr Purchase Page](https://shottr.cc/purchase.html)
- [Shottr URL Schemes Documentation](https://shottr.cc/kb/urlschemes)
- [Shottr FAQ](https://shottr.cc/kb/faq)
- [Shottr S3 Upload Documentation](https://shottr.cc/kb/s3)
- [Shottr vs CleanShot X — Setapp](https://setapp.com/app-reviews/cleanshot-x-vs-shottr)
- [Shottr for Mac Review 2026 — ScreenSnap Pro](https://www.screensnap.pro/blog/shottr-mac-review)
- [6 Reasons I Use Shottr Instead of the Mac Screenshot Tool — How-To Geek](https://www.howtogeek.com/reasons-i-use-shottr-instead-of-the-mac-screenshot-tool/)
- [Shottr Review — Podfeet Podcasts](https://www.podfeet.com/blog/2023/05/shottr/)
- [12 Best Screenshot Apps for Mac 2025 — GrabShot](https://blog.grabshot.io/best-screenshot-apps-for-mac/)
- [CleanshotX vs Shottr vs Xnapper — Toolfolio](https://toolfolio.io/productive-value/compare-cleanshotx-shottr-and-xnapper-to-find-the-best-screenshot-tool-for-your-mac-needs)
- [CleanShot X vs Shottr vs Snagit — Apps.Deals](https://blog.apps.deals/2025-01-23-screenshot-tools-comparison)
- [Screenshot app Shottr 1.8 — AlternativeTo](https://alternativeto.net/news/2024/10/screenshot-app-shottr-1-8-brings-new-backdrop-tool-raycast-and-alfred-integration-and-more/)
- [CleanShot X Official Website](https://cleanshot.com/)
- [CleanShot X All Features](https://cleanshot.com/features)
- [CleanShot X Changelog](https://cleanshot.com/changelog)
- [CleanShot X Pricing](https://cleanshot.com/pricing)
- [CleanShot 4.8 — Product Hunt](https://www.producthunt.com/p/cleanshot/cleanshot-4-8-new-color-picker-horizontal-scrolling-capture-editable-window-screenshots)
- [CleanShot X Review 2026 — Tutsflow](https://tutsflow.com/reviews/cleanshot-x/)
- [CleanShot X Review 2026 — Joseph Nilo](https://josephnilo.com/blog/cleanshot-x-setapp-review/)
- [Best Screenshot Apps 2026 — ScreenSnap Pro](https://www.screensnap.pro/blog/best-screenshot-apps-for-mac)
- [Shottr Product Hunt Reviews](https://www.producthunt.com/products/shottr/reviews)
- [Open Image Files in Shottr — Harry Bailey](https://harrybailey.com/2026/02/open-image-files-in-shottr-by-drag-n-dropping-them/)
- [Shottr Review — Chris Dermody](https://chrisdermody.com/product-review-shottr-screenshot-for-mac/)
- [Shottr Review — AnyMP4](https://www.anymp4.com/recorder/shottr-review.html)
- [Shottr — TechPreneurHive](https://www.techpreneurhive.com/2025/01/shottr-your-all-in-one-screenshot.html)
