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
            NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.area])
        case "capture-window":
            NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.window])
        case "capture-fullscreen":
            NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.fullscreen])
        case "scrolling-capture":
            NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.scrolling])
        case "record-screen":
            NotificationCenter.default.post(name: .initRecordScreen, object: nil)
        case "record-gif":
            NotificationCenter.default.post(name: .initRecordGIF, object: nil)
        case "capture-text":
            NotificationCenter.default.post(name: .initOCRCapture, object: nil)
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
}
