// QuickAccessOverlay.swift
// OpenShot
//
// Floating NSPanel that appears after every capture, showing a thumbnail
// with quick-action buttons (Copy, Save, Annotate, Pin, Close).
// Supports drag-to-app from the thumbnail, auto-close with configurable
// delay, and positioning in any screen corner.

import AppKit
import SwiftUI
import os
import UniformTypeIdentifiers

fileprivate final class AutoCloseCountdownState {
    private(set) var totalDuration: TimeInterval = 0
    private(set) var remainingDuration: TimeInterval = 0
    private var startedAt: Date?

    func start(duration: TimeInterval, now: Date = Date()) {
        totalDuration = duration
        remainingDuration = duration
        startedAt = now
    }

    func pause(now: Date = Date()) {
        guard let startedAt else { return }
        remainingDuration = max(0, remainingDuration - now.timeIntervalSince(startedAt))
        self.startedAt = nil
    }

    func resume(now: Date = Date()) {
        guard totalDuration > 0, remainingDuration > 0 else {
            startedAt = nil
            return
        }

        startedAt = now
    }

    func reset() {
        totalDuration = 0
        remainingDuration = 0
        startedAt = nil
    }

    func progress(at date: Date = Date()) -> CGFloat {
        guard totalDuration > 0 else { return 0 }
        return CGFloat(remainingTime(at: date) / totalDuration)
    }

    func remainingTime(at date: Date = Date()) -> TimeInterval {
        guard totalDuration > 0 else { return 0 }
        guard let startedAt else { return remainingDuration }
        return max(0, remainingDuration - date.timeIntervalSince(startedAt))
    }
}

// MARK: - QuickAccessOverlay

final class QuickAccessOverlay {

    private let logger = Logger(subsystem: "com.openshot", category: "overlay")
    private var panel: NSPanel?
    private var autoCloseTimer: Timer?
    private let countdownState = AutoCloseCountdownState()
    private let capturedImage: NSImage
    private let preferences = Preferences.shared

    /// Keeps a strong reference so the overlay isn't deallocated while shown.
    private static var activeOverlay: QuickAccessOverlay?

    /// Tracks the most recent temp PNG written for clipboard file URL support.
    private static var lastClipboardTempURL: URL?

    /// Stores the image from the most recently dismissed overlay for restore.
    static var lastDismissedImage: NSImage?

    init(image: NSImage) {
        self.capturedImage = image
    }

    // MARK: - Show

    @MainActor
    func show() {
        // Dismiss any existing overlay first.
        QuickAccessOverlay.activeOverlay?.dismiss()
        QuickAccessOverlay.activeOverlay = self
        startAutoCloseTimer()

        let hostingView = NSHostingView(
            rootView: QuickAccessOverlayView(
                image: capturedImage,
                countdownState: countdownState,
                onCopy: { [weak self] in self?.copyToClipboard() },
                onSave: { [weak self] in self?.saveToFile() },
                onAnnotate: { [weak self] in self?.openAnnotationEditor() },
                onPin: { [weak self] in self?.pinAsFloating() },
                onClose: { [weak self] in self?.dismiss() }
            )
        )

        // Measure intrinsic size of the SwiftUI view.
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)

        // Create the non-activating floating panel.
        let overlayPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        overlayPanel.level = .floating
        overlayPanel.isOpaque = false
        overlayPanel.backgroundColor = .clear
        overlayPanel.hasShadow = true
        overlayPanel.isMovableByWindowBackground = true
        overlayPanel.hidesOnDeactivate = false
        overlayPanel.becomesKeyOnlyIfNeeded = true
        overlayPanel.acceptsMouseMovedEvents = true
        overlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Wrap the hosting view in a tracking view for mouse enter/exit.
        let trackingView = OverlayTrackingView(frame: NSRect(origin: .zero, size: fittingSize))
        trackingView.addSubview(hostingView)
        trackingView.onMouseEntered = { [weak self] in
            self?.pauseAutoCloseTimer()
        }
        trackingView.onMouseExited = { [weak self] in
            self?.resumeAutoCloseTimer()
        }
        overlayPanel.contentView = trackingView

        // Position in the configured corner.
        positionPanel(overlayPanel, size: fittingSize)

        overlayPanel.orderFrontRegardless()
        self.panel = overlayPanel

        logger.info("Quick access overlay shown")
    }

    // MARK: - Dismiss

    func dismiss() {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
        countdownState.reset()

        // Store the image before clearing so it can be restored later.
        QuickAccessOverlay.lastDismissedImage = capturedImage

        panel?.orderOut(nil)
        panel?.close()
        panel = nil

        if QuickAccessOverlay.activeOverlay === self {
            QuickAccessOverlay.activeOverlay = nil
        }

        logger.info("Quick access overlay dismissed")
    }

    /// Restores the most recently dismissed overlay by re-creating it with the saved image.
    @MainActor
    static func restoreRecentlyClosed() {
        guard let image = lastDismissedImage else { return }
        let overlay = QuickAccessOverlay(image: image)
        overlay.show()
    }

    // MARK: - Positioning

    private func positionPanel(_ panel: NSPanel, size: NSSize) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 16

        var origin: CGPoint

        switch preferences.overlayPosition {
        case .bottomRight:
            origin = CGPoint(
                x: visibleFrame.maxX - size.width - margin,
                y: visibleFrame.minY + margin
            )
        case .bottomLeft:
            origin = CGPoint(
                x: visibleFrame.minX + margin,
                y: visibleFrame.minY + margin
            )
        case .topRight:
            origin = CGPoint(
                x: visibleFrame.maxX - size.width - margin,
                y: visibleFrame.maxY - size.height - margin
            )
        case .topLeft:
            origin = CGPoint(
                x: visibleFrame.minX + margin,
                y: visibleFrame.maxY - size.height - margin
            )
        }

        panel.setFrameOrigin(origin)
    }

    // MARK: - Auto-Close Timer

    private func startAutoCloseTimer() {
        let delay = preferences.overlayAutoCloseDelay
        guard delay > 0 else {
            autoCloseTimer?.invalidate()
            autoCloseTimer = nil
            countdownState.reset()
            return
        }

        countdownState.start(duration: delay)
        scheduleAutoCloseTimer(after: delay)
    }

    private func pauseAutoCloseTimer() {
        guard autoCloseTimer != nil else { return }
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
        countdownState.pause()
    }

    private func resumeAutoCloseTimer() {
        guard preferences.overlayAutoCloseDelay > 0 else { return }

        let remainingTime = countdownState.remainingTime()
        guard remainingTime > 0 else {
            dismiss()
            return
        }

        countdownState.resume()
        scheduleAutoCloseTimer(after: remainingTime)
    }

    private func scheduleAutoCloseTimer(after delay: TimeInterval) {
        autoCloseTimer?.invalidate()
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    // MARK: - Actions

    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write image data (TIFF) for apps that accept image paste
        pasteboard.writeObjects([capturedImage])

        // Clean up the previous temp clipboard file before writing a new one.
        if let previousURL = QuickAccessOverlay.lastClipboardTempURL {
            try? FileManager.default.removeItem(at: previousURL)
            QuickAccessOverlay.lastClipboardTempURL = nil
        }

        // Also write a temp file URL for apps that accept file URLs
        if let pngData = capturedImage.pngData() {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("OpenShot_clipboard_\(UUID().uuidString).png")
            try? pngData.write(to: tempURL)
            pasteboard.setString(tempURL.absoluteString, forType: .fileURL)
            QuickAccessOverlay.lastClipboardTempURL = tempURL
        }

        logger.info("Image copied to clipboard (image + file URL)")
        Task { @MainActor in
            ToastManager.show(icon: "checkmark.circle.fill", message: "Copied to clipboard")
        }
        dismiss()
    }

    func saveToFile() {
        let saveURL = preferences.saveLocation
        let filename = FileNamer.generate(
            mode: "screenshot",
            fileExtension: preferences.imageFormat.fileExtension
        )
        let fileURL = saveURL.appendingPathComponent(filename)

        let imageData: Data?

        switch preferences.imageFormat {
        case .png:
            guard let tiffData = capturedImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                logger.error("Failed to create bitmap representation for saving")
                return
            }
            imageData = bitmap.representation(using: .png, properties: [:])
        case .jpeg:
            guard let tiffData = capturedImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                logger.error("Failed to create bitmap representation for saving")
                return
            }
            imageData = bitmap.representation(using: .jpeg, properties: [
                .compressionFactor: preferences.jpegQuality
            ])
        case .tiff:
            guard let tiffData = capturedImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                logger.error("Failed to create bitmap representation for saving")
                return
            }
            imageData = bitmap.representation(using: .tiff, properties: [:])
        case .webp:
            imageData = capturedImage.webpData(quality: preferences.jpegQuality)
        case .heic:
            imageData = capturedImage.heicData(quality: preferences.jpegQuality)
        }

        guard let data = imageData else {
            logger.error("Failed to create image data for format \(self.preferences.imageFormat.rawValue)")
            return
        }

        do {
            // Ensure directory exists.
            try FileManager.default.createDirectory(at: saveURL, withIntermediateDirectories: true)
            try data.write(to: fileURL)
            logger.info("Screenshot saved to \(fileURL.path)")
            Task { @MainActor in
                ToastManager.show(
                    icon: "checkmark.circle.fill",
                    message: "Saved",
                    detail: fileURL.path
                )
            }

            // Reveal in Finder.
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } catch {
            logger.error("Failed to save screenshot: \(error.localizedDescription)")
            Task { @MainActor in
                AlertHelper.showGenericError(title: "Save Failed", message: error.localizedDescription)
            }
        }

        dismiss()
    }

    func openAnnotationEditor() {
        logger.info("Opening annotation editor from overlay")
        let image = capturedImage
        dismiss()
        Task { @MainActor in
            AnnotationWindow.show(with: image)
        }
    }

    func pinAsFloating() {
        logger.info("Pinning screenshot as floating window")
        let image = capturedImage
        dismiss()
        let floatingWindow = FloatingScreenshot(image: image)
        floatingWindow.center()
        floatingWindow.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Overlay Tracking View

/// Custom view that monitors mouse enter/exit to pause/resume auto-close.
private class OverlayTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}

// MARK: - QuickAccessOverlayView (SwiftUI)

private struct QuickAccessOverlayView: View {
    let image: NSImage
    let countdownState: AutoCloseCountdownState
    let onCopy: () -> Void
    let onSave: () -> Void
    let onAnnotate: () -> Void
    let onPin: () -> Void
    let onClose: () -> Void

    private var autoCloseDelay: TimeInterval {
        Preferences.shared.overlayAutoCloseDelay
    }

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail — wraps a DraggableImageView via NSViewRepresentable.
            DraggableThumbnail(image: image)
                .aspectRatio(
                    image.size.width / max(image.size.height, 1),
                    contentMode: .fit
                )
                .frame(maxWidth: 300, maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            // Action buttons row.
            HStack(spacing: 12) {
                OverlayButton(icon: "doc.on.doc", label: "Copy", action: onCopy)
                OverlayButton(icon: "square.and.arrow.down", label: "Save", action: onSave)
                OverlayButton(icon: "pencil.tip", label: "Annotate", action: onAnnotate)
                OverlayButton(icon: "pin", label: "Pin", action: onPin)
                OverlayButton(icon: "xmark", label: "Close", action: onClose)
            }

            // Auto-close countdown bar
            if autoCloseDelay > 0 {
                TimelineView(.periodic(from: .now, by: 0.05)) { context in
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(
                                width: geo.size.width * countdownState.progress(at: context.date),
                                height: 3
                            )
                    }
                }
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

// MARK: - DraggableThumbnail (NSViewRepresentable)

/// Wraps a `DraggableImageView` so the thumbnail supports drag-to-app.
struct DraggableThumbnail: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> DraggableImageView {
        let view = DraggableImageView()
        view.image = image
        view.imageScaling = .scaleProportionallyUpOrDown
        view.isEditable = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: DraggableImageView, context: Context) {
        nsView.image = image
    }
}

// MARK: - OverlayButton

struct OverlayButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 48, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        )
        .foregroundStyle(isHovering ? .primary : .secondary)
        .scaleEffect(isHovering ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityLabel(accessibilityName)
        .accessibilityHint(accessibilityHintText)
    }

    private var accessibilityName: String {
        switch label {
        case "Copy": return "Copy screenshot to clipboard"
        case "Save": return "Save screenshot to file"
        case "Annotate": return "Open annotation editor"
        case "Pin": return "Pin as floating screenshot"
        case "Close": return "Dismiss overlay"
        default: return label
        }
    }

    private var accessibilityHintText: String {
        switch label {
        case "Copy": return "Copies the captured image and a temporary file URL to the clipboard"
        case "Save": return "Saves the screenshot to your configured save location"
        case "Annotate": return "Opens the annotation editor with drawing tools"
        case "Pin": return "Creates an always-on-top floating window with this screenshot"
        case "Close": return "Dismisses this overlay without taking any action"
        default: return ""
        }
    }
}
