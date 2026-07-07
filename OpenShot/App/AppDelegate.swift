import AppKit
import SwiftUI
import os

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager.shared
    private let preferences = Preferences.shared
    private let logger = Logger(subsystem: "com.openshot.app", category: "AppDelegate")

    // Menu items that need dynamic enable/disable
    private var restoreItem: NSMenuItem?
    private var recordScreenItem: NSMenuItem?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotkeyCallbacks()
        RecordingCoordinator.shared.statusItemTitleUpdate = { [weak self] title in
            self?.statusItem.button?.title = title
        }
        hotkeyManager.registerAll()
        Permissions.ensureScreenRecording()
        OnboardingWindowManager.showIfNeeded()
        cleanupTempFiles()
        cleanupCaptureHistory()
        logger.info("OpenShot launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterAll()
        logger.info("OpenShot terminating")
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "OpenShot")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            button.image = image
        }

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let captureAreaItem = NSMenuItem(
            title: "Capture Area",
            action: #selector(captureArea),
            keyEquivalent: "4"
        )
        captureAreaItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(captureAreaItem)

        let captureWindowItem = NSMenuItem(
            title: "Capture Window",
            action: #selector(captureWindow),
            keyEquivalent: "5"
        )
        captureWindowItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(captureWindowItem)

        let captureFullscreenItem = NSMenuItem(
            title: "Capture Fullscreen",
            action: #selector(captureFullscreen),
            keyEquivalent: "3"
        )
        captureFullscreenItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(captureFullscreenItem)

        let scrollingCaptureItem = NSMenuItem(
            title: "Scrolling Capture",
            action: #selector(captureScrolling),
            keyEquivalent: "6"
        )
        scrollingCaptureItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(scrollingCaptureItem)

        let capturePreviousItem = NSMenuItem(
            title: "Capture Previous Area",
            action: #selector(capturePreviousArea),
            keyEquivalent: "7"
        )
        capturePreviousItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(capturePreviousItem)

        let selfTimerItem = NSMenuItem(
            title: "Self-Timer Capture",
            action: #selector(selfTimerCapture),
            keyEquivalent: "8"
        )
        selfTimerItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(selfTimerItem)

        menu.addItem(NSMenuItem.separator())

        let allInOneItem = NSMenuItem(
            title: "All-in-One",
            action: #selector(showAllInOne),
            keyEquivalent: "A"
        )
        allInOneItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(allInOneItem)

        menu.addItem(NSMenuItem.separator())

        let recordScreenItem = NSMenuItem(
            title: "Record Screen",
            action: #selector(recordScreen),
            keyEquivalent: "R"
        )
        recordScreenItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(recordScreenItem)

        let recordGIFItem = NSMenuItem(
            title: "Record GIF",
            action: #selector(recordGIF),
            keyEquivalent: "G"
        )
        recordGIFItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(recordGIFItem)

        menu.addItem(NSMenuItem.separator())

        let ocrItem = NSMenuItem(
            title: "OCR - Capture Text",
            action: #selector(captureText),
            keyEquivalent: "T"
        )
        ocrItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(ocrItem)

        menu.addItem(NSMenuItem.separator())

        let restoreMenuItem = NSMenuItem(
            title: "Restore Recently Closed",
            action: #selector(restoreRecentlyClosed),
            keyEquivalent: "Z"
        )
        restoreMenuItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(restoreMenuItem)
        self.restoreItem = restoreMenuItem

        let toggleDesktopItem = NSMenuItem(
            title: "Toggle Desktop Icons",
            action: #selector(toggleDesktopIcons),
            keyEquivalent: "D"
        )
        toggleDesktopItem.keyEquivalentModifierMask = [.control, .shift, .command]
        menu.addItem(toggleDesktopItem)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(
            title: "Capture History",
            action: #selector(showHistory),
            keyEquivalent: ""
        )
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit OpenShot",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Dynamically enable/disable menu items based on current state.
        restoreItem?.isEnabled = QuickAccessOverlay.lastDismissedImage != nil
    }

    // MARK: - Hotkey Callbacks

    private func setupHotkeyCallbacks() {
        hotkeyManager.onHotkeyAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .captureArea:
                self.captureArea()
            case .captureWindow:
                self.captureWindow()
            case .captureFullscreen:
                self.captureFullscreen()
            case .captureScrolling:
                self.captureScrolling()
            case .recordScreen:
                self.recordScreen()
            case .recordGIF:
                self.recordGIF()
            case .ocrCaptureText:
                self.captureText()
            case .allInOne:
                self.showAllInOne()
            case .capturePreviousArea:
                self.capturePreviousArea()
            case .selfTimerCapture:
                self.selfTimerCapture()
            case .restoreRecentlyClosed:
                self.restoreRecentlyClosed()
            case .toggleDesktopIcons:
                self.toggleDesktopIcons()
            }
        }
    }

    // MARK: - Menu Actions

    @objc private func captureArea() {
        logger.info("Capture Area triggered")
        Task { @MainActor in
            await CaptureCoordinator.shared.performCapture(mode: .area)
        }
    }

    @objc private func captureWindow() {
        logger.info("Capture Window triggered")
        Task { @MainActor in
            await CaptureCoordinator.shared.performCapture(mode: .window)
        }
    }

    @objc private func captureFullscreen() {
        logger.info("Capture Fullscreen triggered")
        Task { @MainActor in
            await CaptureCoordinator.shared.performCapture(mode: .fullscreen)
        }
    }

    @objc private func captureScrolling() {
        logger.info("Scrolling Capture triggered")
        Task { @MainActor in
            await CaptureCoordinator.shared.performCapture(mode: .scrolling)
        }
    }

    @objc private func recordScreen() {
        logger.info("Record Screen triggered")
        Task { @MainActor in
            await RecordingCoordinator.shared.toggleRecording()
        }
    }

    @objc private func recordGIF() {
        logger.info("Record GIF triggered")
        Task { @MainActor in
            await GIFCoordinator.shared.toggleGIFRecording()
        }
    }

    @objc private func captureText() {
        logger.info("OCR Capture Text triggered")
        Task { @MainActor in
            await OCRCoordinator.shared.captureText()
        }
    }

    @objc private func capturePreviousArea() {
        logger.info("Capture Previous Area triggered")
        Task { @MainActor in
            await CaptureCoordinator.shared.capturePreviousArea()
        }
    }

    @objc private func selfTimerCapture() {
        logger.info("Self-Timer Capture triggered")
        Task { @MainActor in
            await CaptureCoordinator.shared.captureWithSelfTimer(mode: .fullscreen)
        }
    }

    @objc private func showAllInOne() {
        logger.info("All-in-One triggered")
        Task { @MainActor in
            AllInOnePanel.toggle()
        }
    }

    @objc private func restoreRecentlyClosed() {
        logger.info("Restore Recently Closed triggered")
        Task { @MainActor in
            QuickAccessOverlay.restoreRecentlyClosed()
        }
    }

    @objc private func toggleDesktopIcons() {
        logger.info("Toggle Desktop Icons triggered")
        DesktopManager.toggleDesktopIcons()
    }

    @objc private func showHistory() {
        logger.info("Show History triggered")
        Task { @MainActor in
            HistoryWindowController.shared.show()
        }
    }

    private var settingsWindow: NSWindow?

    @objc private func showSettings() {
        // If settings window already exists, just bring it to front.
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create the settings window directly instead of relying on
        // sendAction("showSettingsWindow:") which is unreliable in
        // LSUIElement (menu bar agent) apps.
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "OpenShot Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 400))
        window.minSize = NSSize(width: 500, height: 400)
        window.setFrameAutosaveName("OpenShot.Settings")
        window.center()

        self.settingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Launch Cleanup

    private func cleanupTempFiles() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )

            let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
            var removedCount = 0

            for fileURL in contents where fileURL.lastPathComponent.hasPrefix("OpenShot_") {
                do {
                    let attributes = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                    if let modified = attributes.contentModificationDate, modified < cutoff {
                        try fileManager.removeItem(at: fileURL)
                        removedCount += 1
                    }
                } catch {
                    logger.debug("Skipping temp file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }

            if removedCount > 0 {
                logger.info("Cleaned up \(removedCount) stale temp file(s)")
            }
        } catch {
            logger.warning("Temp file cleanup failed: \(error.localizedDescription)")
        }
    }

    private func cleanupCaptureHistory() {
        let retentionDays = preferences.historyRetentionDays
        Task.detached(priority: .utility) {
            do {
                let context = try CaptureHistoryManager.shared.makeContext()
                try CaptureHistoryManager.shared.cleanupOldCaptures(
                    olderThan: retentionDays,
                    modelContext: context
                )
            } catch {
                Logger(subsystem: "com.openshot.app", category: "AppDelegate")
                    .warning("History retention cleanup failed: \(error.localizedDescription)")
            }
        }
    }
}
