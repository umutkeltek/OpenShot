// FloatingScreenshot.swift
// OpenShot
//
// Always-on-top pinned screenshot window. Supports drag-to-reposition,
// aspect-ratio-locked resizing, configurable opacity, click-through
// lock mode, arrow-key nudging, and a right-click context menu.
// Double-click opens the annotation editor.

import AppKit
import os

// MARK: - FloatingScreenshot

final class FloatingScreenshot: NSPanel {

    private let logger = Logger(subsystem: "com.openshot", category: "floating")
    private let screenshotImage: NSImage
    private var imageView: NSImageView!
    private var isLocked = false

    /// Keeps strong references so floating windows persist.
    private static var activeWindows: [FloatingScreenshot] = []

    init(image: NSImage) {
        self.screenshotImage = image

        let imageSize = image.size
        let maxDimension: CGFloat = 400
        let scale = min(maxDimension / imageSize.width, maxDimension / imageSize.height, 1.0)
        let windowSize = NSSize(
            width: ceil(imageSize.width * scale),
            height: ceil(imageSize.height * scale)
        )

        super.init(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow(windowSize: windowSize)
        setupImageView(windowSize: windowSize)
        setupContextMenu()
        setupDoubleClickHandler()

        FloatingScreenshot.activeWindows.append(self)
        logger.info("Floating screenshot window created — \(Int(imageSize.width))x\(Int(imageSize.height))")
    }

    // MARK: - Setup

    private func setupWindow(windowSize: NSSize) {
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.title = "OpenShot — Pinned"
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Lock aspect ratio to match the screenshot.
        self.contentAspectRatio = windowSize

        // Set min size to prevent shrinking below usable dimensions.
        self.contentMinSize = NSSize(
            width: max(windowSize.width * 0.25, 80),
            height: max(windowSize.height * 0.25, 60)
        )

        // Listen for window close to clean up the static reference.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            FloatingScreenshot.activeWindows.removeAll { $0 === self }
            self.logger.info("Floating screenshot window closed")
        }
    }

    private func setupImageView(windowSize: NSSize) {
        imageView = NSImageView(frame: NSRect(origin: .zero, size: windowSize))
        imageView.image = screenshotImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.isEditable = false
        imageView.autoresizingMask = [.width, .height]

        self.contentView = imageView
    }

    private func setupContextMenu() {
        let menu = NSMenu(title: "Floating Screenshot")

        // Opacity submenu.
        let opacityItem = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        let opacitySubmenu = NSMenu(title: "Opacity")

        let opacityLevels: [(String, CGFloat)] = [
            ("100%", 1.0),
            ("80%", 0.8),
            ("60%", 0.6),
            ("40%", 0.4),
            ("20%", 0.2),
        ]

        for (label, value) in opacityLevels {
            let item = NSMenuItem(
                title: label,
                action: #selector(setOpacityFromMenuItem(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = Int(value * 100)
            item.state = abs(self.alphaValue - value) < 0.01 ? .on : .off
            opacitySubmenu.addItem(item)
        }

        opacityItem.submenu = opacitySubmenu
        menu.addItem(opacityItem)

        menu.addItem(NSMenuItem.separator())

        // Lock / Unlock (click-through toggle).
        let lockItem = NSMenuItem(
            title: "Lock (Click-Through)",
            action: #selector(toggleLock(_:)),
            keyEquivalent: ""
        )
        lockItem.target = self
        menu.addItem(lockItem)

        menu.addItem(NSMenuItem.separator())

        // Open in Editor.
        let editItem = NSMenuItem(
            title: "Open in Editor",
            action: #selector(openInAnnotationEditor(_:)),
            keyEquivalent: ""
        )
        editItem.target = self
        menu.addItem(editItem)

        // Copy Image.
        let copyItem = NSMenuItem(
            title: "Copy Image",
            action: #selector(copyImageToClipboard(_:)),
            keyEquivalent: "c"
        )
        copyItem.target = self
        menu.addItem(copyItem)

        menu.addItem(NSMenuItem.separator())

        // Close.
        let closeItem = NSMenuItem(
            title: "Close",
            action: #selector(closeWindow(_:)),
            keyEquivalent: "w"
        )
        closeItem.target = self
        menu.addItem(closeItem)

        self.contentView?.menu = menu
    }

    private func setupDoubleClickHandler() {
        let clickRecognizer = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleDoubleClick(_:))
        )
        clickRecognizer.numberOfClicksRequired = 2
        self.contentView?.addGestureRecognizer(clickRecognizer)
    }

    // MARK: - Key Handling

    override var canBecomeKey: Bool { !isLocked }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let step: CGFloat = shift ? 10 : 1
        var origin = self.frame.origin

        switch event.keyCode {
        case 123: // Left arrow
            origin.x -= step
        case 124: // Right arrow
            origin.x += step
        case 125: // Down arrow
            origin.y -= step
        case 126: // Up arrow
            origin.y += step
        case 53: // Escape
            close()
            return
        default:
            super.keyDown(with: event)
            return
        }

        setFrameOrigin(origin)
    }

    // MARK: - Context Menu Actions

    @objc private func setOpacityFromMenuItem(_ sender: NSMenuItem) {
        let newAlpha = CGFloat(sender.tag) / 100.0
        self.animator().alphaValue = newAlpha

        // Update checkmarks in the opacity submenu.
        if let opacityMenu = sender.menu {
            for item in opacityMenu.items {
                item.state = item === sender ? .on : .off
            }
        }

        logger.debug("Floating screenshot opacity set to \(sender.tag)%")
    }

    @objc private func toggleLock(_ sender: NSMenuItem) {
        isLocked.toggle()

        if isLocked {
            // Enable click-through: mouse events pass through to windows below.
            self.ignoresMouseEvents = true
            self.isMovableByWindowBackground = false
            sender.title = "Unlock (Disable Click-Through)"

            // Visual indicator: dim border.
            self.contentView?.wantsLayer = true
            self.contentView?.layer?.borderWidth = 2
            self.contentView?.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.5).cgColor

            logger.info("Floating screenshot locked (click-through enabled)")
        } else {
            self.ignoresMouseEvents = false
            self.isMovableByWindowBackground = true
            sender.title = "Lock (Click-Through)"

            self.contentView?.layer?.borderWidth = 0
            self.contentView?.layer?.borderColor = nil

            logger.info("Floating screenshot unlocked")
        }
    }

    @objc private func openInAnnotationEditor(_ sender: NSMenuItem) {
        logger.info("Opening annotation editor from floating screenshot")
        let image = screenshotImage
        close()
        AnnotationWindow.show(with: image)
    }

    @objc private func copyImageToClipboard(_ sender: NSMenuItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([screenshotImage])
        logger.info("Floating screenshot image copied to clipboard")
    }

    @objc private func closeWindow(_ sender: NSMenuItem) {
        close()
    }

    @objc private func handleDoubleClick(_ sender: NSClickGestureRecognizer) {
        logger.info("Double-click detected on floating screenshot — opening editor")
        let image = screenshotImage
        close()
        AnnotationWindow.show(with: image)
    }

    // MARK: - Validate Menu Items

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Update lock menu item title dynamically.
        if menuItem.action == #selector(toggleLock(_:)) {
            menuItem.title = isLocked ? "Unlock (Disable Click-Through)" : "Lock (Click-Through)"
        }
        return true
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
