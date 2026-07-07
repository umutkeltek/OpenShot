// ClipboardService.swift
// OpenShot
//
// Single shared clipboard-copy implementation used by every "Copy" action
// in the app (Quick Access Overlay, Annotation editor, Floating Screenshot,
// History). Writes both image data and a temp file URL (so apps/drop
// targets that only accept file URLs can still receive the image), cleans
// up the previously-written temp file, and shows the standard toast.

import AppKit
import os

@MainActor
enum ClipboardService {
    private static let logger = Logger(subsystem: "com.openshot", category: "clipboard")

    /// Tracks the most recent temp PNG written for clipboard file-URL support.
    private static var lastTempURL: URL?

    static func copyImage(_ image: NSImage, showToast: Bool = true) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write image data (TIFF) for apps that accept image paste.
        pasteboard.writeObjects([image])

        // Clean up the previous temp clipboard file before writing a new one.
        if let previousURL = lastTempURL {
            do {
                try FileManager.default.removeItem(at: previousURL)
            } catch {
                logger.debug("Failed to remove previous clipboard temp file: \(error.localizedDescription)")
            }
            lastTempURL = nil
        }

        // Also write a temp file URL for apps/drop targets that only accept file URLs.
        if let pngData = image.pngData() {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("OpenShot_clipboard_\(UUID().uuidString).png")
            do {
                try pngData.write(to: tempURL)
                pasteboard.setString(tempURL.absoluteString, forType: .fileURL)
                lastTempURL = tempURL
            } catch {
                logger.error("Failed to write clipboard temp file: \(error.localizedDescription)")
            }
        }

        logger.info("Image copied to clipboard (image + file URL)")
        if showToast {
            ToastManager.show(icon: "checkmark.circle.fill", message: "Copied to clipboard")
        }
    }
}
