import AppKit
import os

class URLSchemeHandler: NSObject {
    static let shared = URLSchemeHandler()
    private let logger = Logger(subsystem: "com.openshot", category: "url-scheme")

    @objc func handleURL(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }

        logger.info("URL scheme invoked: \(urlString)")

        let command = url.host ?? ""

        switch command {
        case "capture-area":
            confirmAndExecute(message: "An external app wants to capture your screen. Allow?") {
                Task { @MainActor in
                    await CaptureCoordinator.shared.performCapture(mode: .area)
                }
            }
        case "capture-window":
            confirmAndExecute(message: "An external app wants to capture your screen. Allow?") {
                Task { @MainActor in
                    await CaptureCoordinator.shared.performCapture(mode: .window)
                }
            }
        case "capture-fullscreen":
            confirmAndExecute(message: "An external app wants to capture your screen. Allow?") {
                Task { @MainActor in
                    await CaptureCoordinator.shared.performCapture(mode: .fullscreen)
                }
            }
        case "scrolling-capture":
            confirmAndExecute(message: "An external app wants to capture your screen. Allow?") {
                Task { @MainActor in
                    await CaptureCoordinator.shared.performCapture(mode: .scrolling)
                }
            }
        case "capture-text":
            confirmAndExecute(message: "An external app wants to capture your screen. Allow?") {
                Task { @MainActor in
                    await OCRCoordinator.shared.captureText()
                }
            }
        case "record-screen":
            confirmAndExecute(message: "An external app wants to start a recording. Allow?") {
                Task { @MainActor in
                    await RecordingCoordinator.shared.toggleRecording()
                }
            }
        case "record-gif":
            confirmAndExecute(message: "An external app wants to start a recording. Allow?") {
                Task { @MainActor in
                    await GIFCoordinator.shared.toggleGIFRecording()
                }
            }
        case "open-history":
            Task { @MainActor in
                HistoryWindowController.shared.show()
            }
        case "toggle-desktop-icons":
            DesktopManager.toggleDesktopIcons()
        case "restore-recently-closed":
            Task { @MainActor in
                QuickAccessOverlay.restoreRecentlyClosed()
            }
        default:
            logger.warning("Unknown URL scheme command: \(command)")
        }
    }

    // MARK: - Confirmation Alert

    private func confirmAndExecute(message: String, action: @escaping () -> Void) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "OpenShot"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            action()
        } else {
            logger.info("User denied URL scheme action: \(message)")
        }
    }
}
