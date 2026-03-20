// ScreenRecorder.swift
// OpenShot
//
// SCStream-based screen recording to MP4. Manages the full lifecycle of
// a screen recording session: creating the content filter, configuring
// the SCStream, writing video/audio sample buffers through AVAssetWriter,
// and exposing observable state for the UI layer.

import ScreenCaptureKit
import AVFoundation
import AppKit
import os

@Observable
final class ScreenRecorder: NSObject, SCStreamOutput, @unchecked Sendable {

    // MARK: - Singleton

    static let shared = ScreenRecorder()

    // MARK: - Observable State

    var isRecording = false
    var isPaused = false
    var elapsedTime: TimeInterval = 0

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.openshot", category: "recorder")
    private let preferences = Preferences.shared

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var startTime: CMTime?
    private var sessionStarted = false
    private var timer: Timer?
    private var recordingStartDate: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartDate: Date?
    private var lastFilter: SCContentFilter?
    private var lastIncludeAudio: Bool = true

    private let clickVisualizer = ClickVisualizer()
    private let keystrokeVisualizer = KeystrokeVisualizer()

    // Serial queue for sample buffer processing
    private let bufferQueue = DispatchQueue(label: "com.openshot.recorder.buffer", qos: .userInteractive)

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Start Recording

    func startRecording(filter: SCContentFilter, includeAudio: Bool = true) async throws {
        guard !isRecording else { throw OpenShotError.recordingAlreadyInProgress }

        // Store filter and audio config for potential restart
        lastFilter = filter
        lastIncludeAudio = includeAudio

        // Create output URL in temporary directory
        let fileName = "OpenShot_Recording_\(Int(Date().timeIntervalSince1970)).mp4"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        outputURL = url

        // Remove any existing file at that path
        try? FileManager.default.removeItem(at: url)

        // Create AVAssetWriter
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            throw OpenShotError.assetWriterFailed("Failed to create AVAssetWriter: \(error.localizedDescription)")
        }

        // Determine dimensions from filter
        let scaleFactor = preferences.recordingResolution.scaleFactor
        let fps = preferences.recordingFPS
        let contentRect = filter.contentRect
        let pointsPerPixel = filter.pointPixelScale

        let pixelWidth = Int(contentRect.width * CGFloat(pointsPerPixel) * scaleFactor)
        let pixelHeight = Int(contentRect.height * CGFloat(pointsPerPixel) * scaleFactor)

        // Configure video input (H.264)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: pixelWidth * pixelHeight * 8,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ] as [String: Any],
        ]

        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true

        let sourcePixelAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: pixelWidth,
            kCVPixelBufferHeightKey as String: pixelHeight,
        ]
        let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: sourcePixelAttributes
        )

        guard writer.canAdd(vInput) else {
            throw OpenShotError.assetWriterFailed("Cannot add video input to asset writer")
        }
        writer.add(vInput)
        videoInput = vInput
        adaptor = pixelAdaptor

        // Configure audio input if requested
        if includeAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000,
            ]
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true

            if writer.canAdd(aInput) {
                writer.add(aInput)
                audioInput = aInput
            } else {
                logger.warning("Cannot add audio input to asset writer; recording without audio")
            }
        }

        // Start the asset writer
        guard writer.startWriting() else {
            let errorDesc = writer.error?.localizedDescription ?? "Unknown error"
            throw OpenShotError.assetWriterFailed("Failed to start writing: \(errorDesc)")
        }
        assetWriter = writer
        sessionStarted = false
        startTime = nil

        // Configure SCStream
        let config = SCStreamConfiguration()
        config.width = pixelWidth
        config.height = pixelHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.showsCursor = true
        config.capturesAudio = includeAudio
        config.pixelFormat = kCVPixelFormatType_32BGRA

        if includeAudio {
            config.sampleRate = 48000
            config.channelCount = 2
        }

        // Create and start SCStream
        let scStream = SCStream(filter: filter, configuration: config, delegate: nil)

        try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: bufferQueue)
        if includeAudio {
            try scStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: bufferQueue)
        }

        try await scStream.startCapture()
        stream = scStream

        // Update observable state on main actor
        await MainActor.run {
            self.isRecording = true
            self.isPaused = false
            self.elapsedTime = 0
            self.pausedDuration = 0
            self.pauseStartDate = nil
            self.recordingStartDate = Date()
            self.startElapsedTimer()
        }

        // Start visualizers if enabled
        if preferences.showClicks {
            await MainActor.run { clickVisualizer.start() }
        }
        if preferences.showKeystrokes {
            await MainActor.run { keystrokeVisualizer.start() }
        }

        // Enable DND during recording
        DNDManager.enableDND()

        logger.info("Recording started: \(pixelWidth)x\(pixelHeight) @ \(fps) FPS, audio: \(includeAudio)")
    }

    // MARK: - Pause / Resume

    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        pauseStartDate = Date()
        timer?.invalidate()
        timer = nil
        logger.info("Recording paused at \(self.elapsedTime)s")
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }
        if let pauseStart = pauseStartDate {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartDate = nil
        isPaused = false
        startElapsedTimer()
        logger.info("Recording resumed")
    }

    // MARK: - Stop Recording

    func stopRecording() async throws -> URL {
        guard isRecording else { throw OpenShotError.recordingNotInProgress }

        // Stop the SCStream
        if let scStream = stream {
            try await scStream.stopCapture()
        }
        stream = nil

        // Finish writing
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        guard let writer = assetWriter else {
            throw OpenShotError.assetWriterFailed("No asset writer available")
        }

        await writer.finishWriting()

        if writer.status == .failed {
            let errorDesc = writer.error?.localizedDescription ?? "Unknown error"
            throw OpenShotError.assetWriterFailed("Asset writer failed: \(errorDesc)")
        }

        guard let url = outputURL else {
            throw OpenShotError.assetWriterFailed("No output URL available")
        }

        // Stop visualizers and restore DND
        await MainActor.run {
            clickVisualizer.stop()
            keystrokeVisualizer.stop()
        }
        DNDManager.disableDND()

        // Reset state
        await MainActor.run {
            self.timer?.invalidate()
            self.timer = nil
            self.isRecording = false
            self.isPaused = false
            self.elapsedTime = 0
        }

        assetWriter = nil
        videoInput = nil
        audioInput = nil
        adaptor = nil
        sessionStarted = false
        startTime = nil
        pausedDuration = 0
        pauseStartDate = nil
        recordingStartDate = nil

        logger.info("Recording stopped. File saved to \(url.path)")
        return url
    }

    // MARK: - Restart Recording

    /// Cancel the current recording without saving, delete the partial file,
    /// and immediately start a new recording with the same filter/configuration.
    func restartRecording() async throws {
        guard isRecording else { throw OpenShotError.recordingNotInProgress }

        let filter = lastFilter
        let includeAudio = lastIncludeAudio

        // Stop the SCStream without finishing the asset writer cleanly
        if let scStream = stream {
            try await scStream.stopCapture()
        }
        stream = nil

        // Cancel the asset writer (discard partial data)
        assetWriter?.cancelWriting()

        // Stop visualizers and restore DND
        await MainActor.run {
            clickVisualizer.stop()
            keystrokeVisualizer.stop()
        }
        DNDManager.disableDND()

        // Delete the partial output file
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
            logger.info("Deleted partial recording at \(url.path)")
        }

        // Reset state
        await MainActor.run {
            self.timer?.invalidate()
            self.timer = nil
            self.isRecording = false
            self.isPaused = false
            self.elapsedTime = 0
        }

        assetWriter = nil
        videoInput = nil
        audioInput = nil
        adaptor = nil
        outputURL = nil
        sessionStarted = false
        startTime = nil
        pausedDuration = 0
        pauseStartDate = nil
        recordingStartDate = nil

        logger.info("Recording cancelled, restarting...")

        // Start a new recording with the same configuration
        guard let savedFilter = filter else {
            throw OpenShotError.invalidConfiguration("No previous filter available for restart")
        }
        try await startRecording(filter: savedFilter, includeAudio: includeAudio)
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !isPaused else { return }
        guard let writer = assetWriter, writer.status == .writing || !sessionStarted else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard timestamp.isValid else { return }

        switch type {
        case .screen:
            guard let vInput = videoInput, vInput.isReadyForMoreMediaData else { return }

            // Handle first frame: start the writer session
            if !sessionStarted {
                writer.startSession(atSourceTime: timestamp)
                startTime = timestamp
                sessionStarted = true
                logger.debug("Writer session started at \(timestamp.seconds)s")
            }

            // Validate the sample buffer has an image buffer
            guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }

            vInput.append(sampleBuffer)

        case .audio:
            guard sessionStarted else { return }
            guard let aInput = audioInput, aInput.isReadyForMoreMediaData else { return }
            aInput.append(sampleBuffer)

        @unknown default:
            break
        }
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartDate else { return }
            let totalPaused = self.pausedDuration + (self.pauseStartDate.map { Date().timeIntervalSince($0) } ?? 0)
            self.elapsedTime = Date().timeIntervalSince(start) - totalPaused
        }
    }

    // MARK: - Filter Factory

    /// Creates an appropriate `SCContentFilter` for the given capture mode.
    /// - Parameters:
    ///   - mode: The capture mode (area, window, fullscreen, scrolling).
    ///   - rect: The selected rectangle (required for `.area` mode).
    /// - Returns: A configured `SCContentFilter`.
    static func createFilter(for mode: CaptureMode, rect: CGRect? = nil) async throws -> SCContentFilter {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        switch mode {
        case .area:
            // For area recording, capture the display that contains the area and crop to rect
            guard let captureRect = rect else {
                throw OpenShotError.invalidConfiguration("Area mode requires a selection rectangle")
            }
            guard let screen = ScreenInfo.screenContainingCursor() else {
                throw OpenShotError.screenNotFound
            }
            let displayID = ScreenInfo.displayID(for: screen)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw OpenShotError.screenNotFound
            }
            // Exclude no windows to capture everything on screen within the rect
            let filter = SCContentFilter(display: display, excludingWindows: [])
            return filter

        case .window:
            // For window recording, use WindowPicker to let user select
            guard let selectedWindow = await WindowPicker.present() else {
                throw OpenShotError.windowNotFound
            }
            let filter = SCContentFilter(desktopIndependentWindow: selectedWindow)
            return filter

        case .fullscreen:
            guard let screen = ScreenInfo.screenContainingCursor() else {
                throw OpenShotError.screenNotFound
            }
            let displayID = ScreenInfo.displayID(for: screen)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw OpenShotError.screenNotFound
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            return filter

        case .scrolling:
            // Scrolling mode for recording falls back to fullscreen behavior
            guard let screen = ScreenInfo.screenContainingCursor() else {
                throw OpenShotError.screenNotFound
            }
            let displayID = ScreenInfo.displayID(for: screen)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw OpenShotError.screenNotFound
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            return filter
        }
    }
}
