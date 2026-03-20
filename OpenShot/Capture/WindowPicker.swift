// WindowPicker.swift
// OpenShot
//
// Window selection overlay. Shows a transparent overlay across all
// screens, highlights the window under the cursor with a blue border,
// and returns the selected `SCWindow` on click (or `nil` on Escape).

import AppKit
import ScreenCaptureKit
import os

// MARK: - WindowPicker

/// Coordinates window picking across all displays.
final class WindowPicker {

    private static let logger = Logger(subsystem: "com.openshot", category: "window-picker")

    /// Present the window picker and return the selected `SCWindow`, or
    /// `nil` if the user cancelled.
    @MainActor
    static func present() async -> SCWindow? {
        let windows: [SCWindow]
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            windows = content.windows.filter { window in
                // Exclude our own overlay and windows that have no title / are tiny.
                guard let title = window.title, !title.isEmpty else { return true }
                return !title.contains("WindowPickerOverlay")
            }
        } catch {
            logger.error("Failed to enumerate windows: \(error.localizedDescription)")
            return nil
        }

        guard !windows.isEmpty else {
            logger.warning("No windows available for selection")
            return nil
        }

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let overlay = WindowPickerOverlay(windows: windows) { selected in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: selected)
            }
            overlay.show()
        }
    }
}

// MARK: - WindowPickerOverlay

/// Manages the transparent overlay window(s) that show window highlight
/// borders and handle user interaction.
private final class WindowPickerOverlay {

    private let scWindows: [SCWindow]
    private let completion: (SCWindow?) -> Void
    private var overlayWindows: [NSWindow] = []
    private var pickerView: WindowPickerView?

    private let logger = Logger(subsystem: "com.openshot", category: "window-picker-overlay")

    init(windows: [SCWindow], completion: @escaping (SCWindow?) -> Void) {
        self.scWindows = windows
        self.completion = completion
    }

    func show() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            completion(nil)
            return
        }

        let combined = ScreenInfo.combinedScreenFrame()

        let window = NSWindow(
            contentRect: combined,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.title = "WindowPickerOverlay"
        window.level = .screenSaver
        window.backgroundColor = NSColor.black.withAlphaComponent(0.001)
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = WindowPickerView(
            frame: NSRect(origin: .zero, size: combined.size),
            scWindows: scWindows,
            windowOrigin: combined.origin
        )
        view.autoresizingMask = [.width, .height]
        view.completion = { [weak self] selected in
            self?.dismiss()
            self?.completion(selected)
        }
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        overlayWindows.append(window)
        pickerView = view

        logger.debug("WindowPicker overlay presented with \(self.scWindows.count) candidate windows")
    }

    private func dismiss() {
        for win in overlayWindows {
            win.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}

// MARK: - WindowPickerView

/// Custom view that tracks the mouse, determines which `SCWindow`
/// is under the cursor, highlights it, and returns it on click.
final class WindowPickerView: NSView {

    var scWindows: [SCWindow]
    var highlightedWindow: SCWindow?
    var highlightedFrame: CGRect?
    var completion: ((SCWindow?) -> Void)?

    /// The origin of the overlay window in screen coordinates, used for
    /// converting between view and screen coordinate spaces.
    private let windowOrigin: CGPoint

    private let logger = Logger(subsystem: "com.openshot", category: "window-picker-view")

    init(frame: NSRect, scWindows: [SCWindow], windowOrigin: CGPoint) {
        self.scWindows = scWindows
        self.windowOrigin = windowOrigin
        super.init(frame: frame)
        setupTrackingArea()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: Tracking area

    private func setupTrackingArea() {
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        setupTrackingArea()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // MARK: Finding the window under cursor

    /// Given a point in screen coordinates (bottom-left origin, matching
    /// `NSScreen`), return the topmost `SCWindow` whose frame contains it.
    private func windowUnderCursor(screenPoint: CGPoint) -> SCWindow? {
        // SCWindow.frame uses top-left origin (CoreGraphics convention).
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let primaryHeight = primaryScreen.frame.height
        let cgPoint = CGPoint(x: screenPoint.x, y: primaryHeight - screenPoint.y)

        // Iterate windows front-to-back (SCShareableContent returns them
        // roughly in z-order, topmost first).
        for scWindow in scWindows {
            let frame = scWindow.frame
            guard frame.width > 0, frame.height > 0 else { continue }
            if frame.contains(cgPoint) {
                return scWindow
            }
        }
        return nil
    }

    /// Convert an `SCWindow.frame` (CG top-left origin) to this view's
    /// coordinate system (bottom-left origin).
    private func viewRect(for scWindowFrame: CGRect) -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else { return scWindowFrame }
        let primaryHeight = primaryScreen.frame.height
        let screenY = primaryHeight - scWindowFrame.origin.y - scWindowFrame.height
        let screenRect = CGRect(
            x: scWindowFrame.origin.x,
            y: screenY,
            width: scWindowFrame.width,
            height: scWindowFrame.height
        )
        // Convert from screen coords to view coords.
        return CGRect(
            x: screenRect.origin.x - windowOrigin.x,
            y: screenRect.origin.y - windowOrigin.y,
            width: screenRect.width,
            height: screenRect.height
        )
    }

    // MARK: Mouse events

    override func mouseMoved(with event: NSEvent) {
        guard let window = self.window else { return }
        let windowPoint = convert(event.locationInWindow, from: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)

        let found = windowUnderCursor(screenPoint: screenPoint)
        if found?.windowID != highlightedWindow?.windowID {
            highlightedWindow = found
            if let f = found {
                highlightedFrame = viewRect(for: f.frame)
            } else {
                highlightedFrame = nil
            }
            setNeedsDisplay(bounds)
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Select whatever is currently highlighted.
        if let selected = highlightedWindow {
            logger.info("Window selected: \(selected.title ?? "untitled") (id: \(selected.windowID))")
            completion?(selected)
        } else {
            completion?(nil)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            logger.debug("Window selection cancelled by Escape key")
            completion?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Light dimming over entire view.
        context.setFillColor(NSColor.black.withAlphaComponent(0.15).cgColor)
        context.fill(bounds)

        // Highlight border around the window under the cursor.
        guard let frame = highlightedFrame else { return }

        // Clear out the window area so it appears bright.
        context.setBlendMode(.clear)
        context.fill(frame)
        context.setBlendMode(.normal)

        // Draw highlight border.
        let borderRect = frame.insetBy(dx: -3, dy: -3)
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(4)
        let path = CGPath(roundedRect: borderRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.addPath(path)
        context.strokePath()

        // Window title label.
        if let title = highlightedWindow?.title, !title.isEmpty {
            drawWindowLabel(title, above: frame)
        }
    }

    private func drawWindowLabel(_ title: String, above frame: CGRect) {
        let text = title as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 8
        let bgWidth = min(textSize.width + padding * 2, frame.width)
        let bgHeight = textSize.height + padding

        let bgOrigin = CGPoint(
            x: frame.midX - bgWidth / 2,
            y: frame.maxY + 8
        )

        // Clamp within bounds.
        let clampedOrigin = CGPoint(
            x: max(bounds.minX + 4, min(bgOrigin.x, bounds.maxX - bgWidth - 4)),
            y: min(bgOrigin.y, bounds.maxY - bgHeight - 4)
        )

        let bgRect = CGRect(origin: clampedOrigin, size: CGSize(width: bgWidth, height: bgHeight))
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6)
        NSColor.systemBlue.withAlphaComponent(0.85).setFill()
        bgPath.fill()

        let textOrigin = CGPoint(
            x: clampedOrigin.x + padding,
            y: clampedOrigin.y + (bgHeight - textSize.height) / 2
        )
        text.draw(at: textOrigin, withAttributes: attributes)
    }
}
