import AppKit
import Carbon.HIToolbox
import os

@Observable
final class HotkeyManager {

    // MARK: - Singleton

    static let shared = HotkeyManager()

    // MARK: - Types

    enum HotkeyAction: String, CaseIterable, Sendable {
        case captureArea
        case captureWindow
        case captureFullscreen
        case captureScrolling
        case recordScreen
        case recordGIF
        case ocrCaptureText
        case allInOne
        case capturePreviousArea
        case selfTimerCapture
        case restoreRecentlyClosed
        case toggleDesktopIcons

        var displayName: String {
            switch self {
            case .captureArea: return "Capture Area"
            case .captureWindow: return "Capture Window"
            case .captureFullscreen: return "Capture Fullscreen"
            case .captureScrolling: return "Scrolling Capture"
            case .recordScreen: return "Record Screen"
            case .recordGIF: return "Record GIF"
            case .ocrCaptureText: return "OCR - Capture Text"
            case .allInOne: return "All-in-One"
            case .capturePreviousArea: return "Capture Previous Area"
            case .selfTimerCapture: return "Self-Timer Capture"
            case .restoreRecentlyClosed: return "Restore Recently Closed"
            case .toggleDesktopIcons: return "Toggle Desktop Icons"
            }
        }
    }

    struct KeyCombo: Equatable, Sendable {
        let keyCode: UInt16
        let modifierFlags: NSEvent.ModifierFlags

        func matches(event: NSEvent) -> Bool {
            return event.keyCode == keyCode
                && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifierFlags.intersection(.deviceIndependentFlagsMask)
        }
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.openshot.app", category: "HotkeyManager")
    private var globalMonitor: Any?
    private(set) var isRegistered: Bool = false

    /// Callback invoked when a registered hotkey is triggered.
    var onHotkeyAction: ((HotkeyAction) -> Void)?

    /// Current hotkey bindings. Modify to customize shortcuts.
    var bindings: [HotkeyAction: KeyCombo] = defaultBindings

    // MARK: - Default Bindings

    /// Default keyboard shortcut bindings.
    /// Key codes reference:
    /// - 3 = F key (but we use number keys on main keyboard)
    /// - kVK_ANSI_3 = 0x14 (20), kVK_ANSI_4 = 0x15 (21), kVK_ANSI_5 = 0x17 (23), kVK_ANSI_6 = 0x16 (22)
    /// - kVK_ANSI_R = 0x0F (15), kVK_ANSI_G = 0x05 (5), kVK_ANSI_T = 0x11 (17)
    static let defaultBindings: [HotkeyAction: KeyCombo] = [
        .captureFullscreen: KeyCombo(
            keyCode: UInt16(kVK_ANSI_3),
            modifierFlags: [.shift, .command]
        ),
        .captureArea: KeyCombo(
            keyCode: UInt16(kVK_ANSI_4),
            modifierFlags: [.shift, .command]
        ),
        .captureWindow: KeyCombo(
            keyCode: UInt16(kVK_ANSI_5),
            modifierFlags: [.shift, .command]
        ),
        .captureScrolling: KeyCombo(
            keyCode: UInt16(kVK_ANSI_6),
            modifierFlags: [.shift, .command]
        ),
        .recordScreen: KeyCombo(
            keyCode: UInt16(kVK_ANSI_R),
            modifierFlags: [.shift, .command]
        ),
        .recordGIF: KeyCombo(
            keyCode: UInt16(kVK_ANSI_G),
            modifierFlags: [.shift, .command]
        ),
        .ocrCaptureText: KeyCombo(
            keyCode: UInt16(kVK_ANSI_T),
            modifierFlags: [.shift, .command]
        ),
        .allInOne: KeyCombo(
            keyCode: UInt16(kVK_ANSI_A),
            modifierFlags: [.shift, .command]
        ),
        .capturePreviousArea: KeyCombo(
            keyCode: UInt16(kVK_ANSI_7),
            modifierFlags: [.shift, .command]
        ),
        .selfTimerCapture: KeyCombo(
            keyCode: UInt16(kVK_ANSI_8),
            modifierFlags: [.shift, .command]
        ),
        .restoreRecentlyClosed: KeyCombo(
            keyCode: UInt16(kVK_ANSI_Z),
            modifierFlags: [.shift, .command]
        ),
        .toggleDesktopIcons: KeyCombo(
            keyCode: UInt16(kVK_ANSI_D),
            modifierFlags: [.shift, .command]
        ),
    ]

    // MARK: - Init

    private init() {
        logger.info("HotkeyManager initialized")
    }

    deinit {
        unregisterAll()
    }

    // MARK: - Registration

    /// Registers the global event monitor for all configured hotkeys.
    func registerAll() {
        guard !isRegistered else {
            logger.warning("Hotkeys already registered")
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        isRegistered = true
        logger.info("Global hotkeys registered (\(self.bindings.count) bindings)")
    }

    /// Removes the global event monitor and unregisters all hotkeys.
    func unregisterAll() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        isRegistered = false
        logger.info("Global hotkeys unregistered")
    }

    // MARK: - Event Handling

    private func handleKeyEvent(_ event: NSEvent) {
        for (action, combo) in bindings {
            if combo.matches(event: event) {
                logger.debug("Hotkey matched: \(action.rawValue)")
                DispatchQueue.main.async { [weak self] in
                    self?.onHotkeyAction?(action)
                }
                return
            }
        }
    }

    // MARK: - Binding Management

    /// Updates the key combo for a specific action.
    func setBinding(_ combo: KeyCombo, for action: HotkeyAction) {
        bindings[action] = combo
        logger.info("Updated binding for \(action.rawValue): keyCode=\(combo.keyCode)")
    }

    /// Resets all bindings to their defaults.
    func resetToDefaults() {
        bindings = Self.defaultBindings
        logger.info("Hotkey bindings reset to defaults")
    }
}
