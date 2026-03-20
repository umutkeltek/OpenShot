// AnnotationWindow.swift
// OpenShot
//
// Dedicated window controller for the annotation editor. Hosts the
// AnnotationCanvas (AppKit NSView) in a scroll view with a SwiftUI
// AnnotationToolbar docked at the top via NSHostingView.

import AppKit
import SwiftUI
import os

// MARK: - AnnotationWindow

final class AnnotationWindow: NSWindow {

    private let logger = Logger(subsystem: "com.openshot", category: "annotation-window")
    private let canvas: AnnotationCanvas
    private let sourceImage: NSImage
    private var toolbarHostingView: NSHostingView<AnnotationToolbar>?
    private var scrollView: NSScrollView!

    /// Toolbar height reserved above the canvas scroll view.
    private static let toolbarHeight: CGFloat = 72

    /// Keeps strong references so annotation windows persist.
    private static var activeWindows: [AnnotationWindow] = []

    init(image: NSImage) {
        self.sourceImage = image

        // Calculate window size, capping at 80% of screen dimensions.
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let maxSize = NSSize(
            width: screen.frame.width * 0.8,
            height: screen.frame.height * 0.8
        )
        let imageSize = image.size
        let scale = min(
            maxSize.width / imageSize.width,
            (maxSize.height - AnnotationWindow.toolbarHeight) / imageSize.height,
            1.0
        )
        let canvasSize = NSSize(
            width: ceil(imageSize.width * scale),
            height: ceil(imageSize.height * scale)
        )
        let windowSize = NSSize(
            width: canvasSize.width,
            height: canvasSize.height + AnnotationWindow.toolbarHeight
        )

        // Create the canvas.
        self.canvas = AnnotationCanvas(
            frame: NSRect(origin: .zero, size: canvasSize)
        )
        canvas.backgroundImage = image

        super.init(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        setupWindow(imageSize: imageSize)
        setupUI(canvasSize: canvasSize, windowSize: windowSize)

        AnnotationWindow.activeWindows.append(self)
        logger.info("Annotation window created for image \(Int(imageSize.width))x\(Int(imageSize.height))")
    }

    // MARK: - Window Setup

    private func setupWindow(imageSize: NSSize) {
        self.title = "OpenShot — Annotate (\(Int(imageSize.width)) x \(Int(imageSize.height)))"
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 320, height: 280)
        self.backgroundColor = NSColor.windowBackgroundColor

        // Clean up on close.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            AnnotationWindow.activeWindows.removeAll { $0 === self }
            self.logger.info("Annotation window closed")
        }
    }

    // MARK: - UI Setup

    private func setupUI(canvasSize: NSSize, windowSize: NSSize) {
        // Container view that holds toolbar + scroll view.
        let containerView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        containerView.autoresizingMask = [.width, .height]

        // 1. SwiftUI toolbar at the top.
        let toolbar = AnnotationToolbar(
            canvas: canvas,
            onSave: { [weak self] in self?.saveAnnotatedImage() },
            onCopy: { [weak self] in self?.copyAnnotatedImage() },
            onReset: { [weak self] in self?.resetAnnotations() }
        )
        let hostingView = NSHostingView(rootView: toolbar)
        hostingView.frame = NSRect(
            x: 0,
            y: windowSize.height - AnnotationWindow.toolbarHeight,
            width: windowSize.width,
            height: AnnotationWindow.toolbarHeight
        )
        hostingView.autoresizingMask = [.width, .minYMargin]
        containerView.addSubview(hostingView)
        self.toolbarHostingView = hostingView

        // 2. Scroll view hosting the canvas.
        let scrollFrame = NSRect(
            x: 0,
            y: 0,
            width: windowSize.width,
            height: windowSize.height - AnnotationWindow.toolbarHeight
        )
        scrollView = NSScrollView(frame: scrollFrame)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(white: 0.15, alpha: 1.0)
        scrollView.drawsBackground = true

        // Allow magnification (pinch-to-zoom).
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 4.0
        scrollView.magnification = 1.0

        // Ensure the canvas is sized to at least fill the scroll view, but
        // uses its natural size if larger.
        canvas.autoresizingMask = []
        canvas.frame = NSRect(origin: .zero, size: canvasSize)
        scrollView.documentView = canvas

        // Center the canvas in the scroll view if it's smaller.
        scrollView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.centerCanvasInScrollView()
        }

        containerView.addSubview(scrollView)

        self.contentView = containerView

        // 3. Add Image menu with transform items.
        setupImageMenu()
    }

    private func setupImageMenu() {
        let imageMenu = NSMenu(title: "Image")

        let rotateCWItem = NSMenuItem(title: "Rotate Clockwise", action: #selector(rotateClockwise), keyEquivalent: "r")
        rotateCWItem.keyEquivalentModifierMask = [.command]
        rotateCWItem.target = self
        imageMenu.addItem(rotateCWItem)

        let rotateCCWItem = NSMenuItem(title: "Rotate Counter-Clockwise", action: #selector(rotateCounterClockwise), keyEquivalent: "r")
        rotateCCWItem.keyEquivalentModifierMask = [.command, .shift]
        rotateCCWItem.target = self
        imageMenu.addItem(rotateCCWItem)

        imageMenu.addItem(NSMenuItem.separator())

        let flipHItem = NSMenuItem(title: "Flip Horizontal", action: #selector(flipHorizontal), keyEquivalent: "h")
        flipHItem.keyEquivalentModifierMask = [.command, .shift]
        flipHItem.target = self
        imageMenu.addItem(flipHItem)

        let flipVItem = NSMenuItem(title: "Flip Vertical", action: #selector(flipVertical), keyEquivalent: "v")
        flipVItem.keyEquivalentModifierMask = [.command, .shift]
        flipVItem.target = self
        imageMenu.addItem(flipVItem)

        imageMenu.addItem(NSMenuItem.separator())

        let resizeItem = NSMenuItem(title: "Resize...", action: #selector(resizeImage), keyEquivalent: "")
        resizeItem.target = self
        imageMenu.addItem(resizeItem)

        let imageMenuItem = NSMenuItem(title: "Image", action: nil, keyEquivalent: "")
        imageMenuItem.submenu = imageMenu

        if let mainMenu = NSApp.mainMenu {
            mainMenu.addItem(imageMenuItem)
        }
    }

    /// Centers the canvas document view within the scroll view's clip view
    /// when the canvas is smaller than the visible area.
    private func centerCanvasInScrollView() {
        guard let documentView = scrollView.documentView else { return }
        let clipBounds = scrollView.contentView.bounds
        let docFrame = documentView.frame

        var newOrigin = clipBounds.origin

        if docFrame.width < clipBounds.width {
            newOrigin.x = -(clipBounds.width - docFrame.width) / 2
        }
        if docFrame.height < clipBounds.height {
            newOrigin.y = -(clipBounds.height - docFrame.height) / 2
        }

        scrollView.contentView.setBoundsOrigin(newOrigin)
    }

    // MARK: - Actions

    private func saveAnnotatedImage() {
        guard let composited = canvas.compositedImage() else {
            logger.error("Failed to composite annotated image for saving")
            return
        }

        let preferences = Preferences.shared
        let filename = FileNamer.generate(
            template: "OpenShot_Annotated_{date}_{time}",
            mode: "annotated",
            fileExtension: preferences.imageFormat.fileExtension
        )
        let saveURL = preferences.saveLocation.appendingPathComponent(filename)

        let imageData: Data?
        switch preferences.imageFormat {
        case .png:
            guard let tiffData = composited.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                logger.error("Failed to create bitmap for saving annotated image")
                return
            }
            imageData = bitmap.representation(using: .png, properties: [:])
        case .jpeg:
            guard let tiffData = composited.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                logger.error("Failed to create bitmap for saving annotated image")
                return
            }
            imageData = bitmap.representation(using: .jpeg, properties: [
                .compressionFactor: preferences.jpegQuality
            ])
        case .tiff:
            guard let tiffData = composited.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                logger.error("Failed to create bitmap for saving annotated image")
                return
            }
            imageData = bitmap.representation(using: .tiff, properties: [:])
        case .webp:
            imageData = composited.webpData(quality: preferences.jpegQuality)
        case .heic:
            imageData = composited.heicData(quality: preferences.jpegQuality)
        }

        guard let data = imageData else {
            logger.error("Failed to encode annotated image as \(preferences.imageFormat.rawValue)")
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: preferences.saveLocation,
                withIntermediateDirectories: true
            )
            try data.write(to: saveURL)
            logger.info("Annotated screenshot saved to \(saveURL.path)")
            NSWorkspace.shared.activateFileViewerSelecting([saveURL])
        } catch {
            logger.error("Failed to save annotated screenshot: \(error.localizedDescription)")
            showSaveError(error)
        }
    }

    private func copyAnnotatedImage() {
        guard let composited = canvas.compositedImage() else {
            logger.error("Failed to composite annotated image for copying")
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([composited])
        logger.info("Annotated image copied to clipboard")
    }

    private func resetAnnotations() {
        canvas.clearAnnotations()
        logger.info("Annotations cleared")
    }

    private func showSaveError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Failed to Save"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: self)
    }

    // MARK: - Image Transforms

    @objc private func rotateClockwise() {
        guard let image = canvas.backgroundImage else { return }
        canvas.backgroundImage = image.rotated(by: -90)
        resizeCanvasToFitImage()
    }

    @objc private func rotateCounterClockwise() {
        guard let image = canvas.backgroundImage else { return }
        canvas.backgroundImage = image.rotated(by: 90)
        resizeCanvasToFitImage()
    }

    @objc private func flipHorizontal() {
        guard let image = canvas.backgroundImage else { return }
        canvas.backgroundImage = image.flippedHorizontally()
        canvas.needsDisplay = true
    }

    @objc private func flipVertical() {
        guard let image = canvas.backgroundImage else { return }
        canvas.backgroundImage = image.flippedVertically()
        canvas.needsDisplay = true
    }

    @objc private func resizeImage() {
        guard let image = canvas.backgroundImage else { return }
        let alert = NSAlert()
        alert.messageText = "Resize Image"
        alert.informativeText = "Enter new dimensions:"

        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 200, height: 60))
        stackView.orientation = .vertical

        let widthField = NSTextField(frame: NSRect(x: 0, y: 30, width: 200, height: 24))
        widthField.placeholderString = "Width"
        widthField.stringValue = "\(Int(image.size.width))"

        let heightField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        heightField.placeholderString = "Height"
        heightField.stringValue = "\(Int(image.size.height))"

        stackView.addArrangedSubview(widthField)
        stackView.addArrangedSubview(heightField)
        alert.accessoryView = stackView
        alert.addButton(withTitle: "Resize")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: self) { response in
            if response == .alertFirstButtonReturn {
                let newWidth = CGFloat(Int(widthField.stringValue) ?? Int(image.size.width))
                let newHeight = CGFloat(Int(heightField.stringValue) ?? Int(image.size.height))
                let newSize = NSSize(width: newWidth, height: newHeight)
                self.canvas.backgroundImage = image.resized(to: newSize)
                self.resizeCanvasToFitImage()
            }
        }
    }

    private func resizeCanvasToFitImage() {
        guard let image = canvas.backgroundImage else { return }
        canvas.frame = NSRect(origin: .zero, size: image.size)
        canvas.needsDisplay = true
        if let scrollView = canvas.enclosingScrollView {
            scrollView.documentView = canvas
        }
    }

    // MARK: - Static Factory

    /// Creates and shows an annotation window for the given image.
    @MainActor
    static func show(with image: NSImage) {
        let window = AnnotationWindow(image: image)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
