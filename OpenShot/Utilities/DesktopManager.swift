import AppKit
import os

/// Manages hiding and showing desktop icons during screen capture.
/// Uses Finder's `CreateDesktop` preference to toggle icon visibility,
/// which requires a Finder restart to take effect.
struct DesktopManager {

    private static let logger = Logger(subsystem: "com.openshot", category: "desktop")

    // MARK: - Hide / Show

    /// Hide desktop icons by setting Finder's `CreateDesktop` preference to false,
    /// then restarting Finder so the change takes effect immediately.
    static func hideDesktopIcons() {
        setCreateDesktop(false)
        restartFinder()
        logger.info("Desktop icons hidden")
    }

    /// Show desktop icons by setting Finder's `CreateDesktop` preference to true,
    /// then restarting Finder so the change takes effect immediately.
    static func showDesktopIcons() {
        setCreateDesktop(true)
        restartFinder()
        logger.info("Desktop icons shown")
    }

    /// Toggle desktop icon visibility based on current state.
    static func toggleDesktopIcons() {
        if areDesktopIconsVisible() {
            hideDesktopIcons()
        } else {
            showDesktopIcons()
        }
    }

    // MARK: - Query State

    /// Check whether desktop icons are currently visible.
    /// Reads the `CreateDesktop` key from `com.apple.finder` defaults.
    /// Returns `true` if the key is absent (Finder's default behavior shows icons).
    static func areDesktopIconsVisible() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.finder", "CreateDesktop"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // suppress stderr when key doesn't exist

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            logger.warning("Failed to read CreateDesktop preference: \(error.localizedDescription)")
            return true // assume visible on failure
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Finder treats missing key or "1" / "true" as visible.
        // Only "0" or "false" means hidden.
        switch output.lowercased() {
        case "0", "false":
            return false
        default:
            return true
        }
    }

    // MARK: - Scoped Hiding

    /// Temporarily hide desktop icons for the duration of `body`, then restore
    /// them if they were visible before. Waits briefly after each Finder restart
    /// so the desktop has time to redraw.
    static func withHiddenIcons<T>(_ body: () async throws -> T) async rethrows -> T {
        let wasVisible = areDesktopIconsVisible()

        if wasVisible {
            hideDesktopIcons()
            // Give Finder time to restart and hide the icon layer.
            try? await Task.sleep(for: .milliseconds(500))
        }

        defer {
            if wasVisible {
                showDesktopIcons()
            }
        }

        return try await body()
    }

    // MARK: - Private Helpers

    /// Write a boolean value to Finder's `CreateDesktop` preference.
    private static func setCreateDesktop(_ value: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = [
            "write",
            "com.apple.finder",
            "CreateDesktop",
            "-bool",
            value ? "true" : "false"
        ]

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            logger.error("Failed to write CreateDesktop preference: \(error.localizedDescription)")
        }
    }

    /// Restart Finder so that preference changes take effect.
    private static func restartFinder() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Finder"]

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            logger.error("Failed to restart Finder: \(error.localizedDescription)")
        }
    }
}
