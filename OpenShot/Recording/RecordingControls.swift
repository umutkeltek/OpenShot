// RecordingControls.swift
// OpenShot
//
// Floating recording toolbar that displays a pulsing red indicator,
// an elapsed-time counter, and pause/stop controls. Presented as
// a non-activating NSPanel positioned at the top-center of the
// primary display during an active screen recording session.

import SwiftUI
import AppKit
import os

// MARK: - RecordingControlsView

struct RecordingControlsView: View {
    @Bindable var recorder: ScreenRecorder
    var onStop: () -> Void
    var onRestart: (() -> Void)?

    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 16) {
            // Pulsing red recording indicator
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(recorder.isPaused ? 0.4 : pulseOpacity)
                .animation(
                    recorder.isPaused
                        ? .default
                        : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: pulseOpacity
                )
                .onAppear {
                    pulseOpacity = 0.3
                }

            // Timer display
            Text(formatTime(recorder.elapsedTime))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(minWidth: 52, alignment: .leading)

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.3))

            // Pause / Resume button
            Button {
                if recorder.isPaused {
                    recorder.resumeRecording()
                } else {
                    recorder.pauseRecording()
                }
            } label: {
                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(recorder.isPaused ? "Resume Recording" : "Pause Recording")

            // Restart button
            if let onRestart {
                Button(action: onRestart) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Restart Recording")
            }

            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Stop Recording")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        )
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = max(0, Int(time))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - RecordingControlsPanel

/// Manages a floating `NSPanel` that hosts `RecordingControlsView`.
/// Show it when recording starts, dismiss when recording stops.
final class RecordingControlsPanel {

    private let logger = Logger(subsystem: "com.openshot", category: "recording-controls")
    private var panel: NSPanel?

    /// Show the recording controls toolbar at the top-center of the screen.
    @MainActor
    func show(recorder: ScreenRecorder, onStop: @escaping () -> Void, onRestart: (() -> Void)? = nil) {
        // Dismiss any existing panel first
        dismiss()

        let view = RecordingControlsView(recorder: recorder, onStop: onStop, onRestart: onRestart)
        let hostingView = NSHostingView(rootView: view)

        // Measure the intrinsic content size
        let fittingSize = hostingView.fittingSize
        let panelWidth = max(fittingSize.width, 240)
        let panelHeight = max(fittingSize.height, 44)

        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        let controlPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        controlPanel.contentView = hostingView
        controlPanel.level = .floating
        controlPanel.isOpaque = false
        controlPanel.backgroundColor = .clear
        controlPanel.hasShadow = false
        controlPanel.isMovableByWindowBackground = true
        controlPanel.hidesOnDeactivate = false
        controlPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position at top-center of the screen containing the cursor
        if let screen = ScreenInfo.screenContainingCursor() ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let originX = screenFrame.midX - panelWidth / 2
            let originY = screenFrame.maxY - panelHeight - 12
            controlPanel.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        controlPanel.orderFrontRegardless()
        self.panel = controlPanel

        logger.info("Recording controls panel shown")
    }

    /// Dismiss and release the recording controls panel.
    @MainActor
    func dismiss() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        logger.info("Recording controls panel dismissed")
    }
}
