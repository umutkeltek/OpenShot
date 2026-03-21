// ToastView.swift
// OpenShot
//
// Lightweight toast notification that briefly appears and auto-dismisses.
// Used to confirm user actions like copy, save, and OCR completion.

import SwiftUI
import AppKit

// MARK: - ToastManager

@MainActor
enum ToastManager {

    private static var activePanel: NSPanel?
    private static var dismissTask: Task<Void, Never>?

    /// Show a toast notification at the top-center of the screen.
    /// Auto-dismisses after `duration` seconds.
    static func show(icon: String, message: String, detail: String? = nil, duration: TimeInterval = 2.0) {
        // Dismiss any existing toast first.
        dismissCurrent()

        let toastView = ToastContentView(icon: icon, message: message, detail: detail)
        let hostingView = NSHostingView(rootView: toastView)
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView

        // Position at top-center of the main screen.
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let originX = visibleFrame.midX - fittingSize.width / 2
            let originY = visibleFrame.maxY - fittingSize.height - 48
            panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // Fade in.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1.0
        }

        activePanel = panel

        // Schedule auto-dismiss.
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            dismissCurrent()
        }
    }

    private static func dismissCurrent() {
        dismissTask?.cancel()
        dismissTask = nil

        guard let panel = activePanel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.close()
        })
        activePanel = nil
    }
}

// MARK: - ToastContentView

private struct ToastContentView: View {
    let icon: String
    let message: String
    let detail: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 13, weight: .medium))

                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
