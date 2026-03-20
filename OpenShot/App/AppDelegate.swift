import AppKit
import SwiftUI
import ScreenCaptureKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager.shared
    private let preferences = Preferences.shared
    private let logger = Logger(subsystem: "com.openshot.app", category: "AppDelegate")

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotkeyCallbacks()
        setupNotificationObservers()
        hotkeyManager.registerAll()
        Permissions.ensureScreenRecording()
        logger.info("OpenShot launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterAll()
        logger.info("OpenShot terminating")
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

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

        let captureAreaItem = NSMenuItem(
            title: "Capture Area",
            action: #selector(captureArea),
            keyEquivalent: "4"
        )
        captureAreaItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(captureAreaItem)

        let captureWindowItem = NSMenuItem(
            title: "Capture Window",
            action: #selector(captureWindow),
            keyEquivalent: "5"
        )
        captureWindowItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(captureWindowItem)

        let captureFullscreenItem = NSMenuItem(
            title: "Capture Fullscreen",
            action: #selector(captureFullscreen),
            keyEquivalent: "3"
        )
        captureFullscreenItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(captureFullscreenItem)

        let scrollingCaptureItem = NSMenuItem(
            title: "Scrolling Capture",
            action: #selector(captureScrolling),
            keyEquivalent: "6"
        )
        scrollingCaptureItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(scrollingCaptureItem)

        let capturePreviousItem = NSMenuItem(
            title: "Capture Previous Area",
            action: #selector(capturePreviousArea),
            keyEquivalent: "7"
        )
        capturePreviousItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(capturePreviousItem)

        let selfTimerItem = NSMenuItem(
            title: "Self-Timer Capture",
            action: #selector(selfTimerCapture),
            keyEquivalent: "8"
        )
        selfTimerItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(selfTimerItem)

        menu.addItem(NSMenuItem.separator())

        let allInOneItem = NSMenuItem(
            title: "All-in-One",
            action: #selector(showAllInOne),
            keyEquivalent: "A"
        )
        allInOneItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(allInOneItem)

        menu.addItem(NSMenuItem.separator())

        let recordScreenItem = NSMenuItem(
            title: "Record Screen",
            action: #selector(recordScreen),
            keyEquivalent: "R"
        )
        recordScreenItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(recordScreenItem)

        let recordGIFItem = NSMenuItem(
            title: "Record GIF",
            action: #selector(recordGIF),
            keyEquivalent: "G"
        )
        recordGIFItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(recordGIFItem)

        menu.addItem(NSMenuItem.separator())

        let ocrItem = NSMenuItem(
            title: "OCR - Capture Text",
            action: #selector(captureText),
            keyEquivalent: "T"
        )
        ocrItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(ocrItem)

        menu.addItem(NSMenuItem.separator())

        let restoreItem = NSMenuItem(
            title: "Restore Recently Closed",
            action: #selector(restoreRecentlyClosed),
            keyEquivalent: "Z"
        )
        restoreItem.keyEquivalentModifierMask = [.shift, .command]
        menu.addItem(restoreItem)

        let toggleDesktopItem = NSMenuItem(
            title: "Toggle Desktop Icons",
            action: #selector(toggleDesktopIcons),
            keyEquivalent: "D"
        )
        toggleDesktopItem.keyEquivalentModifierMask = [.shift, .command]
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
                let image = try await CaptureEngine.shared.captureWithSelfTimer(mode: .area)
                CaptureEngine.shared.presentResult(image)
            } catch {
                logger.warning("Self-Timer Capture failed: \(error.localizedDescription)")
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

    @objc private func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
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
                }
            }
        }

        NotificationCenter.default.addObserver(forName: .initRecordScreen, object: nil, queue: .main) { _ in
            Task { @MainActor in
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    guard let display = content.displays.first else { return }
                    let filter = SCContentFilter(display: display, excludingWindows: [])
                    try await ScreenRecorder.shared.startRecording(filter: filter)
                } catch {
                    Logger(subsystem: "com.openshot", category: "recorder").error("Recording failed: \(error.localizedDescription)")
                }
            }
        }

        NotificationCenter.default.addObserver(forName: .initRecordGIF, object: nil, queue: .main) { _ in
            Task { @MainActor in
                guard let rect = await AreaSelector.present() else { return }
                GIFRecorder().startCapture(rect: rect)
            }
        }

        NotificationCenter.default.addObserver(forName: .initOCRCapture, object: nil, queue: .main) { _ in
            Task { @MainActor in
                let ocr = OCROverlay()
                try? await ocr.captureAndRecognize()
            }
        }

        NotificationCenter.default.addObserver(forName: .showCaptureHistory, object: nil, queue: .main) { [weak self] _ in
            self?.openHistoryWindow()
        }
    }

    // MARK: - History Window

    private func openHistoryWindow() {
        let historyView = HistoryView()
            .modelContainer(for: CaptureRecord.self)
        let hostingController = NSHostingController(rootView: historyView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Capture History"
        window.setContentSize(NSSize(width: 700, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
