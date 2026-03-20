// VideoEditor.swift
// OpenShot
//
// Basic video trim editor using AVFoundation. Presents a SwiftUI view
// with an AVPlayer preview, dual-handle trim slider, and an export
// button that uses AVAssetExportSession to produce a trimmed MP4.

import AVFoundation
import AVKit
import AppKit
import SwiftUI
import os

// MARK: - VideoEditorView

struct VideoEditorView: View {
    let videoURL: URL
    var onExportComplete: ((URL) -> Void)?

    @State private var player: AVPlayer?
    @State private var duration: Double = 1.0
    @State private var startTime: Double = 0
    @State private var endTime: Double = 1.0
    @State private var currentTime: Double = 0
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var boundaryObserver: Any?
    @Environment(\.dismiss) var dismiss

    private let logger = Logger(subsystem: "com.openshot", category: "video-editor")

    var body: some View {
        VStack(spacing: 16) {
            // Video preview
            VideoPlayerView(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Trim range display
            HStack {
                Text("Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatTime(startTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                Spacer()

                Text("Duration: \(formatTime(endTime - startTime))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("End")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatTime(endTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .padding(.horizontal, 4)

            // Start trim slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Trim Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $startTime, in: 0...max(duration, 0.01)) { editing in
                    if !editing {
                        seekToTime(startTime)
                    }
                }
                .onChange(of: startTime) { _, newValue in
                    if newValue > endTime - 0.1 {
                        startTime = max(0, endTime - 0.1)
                    }
                    seekToTime(newValue)
                }
            }

            // End trim slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Trim End")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $endTime, in: 0...max(duration, 0.01)) { editing in
                    if !editing {
                        seekToTime(endTime)
                    }
                }
                .onChange(of: endTime) { _, newValue in
                    if newValue < startTime + 0.1 {
                        endTime = min(duration, startTime + 0.1)
                    }
                    seekToTime(newValue)
                }
            }

            // Playback controls
            HStack(spacing: 16) {
                Button {
                    seekToTime(startTime)
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .buttonStyle(.plain)

                Button {
                    playPreview()
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.plain)

                Button {
                    player?.pause()
                } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(.plain)

                Button {
                    seekToTime(endTime)
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 16))

            // Error display
            if let error = exportError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Action buttons
            HStack {
                Button("Cancel") {
                    player?.pause()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Exporting...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Export Trimmed") {
                    Task {
                        await trimAndExport()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting || (endTime - startTime) < 0.1)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 640, height: 520)
        .task {
            await loadVideo()
        }
        .onDisappear {
            player?.pause()
        }
    }

    // MARK: - Video Loading

    private func loadVideo() async {
        let asset = AVAsset(url: videoURL)
        do {
            let loadedDuration = try await asset.load(.duration)
            let durationSeconds = loadedDuration.seconds
            await MainActor.run {
                self.duration = durationSeconds
                self.endTime = durationSeconds
                self.player = AVPlayer(url: videoURL)
                self.player?.volume = 1.0
            }
            logger.info("Video loaded: \(durationSeconds)s duration")
        } catch {
            logger.error("Failed to load video duration: \(error.localizedDescription)")
            await MainActor.run {
                self.player = AVPlayer(url: videoURL)
            }
        }
    }

    // MARK: - Playback

    private func seekToTime(_ time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func playPreview() {
        // Remove previous observer to avoid accumulation
        if let observer = boundaryObserver {
            player?.removeTimeObserver(observer)
            boundaryObserver = nil
        }

        seekToTime(startTime)
        player?.play()

        // Set up a boundary observer to pause at end time
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
        let endValue = NSValue(time: endCMTime)
        boundaryObserver = player?.addBoundaryTimeObserver(forTimes: [endValue], queue: .main) { [weak player] in
            player?.pause()
        }
    }

    // MARK: - Trim & Export

    private func trimAndExport() async {
        isExporting = true
        exportError = nil

        let asset = AVAsset(url: videoURL)
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            await MainActor.run {
                exportError = "Failed to create export session"
                isExporting = false
            }
            return
        }

        let outputFileName = "OpenShot_Trimmed_\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(outputFileName)

        // Remove existing file if any
        try? FileManager.default.removeItem(at: outputURL)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = timeRange

        await exportSession.export()

        await MainActor.run {
            isExporting = false

            switch exportSession.status {
            case .completed:
                logger.info("Trimmed video exported to \(outputURL.path)")
                onExportComplete?(outputURL)
                dismiss()

            case .failed:
                let errorDesc = exportSession.error?.localizedDescription ?? "Unknown error"
                logger.error("Export failed: \(errorDesc)")
                exportError = "Export failed: \(errorDesc)"

            case .cancelled:
                logger.info("Export cancelled")
                exportError = "Export was cancelled"

            default:
                exportError = "Unexpected export status"
            }
        }
    }

    // MARK: - Formatting

    private func formatTime(_ t: Double) -> String {
        let clamped = max(0, t)
        let totalSeconds = Int(clamped)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let fraction = Int((clamped - Double(totalSeconds)) * 10)
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%d", hours, minutes, seconds, fraction)
        }
        return String(format: "%02d:%02d.%d", minutes, seconds, fraction)
    }
}

// MARK: - VideoPlayerView (NSViewRepresentable)

/// Wraps AVPlayerView for use inside SwiftUI.
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .none
        playerView.player = player
        playerView.videoGravity = .resizeAspect
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

// MARK: - VideoEditorWindow

/// Convenience to present the video editor in its own window.
final class VideoEditorWindow {

    private static let logger = Logger(subsystem: "com.openshot", category: "video-editor-window")

    @MainActor
    static func show(videoURL: URL, onExportComplete: ((URL) -> Void)? = nil) {
        let editorView = VideoEditorView(videoURL: videoURL, onExportComplete: onExportComplete)
        let hostingView = NSHostingView(rootView: editorView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenShot - Video Editor"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false

        logger.info("Video editor window presented for \(videoURL.lastPathComponent)")
    }
}
