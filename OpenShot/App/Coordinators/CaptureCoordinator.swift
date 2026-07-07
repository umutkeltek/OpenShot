// CaptureCoordinator.swift
// OpenShot
//
// Runs the capture flow for all four capture modes plus "previous area" and
// self-timer variants: permission check, optional desktop-icon hiding,
// dispatch to CaptureEngine, and presenting the result. Single shared code
// path for the menu/hotkey, All-in-One panel, and `openshot://` URL scheme
// entry points, so the permission check and error-surfacing can't drift
// between them.

import AppKit
import os

@MainActor
final class CaptureCoordinator {
    static let shared = CaptureCoordinator()

    private let logger = Logger(subsystem: "com.openshot", category: "capture-coordinator")
    private let preferences = Preferences.shared

    private init() {}

    func performCapture(mode: CaptureMode) async {
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }

        let engine = CaptureEngine.shared
        do {
            let image: NSImage
            if preferences.hideDesktopIconsDuringCapture {
                image = try await DesktopManager.withHiddenIcons {
                    try await Self.capture(mode: mode, engine: engine)
                }
            } else {
                image = try await Self.capture(mode: mode, engine: engine)
            }
            engine.presentResult(image)
        } catch {
            if case CaptureEngineError.cancelled = error { return }
            logger.error("Capture failed: \(error.localizedDescription)")
            if let osError = error as? OpenShotError {
                AlertHelper.showError(osError)
            } else {
                AlertHelper.showGenericError(title: "Capture Failed", message: error.localizedDescription)
            }
        }
    }

    private static func capture(mode: CaptureMode, engine: CaptureEngine) async throws -> NSImage {
        switch mode {
        case .area: return try await engine.captureArea()
        case .window: return try await engine.captureWindow()
        case .fullscreen: return try await engine.captureFullscreen()
        case .scrolling: return try await engine.captureScrolling()
        }
    }

    func capturePreviousArea() async {
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        do {
            let image = try await CaptureEngine.shared.capturePreviousArea()
            CaptureEngine.shared.presentResult(image)
        } catch {
            logger.warning("Capture Previous Area failed: \(error.localizedDescription)")
            if let osError = error as? OpenShotError {
                AlertHelper.showError(osError)
            }
        }
    }

    func captureWithSelfTimer(mode: CaptureMode) async {
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        do {
            let image = try await CaptureEngine.shared.captureWithSelfTimer(mode: mode)
            CaptureEngine.shared.presentResult(image)
        } catch {
            logger.warning("Self-Timer Capture failed: \(error.localizedDescription)")
            if let osError = error as? OpenShotError {
                AlertHelper.showError(osError)
            }
        }
    }
}
