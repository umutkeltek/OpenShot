// KeystrokeVisualizer.swift
// OpenShot
//
// Shows pressed keys in a floating pill at bottom-center of screen.

import AppKit
import SwiftUI
import os

class KeystrokeVisualizer {
    private let logger = Logger(subsystem: "com.openshot", category: "keystroke-viz")
    private var monitor: Any?
    private var panel: NSPanel?
    private var displayTimer: Timer?
    var isActive = false

    @MainActor
    func start() {
        guard !isActive else { return }
        isActive = true

        // Create floating pill panel at bottom-center
        let panelSize = NSSize(width: 300, height: 44)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: panelSize),
                       styleMask: [.nonactivatingPanel, .borderless],
                       backing: .buffered, defer: false)
        p.level = .screenSaver
        p.backgroundColor = .clear
        p.isOpaque = false
        p.ignoresMouseEvents = true
        p.hasShadow = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let screen = NSScreen.main {
            p.setFrameOrigin(NSPoint(
                x: screen.frame.midX - panelSize.width / 2,
                y: screen.visibleFrame.minY + 40
            ))
        }

        self.panel = p

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        logger.info("Keystroke visualizer started")
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        displayTimer?.invalidate()
        displayTimer = nil
        panel?.close()
        panel = nil
        isActive = false
        logger.info("Keystroke visualizer stopped")
    }

    private func handleKeyEvent(_ event: NSEvent) {
        var parts: [String] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) { parts.append("\u{2303}") }
        if flags.contains(.option) { parts.append("\u{2325}") }
        if flags.contains(.shift) { parts.append("\u{21E7}") }
        if flags.contains(.command) { parts.append("\u{2318}") }

        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            parts.append(chars.uppercased())
        }

        let keystroke = parts.joined()

        DispatchQueue.main.async { [weak self] in
            self?.showKeystroke(keystroke)
        }
    }

    @MainActor
    private func showKeystroke(_ text: String) {
        guard let panel = panel else { return }

        let hostingView = NSHostingView(rootView:
            Text(text)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
        )
        hostingView.frame = panel.frame.insetBy(dx: 0, dy: 0)
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)

        panel.setContentSize(fittingSize)
        panel.contentView = hostingView
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        // Reposition center-bottom
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(
                x: screen.frame.midX - fittingSize.width / 2,
                y: screen.visibleFrame.minY + 40
            ))
        }

        // Auto-hide after 1.5 seconds
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    self?.panel?.animator().alphaValue = 0
                }
            }
        }
    }
}
