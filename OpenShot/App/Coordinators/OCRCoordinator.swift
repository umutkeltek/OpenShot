// OCRCoordinator.swift
// OpenShot
//
// Runs the OCR (capture-text) flow: checks screen-recording permission,
// presents the OCR overlay, recognizes text, and surfaces failures
// consistently with the rest of the capture pipeline. A singleton so the
// menu/hotkey, All-in-One panel, and `openshot://` URL scheme entry points
// can all trigger the same permission-checked flow directly.

import AppKit
import os

@MainActor
final class OCRCoordinator {
    static let shared = OCRCoordinator()

    private let logger = Logger(subsystem: "com.openshot", category: "ocr")

    private init() {}

    func captureText() async {
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }

        let ocr = OCROverlay()
        do {
            try await ocr.captureAndRecognize()
        } catch {
            if case CaptureEngineError.cancelled = error { return }
            logger.error("OCR failed: \(error.localizedDescription)")
            AlertHelper.showGenericError(title: "OCR Failed", message: error.localizedDescription)
        }
    }
}
