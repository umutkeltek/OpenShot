import Foundation

enum CaptureMode: String, CaseIterable, Sendable {
    case area
    case window
    case fullscreen
    case scrolling

    var displayName: String {
        switch self {
        case .area:
            return "Capture Area"
        case .window:
            return "Capture Window"
        case .fullscreen:
            return "Capture Fullscreen"
        case .scrolling:
            return "Scrolling Capture"
        }
    }

    var systemImageName: String {
        switch self {
        case .area:
            return "rectangle.dashed"
        case .window:
            return "macwindow"
        case .fullscreen:
            return "rectangle.inset.filled"
        case .scrolling:
            return "arrow.up.and.down.text.horizontal"
        }
    }
}
