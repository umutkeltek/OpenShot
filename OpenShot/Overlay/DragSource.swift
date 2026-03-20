// DragSource.swift
// OpenShot
//
// NSDraggingSource implementation for drag-to-app functionality.
// Provides a DraggableImageView that writes both the NSImage pasteboard
// data and a temporary PNG file URL, so receiving apps can accept either
// format.

import AppKit
import UniformTypeIdentifiers
import os

// MARK: - DraggableImageView

final class DraggableImageView: NSImageView, NSDraggingSource {

    private let logger = Logger(subsystem: "com.openshot", category: "drag-source")

    /// Called when a drag session begins. Clients can use this to dismiss
    /// the overlay or perform other side effects.
    var onDragStarted: (() -> Void)?

    /// Called when a drag session ends.
    var onDragEnded: (() -> Void)?

    /// The temporary file URL created for file-based drag.
    private var tempFileURL: URL?

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return .copy
        case .withinApplication:
            return .copy
        @unknown default:
            return .copy
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        // Clean up the temporary file after the drag completes.
        cleanupTempFile()
        onDragEnded?()

        if operation != [] {
            logger.info("Drag completed successfully")
        } else {
            logger.debug("Drag cancelled or dropped outside valid target")
        }
    }

    // MARK: - Mouse Handling

    override func mouseDown(with event: NSEvent) {
        // Only start a drag if we actually have an image.
        guard let image = self.image else {
            super.mouseDown(with: event)
            return
        }

        // Write the image to a temp file so file-based drops work.
        let tempURL = createTempFile(from: image)

        // Build the pasteboard writer. We use NSFilePromiseProvider for
        // broad compatibility, but also put the image on the pasteboard.
        var pasteboardWriters: [NSPasteboardWriting] = [image]

        if let tempURL {
            self.tempFileURL = tempURL
            pasteboardWriters.append(tempURL as NSURL)
        }

        // Create dragging items.
        let draggingItem = NSDraggingItem(pasteboardWriter: image)

        // Use a scaled-down version of the image as the drag image.
        let maxDragSize: CGFloat = 200
        let imageSize = image.size
        let dragScale = min(maxDragSize / imageSize.width, maxDragSize / imageSize.height, 1.0)
        let dragSize = NSSize(
            width: imageSize.width * dragScale,
            height: imageSize.height * dragScale
        )
        let dragFrame = NSRect(
            x: event.locationInWindow.x - dragSize.width / 2,
            y: event.locationInWindow.y - dragSize.height / 2,
            width: dragSize.width,
            height: dragSize.height
        )

        // Create a composited drag image with slight transparency.
        let dragImage = NSImage(size: dragSize)
        dragImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: dragSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 0.8
        )
        dragImage.unlockFocus()

        draggingItem.setDraggingFrame(dragFrame, contents: dragImage)

        // If we have a file URL, create a second dragging item for it.
        if let tempURL {
            let fileItem = NSDraggingItem(pasteboardWriter: tempURL as NSURL)
            fileItem.setDraggingFrame(dragFrame, contents: dragImage)
            beginDraggingSession(with: [draggingItem, fileItem], event: event, source: self)
        } else {
            beginDraggingSession(with: [draggingItem], event: event, source: self)
        }

        onDragStarted?()
        logger.info("Drag session started")
    }

    // MARK: - Temp File Management

    private func createTempFile(from image: NSImage) -> URL? {
        // Clean up any previous temp file first.
        cleanupTempFile()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "OpenShot_\(timestamp).png"

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.openshot.drag", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: tempDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Failed to create temp drag directory: \(error.localizedDescription)")
            return nil
        }

        let fileURL = tempDirectory.appendingPathComponent(filename)

        guard let pngData = image.pngData() else {
            logger.error("Failed to create PNG data for drag temp file")
            return nil
        }

        do {
            try pngData.write(to: fileURL)
            logger.debug("Temp drag file written: \(fileURL.path)")
            return fileURL
        } catch {
            logger.error("Failed to write temp drag file: \(error.localizedDescription)")
            return nil
        }
    }

    private func cleanupTempFile() {
        guard let url = tempFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        tempFileURL = nil
    }

    // MARK: - View Configuration

    override var acceptsFirstResponder: Bool { true }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Accept first mouse so clicks work without first activating the window.
        return true
    }

    // MARK: - Cleanup

    deinit {
        cleanupTempFile()
    }
}
