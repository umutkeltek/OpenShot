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
    /// This will present the system permission dialog if permission
    /// has not yet been granted or denied.
    static func requestScreenRecording() {
        logger.info("Requesting screen recording permission")
        CGRequestScreenCaptureAccess()
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
