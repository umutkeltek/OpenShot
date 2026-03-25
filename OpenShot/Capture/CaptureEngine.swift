// CaptureEngine.swift
// OpenShot
//
// Central capture engine wrapping ScreenCaptureKit for all capture
// modes: area, window, fullscreen, and scrolling. Each method
// presents the appropriate selection UI, performs the capture via
// SCScreenshotManager, and returns an NSImage.

import AppKit
import ScreenCaptureKit
import SwiftData
import os

@Observable
final class CaptureEngine {

    // MARK: - Singleton

    static let shared = CaptureEngine()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.openshot", category: "capture")
    private let preferences = Preferences.shared

    /// The most recently captured image, observable for UI binding.
    private(set) var lastCapturedImage: NSImage?

    /// The rectangle from the most recent area capture, for "Capture Previous Area".
    private(set) var lastCapturedRect: CGRect?

    /// The most recently dismissed capture result, for "Restore Recently Closed".
    static var lastDismissedImage: NSImage?

    // MARK: - Initializer

    private init() {}

    // MARK: - Area Capture

    /// Present the area selector overlay, let the user rubber-band a
    /// region, then capture that region via ScreenCaptureKit.
    @MainActor
    func captureArea() async throws -> NSImage {
        logger.info("Starting area capture")

        // 0. If freeze-screen is enabled, capture the current screen first.
        var frozenImage: NSImage?
        if preferences.freezeScreen {
            logger.debug("Freeze screen enabled — capturing frozen background")
            let combined = ScreenInfo.combinedScreenFrame()
            if let cgImage = CGWindowListCreateImage(
                combined,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
            ) {
                frozenImage = NSImage(cgImage: cgImage, size: combined.size)
            }
        }

        // 1. Let the user draw a selection rectangle.
        guard let selectedRect = await AreaSelector.present(
            crosshair: preferences.showCrosshair,
            magnifier: preferences.showMagnifier,
            frozenBackground: frozenImage
        ) else {
            logger.debug("Area capture cancelled by user")
            throw CaptureEngineError.cancelled
        }

        // Store the rect for "Capture Previous Area" feature.
        lastCapturedRect = selectedRect

        logger.debug("Area selected: \(selectedRect.debugDescription)")

        // 2. Enumerate shareable content.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // 3. Find the display that contains the centre of the selection.
        guard let display = displayContaining(point: CGPoint(x: selectedRect.midX, y: selectedRect.midY),
                                              in: content.displays) else {
            throw CaptureEngineError.noDisplayFound
        }

        // 4. Build filter — capture the full display, we crop to the rect.
        let excludedWindows = openShotWindows(from: content.windows)
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        // 5. Build configuration targeting the selected rectangle.
        let config = SCStreamConfiguration()
        config.sourceRect = convertToCGSourceRect(selectedRect, display: display)
        config.width = Int(selectedRect.width * (NSScreen.main?.backingScaleFactor ?? 2))
        config.height = Int(selectedRect.height * (NSScreen.main?.backingScaleFactor ?? 2))
        config.captureResolution = .best
        config.showsCursor = preferences.includeCursor

        // 6. Capture.
        let image = try await performCapture(filter: filter, config: config)
        logger.info("Area capture completed (\(Int(selectedRect.width))×\(Int(selectedRect.height)))")
        return image
    }

    // MARK: - Window Capture

    /// Present the window picker, let the user click a window, then
    /// capture that window.
    @MainActor
    func captureWindow() async throws -> NSImage {
        logger.info("Starting window capture")

        guard let scWindow = await WindowPicker.present() else {
            logger.debug("Window capture cancelled by user")
            throw CaptureEngineError.cancelled
        }

        logger.debug("Window selected: \(scWindow.title ?? "untitled") (id: \(scWindow.windowID))")

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)

        let config = SCStreamConfiguration()
        config.width = Int(scWindow.frame.width * (NSScreen.main?.backingScaleFactor ?? 2))
        config.height = Int(scWindow.frame.height * (NSScreen.main?.backingScaleFactor ?? 2))
        config.captureResolution = .best
        config.showsCursor = preferences.includeCursor

        // When the user has disabled window shadow, set an opaque
        // background so the shadow region is replaced with a solid fill
        // rather than transparent alpha.
        if !preferences.windowShadow {
            config.backgroundColor = .white
        }

        let image = try await performCapture(filter: filter, config: config)

        var finalImage = image
        if preferences.windowBackground != .none {
            let style: WindowBackgroundRenderer.BackgroundStyle
            switch preferences.windowBackground {
            case .none: style = .none
            case .solid: style = .solid(.windowBackgroundColor)
            case .gradient: style = .gradient(.systemBlue, .systemPurple, .diagonal)
            case .desktop: style = .preset(.oceanBlue)
            }
            finalImage = WindowBackgroundRenderer.apply(
                to: image,
                style: style,
                padding: preferences.windowPadding,
                shadowEnabled: preferences.windowShadow
            )
        }

        logger.info("Window capture completed")
        return finalImage
    }

    // MARK: - Fullscreen Capture

    /// Capture the entire display that the cursor is currently on.
    @MainActor
    func captureFullscreen() async throws -> NSImage {
        logger.info("Starting fullscreen capture")

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Determine cursor location and find matching display.
        let cursorLocation = NSEvent.mouseLocation
        guard let display = displayContaining(
            point: nsPointToCGPoint(cursorLocation),
            in: content.displays
        ) else {
            throw CaptureEngineError.noDisplayFound
        }

        let excludedWindows = openShotWindows(from: content.windows)
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) * (NSScreen.main?.backingScaleFactor ?? 2))
        config.height = Int(CGFloat(display.height) * (NSScreen.main?.backingScaleFactor ?? 2))
        config.captureResolution = .best
        config.showsCursor = preferences.includeCursor

        let image = try await performCapture(filter: filter, config: config)
        logger.info("Fullscreen capture completed (\(display.width)×\(display.height))")
        return image
    }

    // MARK: - Scrolling Capture (experimental)

    /// Basic scrolling capture — captures the visible area, scrolls down,
    /// captures again, and stitches the images vertically.
    ///
    /// - Note: This is experimental. Works best with simple scrolling
    ///   content. Future versions may use more sophisticated stitching.
    @MainActor
    func captureScrolling() async throws -> NSImage {
        logger.info("Starting scrolling capture (experimental)")

        // Step 1: Let the user select the scrollable area.
        guard let selectedRect = await AreaSelector.present(
            crosshair: true,
            magnifier: false
        ) else {
            throw CaptureEngineError.cancelled
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = displayContaining(
            point: CGPoint(x: selectedRect.midX, y: selectedRect.midY),
            in: content.displays
        ) else {
            throw CaptureEngineError.noDisplayFound
        }

        let excludedWindows = openShotWindows(from: content.windows)
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        let config = SCStreamConfiguration()
        config.sourceRect = convertToCGSourceRect(selectedRect, display: display)
        config.width = Int(selectedRect.width * (NSScreen.main?.backingScaleFactor ?? 2))
        config.height = Int(selectedRect.height * (NSScreen.main?.backingScaleFactor ?? 2))
        config.captureResolution = .best
        config.showsCursor = false

        var capturedFrames: [NSImage] = []

        // Capture initial frame.
        let firstFrame = try await performCapture(filter: filter, config: config)
        capturedFrames.append(firstFrame)

        // Scroll and capture additional frames (up to 5 scrolls).
        let scrollCount = 5
        let scrollAmount: Int32 = -3  // negative = scroll down

        for i in 1...scrollCount {
            // Small delay to let rendering settle.
            try await Task.sleep(for: .milliseconds(400))

            // Inject scroll event at the centre of the selected area.
            let scrollPoint = CGPoint(x: selectedRect.midX, y: selectedRect.midY)
            guard let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 1,
                wheel1: scrollAmount,
                wheel2: 0,
                wheel3: 0
            ) else { continue }
            scrollEvent.location = scrollPoint
            scrollEvent.post(tap: .cghidEventTap)

            // Wait for scroll animation.
            try await Task.sleep(for: .milliseconds(500))

            let frame = try await performCapture(filter: filter, config: config)
            capturedFrames.append(frame)
            logger.debug("Scrolling capture: captured frame \(i + 1)")
        }

        // Stitch frames vertically.
        let stitched = stitchImagesVertically(capturedFrames)
        logger.info("Scrolling capture completed with \(capturedFrames.count) frames")
        return stitched
    }

    // MARK: - Self-Timer Capture

    /// Show a countdown overlay, then trigger the specified capture mode.
    /// - Parameter mode: The capture mode to execute after the countdown.
    @MainActor
    func captureWithSelfTimer(mode: CaptureMode) async throws -> NSImage {
        logger.info("Starting self-timer capture (mode: \(mode.rawValue), delay: \(self.preferences.selfTimerDuration)s)")
        await SelfTimerOverlay.present(seconds: preferences.selfTimerDuration)

        switch mode {
        case .area:
            return try await captureArea()
        case .window:
            return try await captureWindow()
        case .fullscreen:
            return try await captureFullscreen()
        case .scrolling:
            return try await captureScrolling()
        }
    }

    // MARK: - Capture Previous Area

    /// Re-capture the most recently selected area rectangle without
    /// presenting the selector UI. Throws if no previous area exists.
    @MainActor
    func capturePreviousArea() async throws -> NSImage {
        guard let rect = lastCapturedRect else {
            logger.warning("No previous area rect stored")
            ToastManager.show(
                icon: "exclamationmark.triangle",
                message: "No previous area",
                detail: "Capture an area first with ⇧⌘4"
            )
            throw CaptureEngineError.cancelled
        }

        logger.info("Recapturing previous area: \(rect.debugDescription)")

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = displayContaining(
            point: CGPoint(x: rect.midX, y: rect.midY),
            in: content.displays
        ) else {
            throw CaptureEngineError.noDisplayFound
        }

        let excludedWindows = openShotWindows(from: content.windows)
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        let config = SCStreamConfiguration()
        config.sourceRect = convertToCGSourceRect(rect, display: display)
        config.width = Int(rect.width * (NSScreen.main?.backingScaleFactor ?? 2))
        config.height = Int(rect.height * (NSScreen.main?.backingScaleFactor ?? 2))
        config.captureResolution = .best
        config.showsCursor = preferences.includeCursor

        let image = try await performCapture(filter: filter, config: config)
        logger.info("Previous area recapture completed (\(Int(rect.width))×\(Int(rect.height)))")
        return image
    }

    // MARK: - Present Result

    /// Display the captured image via the QuickAccessOverlay.
    @MainActor
    func presentResult(_ image: NSImage) {
        lastCapturedImage = image
        let overlay = QuickAccessOverlay(image: image)
        overlay.show()
        SoundEffects.playCapture()

        do {
            let container = try ModelContainer(for: CaptureRecord.self)
            let context = ModelContext(container)
            _ = try CaptureHistoryManager.shared.saveCapture(
                image: image,
                type: "screenshot",
                preferences: preferences,
                modelContext: context
            )
        } catch {
            logger.warning("Failed to save capture to history: \(error.localizedDescription)")
        }
    }

    // MARK: - Core Capture

    /// Perform the actual ScreenCaptureKit screenshot capture.
    private func performCapture(
        filter: SCContentFilter,
        config: SCStreamConfiguration
    ) async throws -> NSImage {
        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            logger.error("SCScreenshotManager capture failed: \(error.localizedDescription)")
            throw CaptureEngineError.captureFailure(error)
        }

        return NSImage.fromCGImage(cgImage)
    }

    // MARK: - Display Matching

    /// Find the `SCDisplay` whose frame contains the given point.
    /// The point should be in CoreGraphics coordinates (top-left origin).
    private func displayContaining(point: CGPoint, in displays: [SCDisplay]) -> SCDisplay? {
        for display in displays {
            if display.frame.contains(point) {
                return display
            }
        }
        // Fallback to the first display.
        return displays.first
    }

    /// Convert an NSEvent mouse location (bottom-left origin) to
    /// CoreGraphics coordinates (top-left origin).
    private func nsPointToCGPoint(_ point: CGPoint) -> CGPoint {
        guard let primaryScreen = NSScreen.screens.first else { return point }
        let primaryHeight = primaryScreen.frame.height
        return CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Convert a user-selected rect (in NSScreen / bottom-left coordinates)
    /// to a CG `sourceRect` relative to the display's frame (top-left origin).
    private func convertToCGSourceRect(_ rect: CGRect, display: SCDisplay) -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else { return rect }
        let primaryHeight = primaryScreen.frame.height

        // Convert selection from bottom-left to top-left origin.
        let cgY = primaryHeight - rect.origin.y - rect.height

        // Make relative to the display's origin.
        let displayFrame = display.frame
        let relativeX = rect.origin.x - displayFrame.origin.x
        let relativeY = cgY - displayFrame.origin.y

        return CGRect(x: relativeX, y: relativeY, width: rect.width, height: rect.height)
    }

    // MARK: - OpenShot Window Exclusion

    /// Return all windows that belong to this app so they can be excluded
    /// from screen captures.
    private func openShotWindows(from windows: [SCWindow]) -> [SCWindow] {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.openshot"
        return windows.filter { window in
            window.owningApplication?.bundleIdentifier == bundleID
        }
    }

    // MARK: - Image Stitching

    /// Stitch an array of images vertically into a single tall image.
    /// Uses simple concatenation; a production implementation would use
    /// overlap detection and blending.
    private func stitchImagesVertically(_ images: [NSImage]) -> NSImage {
        guard !images.isEmpty else {
            return NSImage(size: .zero)
        }

        if images.count == 1 {
            return images[0]
        }

        let width = images.map(\.size.width).max() ?? 0
        let totalHeight = images.reduce(CGFloat(0)) { $0 + $1.size.height }

        let stitchedImage = NSImage(size: NSSize(width: width, height: totalHeight))
        stitchedImage.lockFocus()

        var yOffset: CGFloat = totalHeight
        for image in images {
            yOffset -= image.size.height
            image.draw(
                in: NSRect(x: 0, y: yOffset, width: image.size.width, height: image.size.height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        }

        stitchedImage.unlockFocus()
        return stitchedImage
    }
}

// MARK: - CaptureEngineError

/// Errors specific to `CaptureEngine` operations.
enum CaptureEngineError: LocalizedError {
    case cancelled
    case noDisplayFound
    case captureFailure(Error)
    case stitchingFailed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Capture was cancelled by the user."
        case .noDisplayFound:
            return "Could not determine which display to capture."
        case .captureFailure(let underlying):
            return "Screen capture failed: \(underlying.localizedDescription)"
        case .stitchingFailed:
            return "Failed to stitch scrolling capture frames."
        }
    }
}
