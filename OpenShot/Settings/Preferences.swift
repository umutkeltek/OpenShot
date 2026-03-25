import Foundation
import SwiftUI
import os

@Observable
final class Preferences {

    // MARK: - Singleton

    static let shared = Preferences()

    // MARK: - Keys

    private enum Keys {
        static let saveLocation = "pref_saveLocation"
        static let imageFormat = "pref_imageFormat"
        static let jpegQuality = "pref_jpegQuality"
        static let showCrosshair = "pref_showCrosshair"
        static let showMagnifier = "pref_showMagnifier"
        static let freezeScreen = "pref_freezeScreen"
        static let includeCursor = "pref_includeCursor"
        static let windowShadow = "pref_windowShadow"
        static let windowPadding = "pref_windowPadding"
        static let windowBackground = "pref_windowBackground"
        static let selfTimerDuration = "pref_selfTimerDuration"
        static let captureSound = "pref_captureSound"
        static let overlayPosition = "pref_overlayPosition"
        static let overlayAutoCloseDelay = "pref_overlayAutoCloseDelay"
        static let recordingFPS = "pref_recordingFPS"
        static let recordingResolution = "pref_recordingResolution"
        static let showClicks = "pref_showClicks"
        static let showKeystrokes = "pref_showKeystrokes"
        static let historyRetentionDays = "pref_historyRetentionDays"
        static let launchAtLogin = "pref_launchAtLogin"
        static let playRecordingSounds = "pref_playRecordingSounds"
        static let hideDesktopIconsDuringCapture = "pref_hideDesktopIconsDuringCapture"
        static let fileNamingTemplate = "pref_fileNamingTemplate"
    }

    // MARK: - Nested Enums

    enum ImageFormat: String, CaseIterable, Sendable {
        case png
        case jpeg
        case tiff
        case webp
        case heic

        var fileExtension: String { rawValue }

        var utType: String {
            switch self {
            case .png: return "public.png"
            case .jpeg: return "public.jpeg"
            case .tiff: return "public.tiff"
            case .webp: return "org.webmproject.webp"
            case .heic: return "public.heic"
            }
        }
    }

    enum WindowBackground: String, CaseIterable, Sendable {
        case none
        case desktop
        case solid
        case gradient
    }

    enum OverlayPosition: String, CaseIterable, Sendable {
        case bottomRight
        case bottomLeft
        case topRight
        case topLeft

        var displayName: String {
            switch self {
            case .bottomRight: return "Bottom Right"
            case .bottomLeft: return "Bottom Left"
            case .topRight: return "Top Right"
            case .topLeft: return "Top Left"
            }
        }
    }

    enum RecordingResolution: String, CaseIterable, Sendable {
        case native
        case half

        var displayName: String {
            switch self {
            case .native: return "Native"
            case .half: return "Half"
            }
        }

        var scaleFactor: CGFloat {
            switch self {
            case .native: return 1.0
            case .half: return 0.5
            }
        }
    }

    // MARK: - Private Storage

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.openshot.app", category: "Preferences")

    // MARK: - Properties

    var saveLocation: URL {
        get {
            if let data = defaults.data(forKey: Keys.saveLocation),
               let url = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: data) as URL? {
                return url
            }
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Desktop")
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue as NSURL, requiringSecureCoding: true) {
                defaults.set(data, forKey: Keys.saveLocation)
            }
            logger.debug("Save location updated to \(newValue.path(percentEncoded: false))")
        }
    }

    var imageFormat: ImageFormat {
        get {
            if let raw = defaults.string(forKey: Keys.imageFormat),
               let format = ImageFormat(rawValue: raw) {
                return format
            }
            return .png
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.imageFormat)
        }
    }

    var jpegQuality: Double {
        get {
            let value = defaults.double(forKey: Keys.jpegQuality)
            return value > 0 ? value : 0.8
        }
        set {
            defaults.set(newValue, forKey: Keys.jpegQuality)
        }
    }

    var showCrosshair: Bool {
        get {
            if defaults.object(forKey: Keys.showCrosshair) == nil { return true }
            return defaults.bool(forKey: Keys.showCrosshair)
        }
        set {
            defaults.set(newValue, forKey: Keys.showCrosshair)
        }
    }

    var showMagnifier: Bool {
        get {
            if defaults.object(forKey: Keys.showMagnifier) == nil { return true }
            return defaults.bool(forKey: Keys.showMagnifier)
        }
        set {
            defaults.set(newValue, forKey: Keys.showMagnifier)
        }
    }

    var freezeScreen: Bool {
        get { defaults.bool(forKey: Keys.freezeScreen) }
        set { defaults.set(newValue, forKey: Keys.freezeScreen) }
    }

    var includeCursor: Bool {
        get { defaults.bool(forKey: Keys.includeCursor) }
        set { defaults.set(newValue, forKey: Keys.includeCursor) }
    }

    var windowShadow: Bool {
        get {
            if defaults.object(forKey: Keys.windowShadow) == nil { return true }
            return defaults.bool(forKey: Keys.windowShadow)
        }
        set {
            defaults.set(newValue, forKey: Keys.windowShadow)
        }
    }

    var windowPadding: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.windowPadding)) }
        set { defaults.set(Double(newValue), forKey: Keys.windowPadding) }
    }

    var windowBackground: WindowBackground {
        get {
            if let raw = defaults.string(forKey: Keys.windowBackground),
               let bg = WindowBackground(rawValue: raw) {
                return bg
            }
            return .none
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.windowBackground)
        }
    }

    var hideDesktopIconsDuringCapture: Bool {
        get { defaults.bool(forKey: Keys.hideDesktopIconsDuringCapture) }
        set { defaults.set(newValue, forKey: Keys.hideDesktopIconsDuringCapture) }
    }

    /// Self-timer countdown duration in seconds (0 = disabled, 3 or 5 typical).
    var selfTimerDuration: Int {
        get {
            let value = defaults.integer(forKey: Keys.selfTimerDuration)
            return value > 0 ? value : 3
        }
        set {
            defaults.set(newValue, forKey: Keys.selfTimerDuration)
        }
    }

    var captureSound: Bool {
        get {
            if defaults.object(forKey: Keys.captureSound) == nil { return true }
            return defaults.bool(forKey: Keys.captureSound)
        }
        set {
            defaults.set(newValue, forKey: Keys.captureSound)
        }
    }

    var overlayPosition: OverlayPosition {
        get {
            if let raw = defaults.string(forKey: Keys.overlayPosition),
               let pos = OverlayPosition(rawValue: raw) {
                return pos
            }
            return .bottomRight
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.overlayPosition)
        }
    }

    var overlayAutoCloseDelay: TimeInterval {
        get {
            if defaults.object(forKey: Keys.overlayAutoCloseDelay) == nil {
                return 5.0
            }
            return defaults.double(forKey: Keys.overlayAutoCloseDelay)
        }
        set {
            defaults.set(newValue, forKey: Keys.overlayAutoCloseDelay)
        }
    }

    var recordingFPS: Int {
        get {
            let value = defaults.integer(forKey: Keys.recordingFPS)
            return value > 0 ? value : 30
        }
        set {
            defaults.set(newValue, forKey: Keys.recordingFPS)
        }
    }

    var recordingResolution: RecordingResolution {
        get {
            if let raw = defaults.string(forKey: Keys.recordingResolution),
               let res = RecordingResolution(rawValue: raw) {
                return res
            }
            return .native
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.recordingResolution)
        }
    }

    var showClicks: Bool {
        get { defaults.bool(forKey: Keys.showClicks) }
        set { defaults.set(newValue, forKey: Keys.showClicks) }
    }

    var showKeystrokes: Bool {
        get { defaults.bool(forKey: Keys.showKeystrokes) }
        set { defaults.set(newValue, forKey: Keys.showKeystrokes) }
    }

    var historyRetentionDays: Int {
        get {
            let value = defaults.integer(forKey: Keys.historyRetentionDays)
            return value > 0 ? value : 30
        }
        set {
            defaults.set(newValue, forKey: Keys.historyRetentionDays)
        }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    var playRecordingSounds: Bool {
        get {
            if defaults.object(forKey: Keys.playRecordingSounds) == nil { return true }
            return defaults.bool(forKey: Keys.playRecordingSounds)
        }
        set {
            defaults.set(newValue, forKey: Keys.playRecordingSounds)
        }
    }

    var fileNamingTemplate: String {
        get {
            defaults.string(forKey: Keys.fileNamingTemplate) ?? FileNamer.defaultTemplate
        }
        set {
            defaults.set(newValue, forKey: Keys.fileNamingTemplate)
        }
    }

    // MARK: - Init

    private init() {
        logger.info("Preferences initialized")
    }
}
