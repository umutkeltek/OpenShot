# CleanShot X -- Exhaustive Feature Inventory
## Competitive Intelligence for OpenShot
### Compiled: 2026-03-20

---

## 1. CAPTURE MODES

### 1.1 Capture Area (Region)
- Manually select any rectangular region of the screen
- Shows dimension overlay (width x height in pixels) during selection
- Remembers last selection area
- Crosshair overlay with pixel coordinates (activated via CMD key)
- Magnifying glass in crosshair mode (togglable in advanced preferences)
- Freeze screen option -- freezes display so moving content can be captured precisely
- Self-timer option (configurable 2-15 second delay)
- Capture sound option

### 1.2 Capture Window
- Click any window to capture it pixel-perfectly
- Automatic transparent background (no desktop behind window)
- Automatic drop shadow (togglable)
- Rounded corners preserved
- Option to capture window with custom background (solid color, gradient, wallpaper, or custom image)
- Adjustable padding around window
- Can capture specific window via click targeting
- Shadow padding customizable

### 1.3 Capture Fullscreen
- Captures the entire display
- Multi-display support (captures the display the cursor is on, or specify display 1, 2, etc.)
- Option to hide desktop icons before capture
- Option to hide widgets before capture

### 1.4 Scrolling Capture
- Vertical scrolling capture (web pages, long documents, chat logs, code)
- Horizontal scrolling capture (added in v4.8)
- Auto-scroll mode -- automatically detects content boundaries and scrolls
- Manual scroll mode -- user scrolls, app stitches frames
- Automatic image stitching of scrolled frames
- Start capture button, then auto-scroll button, then done button workflow
- Can combine with OCR to extract text from scrolling captures
- Multi-page printing support for scrolling captures

### 1.5 Text Capture (OCR)
- Select any area to extract text
- Copies extracted text directly to clipboard
- Works on non-selectable text (images, videos, scanned documents)
- Entirely on-device processing (privacy-preserving, no data leaves Mac)
- Automatic language detection
- Supports multiple languages including Arabic, Czech, Danish, Dutch, Indonesian, Malay, Norwegian, Polish, Romanian, Swedish, Turkish (added in v4.8.4)

### 1.6 Self-Timer Capture
- Configurable delay: 2 to 15 seconds
- Countdown displayed on screen
- Works with area capture
- Useful for capturing tooltips, menus, hover states

### 1.7 All-In-One Mode
- Single keyboard shortcut opens floating panel with all capture modes
- Access to: Area, Window, Fullscreen, Scrolling, Self-Timer, Recording, GIF from one shortcut
- Custom size specification within All-In-One panel
- Aspect ratio locking
- Remembers last selection dimensions
- Coordinate specification (x, y, width, height)

### 1.8 Capture Previous Area
- Re-capture the exact same region as the last screenshot
- One-click/shortcut to repeat capture

---

## 2. ANNOTATION / EDITING TOOLS

### 2.1 Core Drawing Tools
- **Arrow** -- 4 styles available, including curved arrows; adjustable thickness, curvature, color
- **Line** -- straight line tool with color and thickness controls
- **Rectangle** -- outline rectangle with color and thickness
- **Filled Rectangle** -- solid fill rectangle
- **Ellipse** -- circle/oval shape tool
- **Pencil / Freehand** -- with auto-smoothing for cleaner drawings

### 2.2 Text & Labels
- **Text Tool** -- 7 predefined styles:
  - Standard text
  - Monospaced text
  - Outlined text (cartoony style)
  - Text inside rounded rectangle box
  - Text inside fully rounded pillbox
  - (+ additional styles)
- Adjustable font size and color
- Font choice: standard or monospaced (not full system font access)
- Emoji picker integration (smiley face icon above text)
- Text alignment controls

### 2.3 Highlighting & Emphasis
- **Highlighter** -- semi-transparent marker tool
- **Smart Highlighter** (v4.7+) -- automatically detects words and adjusts brush size to match text
- **Spotlight** -- dims everything except the selected region (keeps brightness in rounded rectangle, dims the rest)
- **Counter / Numbered Steps** -- auto-incrementing numbered markers for step-by-step tutorials; customizable styles

### 2.4 Redaction & Privacy
- **Pixelate** -- drag across region to pixelate; applied randomization for better security
- **Blur** -- two modes: secure blur and smooth blur; drag, move, resize
- **Black Out / Redaction** -- solid fill to completely obscure content

### 2.5 Crop & Canvas
- **Crop Tool** -- with aspect ratio specification and edge snapping
- **Resize Tool** (v4.7+) -- change output resolution/dimensions
- **Rotate and Flip** (v4.8+) -- rotate images and flip horizontally/vertically
- **Expand Canvas** -- annotation editor can expand the image with transparent background to accommodate annotations drawn outside screenshot boundaries
- **Auto Balance** -- automatically adjusts space around content for perfect alignment
- **Combine/Merge Screenshots** -- drag and drop another screenshot into the annotate window to combine multiple images into one

### 2.6 Color & Styling
- **Color Picker** (v4.8+) -- select and save custom colors in the annotation editor
- Color controls for all tools (arrows, shapes, text, etc.)
- Thickness/weight controls for line-based tools

### 2.7 Project Files
- Save as editable .cleanshot project files
- Re-open and modify annotations later without flattening
- Non-destructive editing workflow

### 2.8 Export Formats
- PNG (default, most efficient for screenshots)
- JPG
- PDF
- WebP support (v4.8+)
- HEIC support (v4.8+)
- GIF (for recordings)
- MP4 H.264 (for recordings)
- sRGB color profile conversion

---

## 3. BACKGROUND TOOL (Window Capture Beautification)

### 3.1 Built-in Backgrounds
- 10+ aesthetically pleasing preset backgrounds included
- Gradient backgrounds (multiple color combinations)
- Solid color backgrounds
- Custom wallpaper/image backgrounds (upload your own)

### 3.2 Background Controls
- Adjustable padding around the screenshot
- Multiple alignment options (center, offset positioning)
- Aspect ratio locking (e.g., 16:9 for social media)
- Auto Balance -- automatically adjusts spacing for perfect alignment
- Reposition screenshot within canvas by dragging

### 3.3 Window Effects
- Transparent background (no background, just the window)
- Drop shadow (togglable, adjustable padding)
- Rounded corners preserved
- Editable Window Screenshots (v4.8+) -- change or remove the background AFTER taking the screenshot
- Custom background creation

---

## 4. SCREEN RECORDING FEATURES

### 4.1 Recording Modes
- **Video Recording** (MP4 H.264)
- **GIF Recording**
- Record specific window
- Record selected area/region
- Record fullscreen
- Custom dimension specification before recording
- Resolution: 480p up to 4K
- Configurable FPS (frames per second)
- Quality controls

### 4.2 Audio Capture
- Computer/system audio recording (captures Mac output)
- Microphone recording
- Both simultaneously
- Volume adjustment
- Stereo to mono audio conversion
- Audio removal capability
- Muting option

### 4.3 Camera / Webcam Overlay
- Webcam overlay during recordings
- Continuity Camera support (use iPhone as webcam)
- Overlay shapes: circular, square, or vertical format
- Adjustable position on screen
- Adjustable size
- Fullscreen camera mode

### 4.4 Input Visualization
- **Mouse Click Highlighting** -- shows visual indicator on clicks
  - Configurable color, size, style
  - Animation toggles
- **Keystroke Highlighting** -- displays pressed keys on screen
  - Configurable position on screen
  - Adjustable size
  - Dark or light style options
  - Key filtering (choose which keys to show)
- **Cursor visibility toggle** -- show or hide the cursor
- Can change these settings on-the-fly as recording starts

### 4.5 Recording Controls
- Pause / Resume recording
- Restart recording (redo intro without accumulating bad takes)
- Countdown timer before recording starts
- Menu bar displays recording duration
- Do Not Disturb auto-enable during recording
- Desktop icon hiding during recording
- Widget hiding during recording

### 4.6 Video Editor (Built-in)
- Trim start and end of recording
- GIF trimming
- Quality/resolution adjustment post-recording
- File size reduction
- Video playback preview
- Resolution change
- Volume adjustment / muting
- Stereo to mono conversion

---

## 5. QUICK ACCESS OVERLAY

### 5.1 Core Behavior
- Appears as floating thumbnail in corner of screen immediately after capture
- Shows preview of the captured screenshot or recording
- Small, non-intrusive popup

### 5.2 Actions Available
- **Copy** to clipboard (Cmd+C)
- **Save** to file (Cmd+S)
- **Annotate** / open in editor (Cmd+E)
- **Upload** to CleanShot Cloud (Cmd+U)
- **Pin** to screen (keeps screenshot floating on top)
- **Drag & Drop** -- drag the overlay directly into any app
- "Drag me" handle at bottom for drag-and-drop
- Right-click context menu with additional options (Move to trash, Extract text/OCR, etc.)

### 5.3 Overlay Settings
- Adjustable position on screen (drag to any corner/edge)
- Adjustable overlay size
- Auto-close timer (configurable -- auto-dismiss after X seconds)
- Multi-display support
- Swipe gesture controls (dismiss with swipe)
- Displays file information (dimensions, file size, etc.)

### 5.4 Restore Behavior
- If accidentally closed, use "Restore Recently Closed File" from CleanShot menu
- Dedicated keyboard shortcut available
- Available via URL scheme: /restore-recently-closed

---

## 6. CLEANSHOT CLOUD

### 6.1 Basic Cloud (Included with license)
- One-click upload from Quick Access Overlay
- Instant shareable link generation (copied to clipboard)
- 1GB cloud storage included with one-time license purchase
- Web dashboard to manage all uploads
- Delete, re-share, or export from dashboard

### 6.2 Cloud Pro (Subscription -- $8/user/month annual, $10/month monthly)
- Unlimited cloud storage
- Custom domain (use your own domain for share links)
- Custom branding (your logo on share pages)
- Password-protected links
- Self-destruct timers (auto-delete after set period)
- File tagging and naming
- Team management features
- Advanced security features

### 6.3 Cloud Notifications
- Push Notifications (v4.8.4+) -- alerts when someone comments on or views your shared media

---

## 7. KEYBOARD SHORTCUTS & ALL-IN-ONE

### 7.1 Global Capture Shortcuts (All Customizable)
- Capture Area
- Capture Window
- Capture Fullscreen
- Capture Previous Area
- Scrolling Capture
- Self-Timer
- All-In-One mode
- Record Screen
- Record GIF
- Capture Text (OCR)
- Toggle Desktop Icons
- Open Capture History
- Restore Recently Closed
- Pin Screenshot

### 7.2 Annotation Editor Shortcuts
- All annotation tools have keyboard shortcuts
- Many pre-assigned, additional ones configurable
- Cmd+C = Copy, Cmd+S = Save, Cmd+U = Upload, Cmd+E = Annotate

### 7.3 Quick Access Overlay Shortcuts
- Dedicated keyboard shortcuts for overlay actions
- Copy, Save, Upload, Annotate from overlay

### 7.4 All-In-One Shortcut
- Single shortcut opens floating panel
- Panel shows all capture modes in one interface
- Select mode, configure size/aspect ratio, execute

### 7.5 System Integration
- Can replace macOS default screenshot shortcuts (Cmd+Shift+3, Cmd+Shift+4, etc.)
- Configure via System Preferences > Keyboard > Shortcuts

---

## 8. SELF-TIMER & FREEZE SCREEN

### 8.1 Self-Timer
- Accessible from menu bar icon > Self-Timer
- Configurable interval: 2 to 15 seconds in preferences
- Countdown displayed on screen
- Select area first, then timer starts automatically
- Ideal for capturing tooltips, dropdown menus, hover states, transient UI

### 8.2 Freeze Screen
- Freezes the entire display in place
- Allows precise capture of moving content, animations, video frames
- Screen appears frozen while you draw your capture region
- Toggle in preferences or per-capture

---

## 9. DESKTOP ICON HIDING

### 9.1 Auto-Hide During Capture
- Setting in General preferences: "Hide while capturing"
- Automatically hides all desktop icons when taking any screenshot
- Icons return after capture completes

### 9.2 Manual Toggle
- Toggle desktop icons on/off from menu bar icon
- Can hide icons permanently (not just during capture)
- Useful for clean desktop presentations or recordings

### 9.3 Widget Hiding
- Can also hide macOS widgets during capture/recording
- Ensures completely clean desktop appearance

### 9.4 URL Scheme Commands
- /toggle-desktop-icons
- /hide-desktop-icons
- /show-desktop-icons

---

## 10. WINDOW CAPTURE BACKGROUNDS & EFFECTS

### 10.1 Background Types
- **Transparent** -- no background, just the window with alpha channel
- **Solid Colors** -- single color background
- **Gradients** -- multi-color gradient backgrounds
- **Built-in Presets** -- 10+ aesthetically designed backgrounds
- **Custom Image/Wallpaper** -- upload any image as background
- **macOS Wallpaper** -- use your current desktop wallpaper

### 10.2 Post-Capture Editing (v4.8+)
- Change or remove background AFTER taking the screenshot
- Don't need to re-capture to change background
- Edit window screenshots retroactively

### 10.3 Effects
- Drop shadow (togglable, adjustable)
- Rounded corners (automatic for window captures)
- Padding controls (adjustable spacing around window)
- Auto Balance alignment

---

## 11. CROSSHAIR OVERLAY & MAGNIFIER

### 11.1 Crosshair
- Activated by holding CMD key during capture
- Shows precise crosshair lines for pixel-accurate selection
- Displays pixel coordinates

### 11.2 Magnifier / Magnifying Glass
- Zoomed-in view at cursor position
- Pixel-level precision for exact selection
- Togglable in advanced preferences
- Shows alongside crosshair

### 11.3 Dimension Display
- Shows capture region dimensions (width x height) during selection
- Real-time dimension update as selection is resized

---

## 12. CAPTURE HISTORY

### 12.1 History Storage
- Automatically saves all recent captures
- Configurable retention: up to 1 month of history (added in v4.7)
- Accessible from menu bar or keyboard shortcut

### 12.2 History Management
- Browse all recent captures visually
- Filter by capture type (screenshot, recording, GIF, scrolling capture)
- Delete individual captures from history
- Restore any capture from history to Quick Access Overlay or editor

### 12.3 History Actions
- Open any historical capture in annotation editor
- Re-upload to cloud
- Copy to clipboard
- Drag and drop from history into other apps

---

## 13. RESTORE RECENTLY CLOSED SCREENSHOTS

- Menu bar option: "Restore Recently Closed File"
- Dedicated keyboard shortcut available
- URL scheme command: /restore-recently-closed
- Recovers the most recently dismissed Quick Access Overlay
- Brings back accidentally closed captures

---

## 14. PIN SCREENSHOTS (Floating Screenshots)

### 14.1 Pinning Behavior
- Pin any screenshot to float on top of all windows
- Always-on-top display
- Multiple pinned screenshots simultaneously

### 14.2 Pin Controls
- Resize pinned screenshots (drag corners)
- Adjust opacity (transparency slider)
- Precise positioning with arrow keys
- Drag to reposition anywhere on screen
- Rounded corners option (togglable)
- Shadow option (togglable)
- Border option (togglable)

### 14.3 Lock Mode
- Interact with applications underneath the pinned screenshot
- Pin becomes click-through so it doesn't interfere with work
- Pin stays visible but doesn't capture mouse events

### 14.4 Pin Shortcut
- Hold Alt/Option key + drag the "Drag me" button to pin
- Pin from Quick Access Overlay button
- Pin via URL scheme: /pin with optional filepath parameter

---

## 15. DRAG AND DROP BEHAVIORS

### 15.1 From Quick Access Overlay
- "Drag me" handle at bottom of overlay
- Drag directly into any application (Slack, email, Figma, etc.)
- Drag copies the image file into the target app

### 15.2 From Capture History
- Drag any capture from history into other applications
- Immediately copies and pastes the content

### 15.3 From Annotation Editor
- "Drag me" handle in annotation editor
- Drag annotated screenshot directly into any app
- No need to save first

### 15.4 Into Annotation Editor
- Drag and drop external images INTO the annotation window
- Combine multiple screenshots by dragging one into another
- Position the dropped image within the canvas

### 15.5 Save via Drag
- Drag to desktop or Finder to save as file
- Drag to any folder location

---

## 16. UNIQUE / PREMIUM / ADVANCED FEATURES

### 16.1 PixelSnap Integration
- Integration with PixelSnap app for measuring distances between UI elements
- Pixel-perfect measurement alongside screenshot capture

### 16.2 QR Code Reader
- Can detect and read QR codes in captures

### 16.3 URL Scheme API
- Full programmatic control via URL scheme
- Commands for every capture mode, annotation, settings
- Integration with Alfred, Raycast, Keyboard Maestro, and other automation tools
- Parameters: x, y, width, height, display, action (copy/save/annotate/upload/pin)
- Available commands:
  - /all-in-one
  - /capture-area
  - /capture-previous-area
  - /capture-fullscreen
  - /capture-window
  - /self-timer
  - /scrolling-capture (with auto-start and auto-scroll parameters)
  - /record-screen
  - /capture-text
  - /open-annotate
  - /open-from-clipboard
  - /toggle-desktop-icons
  - /hide-desktop-icons
  - /show-desktop-icons
  - /add-quick-access-overlay
  - /open-history
  - /restore-recently-closed
  - /open-settings (with tab parameter: general, wallpaper, shortcuts, quickaccess, recording, screenshots, annotate, cloud, advanced, about)
  - /pin

### 16.4 Retina Display Handling
- Captures at Retina resolution by default
- Option to automatically scale down Retina screenshots to standard (1x) resolution
- sRGB color profile conversion

### 16.5 File Naming & Organization
- Custom file name templates
- Auto-increment numbering
- Include app name in filename
- Include window title in filename
- Configurable save location/destination

### 16.6 Notification System
- Push notifications when someone comments on or views shared media (v4.8.4+)

### 16.7 Virtual Camera Support
- Can use CleanShot as a virtual camera source

### 16.8 System Share Menu Integration
- Share via macOS system share sheet

### 16.9 Dark Mode / Light Mode
- Full dark mode support
- Full light mode support
- Follows system appearance

### 16.10 Menu Bar Presence
- Lives in macOS menu bar for quick access
- Option to hide menu bar icon
- Menu bar dropdown with all capture modes
- Shows recording duration during active recording

### 16.11 Apple Silicon Native
- Native Apple Silicon (M1/M2/M3/M4) support
- macOS Tahoe (latest macOS) compatibility

### 16.12 Continuity Camera
- Use iPhone as webcam overlay in recordings

### 16.13 Presenter Overlay Support
- Support for presenter overlay during recordings

### 16.14 Do Not Disturb Integration
- Auto-enable DND during screen recording
- Prevents notification popups from appearing in recordings

### 16.15 Raycast AI Chat Integration
- Integration with Raycast for AI-powered workflows

---

## 17. PRICING MODEL

| Plan | Price | Includes |
|------|-------|----------|
| App + Cloud Basic | $29 one-time | Full app forever, 1 year updates, 1GB cloud |
| Update Renewal | $19/year (optional) | Continued updates after first year |
| Cloud Pro | $8/user/month (annual) or $10/month | Unlimited storage, custom domain, branding, passwords, self-destruct, teams |
| Setapp | Included in Setapp subscription | Full app access |

---

## 18. SETTINGS / PREFERENCES TABS

1. **General** -- desktop icon hiding, startup behavior, appearance
2. **Wallpaper/Background** -- background presets, custom backgrounds
3. **Shortcuts** -- all keyboard shortcut customization
4. **Quick Access** -- overlay behavior, position, auto-close, size
5. **Recording** -- video quality, FPS, audio, cursor, click/keystroke highlighting
6. **Screenshots** -- file format, save location, naming templates, Retina scaling
7. **Annotate** -- annotation tool defaults, editor preferences
8. **Cloud** -- cloud account settings, upload preferences
9. **Advanced** -- crosshair, magnifier, freeze screen, and other advanced options
10. **About** -- version info, license

---

## 19. TOTAL FEATURE COUNT SUMMARY

CleanShot X advertises "50+ features" but the actual enumeration reveals significantly more individual capabilities when each sub-feature is counted:

- **8 distinct capture modes** (Area, Window, Fullscreen, Scrolling Vertical, Scrolling Horizontal, OCR/Text, Self-Timer, All-In-One)
- **15+ annotation tools** (Arrow x4 styles, Line, Rectangle, Filled Rectangle, Ellipse, Pencil, Text x7 styles, Highlighter, Smart Highlighter, Spotlight, Counter, Pixelate, Blur x2 modes, Black Out, Crop, Resize, Rotate/Flip, Color Picker)
- **6 background types** (Transparent, Solid, Gradient, Presets, Custom Image, Wallpaper)
- **2 recording formats** (MP4, GIF) with 3 area modes (region, window, fullscreen)
- **3 audio sources** (system, microphone, both)
- **3 webcam shapes** (circle, square, vertical)
- **20+ URL scheme API commands**
- **10 settings tabs**
- **Cloud with 2 tiers** (Basic, Pro)

---

## SOURCES

- [CleanShot X -- All Features](https://cleanshot.com/features)
- [CleanShot X -- Changelog](https://cleanshot.com/changelog)
- [CleanShot X -- URL Scheme API](https://cleanshot.com/docs-api)
- [CleanShot X -- Pricing](https://cleanshot.com/pricing)
- [CleanShot Cloud](https://cleanshot.com/cloud/)
- [CleanShot X launches Pro Cloud accounts -- 9to5Mac](https://9to5mac.com/2021/05/20/cleanshot-x-launches-pro-cloud-accounts/)
- [CleanShot X Review -- Podfeet Podcasts](https://www.podfeet.com/blog/2022/04/cleanshot-x/)
- [CleanShot X Review -- Dave Swift](https://daveswift.com/cleanshot-x/)
- [CleanShot X -- Setapp](https://setapp.com/apps/cleanshot)
- [CleanShot X Tutorial -- Setapp](https://setapp.com/how-to/no-clutter-screen-capturing-for-mac)
- [CleanShot X Review -- OWC](https://www.owc.com/blog/cleanshot-x-is-the-screenshot-utility-built-for-pros)
- [CleanShot X Review -- Tario Sultan](https://tariosultan.com/blog/cleanshot-x-review-screen-capture-tool-tutorial)
- [CleanShot X -- Alchemists](https://alchemists.io/articles/clean_shot)
- [CleanShot X Keyboard Shortcuts -- KeyScreen](https://keyscreenapp.com/cleanshot-x-keyboard-shortcuts)
- [CleanShot X shortcuts -- Pie Menu](https://www.pie-menu.com/shortcuts/cleanshot)
- [CleanShot X iMore shortcuts article](https://www.imore.com/cleanshot-x-gains-new-keyboard-shortcuts-quick-access-overlay-more)
- [CleanShot X Custom Backgrounds -- Scott W](https://scottw.com/cleanshot-custom-backgrou/)
- [CleanShot X OCR -- Scott Willsey](https://scottwillsey.com/cleanshotx-text-recog/)
- [CleanShot X Scrolling Screenshots -- Scott Willsey](https://scottwillsey.com/cleanshotx-scrolling-screenshots/)
- [CleanShot 4.8 tweet](https://x.com/CleanShot/status/1927383100247396569)
- [CleanShot X v4.7 -- AlternativeTo](https://alternativeto.net/news/2024/5/screen-capture-tool-cleanshot-x-releases-v4-7-with-resize-tool-and-smart-highlighter/)
- [CleanShot X Review 2026 -- TheSweetBits](https://thesweetbits.com/tools/cleanshot-review/)
- [CleanShot X -- XDA Developers](https://www.xda-developers.com/cleanshot-x-best-screenshot-tool-macos/)
- [CleanShot X -- How to Take Screenshot](https://how-to-take-screenshot.com/cleanshotx/)
- [CleanShot X -- Hulry Review](https://hulry.com/cleanshot-review/)
