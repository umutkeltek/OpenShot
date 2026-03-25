import AppKit
import SwiftUI
import ScreenCaptureKit
import SwiftData
import os

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager.shared
    private let preferences = Preferences.shared
    private let logger = Logger(subsystem: "com.openshot.app", category: "AppDelegate")
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingControlsPanel: RecordingControlsPanel?
    private var gifRecorder: GIFRecorder?

    // Menu items that need dynamic enable/disable
    private var restoreItem: NSMenuItem?
    private var recordScreenItem: NSMenuItem?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotkeyCallbacks()
        setupNotificationObservers()
        hotkeyManager.registerAll()
        Permissions.ensureScreenRecording()
        OnboardingWindowManager.showIfNeeded()
        cleanupTempFiles()
        cleanupCaptureHistory()
        logger.info("OpenShot launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterAll()
        NotificationCenter.default.removeObserver(self)
        recordingTimer?.invalidate()
        recordingTimer = nil
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
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .initCapture,
                object: nil,
                userInfo: ["mode": CaptureMode.area]
            )
        }
    }

    @objc private func captureWindow() {
        logger.info("Capture Window triggered")
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .initCapture,
                object: nil,
                userInfo: ["mode": CaptureMode.window]
            )
        }
    }

    @objc private func captureFullscreen() {
        logger.info("Capture Fullscreen triggered")
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .initCapture,
                object: nil,
                userInfo: ["mode": CaptureMode.fullscreen]
            )
        }
    }

    @objc private func captureScrolling() {
        logger.info("Scrolling Capture triggered")
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .initCapture,
                object: nil,
                userInfo: ["mode": CaptureMode.scrolling]
            )
        }
    }

    @objc private func recordScreen() {
        logger.info("Record Screen triggered")
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        Task { @MainActor in
            NotificationCenter.default.post(name: .initRecordScreen, object: nil)
        }
    }

    @objc private func recordGIF() {
        logger.info("Record GIF triggered")
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        Task { @MainActor in
            NotificationCenter.default.post(name: .initRecordGIF, object: nil)
        }
    }

    @objc private func captureText() {
        logger.info("OCR Capture Text triggered")
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        Task { @MainActor in
            NotificationCenter.default.post(name: .initOCRCapture, object: nil)
        }
    }

    @objc private func capturePreviousArea() {
        logger.info("Capture Previous Area triggered")
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        Task { @MainActor in
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
    }

    @objc private func selfTimerCapture() {
        logger.info("Self-Timer Capture triggered")
        guard Permissions.checkScreenRecording() else {
            Permissions.requestScreenRecording()
            return
        }
        Task { @MainActor in
            do {
                let image = try await CaptureEngine.shared.captureWithSelfTimer(mode: .fullscreen)
                CaptureEngine.shared.presentResult(image)
            } catch {
                logger.warning("Self-Timer Capture failed: \(error.localizedDescription)")
                if let osError = error as? OpenShotError {
                    AlertHelper.showError(osError)
                }
            }
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
        NotificationCenter.default.post(name: .showCaptureHistory, object: nil)
    }

    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?

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

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: .initCapture, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            guard let mode = notification.userInfo?["mode"] as? CaptureMode else { return }
            Task { @MainActor in
                do {
                    let engine = CaptureEngine.shared
                    let image: NSImage

                    if self.preferences.hideDesktopIconsDuringCapture {
                        image = try await DesktopManager.withHiddenIcons {
                            switch mode {
                            case .area: return try await engine.captureArea()
                            case .window: return try await engine.captureWindow()
                            case .fullscreen: return try await engine.captureFullscreen()
                            case .scrolling: return try await engine.captureScrolling()
                            }
                        }
                    } else {
                        switch mode {
                        case .area: image = try await engine.captureArea()
                        case .window: image = try await engine.captureWindow()
                        case .fullscreen: image = try await engine.captureFullscreen()
                        case .scrolling: image = try await engine.captureScrolling()
                        }
                    }

                    engine.presentResult(image)
                } catch {
                    if case CaptureEngineError.cancelled = error { return }
                    Logger(subsystem: "com.openshot", category: "capture").error("Capture failed: \(error.localizedDescription)")
                    if let osError = error as? OpenShotError {
                        AlertHelper.showError(osError)
                    } else {
                        AlertHelper.showGenericError(title: "Capture Failed", message: error.localizedDescription)
                    }
                }
            }
        }

        NotificationCenter.default.addObserver(forName: .initRecordScreen, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if ScreenRecorder.shared.isRecording {
                    // Stop recording
                    do {
                        let url = try await ScreenRecorder.shared.stopRecording()
                        self.stopRecordingUI()
                        SoundEffects.playRecordingStop()

                        let preferences = Preferences.shared
                        let saveDir = preferences.saveLocation
                        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)

                        let filename = url.lastPathComponent
                        let destinationURL = saveDir.appendingPathComponent(filename)
                        do {
                            try FileManager.default.moveItem(at: url, to: destinationURL)
                        } catch {
                            self.logger.warning("Failed to move recording to save location: \(error.localizedDescription)")
                        }

                        let finalURL = FileManager.default.fileExists(atPath: destinationURL.path) ? destinationURL : url
                        self.logger.info("Recording saved to \(finalURL.path)")
                        ToastManager.show(icon: "checkmark.circle.fill", message: "Recording saved", detail: finalURL.lastPathComponent)

                        do {
                            let context = try CaptureHistoryManager.shared.makeContext()
                            try CaptureHistoryManager.shared.saveRecording(
                                url: finalURL,
                                type: "recording",
                                modelContext: context
                            )
                        } catch {
                            self.logger.warning("Failed to save recording to history: \(error.localizedDescription)")
                        }
                    } catch {
                        self.stopRecordingUI()
                        Logger(subsystem: "com.openshot", category: "recorder").error("Stop recording failed: \(error.localizedDescription)")
                        AlertHelper.showGenericError(title: "Recording Failed", message: error.localizedDescription)
                    }
                } else {
                    // Start recording
                    do {
                        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                        guard let display = content.displays.first else { return }
                        let filter = SCContentFilter(display: display, excludingWindows: [])
                        try await ScreenRecorder.shared.startRecording(filter: filter)
                        self.startRecordingUI()
                        SoundEffects.playRecordingStart()
                    } catch {
                        Logger(subsystem: "com.openshot", category: "recorder").error("Recording failed: \(error.localizedDescription)")
                        AlertHelper.showGenericError(title: "Recording Failed", message: error.localizedDescription)
                    }
                }
            }
        }

        NotificationCenter.default.addObserver(forName: .initRecordGIF, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }

            if let activeRecorder = self.gifRecorder, activeRecorder.isRecording {
                Task {
                    do {
                        let url = try await activeRecorder.stopCapture()
                        await MainActor.run {
                            self.gifRecorder = nil
                            ToastManager.show(icon: "checkmark.circle.fill", message: "GIF saved", detail: url.lastPathComponent)

                            do {
                                let context = try CaptureHistoryManager.shared.makeContext()
                                try CaptureHistoryManager.shared.saveRecording(
                                    url: url,
                                    type: "gif",
                                    modelContext: context
                                )
                            } catch {
                                self.logger.warning("Failed to save GIF to history: \(error.localizedDescription)")
                            }

                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    } catch {
                        await MainActor.run {
                            self.gifRecorder = nil
                            AlertHelper.showGenericError(title: "GIF Export Failed", message: error.localizedDescription)
                        }
                    }
                }
                return
            }

            Task { @MainActor in
                guard let rect = await AreaSelector.present() else { return }
                let recorder = GIFRecorder()
                self.gifRecorder = recorder
                recorder.startCapture(rect: rect)
            }
        }

        NotificationCenter.default.addObserver(forName: .initOCRCapture, object: nil, queue: .main) { _ in
            Task { @MainActor in
                let ocr = OCROverlay()
                do {
                    try await ocr.captureAndRecognize()
                } catch {
                    if case CaptureEngineError.cancelled = error { return }
                    Logger(subsystem: "com.openshot", category: "ocr").error("OCR failed: \(error.localizedDescription)")
                    AlertHelper.showGenericError(title: "OCR Failed", message: error.localizedDescription)
                }
            }
        }

        NotificationCenter.default.addObserver(forName: .showCaptureHistory, object: nil, queue: .main) { [weak self] _ in
            self?.openHistoryWindow()
        }
    }

    // MARK: - Recording UI

    @MainActor
    private func startRecordingUI() {
        recordingStartTime = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            let minutes = elapsed / 60
            let seconds = elapsed % 60
            let timeString = String(format: "%02d:%02d", minutes, seconds)
            self.statusItem.button?.title = " \(timeString)"
        }

        let controlsPanel = RecordingControlsPanel()
        controlsPanel.show(
            recorder: ScreenRecorder.shared,
            onStop: { [weak self] in
                self?.recordScreen()
            },
            onRestart: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    do {
                        try await ScreenRecorder.shared.restartRecording()
                        SoundEffects.playRecordingStart()
                    } catch {
                        self.stopRecordingUI()
                        AlertHelper.showGenericError(title: "Restart Failed", message: error.localizedDescription)
                    }
                }
            }
        )
        self.recordingControlsPanel = controlsPanel
    }

    @MainActor
    private func stopRecordingUI() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        recordingControlsPanel?.dismiss()
        recordingControlsPanel = nil
        statusItem.button?.title = ""
    }

    // MARK: - History Window

    private func openHistoryWindow() {
        if let existing = historyWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let historyView = HistoryView()
            .modelContainer(for: CaptureRecord.self)
        let hostingController = NSHostingController(rootView: historyView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Capture History"
        window.setContentSize(NSSize(width: 700, height: 500))
        window.minSize = NSSize(width: 400, height: 300)
        window.setFrameAutosaveName("OpenShot.History")
        window.center()

        self.historyWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

// MARK: - Notification Names

extension Notification.Name {
    static let initCapture = Notification.Name("com.openshot.initCapture")
    static let initRecordScreen = Notification.Name("com.openshot.initRecordScreen")
    static let initRecordGIF = Notification.Name("com.openshot.initRecordGIF")
    static let initOCRCapture = Notification.Name("com.openshot.initOCRCapture")
    static let showCaptureHistory = Notification.Name("com.openshot.showCaptureHistory")
}
