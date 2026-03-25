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

    /// Requests screen recording permission from the user.
    /// On first request, presents the system permission dialog.
    /// On subsequent requests (when already denied), shows an alert
    /// guiding the user to System Settings.
    static func requestScreenRecording() {
        logger.info("Requesting screen recording permission")

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
