// DNDManager.swift
// OpenShot
//
// Manages Do Not Disturb / Focus mode during recording.

import AppKit
import os

struct DNDManager {
    private static let logger = Logger(subsystem: "com.openshot", category: "dnd")

    /// Enable Do Not Disturb by running shortcuts or defaults
    /// macOS 14+ doesn't have a simple public API for DND, so we use a workaround
    static func enableDND() {
        // Use shortcuts app automation or defaults write
        // The most reliable approach on macOS 14+ is via the Focus system
        // We use the `shortcuts` CLI to run a shortcut named "Enable DND" if it exists
        // Fallback: use NSDistributedNotificationCenter (limited on newer macOS)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", "Enable DND"]
        task.standardError = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        try? task.run()
        logger.info("DND enable requested via Shortcuts")
    }

    static func disableDND() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", "Disable DND"]
        task.standardError = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        try? task.run()
        logger.info("DND disable requested via Shortcuts")
    }

    /// Scoped DND: enable during the given async operation, disable after
    static func withDND<T>(_ body: () async throws -> T) async rethrows -> T {
        enableDND()
        defer { disableDND() }
        return try await body()
    }
}
