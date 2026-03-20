import AppKit
import CoreGraphics
import os

struct ScreenInfo {

    private static let logger = Logger(subsystem: "com.openshot.app", category: "ScreenInfo")

    /// Returns the NSScreen that currently contains the mouse cursor,
    /// or `nil` if the cursor is not on any screen.
    static func screenContainingCursor() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }
        logger.warning("No screen found containing cursor at \(mouseLocation.x), \(mouseLocation.y)")
        return NSScreen.main
    }

    /// Returns an array of frames for all connected screens.
    /// Frames are in the global display coordinate system.
    static func allScreenFrames() -> [CGRect] {
        return NSScreen.screens.map { $0.frame }
    }

    /// Returns the combined bounding rectangle that encompasses all connected screens.
    /// This is the union of all individual screen frames.
    static func combinedScreenFrame() -> CGRect {
        let frames = allScreenFrames()
        guard let first = frames.first else {
            logger.warning("No screens available for combined frame calculation")
            return .zero
        }
        return frames.dropFirst().reduce(first) { result, frame in
            result.union(frame)
        }
    }

    /// Returns the CGDirectDisplayID for a given NSScreen.
    /// This is needed for ScreenCaptureKit and other CoreGraphics display APIs.
    static func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            logger.error("Could not extract display ID from screen device description")
            return CGMainDisplayID()
        }
        return screenNumber.uint32Value
    }
}
