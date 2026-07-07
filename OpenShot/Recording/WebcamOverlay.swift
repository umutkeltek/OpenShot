import AVFoundation
import AppKit
import os

class WebcamOverlay {
    private let logger = Logger(subsystem: "com.openshot", category: "webcam")
    private var panel: NSPanel?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    var diameter: CGFloat = 128
    var isActive = false

    @MainActor
    func start() {
        guard !isActive else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(for: .video) else {
            logger.warning("No camera available for webcam overlay")
            ToastManager.show(icon: "video.slash", message: "No camera found", detail: "Webcam overlay needs a connected camera")
            return
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch {
            logger.warning("Failed to create camera input: \(error.localizedDescription)")
            ToastManager.show(icon: "video.slash", message: "Webcam unavailable", detail: error.localizedDescription)
            return
        }

        guard session.canAddInput(input) else {
            logger.warning("Session cannot add camera input")
            ToastManager.show(icon: "video.slash", message: "Webcam unavailable", detail: "Camera input could not be added")
            return
        }
        session.addInput(input)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        preview.cornerRadius = diameter / 2
        preview.masksToBounds = true

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        containerView.wantsLayer = true
        containerView.layer?.addSublayer(preview)
        containerView.layer?.cornerRadius = diameter / 2
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 3
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor

        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: diameter, height: diameter),
                       styleMask: [.nonactivatingPanel, .borderless],
                       backing: .buffered, defer: false)
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.contentView = containerView

        // Position bottom-right
        if let screen = NSScreen.main {
            p.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.maxX - diameter - 20,
                y: screen.visibleFrame.minY + 20
            ))
        }

        p.orderFrontRegardless()

        session.startRunning()

        self.panel = p
        self.captureSession = session
        self.previewLayer = preview
        self.isActive = true
        logger.info("Webcam overlay started")
    }

    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer = nil
        panel?.close()
        panel = nil
        isActive = false
        logger.info("Webcam overlay stopped")
    }
}
