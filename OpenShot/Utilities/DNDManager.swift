// DNDManager.swift
// OpenShot
//
// Manages Do Not Disturb / Focus mode during recording.

import AppKit
import os

/// A thread-safe "fire at most once" gate. `Process.terminationHandler`
/// isn't guaranteed to run on the main thread, so a plain `Bool` flag mutated
/// from it is a data race; this serializes access with an unfair lock.
final class OnceGate: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)

    /// Returns `true` the first time it's called, `false` on every call after.
    @discardableResult
    func fireOnce() -> Bool {
        lock.withLock { fired in
            guard !fired else { return false }
            fired = true
            return true
        }
    }
}

struct DNDManager {
    private static let logger = Logger(subsystem: "com.openshot", category: "dnd")
    private static let warnGate = OnceGate()

    /// Enable Do Not Disturb via the Shortcuts CLI. Runs asynchronously
    /// to avoid blocking the cooperative thread pool.
    static func enableDND() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", "Enable DND"]
        task.standardError = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.terminationHandler = { process in
            if process.terminationStatus != 0 {
                logger.warning("Enable DND shortcut exited with status \(process.terminationStatus)")
                showDNDWarningOnce()
            } else {
                logger.info("DND enabled via Shortcuts")
            }
        }
        do {
            try task.run()
        } catch {
            logger.warning("Failed to run Enable DND shortcut: \(error.localizedDescription)")
            showDNDWarningOnce()
        }
    }

    static func disableDND() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", "Disable DND"]
        task.standardError = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.terminationHandler = { process in
            if process.terminationStatus != 0 {
                logger.warning("Disable DND shortcut exited with status \(process.terminationStatus)")
            } else {
                logger.info("DND disabled via Shortcuts")
            }
        }
        do {
            try task.run()
        } catch {
            logger.warning("Failed to run Disable DND shortcut: \(error.localizedDescription)")
        }
    }

    private static func showDNDWarningOnce() {
        guard warnGate.fireOnce() else { return }
        DispatchQueue.main.async {
            ToastManager.show(icon: "moon.slash", message: "DND not available", detail: "Create 'Enable DND' shortcut in Shortcuts app")
        }
    }

    /// Scoped DND: enable during the given async operation, disable after
    static func withDND<T>(_ body: () async throws -> T) async rethrows -> T {
        enableDND()
        defer { disableDND() }
        return try await body()
    }
}
