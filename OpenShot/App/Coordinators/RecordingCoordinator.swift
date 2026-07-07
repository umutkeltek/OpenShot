// RecordingCoordinator.swift
// OpenShot
//
// Runs the screen-recording start/stop flow: owns the recording-controls
// panel and elapsed-time timer, starts/stops ScreenRecorder, and archives
// the finished file via CaptureHistoryManager.archiveRecording — the same
// shared "move out of temp, then save to history" helper GIFCoordinator
// uses, so the two recording types can't drift out of sync again.

import AppKit
import ScreenCaptureKit
import os

@MainActor
final class RecordingCoordinator {
    static let shared = RecordingCoordinator()

    private let logger = Logger(subsystem: "com.openshot", category: "recording-coordinator")

    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingControlsPanel: RecordingControlsPanel?

    /// Set once by AppDelegate so the menu-bar status item can reflect
    /// elapsed recording time without this coordinator owning the status item.
    var statusItemTitleUpdate: ((String) -> Void)?

    private init() {}

    func toggleRecording() async {
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }

        if ScreenRecorder.shared.isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    func restartRecording() async {
        do {
            try await ScreenRecorder.shared.restartRecording()
            SoundEffects.playRecordingStart()
        } catch {
            stopRecordingUI()
            AlertHelper.showGenericError(title: "Restart Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Start / Stop

    private func startRecording() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                throw OpenShotError.screenNotFound
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            try await ScreenRecorder.shared.startRecording(filter: filter)
            startRecordingUI()
            SoundEffects.playRecordingStart()
        } catch {
            logger.error("Recording failed: \(error.localizedDescription)")
            if let osError = error as? OpenShotError {
                AlertHelper.showError(osError)
            } else {
                AlertHelper.showGenericError(title: "Recording Failed", message: error.localizedDescription)
            }
        }
    }

    private func stopRecording() async {
        let url: URL
        do {
            url = try await ScreenRecorder.shared.stopRecording()
        } catch {
            stopRecordingUI()
            logger.error("Stop recording failed: \(error.localizedDescription)")
            AlertHelper.showGenericError(title: "Recording Failed", message: error.localizedDescription)
            return
        }

        stopRecordingUI()
        SoundEffects.playRecordingStop()

        do {
            let context = try CaptureHistoryManager.shared.makeContext()
            let finalURL = try CaptureHistoryManager.shared.archiveRecording(
                tempURL: url,
                type: "recording",
                preferences: Preferences.shared,
                modelContext: context
            )
            logger.info("Recording saved to \(finalURL.path)")
            ToastManager.show(icon: "checkmark.circle.fill", message: "Recording saved", detail: finalURL.lastPathComponent)
        } catch {
            logger.warning("Failed to archive recording: \(error.localizedDescription)")
            ToastManager.show(icon: "exclamationmark.triangle", message: "Recording save failed", detail: error.localizedDescription)
        }
    }

    // MARK: - Recording UI

    private func startRecordingUI() {
        recordingStartTime = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            let minutes = elapsed / 60
            let seconds = elapsed % 60
            let timeString = String(format: "%02d:%02d", minutes, seconds)
            self.statusItemTitleUpdate?(" \(timeString)")
        }

        let controlsPanel = RecordingControlsPanel()
        controlsPanel.show(
            recorder: ScreenRecorder.shared,
            onStop: { [weak self] in
                Task { @MainActor in
                    await self?.toggleRecording()
                }
            },
            onRestart: { [weak self] in
                Task { @MainActor in
                    await self?.restartRecording()
                }
            }
        )
        self.recordingControlsPanel = controlsPanel
    }

    private func stopRecordingUI() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        recordingControlsPanel?.dismiss()
        recordingControlsPanel = nil
        statusItemTitleUpdate?("")
    }
}
