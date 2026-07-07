import AppKit
import os

struct Permissions {

    private static let logger = Logger(subsystem: "com.openshot.app", category: "Permissions")

    /// Checks whether the app currently has screen recording permission.
    /// Returns `true` if permission has already been granted.
    static func checkScreenRecording() -> Bool {
        let hasAccess = CGPreflightScreenCaptureAccess()
        logger.debug("Screen recording permission check: \(hasAccess)")
        return hasAccess
    }

    /// Whether the user has already seen the one-time "app will quit and
    /// reopen" warning shown before the very first system permission prompt.
    private static let hasShownRelaunchPrimerKey = "pref_hasShownScreenRecordingPrimer"

    /// Requests screen recording permission from the user.
    /// On first request, warns that macOS will quit the app after access is
    /// granted (standard TCC behavior — otherwise it looks like a crash),
    /// then presents the system permission dialog.
    /// On subsequent requests (when already denied), shows an alert
    /// guiding the user to System Settings.
    static func requestScreenRecording() {
        logger.info("Requesting screen recording permission")

        if !UserDefaults.standard.bool(forKey: hasShownRelaunchPrimerKey) {
            UserDefaults.standard.set(true, forKey: hasShownRelaunchPrimerKey)
            showRelaunchPrimerAlert()
        }

        // CGRequestScreenCaptureAccess() only shows the system prompt once.
        // If already denied, it returns false silently. In that case, show
        // an alert directing the user to System Settings.
        let granted = CGRequestScreenCaptureAccess()
        if !granted {
            Task { @MainActor in
                showPermissionAlert()
            }
        }
    }

    /// Warns the user, before the system permission dialog appears for the
    /// first time, that granting Screen Recording access will cause macOS to
    /// automatically quit the app (it must relaunch to pick up the new
    /// privacy state) — without this warning, the quit looks like a crash.
    private static func showRelaunchPrimerAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Needed"
        alert.informativeText = "OpenShot needs Screen Recording access to capture your screen. After you click Allow in the next dialog, macOS will quit OpenShot automatically — just reopen it and you're all set."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.runModal()
    }

    /// Shows the existing permission alert via AlertHelper.
    @MainActor
    private static func showPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)
        AlertHelper.showError(.captureNotPermitted)
    }

    /// Checks screen recording permission and requests it if not already granted.
    /// Call this on app launch to ensure the permission flow is initiated early.
    static func ensureScreenRecording() {
        if !checkScreenRecording() {
            logger.info("Screen recording not permitted, requesting access")
            requestScreenRecording()
        } else {
            logger.info("Screen recording permission already granted")
        }
    }
}
