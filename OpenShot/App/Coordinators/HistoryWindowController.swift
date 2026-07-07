// HistoryWindowController.swift
// OpenShot
//
// Owns the Capture History window's lifecycle — creating it once, bringing
// it to front on repeat requests, and wiring it to the app's single shared
// SwiftData ModelContainer (never a second, independent one).

import AppKit
import SwiftUI
import SwiftData
import os

@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()

    private let logger = Logger(subsystem: "com.openshot", category: "history-window")
    private var window: NSWindow?

    private init() {}

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let container: ModelContainer
        do {
            container = try CaptureHistoryManager.shared.sharedContainer
        } catch {
            logger.error("Failed to obtain shared ModelContainer for History: \(error.localizedDescription)")
            AlertHelper.showGenericError(title: "History Unavailable", message: error.localizedDescription)
            return
        }

        let historyView = HistoryView()
            .modelContainer(container)
        let hostingController = NSHostingController(rootView: historyView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Capture History"
        newWindow.setContentSize(NSSize(width: 700, height: 500))
        newWindow.minSize = NSSize(width: 400, height: 300)
        newWindow.setFrameAutosaveName("OpenShot.History")
        newWindow.center()

        self.window = newWindow

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
