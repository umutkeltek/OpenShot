// SelfTimerOverlay.swift
// OpenShot
//
// Transparent fullscreen overlay that shows a countdown (3, 2, 1)
// before triggering a capture. Used when the user enables the
// self-timer feature to give time to arrange the screen.

import AppKit
import os

// MARK: - SelfTimerOverlay

class SelfTimerOverlay {

    private static let logger = Logger(subsystem: "com.openshot", category: "self-timer")

    /// Show a countdown overlay then return when the countdown reaches zero.
    /// - Parameter seconds: number of seconds to count down (e.g. 3 or 5)
    @MainActor
    static func present(seconds: Int) async {
        guard seconds > 0 else { return }
        logger.info("Self-timer countdown starting: \(seconds) seconds")

        // 1. Create a borderless, transparent window covering the main screen.
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 2. Create the countdown view and install it.
        let countdownView = CountdownView(frame: NSRect(origin: .zero, size: screenFrame.size))
        countdownView.currentNumber = seconds
        window.contentView = countdownView
        window.makeKeyAndOrderFront(nil)

        // 3. Animate the countdown.
        for number in stride(from: seconds, through: 1, by: -1) {
            countdownView.currentNumber = number
            countdownView.needsDisplay = true
            logger.debug("Countdown: \(number)")
            try? await Task.sleep(for: .seconds(1))
        }

        // 4. Close the overlay window.
        window.orderOut(nil)
        logger.info("Self-timer countdown completed")
    }
}

// MARK: - CountdownView

/// Custom `NSView` that draws a large countdown number centered
/// inside a semi-transparent dark circle.
class CountdownView: NSView {

    var currentNumber: Int = 3

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // --- Semi-transparent dark circle ---
        let circleSize: CGFloat = 200
        let circleRect = CGRect(
            x: bounds.midX - circleSize / 2,
            y: bounds.midY - circleSize / 2,
            width: circleSize,
            height: circleSize
        )
        context.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        context.fillEllipse(in: circleRect)

        // --- Large white number ---
        let text = "\(currentNumber)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 120, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        let textOrigin = CGPoint(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2
        )
        text.draw(at: textOrigin, withAttributes: attributes)
    }
}
