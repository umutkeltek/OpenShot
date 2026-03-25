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
                NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.area])
            }
        case "capture-window":
            confirmAndExecute(message: "An external app wants to capture your screen. Allow?") {
                NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.window])
            }
        case "capture-fullscreen":
            confirmAndExecute(message: "An external app wants to capture your screen. Allow?") {
                NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.fullscreen])
            }
        case "scrolling-capture":
            confirmAndExecute(message: "An external app wants to capture your screen. Allow?") {
                NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.scrolling])
            }
        case "capture-text":
            confirmAndExecute(message: "An external app wants to capture your screen. Allow?") {
                NotificationCenter.default.post(name: .initOCRCapture, object: nil)
            }
        case "record-screen":
            confirmAndExecute(message: "An external app wants to start a recording. Allow?") {
                NotificationCenter.default.post(name: .initRecordScreen, object: nil)
            }
        case "record-gif":
            confirmAndExecute(message: "An external app wants to start a recording. Allow?") {
                NotificationCenter.default.post(name: .initRecordGIF, object: nil)
            }
        case "open-history":
            NotificationCenter.default.post(name: .showCaptureHistory, object: nil)
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
