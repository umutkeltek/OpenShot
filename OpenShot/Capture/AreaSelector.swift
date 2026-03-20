// AreaSelector.swift
// OpenShot
//
// Transparent fullscreen overlay for rubber-band area selection.
// Covers all screens with a dim overlay, lets the user rubber-band
// a rectangle, and returns the selected CGRect in global screen
// coordinates. Includes optional crosshair, magnifier loupe with
// hex color readout, and a live dimension label.

import AppKit
import os

// MARK: - AreaSelectorWindow

/// Borderless, transparent window placed at `.screenSaver` level so
/// it sits above everything while the user draws a selection rectangle.
final class AreaSelectorWindow: NSWindow {

    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver
        self.backgroundColor = NSColor.black.withAlphaComponent(0.001)
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - AreaSelector

/// `NSView` that handles mouse interaction for rubber-band selection.
/// Call the static `present()` method, which returns the selected
/// `CGRect` in global (screen) coordinates, or `nil` on cancellation.
final class AreaSelector: NSView {

    // MARK: Public configuration

    var crosshairEnabled: Bool = true
    var magnifierEnabled: Bool = true

    /// Optional frozen screen image. When set, this image is drawn as the
    /// background instead of seeing through to the live desktop. This lets
    /// users capture tooltips, menus, and other hover-states that would
    /// dismiss when clicking.
    var frozenBackground: NSImage?

    // MARK: State

    private var selectionRect: CGRect?
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isSelecting: Bool = false
    private var completion: ((CGRect?) -> Void)?

    private var hostWindows: [AreaSelectorWindow] = []

    private let logger = Logger(subsystem: "com.openshot", category: "area-selector")

    // MARK: - Static entry point

    /// Present the area selector across all screens and await user selection.
    /// Returns the selected rectangle in global (screen) coordinates, or
    /// `nil` if the user presses Escape.
    ///
    /// - Parameters:
    ///   - crosshair: Whether to draw crosshair guides.
    ///   - magnifier: Whether to show the magnifier loupe.
    ///   - frozenBackground: An optional frozen screenshot of the screen. When
    ///     provided the overlay renders this image as its background instead of
    ///     being semi-transparent, allowing the user to select a region from
    ///     the frozen state (useful for capturing tooltips, menus, etc.).
    @MainActor
    static func present(
        crosshair: Bool = true,
        magnifier: Bool = true,
        frozenBackground: NSImage? = nil
    ) async -> CGRect? {
        // Check screens BEFORE entering continuation to avoid double-resume
        guard !NSScreen.screens.isEmpty else { return nil }

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let selector = AreaSelector()
            selector.crosshairEnabled = crosshair
            selector.magnifierEnabled = magnifier
            selector.frozenBackground = frozenBackground
            selector.completion = { rect in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: rect)
            }
            selector.showOnAllScreens()
        }
    }

    // MARK: - Window management

    private func showOnAllScreens() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            completion?(nil)
            return
        }

        let combined = ScreenInfo.combinedScreenFrame()

        let window = AreaSelectorWindow(frame: combined)

        if let frozen = frozenBackground {
            // Use the frozen image as an opaque background so the user
            // selects from the captured state rather than the live desktop.
            window.backgroundColor = .black
            window.isOpaque = true

            // Create an NSImageView as the base layer with the frozen image.
            let imageView = NSImageView(frame: NSRect(origin: .zero, size: combined.size))
            imageView.image = frozen
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.autoresizingMask = [.width, .height]

            // The selector view draws overlays (dimming, crosshair, etc.)
            // on top of the frozen image.
            let selectorView = self
            selectorView.frame = NSRect(origin: .zero, size: combined.size)
            selectorView.autoresizingMask = [.width, .height]

            imageView.addSubview(selectorView)
            window.contentView = imageView
        } else {
            window.backgroundColor = NSColor.black.withAlphaComponent(0.15)

            let selectorView = self
            selectorView.frame = NSRect(origin: .zero, size: combined.size)
            selectorView.autoresizingMask = [.width, .height]

            window.contentView = selectorView
        }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(self)

        hostWindows.append(window)

        // Store the window origin so we can convert to global coords later.
        logger.debug("AreaSelector presented – combined frame: \(combined.debugDescription)")
    }

    private func dismiss() {
        for win in hostWindows {
            win.orderOut(nil)
        }
        hostWindows.removeAll()
    }

    // MARK: - NSView overrides

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: Mouse events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPoint = point
        selectionRect = nil
        isSelecting = true
        setNeedsDisplay(bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelecting, let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        currentPoint = current

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)
        selectionRect = CGRect(x: x, y: y, width: w, height: h)

        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        guard isSelecting else { return }
        isSelecting = false

        guard let rect = selectionRect, rect.width >= 3, rect.height >= 3 else {
            // Selection too small — treat as click (cancel).
            dismiss()
            completion?(nil)
            return
        }

        // Convert from view coordinates to global screen coordinates.
        let globalRect = convertToScreenCoordinates(rect)
        logger.info("Selection completed: \(globalRect.debugDescription)")
        dismiss()
        completion?(globalRect)
    }

    override func mouseMoved(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        if !isSelecting {
            setNeedsDisplay(bounds)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            logger.debug("Selection cancelled by Escape key")
            isSelecting = false
            dismiss()
            completion?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Dimming overlay
        drawDimmingOverlay(in: context)

        // 2. Selection rectangle
        if let rect = selectionRect {
            drawSelectionRect(rect, in: context)
            drawDimensionLabel(for: rect, in: context)
        }

        // 3. Crosshair
        if crosshairEnabled, let point = currentPoint ?? startPoint {
            drawCrosshair(at: point, in: context)
        }

        // 4. Magnifier
        if magnifierEnabled, !isSelecting, let point = currentPoint {
            drawMagnifier(at: point, in: context)
        }
    }

    // MARK: Dimming overlay

    private func drawDimmingOverlay(in context: CGContext) {
        // Fill entire view with dim color.
        context.setFillColor(NSColor.black.withAlphaComponent(0.3).cgColor)
        context.fill(bounds)

        // If there's a selection, cut it out so the selected area looks bright.
        if let rect = selectionRect {
            context.setBlendMode(.clear)
            context.fill(rect)
            context.setBlendMode(.normal)
        }
    }

    // MARK: Selection rectangle

    private func drawSelectionRect(_ rect: CGRect, in context: CGContext) {
        let dashPattern: [CGFloat] = [6, 3]
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: dashPattern)
        context.stroke(rect)
        context.setLineDash(phase: 0, lengths: [])

        // Subtle inner white line for contrast.
        let inner = rect.insetBy(dx: 1, dy: 1)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.5)
        context.stroke(inner)
    }

    // MARK: Dimension label

    private func drawDimensionLabel(for rect: CGRect, in context: CGContext) {
        let w = Int(rect.width)
        let h = Int(rect.height)
        let text = "\(w) × \(h)" as NSString

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]

        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 6

        let bgWidth = textSize.width + padding * 2
        let bgHeight = textSize.height + padding
        var bgOrigin = CGPoint(
            x: rect.midX - bgWidth / 2,
            y: rect.maxY + 8
        )

        // Keep inside view bounds.
        if bgOrigin.y + bgHeight > bounds.maxY - 4 {
            bgOrigin.y = rect.minY - bgHeight - 8
        }
        if bgOrigin.x < bounds.minX + 4 {
            bgOrigin.x = bounds.minX + 4
        }
        if bgOrigin.x + bgWidth > bounds.maxX - 4 {
            bgOrigin.x = bounds.maxX - bgWidth - 4
        }

        let bgRect = CGRect(origin: bgOrigin, size: CGSize(width: bgWidth, height: bgHeight))
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bgPath.fill()

        let textOrigin = CGPoint(
            x: bgOrigin.x + padding,
            y: bgOrigin.y + (bgHeight - textSize.height) / 2
        )
        text.draw(at: textOrigin, withAttributes: attributes)
    }

    // MARK: Crosshair

    private func drawCrosshair(at point: CGPoint, in context: CGContext) {
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(0.5)

        // Vertical line
        context.move(to: CGPoint(x: point.x, y: bounds.minY))
        context.addLine(to: CGPoint(x: point.x, y: bounds.maxY))
        context.strokePath()

        // Horizontal line
        context.move(to: CGPoint(x: bounds.minX, y: point.y))
        context.addLine(to: CGPoint(x: bounds.maxX, y: point.y))
        context.strokePath()
    }

    // MARK: Magnifier

    private func drawMagnifier(at point: CGPoint, in context: CGContext) {
        let captureSize: CGFloat = 20       // pixels to capture around cursor
        let magnification: CGFloat = 5      // zoom factor
        let loupeSize = captureSize * magnification  // rendered loupe diameter

        // Position the loupe to the upper-right of the cursor, clamped in bounds.
        var loupeOrigin = CGPoint(x: point.x + 24, y: point.y + 24)
        if loupeOrigin.x + loupeSize > bounds.maxX - 8 {
            loupeOrigin.x = point.x - loupeSize - 24
        }
        if loupeOrigin.y + loupeSize > bounds.maxY - 8 {
            loupeOrigin.y = point.y - loupeSize - 24
        }
        if loupeOrigin.x < bounds.minX + 8 {
            loupeOrigin.x = bounds.minX + 8
        }
        if loupeOrigin.y < bounds.minY + 8 {
            loupeOrigin.y = bounds.minY + 8
        }

        let loupeRect = CGRect(origin: loupeOrigin, size: CGSize(width: loupeSize, height: loupeSize))

        // Convert view point to screen coordinates for CGWindowListCreateImage.
        let screenPoint = convertToScreenPoint(point)
        let captureRect = CGRect(
            x: screenPoint.x - captureSize / 2,
            y: screenPoint.y - captureSize / 2,
            width: captureSize,
            height: captureSize
        )

        // Capture the area around the cursor (excluding our own overlay windows).
        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenBelowWindow,
            CGWindowID(0),
            [.bestResolution]
        ) else { return }

        // Draw loupe background.
        let loupePath = NSBezierPath(ovalIn: loupeRect)
        context.saveGState()

        // Clip to circle.
        loupePath.addClip()

        // Draw captured image scaled up.
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: captureSize, height: captureSize))
        nsImage.draw(in: loupeRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        // Grid lines inside the loupe for per-pixel visibility.
        context.setStrokeColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        let step = magnification
        for i in 0...Int(captureSize) {
            let offset = CGFloat(i) * step
            context.move(to: CGPoint(x: loupeRect.minX + offset, y: loupeRect.minY))
            context.addLine(to: CGPoint(x: loupeRect.minX + offset, y: loupeRect.maxY))
            context.strokePath()
            context.move(to: CGPoint(x: loupeRect.minX, y: loupeRect.minY + offset))
            context.addLine(to: CGPoint(x: loupeRect.maxX, y: loupeRect.minY + offset))
            context.strokePath()
        }

        context.restoreGState()

        // Loupe border.
        NSColor.white.setStroke()
        loupePath.lineWidth = 2.5
        loupePath.stroke()

        // Center crosshair dot.
        let dotSize: CGFloat = 3
        let dotRect = CGRect(
            x: loupeRect.midX - dotSize / 2,
            y: loupeRect.midY - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        NSColor.red.setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        // Hex color label below the loupe.
        drawHexColorLabel(for: cgImage, below: loupeRect)
    }

    private func drawHexColorLabel(for image: CGImage, below loupeRect: CGRect) {
        // Sample the center pixel.
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        let centerX = bitmapRep.pixelsWide / 2
        let centerY = bitmapRep.pixelsHigh / 2
        guard let color = bitmapRep.colorAt(x: centerX, y: centerY)?
            .usingColorSpace(.sRGB) else { return }

        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        let hex = String(format: "#%02X%02X%02X", r, g, b)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.white,
        ]
        let text = hex as NSString
        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 4

        let bgWidth = textSize.width + padding * 2
        let bgHeight = textSize.height + padding
        let bgOrigin = CGPoint(
            x: loupeRect.midX - bgWidth / 2,
            y: loupeRect.minY - bgHeight - 4
        )
        let bgRect = CGRect(origin: bgOrigin, size: CGSize(width: bgWidth, height: bgHeight))

        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 3, yRadius: 3)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bgPath.fill()

        // Color swatch.
        let swatchRect = CGRect(x: bgOrigin.x + padding, y: bgOrigin.y + (bgHeight - 10) / 2, width: 10, height: 10)
        color.setFill()
        NSBezierPath(roundedRect: swatchRect, xRadius: 2, yRadius: 2).fill()

        let textOrigin = CGPoint(
            x: swatchRect.maxX + 4,
            y: bgOrigin.y + (bgHeight - textSize.height) / 2
        )
        text.draw(at: textOrigin, withAttributes: attributes)
    }

    // MARK: - Coordinate conversion helpers

    /// Convert a point in this view's coordinate system to global screen
    /// coordinates (top-left origin, as used by CGWindowListCreateImage).
    private func convertToScreenPoint(_ point: CGPoint) -> CGPoint {
        guard let window = self.window else { return point }
        let windowPoint = convert(point, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        // CoreGraphics uses top-left origin; NSScreen uses bottom-left.
        guard let screen = NSScreen.screens.first else { return screenPoint }
        let maxY = screen.frame.origin.y + screen.frame.size.height
        return CGPoint(x: screenPoint.x, y: maxY - screenPoint.y)
    }

    /// Convert a rect in view coordinates to global screen coordinates
    /// (bottom-left origin, as used by ScreenCaptureKit).
    private func convertToScreenCoordinates(_ rect: CGRect) -> CGRect {
        guard let window = self.window else { return rect }
        let bottomLeft = convert(CGPoint(x: rect.minX, y: rect.minY), to: nil)
        let topRight = convert(CGPoint(x: rect.maxX, y: rect.maxY), to: nil)
        let screenBL = window.convertPoint(toScreen: bottomLeft)
        let screenTR = window.convertPoint(toScreen: topRight)
        return CGRect(
            x: min(screenBL.x, screenTR.x),
            y: min(screenBL.y, screenTR.y),
            width: abs(screenTR.x - screenBL.x),
            height: abs(screenTR.y - screenBL.y)
        )
    }
}
