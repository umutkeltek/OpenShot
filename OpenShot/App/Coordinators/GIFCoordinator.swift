// GIFCoordinator.swift
// OpenShot
//
// Runs the GIF recording start/stop flow: owns the GIFRecorder instance and
// archives the finished file via CaptureHistoryManager.archiveRecording —
// the same shared helper RecordingCoordinator uses for MP4 — so a GIF can
// no longer be left behind in the temp directory (and later silently
// deleted by the 24h temp-file sweep) while MP4 recordings are handled
// correctly.

import AppKit
import os

@MainActor
final class GIFCoordinator {
    static let shared = GIFCoordinator()

    private let logger = Logger(subsystem: "com.openshot", category: "gif-coordinator")
    private var gifRecorder: GIFRecorder?

    private init() {}

    func toggleGIFRecording() async {
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }

        if let activeRecorder = gifRecorder, activeRecorder.isRecording {
            await stopGIFRecording(activeRecorder)
        } else {
            await startGIFRecording()
        }
    }

    private func startGIFRecording() async {
        guard let rect = await AreaSelector.present() else { return }
        let recorder = GIFRecorder()
        gifRecorder = recorder
        recorder.startCapture(rect: rect)
    }

    private func stopGIFRecording(_ recorder: GIFRecorder) async {
        let url: URL
        do {
            url = try await recorder.stopCapture()
        } catch {
            gifRecorder = nil
            logger.warning("GIF export failed: \(error.localizedDescription)")
            AlertHelper.showGenericError(title: "GIF Export Failed", message: error.localizedDescription)
            return
        }
        gifRecorder = nil

        do {
            let context = try CaptureHistoryManager.shared.makeContext()
            let finalURL = try CaptureHistoryManager.shared.archiveRecording(
                tempURL: url,
                type: "gif",
                preferences: Preferences.shared,
                modelContext: context
            )
            ToastManager.show(icon: "checkmark.circle.fill", message: "GIF saved", detail: finalURL.lastPathComponent)
            NSWorkspace.shared.activateFileViewerSelecting([finalURL])
        } catch {
            logger.warning("Failed to archive GIF: \(error.localizedDescription)")
            ToastManager.show(icon: "exclamationmark.triangle", message: "GIF save failed", detail: error.localizedDescription)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
