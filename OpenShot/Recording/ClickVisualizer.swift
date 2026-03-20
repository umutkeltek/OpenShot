// ClickVisualizer.swift
// OpenShot
//
// Shows an expanding, fading circle on every mouse click during recording.

import AppKit
import os

class ClickVisualizer {
    private let logger = Logger(subsystem: "com.openshot", category: "click-viz")
    private var monitor: Any?
    private var overlayWindows: [NSWindow] = []

    var clickColor: NSColor = .systemYellow
    var clickRadius: CGFloat = 30
    var isActive = false

    func start() {
        guard !isActive else { return }
        isActive = true

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.showClickAt(event.locationInWindow, screen: NSScreen.main)
        }
        logger.info("Click visualizer started")
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isActive = false
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()
        logger.info("Click visualizer stopped")
    }

    private func showClickAt(_ point: NSPoint, screen: NSScreen?) {
        // Get the global mouse location
        let mouseLocation = NSEvent.mouseLocation

        let size = clickRadius * 2
        let frame = NSRect(
            x: mouseLocation.x - clickRadius,
            y: mouseLocation.y - clickRadius,
            width: size,
            height: size
        )

        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.hasShadow = false

        let clickView = ClickAnimationView(frame: NSRect(origin: .zero, size: NSSize(width: size, height: size)))
        clickView.color = clickColor
        window.contentView = clickView
        window.orderFrontRegardless()

        overlayWindows.append(window)

        // Animate: expand and fade over 0.4 seconds
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
            let expanded = frame.insetBy(dx: -clickRadius * 0.5, dy: -clickRadius * 0.5)
            window.animator().setFrame(expanded, display: true)
        }, completionHandler: { [weak self] in
            window.close()
            self?.overlayWindows.removeAll { $0 == window }
        })
    }
}

class ClickAnimationView: NSView {
    var color: NSColor = .systemYellow

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
        color.withAlphaComponent(0.4).setFill()
        path.fill()
        color.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
