// AlertHelper.swift
// OpenShot
//
// User-facing error alerts. Replaces silent console-only error logging
// with NSAlert dialogs that explain what went wrong and how to fix it.

import AppKit

@MainActor
enum AlertHelper {

    /// Show an error alert for an OpenShotError.
    /// For permission errors, includes a button to open System Settings.
    static func showError(_ error: OpenShotError) {
        let alert = NSAlert()
        alert.messageText = errorTitle(for: error)
        alert.informativeText = error.errorDescription ?? "An unknown error occurred."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        if case .captureNotPermitted = error {
            alert.addButton(withTitle: "Open System Settings")
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                openScreenRecordingSettings()
            }
        } else {
            alert.runModal()
        }
    }

    /// Show a generic error alert with a custom message.
    static func showGenericError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Private

    private static func errorTitle(for error: OpenShotError) -> String {
        switch error {
        case .captureNotPermitted:
            return "Permission Required"
        case .captureFailedNoImage, .captureFailedNoContent:
            return "Capture Failed"
        case .screenNotFound:
            return "Screen Not Found"
        case .windowNotFound:
            return "Window Not Found"
        case .recordingAlreadyInProgress:
            return "Recording In Progress"
        case .recordingNotInProgress:
            return "No Active Recording"
        case .assetWriterFailed:
            return "Recording Error"
        case .gifExportFailed:
            return "GIF Export Failed"
        case .ocrFailed:
            return "Text Recognition Failed"
        case .fileIOFailed:
            return "File Error"
        case .invalidConfiguration:
            return "Configuration Error"
        }
    }

    private static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
