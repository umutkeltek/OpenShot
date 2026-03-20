// LaunchAtLogin.swift
// OpenShot
//
// Manages launch-at-login registration using SMAppService (macOS 13+).

import ServiceManagement
import os

struct LaunchAtLogin {
    private static let logger = Logger(subsystem: "com.openshot.app", category: "launch-at-login")

    static func update(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Registered for launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Unregistered from launch at login")
            }
        } catch {
            logger.error("Failed to update launch at login: \(error.localizedDescription)")
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
