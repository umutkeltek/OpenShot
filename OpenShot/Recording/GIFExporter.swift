// GIFExporter.swift
// OpenShot
//
// Convert captured frames to an animated GIF file using ImageIO,
// and a companion GIFRecorder that captures screen frames at a
// lower FPS using CGWindowListCreateImage for lightweight GIF
// creation without the overhead of SCStream.

import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import os

// MARK: - GIFExporter

/// Encodes an array of CGImage frames into an animated GIF file.
final class GIFExporter {

    private let logger = Logger(subsystem: "com.openshot", category: "gif")

    /// A single frame in the GIF animation.
    struct GIFFrame {
        let image: CGImage
        let delay: TimeInterval
    }

    /// Export an array of frames to an animated GIF at the given URL.
    /// - Parameters:
    ///   - frames: The frames to encode, each with an associated delay.
    ///   - url: The destination file URL.
    ///   - maxWidth: Maximum pixel width; frames wider than this are downscaled.
    ///   - loopCount: Number of loops (0 = infinite).
    func export(frames: [GIFFrame], to url: URL, maxWidth: CGFloat = 640, loopCount: Int = 0) throws {
        guard !frames.isEmpty else {
            throw OpenShotError.gifExportFailed("No frames to export")
        }

        // Create the image destination
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw OpenShotError.gifExportFailed("Failed to create image destination at \(url.path)")
        }

        // Set global GIF properties (loop count)
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loopCount,
            ],
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        // Add each frame
        for (index, frame) in frames.enumerated() {
            let resized = resizeImage(frame.image, maxWidth: maxWidth)

            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: frame.delay,
                    kCGImagePropertyGIFUnclampedDelayTime as String: frame.delay,
                ],
            ]

            CGImageDestinationAddImage(destination, resized, frameProperties as CFDictionary)

            if index % 50 == 0 {
                logger.debug("GIF encoding progress: frame \(index)/\(frames.count)")
            }
        }

        // Finalize the GIF file
        guard CGImageDestinationFinalize(destination) else {
            throw OpenShotError.gifExportFailed("Failed to finalize GIF file")
        }

        logger.info("GIF exported: \(frames.count) frames to \(url.path)")
    }

    /// Export frames from a video file URL by sampling at the given FPS.
    /// - Parameters:
    ///   - videoURL: Source video file.
    ///   - outputURL: Destination GIF file.
    ///   - fps: Frames per second to sample from the video.
    ///   - maxWidth: Maximum pixel width for the GIF.
    func exportFromVideo(_ videoURL: URL, to outputURL: URL, fps: Double = 10, maxWidth: CGFloat = 640) async throws {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = duration.seconds

        guard durationSeconds > 0 else {
            throw OpenShotError.gifExportFailed("Video has zero duration")
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        let frameInterval = 1.0 / fps
        var frames: [GIFFrame] = []
        var time: Double = 0

        while time < durationSeconds {
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            do {
                let (image, _) = try await generator.image(at: cmTime)
                frames.append(GIFFrame(image: image, delay: frameInterval))
            } catch {
                logger.warning("Failed to generate frame at \(time)s: \(error.localizedDescription)")
            }
            time += frameInterval
        }

        try export(frames: frames, to: outputURL, maxWidth: maxWidth)
    }

    // MARK: - Image Resizing

    private func resizeImage(_ image: CGImage, maxWidth: CGFloat) -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        guard width > maxWidth else { return image }

        let scale = maxWidth / width
        let newWidth = Int(width * scale)
        let newHeight = Int(height * scale)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            logger.warning("Failed to create resize context; returning original image")
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context.makeImage() ?? image
    }
}

// MARK: - GIFRecorder

/// Real-time screen capture to GIF. Uses CGWindowListCreateImage at a
/// lower frame rate (default 10 FPS) to capture frames directly, then
/// exports them via `GIFExporter`. Lighter weight than using SCStream
/// for situations where GIF-quality output is sufficient.
@Observable
final class GIFRecorder {

    private let logger = Logger(subsystem: "com.openshot", category: "gif-recorder")

    // MARK: - Observable State

    var isRecording = false
    var elapsedTime: TimeInterval = 0
    var frameCount: Int = 0

    // MARK: - Private Properties

    private var frames: [GIFExporter.GIFFrame] = []
    private var captureTimer: DispatchSourceTimer?
    private var elapsedTimeTimer: Timer?
    private var startDate: Date?
    private let fps: Double = 10
    private var captureRect: CGRect?
    private let captureQueue = DispatchQueue(label: "com.openshot.gif-capture", qos: .userInitiated)

    // MARK: - Start Capture

    /// Begin capturing frames within the specified rectangle.
    /// The rectangle should be in CoreGraphics screen coordinates (top-left origin).
    func startCapture(rect: CGRect) {
        guard !isRecording else {
            logger.warning("GIF capture already in progress")
            return
        }

        isRecording = true
        captureRect = rect
        startDate = Date()
        frames = []
        frameCount = 0
        elapsedTime = 0

        logger.info("GIF capture started: \(Int(rect.width))x\(Int(rect.height)) @ \(self.fps) FPS")

        // Use a DispatchSourceTimer for precise frame timing
        let timer = DispatchSource.makeTimerSource(queue: captureQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / fps, leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in
            self?.captureFrame()
        }
        timer.resume()
        captureTimer = timer

        // UI timer for elapsed time updates
        startElapsedTimeUpdates()
    }

    // MARK: - Stop Capture

    /// Stop capturing and export all collected frames to an animated GIF.
    /// Returns the URL of the exported GIF file.
    func stopCapture() async throws -> URL {
        // Always cancel timers first, regardless of state
        captureTimer?.cancel()
        captureTimer = nil
        stopElapsedTimeUpdates()

        guard isRecording else {
            throw OpenShotError.gifExportFailed("No GIF capture in progress")
        }

        isRecording = false

        let capturedFrames = frames
        frames = []

        guard !capturedFrames.isEmpty else {
            throw OpenShotError.gifExportFailed("No frames were captured")
        }

        logger.info("GIF capture stopped: \(capturedFrames.count) frames captured")

        // Export to GIF
        let exporter = GIFExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenShot_\(Int(Date().timeIntervalSince1970)).gif")

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        try exporter.export(frames: capturedFrames, to: outputURL)

        // Reset state
        await MainActor.run {
            self.frameCount = 0
            self.elapsedTime = 0
        }

        return outputURL
    }

    // MARK: - Frame Capture

    /// Maximum GIF width — downsample immediately on capture to limit memory.
    private let maxCaptureWidth: CGFloat = 640

    private func captureFrame() {
        guard let rect = captureRect, isRecording else { return }

        // CGWindowListCreateImage captures the screen content within the given rect
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            logger.debug("Failed to capture frame")
            return
        }

        // Downsample immediately to limit memory usage
        let downsampledImage = downsampleIfNeeded(cgImage)
        let frame = GIFExporter.GIFFrame(image: downsampledImage, delay: 1.0 / fps)
        frames.append(frame)

        DispatchQueue.main.async { [weak self] in
            self?.frameCount = self?.frames.count ?? 0
        }
    }

    private func downsampleIfNeeded(_ image: CGImage) -> CGImage {
        let width = CGFloat(image.width)
        guard width > maxCaptureWidth else { return image }
        let scale = maxCaptureWidth / width
        let newWidth = Int(width * scale)
        let newHeight = Int(CGFloat(image.height) * scale)
        guard let context = CGContext(
            data: nil, width: newWidth, height: newHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return image }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
    }

    // MARK: - Elapsed Time

    private func startElapsedTimeUpdates() {
        elapsedTimeTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRecording else { return }
            self.elapsedTimeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                guard self.isRecording else {
                    timer.invalidate()
                    return
                }
                if let start = self.startDate {
                    self.elapsedTime = Date().timeIntervalSince(start)
                }
            }
        }
    }

    private func stopElapsedTimeUpdates() {
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = nil
    }
}
