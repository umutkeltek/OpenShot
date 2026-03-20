// OCROverlay.swift
// OpenShot
//
// Orchestrates the OCR workflow: presents the AreaSelector for the
// user to select a screen region, captures that region, runs on-device
// text recognition via TextRecognizer, copies the result to the
// clipboard, and shows a floating result panel.

import AppKit
import os

// MARK: - OCROverlay

final class OCROverlay {

    private let logger = Logger(subsystem: "com.openshot", category: "ocr-overlay")
    private let textRecognizer = TextRecognizer()

    /// Keeps the active result panel alive so it isn't deallocated.
    private static var activePanel: NSPanel?

    /// Run the full OCR capture flow: area selection, screen capture,
    /// text recognition, clipboard copy, and result display.
    func captureAndRecognize() async throws {
        // 1. Present the area selector for the user to draw a region
        guard let rect = await AreaSelector.present(crosshair: true, magnifier: false) else {
            logger.info("OCR capture cancelled by user")
            return
        }

        logger.info("OCR capture area selected: \(rect.debugDescription)")

        // 2. Brief delay to let the selector overlay dismiss fully
        try? await Task.sleep(for: .milliseconds(150))

        // 3. Capture the selected region
        // Convert the rect from NSScreen coordinates (bottom-left origin)
        // to CoreGraphics coordinates (top-left origin) for CGWindowListCreateImage.
        let cgRect = convertToCGCoordinates(rect)

        guard let cgImage = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            throw OpenShotError.captureFailedNoImage
        }

        let nsImage = NSImage.fromCGImage(cgImage)

        // 4. Run text recognition
        let recognizedText = try await textRecognizer.recognizeAndCopy(from: nsImage)

        if recognizedText.isEmpty {
            logger.info("OCR found no text in the selected region")
            await MainActor.run {
                showNoTextAlert()
            }
            return
        }

        logger.info("OCR recognized \(recognizedText.count) characters across \(recognizedText.components(separatedBy: "\n").count) lines")

        // 5. Show the result in a floating panel
        await MainActor.run {
            showOCRResult(text: recognizedText, image: nsImage)
        }
    }

    // MARK: - Coordinate Conversion

    /// Convert an NSScreen rect (bottom-left origin) to CoreGraphics
    /// coordinates (top-left origin) as required by CGWindowListCreateImage.
    private func convertToCGCoordinates(_ rect: CGRect) -> CGRect {
        guard let mainScreen = NSScreen.screens.first else { return rect }
        let screenHeight = mainScreen.frame.height
        return CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - Result Display

    @MainActor
    private func showOCRResult(text: String, image: NSImage) {
        // Dismiss any existing result panel
        OCROverlay.activePanel?.close()
        OCROverlay.activePanel = nil

        // Calculate panel size based on text length
        let panelWidth: CGFloat = 420
        let textHeight: CGFloat = min(max(CGFloat(text.count) / 2, 100), 300)
        let panelHeight: CGFloat = textHeight + 80

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "OCR Result -- Copied to Clipboard"
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        // Build content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))

        // Status bar at top
        let statusLabel = NSTextField(labelWithString: "Text copied to clipboard")
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 12, y: panelHeight - 28, width: panelWidth - 60, height: 18)
        contentView.addSubview(statusLabel)

        // Character count
        let charCount = NSTextField(labelWithString: "\(text.count) characters")
        charCount.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        charCount.textColor = .tertiaryLabelColor
        charCount.alignment = .right
        charCount.frame = NSRect(x: panelWidth - 120, y: panelHeight - 28, width: 108, height: 18)
        contentView.addSubview(charCount)

        // Scrollable text view
        let scrollView = NSScrollView(frame: NSRect(x: 12, y: 44, width: panelWidth - 24, height: panelHeight - 76))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: scrollView.contentSize.width, height: scrollView.contentSize.height))
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        contentView.addSubview(scrollView)

        // Bottom button bar
        let copyButton = NSButton(title: "Copy Again", target: nil, action: nil)
        copyButton.frame = NSRect(x: 12, y: 10, width: 90, height: 24)
        copyButton.bezelStyle = .rounded
        copyButton.target = self
        copyButton.action = #selector(copyTextAgain(_:))
        copyButton.tag = text.hashValue
        contentView.addSubview(copyButton)

        let closeButton = NSButton(title: "Close", target: nil, action: nil)
        closeButton.frame = NSRect(x: panelWidth - 80, y: 10, width: 68, height: 24)
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}" // Escape
        closeButton.target = self
        closeButton.action = #selector(closeResultPanel(_:))
        contentView.addSubview(closeButton)

        panel.contentView = contentView
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        // Store the text in the panel for later re-copy
        objc_setAssociatedObject(panel, "ocrText", text, .OBJC_ASSOCIATION_RETAIN)

        OCROverlay.activePanel = panel

        // Auto-close after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak panel] in
            guard let panel, panel.isVisible else { return }
            panel.close()
            if OCROverlay.activePanel === panel {
                OCROverlay.activePanel = nil
            }
        }
    }

    @MainActor
    private func showNoTextAlert() {
        let alert = NSAlert()
        alert.messageText = "No Text Found"
        alert.informativeText = "No readable text was detected in the selected area. Try selecting a region with clearer text."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Button Actions

    @objc private func copyTextAgain(_ sender: NSButton) {
        guard let panel = OCROverlay.activePanel,
              let text = objc_getAssociatedObject(panel, "ocrText") as? String else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        logger.info("OCR text re-copied to clipboard")
    }

    @objc private func closeResultPanel(_ sender: NSButton) {
        OCROverlay.activePanel?.close()
        OCROverlay.activePanel = nil
    }
}
