// AllInOnePanel.swift
// OpenShot
//
// Floating panel showing all capture/record modes in one place.
// Like CleanShot X's All-in-One mode.

import SwiftUI
import AppKit
import os

// MARK: - AllInOneAction

enum AllInOneAction: String, CaseIterable, Identifiable {
    case captureArea, captureWindow, captureFullscreen, scrollingCapture
    case recordScreen, recordGIF, ocrText

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .captureArea: "Capture Area"
        case .captureWindow: "Capture Window"
        case .captureFullscreen: "Fullscreen"
        case .scrollingCapture: "Scrolling"
        case .recordScreen: "Record Screen"
        case .recordGIF: "Record GIF"
        case .ocrText: "OCR Text"
        }
    }

    var systemImage: String {
        switch self {
        case .captureArea: "rectangle.dashed"
        case .captureWindow: "macwindow"
        case .captureFullscreen: "rectangle.inset.filled"
        case .scrollingCapture: "arrow.up.and.down.text.horizontal"
        case .recordScreen: "record.circle"
        case .recordGIF: "photo.stack"
        case .ocrText: "text.viewfinder"
        }
    }

    var shortcutHint: String {
        switch self {
        case .captureArea: "⇧⌘4"
        case .captureWindow: "⇧⌘5"
        case .captureFullscreen: "⇧⌘3"
        case .scrollingCapture: "⇧⌘6"
        case .recordScreen: "⇧⌘R"
        case .recordGIF: "⇧⌘G"
        case .ocrText: "⇧⌘T"
        }
    }
}

// MARK: - AllInOnePanel

class AllInOnePanel {
    private static let logger = Logger(subsystem: "com.openshot", category: "all-in-one")
    private static var panel: NSPanel?
    private static var escapeMonitor: Any?

    @MainActor
    static func toggle() {
        if panel != nil {
            dismiss()
        } else {
            show()
        }
    }

    @MainActor
    static func show() {
        dismiss() // close any existing

        let view = AllInOneView(onAction: { action in
            dismiss()
            handleAction(action)
        }, onDismiss: {
            dismiss()
        })

        let hostingView = NSHostingView(rootView: view)
        let size = NSSize(width: 320, height: 280)
        hostingView.frame = NSRect(origin: .zero, size: size)

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .titled, .closable, .hudWindow],
            backing: .buffered, defer: false
        )
        p.title = "OpenShot — Capture Modes"
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.contentView = hostingView
        p.hidesOnDeactivate = false
        p.center()
        p.makeKeyAndOrderFront(nil)

        // Monitor for Escape to dismiss
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                dismiss()
                return nil
            }
            return event
        }

        self.panel = p
        logger.info("All-in-one panel shown")
    }

    @MainActor
    static func dismiss() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
        panel?.close()
        panel = nil
        logger.info("All-in-one panel dismissed")
    }

    private static func handleAction(_ action: AllInOneAction) {
        switch action {
        case .captureArea:
            NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.area])
        case .captureWindow:
            NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.window])
        case .captureFullscreen:
            NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.fullscreen])
        case .scrollingCapture:
            NotificationCenter.default.post(name: .initCapture, object: nil, userInfo: ["mode": CaptureMode.scrolling])
        case .recordScreen:
            NotificationCenter.default.post(name: .initRecordScreen, object: nil)
        case .recordGIF:
            NotificationCenter.default.post(name: .initRecordGIF, object: nil)
        case .ocrText:
            NotificationCenter.default.post(name: .initOCRCapture, object: nil)
        }
    }
}

// MARK: - AllInOneView (SwiftUI)

struct AllInOneView: View {
    let onAction: (AllInOneAction) -> Void
    let onDismiss: () -> Void

    let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("OpenShot")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Grid of action buttons
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AllInOneAction.allCases) { action in
                    AllInOneButton(action: action) {
                        onAction(action)
                    }
                }
            }

            // Escape hint
            Text("Press Esc to close")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding()
    }
}

private struct AllInOneButton: View {
    let action: AllInOneAction
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 24))
                    .frame(height: 30)
                Text(action.displayName)
                    .font(.caption)
                    .lineLimit(1)
                Text(action.shortcutHint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 85, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.accentColor.opacity(0.15) : Color(.controlBackgroundColor))
            )
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
