// AnnotationCanvas.swift
// OpenShot
//
// NSView-based drawing canvas — the core annotation editor view.
// Handles drawing the background screenshot, all annotations, in-progress drawing,
// selection, dragging, undo/redo, and image export.

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import os

private let logger = Logger(subsystem: "com.openshot.app", category: "AnnotationCanvas")

class AnnotationCanvas: NSView {

    // MARK: - Public Properties

    var backgroundImage: NSImage? {
        didSet { needsDisplay = true }
    }

    var annotations: [AnnotationItem] = []

    var currentTool: AnnotationToolType = .arrow
    var currentColor: NSColor = .red
    var currentStrokeWidth: CGFloat = 2.0

    /// Callback fired when annotations change (for SwiftUI bindings).
    var onAnnotationsChanged: (() -> Void)?

    // MARK: - Private Drawing State

    private var isDrawing = false
    private var startPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var pencilPoints: [CGPoint] = []
    private var activeAnnotation: AnnotationItem?
    private var selectedAnnotation: AnnotationItem?
    private var isDragging = false
    private var dragOffset: CGPoint = .zero
    private var counterValue: Int = 1

    /// Resize handle tracking.
    private var activeHandleIndex: Int = -1
    private var isResizing: Bool = false
    private var resizeStartBounds: CGRect = .zero

    /// CIContext for blur/pixelate rendering — reused for performance.
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - NSView Configuration

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw background image
        if let image = backgroundImage,
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.saveGState()
            // In flipped coordinate system, flip the image drawing
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))
            context.restoreGState()
        }

        // 2. Render blur/pixelate annotations by applying CIFilter to the background
        renderBlurAnnotations(in: context)

        // 2b. Render smart blur annotations (text-only blur via Vision)
        renderSmartBlurAnnotations(in: context)

        // 2c. Render magnifier annotations (magnified region from background)
        renderMagnifierAnnotations(in: context)

        // 3. Render spotlight overlay if any spotlight annotations exist
        renderSpotlightOverlay(in: context)

        // 4. Draw all non-blur/spotlight/magnifier annotations
        for annotation in annotations {
            if annotation is BlurAnnotation || annotation is SmartBlurAnnotation || annotation is SpotlightAnnotation || annotation is MagnifierAnnotation { continue }

            context.saveGState()
            annotation.draw(in: context)
            context.restoreGState()

            if annotation.isSelected {
                drawSelectionHandles(for: annotation, in: context)
            }
        }

        // 5. Draw blur/spotlight/magnifier annotation borders and selection handles
        for annotation in annotations {
            if annotation is BlurAnnotation || annotation is SmartBlurAnnotation || annotation is SpotlightAnnotation || annotation is MagnifierAnnotation {
                context.saveGState()
                annotation.draw(in: context)
                context.restoreGState()

                if annotation.isSelected {
                    drawSelectionHandles(for: annotation, in: context)
                }
            }
        }

        // 6. Draw in-progress annotation while mouse is being dragged
        if isDrawing, let active = activeAnnotation {
            context.saveGState()
            active.draw(in: context)
            context.restoreGState()
        }
    }

    private func drawSelectionHandles(for annotation: AnnotationItem, in context: CGContext) {
        for handle in annotation.selectionHandles() {
            context.setFillColor(NSColor.white.cgColor)
            context.fill(handle)
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(1)
            context.stroke(handle)
        }
    }

    // MARK: - Blur / Pixelate Rendering

    private func renderBlurAnnotations(in context: CGContext) {
        guard let bgImage = backgroundImage,
              let cgBgImage = bgImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let blurAnnotations = annotations.compactMap { $0 as? BlurAnnotation }
        guard !blurAnnotations.isEmpty else { return }

        let imageWidth = CGFloat(cgBgImage.width)
        let imageHeight = CGFloat(cgBgImage.height)
        let scaleX = imageWidth / bounds.width
        let scaleY = imageHeight / bounds.height

        for blurAnn in blurAnnotations {
            // Convert view rect to image coordinates (flipped for CIImage bottom-left origin)
            let imgRect = CGRect(
                x: blurAnn.bounds.origin.x * scaleX,
                y: (bounds.height - blurAnn.bounds.maxY) * scaleY,
                width: blurAnn.bounds.width * scaleX,
                height: blurAnn.bounds.height * scaleY
            )

            let ciImage = CIImage(cgImage: cgBgImage)

            let filtered: CIImage?
            if blurAnn.isPixelate {
                let cropped = ciImage.cropped(to: imgRect)
                let pixelate = CIFilter.pixellate()
                pixelate.inputImage = cropped
                pixelate.scale = Float(blurAnn.radius * scaleX)
                pixelate.center = CGPoint(x: imgRect.midX, y: imgRect.midY)
                filtered = pixelate.outputImage?.cropped(to: imgRect)
            } else {
                // Clamp first to prevent transparent edges
                let clamp = CIFilter.affineClamp()
                clamp.inputImage = ciImage
                clamp.transform = CGAffineTransform.identity

                let blur = CIFilter.gaussianBlur()
                blur.inputImage = clamp.outputImage
                blur.radius = Float(blurAnn.radius * scaleX)
                filtered = blur.outputImage?.cropped(to: imgRect)
            }

            if let output = filtered,
               let resultCG = ciContext.createCGImage(output, from: imgRect) {
                context.saveGState()
                // Draw the processed region in view coordinates (flipped)
                context.translateBy(x: 0, y: bounds.height)
                context.scaleBy(x: 1, y: -1)
                let viewRect = CGRect(
                    x: blurAnn.bounds.origin.x,
                    y: bounds.height - blurAnn.bounds.maxY,
                    width: blurAnn.bounds.width,
                    height: blurAnn.bounds.height
                )
                context.draw(resultCG, in: viewRect)
                context.restoreGState()
            }
        }
    }

    // MARK: - Smart Blur Rendering

    private func renderSmartBlurAnnotations(in context: CGContext) {
        guard let bgImage = backgroundImage,
              let cgBgImage = bgImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let smartBlurAnnotations = annotations.compactMap { $0 as? SmartBlurAnnotation }
        guard !smartBlurAnnotations.isEmpty else { return }

        let imageWidth = CGFloat(cgBgImage.width)
        let imageHeight = CGFloat(cgBgImage.height)
        let scaleX = imageWidth / bounds.width
        let scaleY = imageHeight / bounds.height

        for smartAnn in smartBlurAnnotations {
            // Convert view rect to image coordinates (top-left origin for SmartBlur detection)
            let imgRect = CGRect(
                x: smartAnn.bounds.origin.x * scaleX,
                y: smartAnn.bounds.origin.y * scaleY,
                width: smartAnn.bounds.width * scaleX,
                height: smartAnn.bounds.height * scaleY
            )

            // Try smart text-only blur first
            if let smartResult = SmartBlur.applyTextOnlyBlur(
                to: cgBgImage,
                in: imgRect,
                blurRadius: smartAnn.blurRadius * scaleX
            ) {
                context.saveGState()
                context.translateBy(x: 0, y: bounds.height)
                context.scaleBy(x: 1, y: -1)
                let viewRect = CGRect(
                    x: smartAnn.bounds.origin.x,
                    y: bounds.height - smartAnn.bounds.maxY,
                    width: smartAnn.bounds.width,
                    height: smartAnn.bounds.height
                )
                context.draw(smartResult, in: viewRect)
                context.restoreGState()
            } else {
                // Fallback: no text detected, apply standard full blur
                let ciImage = CIImage(cgImage: cgBgImage)
                let flippedImgRect = CGRect(
                    x: smartAnn.bounds.origin.x * scaleX,
                    y: (bounds.height - smartAnn.bounds.maxY) * scaleY,
                    width: smartAnn.bounds.width * scaleX,
                    height: smartAnn.bounds.height * scaleY
                )

                let clamp = CIFilter.affineClamp()
                clamp.inputImage = ciImage
                clamp.transform = CGAffineTransform.identity

                let blur = CIFilter.gaussianBlur()
                blur.inputImage = clamp.outputImage
                blur.radius = Float(smartAnn.blurRadius * scaleX)

                if let filtered = blur.outputImage?.cropped(to: flippedImgRect),
                   let resultCG = ciContext.createCGImage(filtered, from: flippedImgRect) {
                    context.saveGState()
                    context.translateBy(x: 0, y: bounds.height)
                    context.scaleBy(x: 1, y: -1)
                    let viewRect = CGRect(
                        x: smartAnn.bounds.origin.x,
                        y: bounds.height - smartAnn.bounds.maxY,
                        width: smartAnn.bounds.width,
                        height: smartAnn.bounds.height
                    )
                    context.draw(resultCG, in: viewRect)
                    context.restoreGState()
                }
            }
        }
    }

    // MARK: - Magnifier Rendering

    private func renderMagnifierAnnotations(in context: CGContext) {
        guard let bgImage = backgroundImage,
              let cgBgImage = bgImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let magnifierAnnotations = annotations.compactMap { $0 as? MagnifierAnnotation }
        guard !magnifierAnnotations.isEmpty else { return }

        let imageWidth = CGFloat(cgBgImage.width)
        let imageHeight = CGFloat(cgBgImage.height)
        let scaleX = imageWidth / bounds.width
        let scaleY = imageHeight / bounds.height

        for magAnn in magnifierAnnotations {
            // Convert source rect from view coordinates to image coordinates (top-left origin)
            let imgSourceRect = CGRect(
                x: magAnn.sourceRect.origin.x * scaleX,
                y: magAnn.sourceRect.origin.y * scaleY,
                width: magAnn.sourceRect.width * scaleX,
                height: magAnn.sourceRect.height * scaleY
            ).intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

            guard imgSourceRect.width > 0, imgSourceRect.height > 0 else { continue }

            // Crop the source region from the background image
            // CGImage.cropping uses bottom-left origin, so flip Y
            let croppingRect = CGRect(
                x: imgSourceRect.origin.x,
                y: imageHeight - imgSourceRect.origin.y - imgSourceRect.height,
                width: imgSourceRect.width,
                height: imgSourceRect.height
            )

            guard let croppedImage = cgBgImage.cropping(to: croppingRect) else { continue }

            // Draw the cropped region inside a circular clip at the display center
            let circleRect = CGRect(
                x: magAnn.displayCenter.x - magAnn.displayRadius,
                y: magAnn.displayCenter.y - magAnn.displayRadius,
                width: magAnn.displayRadius * 2,
                height: magAnn.displayRadius * 2
            )

            context.saveGState()

            // Clip to circle
            context.addEllipse(in: circleRect)
            context.clip()

            // Draw the zoomed image in the circle, flipping for the flipped coordinate system
            context.saveGState()
            context.translateBy(x: circleRect.origin.x, y: circleRect.origin.y + circleRect.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(croppedImage, in: CGRect(origin: .zero, size: circleRect.size))
            context.restoreGState()

            context.restoreGState()

            // Draw the border/frame on top (via MagnifierAnnotation.draw)
            context.saveGState()
            magAnn.draw(in: context)
            context.restoreGState()
        }
    }

    // MARK: - Spotlight Overlay Rendering

    private func renderSpotlightOverlay(in context: CGContext) {
        let spotlightAnnotations = annotations.compactMap { $0 as? SpotlightAnnotation }
        guard !spotlightAnnotations.isEmpty else { return }

        context.saveGState()

        // Create a path that covers the entire canvas
        let fullPath = CGMutablePath()
        fullPath.addRect(bounds)

        // Cut out each spotlight region using even-odd fill rule
        for spotlight in spotlightAnnotations {
            fullPath.addRect(spotlight.bounds)
        }

        context.addPath(fullPath)
        context.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
        context.fillPath(using: .evenOdd)

        context.restoreGState()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // First, check if clicking on a selection handle of the currently selected annotation
        if let selected = selectedAnnotation, selected.isSelected {
            let handles = selected.selectionHandles()
            for (index, handle) in handles.enumerated() {
                if handle.contains(point) {
                    isResizing = true
                    activeHandleIndex = index
                    resizeStartBounds = selected.bounds
                    startPoint = point
                    return
                }
            }
        }

        // Check if clicking on an existing annotation (reverse order for top-most first)
        for annotation in annotations.reversed() {
            if annotation.hitTest(point: point) {
                deselectAll()
                annotation.isSelected = true
                selectedAnnotation = annotation
                isDragging = true
                dragOffset = CGPoint(
                    x: point.x - annotation.bounds.origin.x,
                    y: point.y - annotation.bounds.origin.y
                )
                needsDisplay = true
                return
            }
        }

        // Deselect any selected annotation
        deselectAll()

        // Start creating a new annotation based on currentTool
        startPoint = point
        currentPoint = point
        isDrawing = true

        switch currentTool {
        case .pencil, .highlighter:
            pencilPoints = [point]
            let annotation = PencilAnnotation(
                points: pencilPoints,
                color: currentColor,
                width: currentTool == .highlighter ? max(currentStrokeWidth, 12) : currentStrokeWidth,
                isHighlighter: currentTool == .highlighter
            )
            activeAnnotation = annotation

        case .text:
            isDrawing = false
            let textAnnotation = TextAnnotationItem(at: point, text: "", style: .whitePillRed)
            textAnnotation.strokeColor = currentColor
            textAnnotation.backgroundColor = currentColor
            TextAnnotationEditor.createEditor(at: point, in: self, style: .whitePillRed) { [weak self] text in
                guard let self, !text.isEmpty else { return }
                textAnnotation.text = text
                textAnnotation.applyStyle(textAnnotation.style)
                self.addAnnotation(textAnnotation)
            }

        case .counter:
            isDrawing = false
            let counter = CounterAnnotation(at: point, number: counterValue, color: currentColor)
            counterValue += 1
            addAnnotation(counter)

        case .arrow:
            let annotation = ArrowAnnotation(start: point, end: point, color: currentColor, width: currentStrokeWidth)
            activeAnnotation = annotation

        case .line:
            let annotation = LineAnnotation(start: point, end: point, color: currentColor, width: currentStrokeWidth)
            activeAnnotation = annotation

        case .rectangle:
            let annotation = RectAnnotation(bounds: CGRect(origin: point, size: .zero))
            annotation.strokeColor = currentColor
            annotation.strokeWidth = currentStrokeWidth
            activeAnnotation = annotation

        case .blackOut:
            let annotation = BlackOutAnnotation(bounds: CGRect(origin: point, size: .zero))
            annotation.strokeColor = .black
            activeAnnotation = annotation

        case .ellipse:
            let annotation = EllipseAnnotation(bounds: CGRect(origin: point, size: .zero))
            annotation.strokeColor = currentColor
            annotation.strokeWidth = currentStrokeWidth
            activeAnnotation = annotation

        case .blur:
            let annotation = BlurAnnotation(bounds: CGRect(origin: point, size: .zero), isPixelate: false)
            activeAnnotation = annotation

        case .pixelate:
            let annotation = BlurAnnotation(bounds: CGRect(origin: point, size: .zero), isPixelate: true)
            activeAnnotation = annotation

        case .smartBlur:
            let annotation = SmartBlurAnnotation(bounds: CGRect(origin: point, size: .zero))
            activeAnnotation = annotation

        case .spotlight:
            let annotation = SpotlightAnnotation(spotlightBounds: CGRect(origin: point, size: .zero))
            activeAnnotation = annotation

        case .crop:
            let annotation = CropAnnotation(bounds: CGRect(origin: point, size: .zero))
            activeAnnotation = annotation

        case .ruler:
            let annotation = RulerAnnotation(start: point, end: point)
            activeAnnotation = annotation

        case .colorPicker:
            isDrawing = false
            pickColor(at: point)

        case .magnifier:
            // Record source point; magnifier created on mouseUp with display center at release
            break
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentPoint = point

        // Handle resize
        if isResizing, let selected = selectedAnnotation {
            let dx = point.x - startPoint.x
            let dy = point.y - startPoint.y
            var newBounds = resizeStartBounds

            switch activeHandleIndex {
            case 0: // Top-left
                newBounds.origin.x = resizeStartBounds.origin.x + dx
                newBounds.origin.y = resizeStartBounds.origin.y + dy
                newBounds.size.width = resizeStartBounds.width - dx
                newBounds.size.height = resizeStartBounds.height - dy
            case 1: // Top-center
                newBounds.origin.y = resizeStartBounds.origin.y + dy
                newBounds.size.height = resizeStartBounds.height - dy
            case 2: // Top-right
                newBounds.origin.y = resizeStartBounds.origin.y + dy
                newBounds.size.width = resizeStartBounds.width + dx
                newBounds.size.height = resizeStartBounds.height - dy
            case 3: // Right-center
                newBounds.size.width = resizeStartBounds.width + dx
            case 4: // Bottom-right
                newBounds.size.width = resizeStartBounds.width + dx
                newBounds.size.height = resizeStartBounds.height + dy
            case 5: // Bottom-center
                newBounds.size.height = resizeStartBounds.height + dy
            case 6: // Bottom-left
                newBounds.origin.x = resizeStartBounds.origin.x + dx
                newBounds.size.width = resizeStartBounds.width - dx
                newBounds.size.height = resizeStartBounds.height + dy
            case 7: // Left-center
                newBounds.origin.x = resizeStartBounds.origin.x + dx
                newBounds.size.width = resizeStartBounds.width - dx
            default:
                break
            }

            selected.bounds = newBounds.standardized
            needsDisplay = true
            return
        }

        // Handle dragging an existing annotation
        if isDragging, let selected = selectedAnnotation {
            let newOrigin = CGPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y)

            if let arrow = selected as? ArrowAnnotation {
                let dx = newOrigin.x - selected.bounds.origin.x
                let dy = newOrigin.y - selected.bounds.origin.y
                arrow.startPoint.x += dx
                arrow.startPoint.y += dy
                arrow.endPoint.x += dx
                arrow.endPoint.y += dy
                arrow.bounds.origin = newOrigin
            } else if let line = selected as? LineAnnotation {
                let dx = newOrigin.x - selected.bounds.origin.x
                let dy = newOrigin.y - selected.bounds.origin.y
                line.startPoint.x += dx
                line.startPoint.y += dy
                line.endPoint.x += dx
                line.endPoint.y += dy
                line.bounds.origin = newOrigin
            } else if let ruler = selected as? RulerAnnotation {
                let dx = newOrigin.x - selected.bounds.origin.x
                let dy = newOrigin.y - selected.bounds.origin.y
                ruler.startPoint.x += dx
                ruler.startPoint.y += dy
                ruler.endPoint.x += dx
                ruler.endPoint.y += dy
                ruler.bounds.origin = newOrigin
            } else if let pencil = selected as? PencilAnnotation {
                let dx = newOrigin.x - selected.bounds.origin.x
                let dy = newOrigin.y - selected.bounds.origin.y
                for i in 0..<pencil.points.count {
                    pencil.points[i].x += dx
                    pencil.points[i].y += dy
                }
                pencil.bounds.origin = newOrigin
            } else if let mag = selected as? MagnifierAnnotation {
                let dx = newOrigin.x - selected.bounds.origin.x
                let dy = newOrigin.y - selected.bounds.origin.y
                mag.displayCenter.x += dx
                mag.displayCenter.y += dy
                mag.bounds.origin = newOrigin
            } else {
                selected.bounds.origin = newOrigin
            }

            needsDisplay = true
            return
        }

        // Handle drawing in-progress annotation
        if isDrawing {
            let rect = rectFromPoints(startPoint, point)

            switch currentTool {
            case .pencil, .highlighter:
                pencilPoints.append(point)
                if let pencil = activeAnnotation as? PencilAnnotation {
                    pencil.points = pencilPoints
                    pencil.recalculateBounds()
                }

            case .arrow:
                if let arrow = activeAnnotation as? ArrowAnnotation {
                    arrow.endPoint = point
                    arrow.bounds = rectFromPoints(arrow.startPoint, arrow.endPoint)
                }

            case .line:
                if let line = activeAnnotation as? LineAnnotation {
                    line.endPoint = point
                    line.bounds = rectFromPoints(line.startPoint, line.endPoint)
                }

            case .rectangle, .blackOut:
                activeAnnotation?.bounds = rect

            case .ellipse:
                activeAnnotation?.bounds = rect

            case .blur, .pixelate, .smartBlur:
                activeAnnotation?.bounds = rect

            case .spotlight:
                activeAnnotation?.bounds = rect

            case .crop:
                activeAnnotation?.bounds = rect

            case .ruler:
                if let ruler = activeAnnotation as? RulerAnnotation {
                    ruler.endPoint = point
                    ruler.bounds = rectFromPoints(ruler.startPoint, ruler.endPoint)
                }

            case .magnifier:
                break // Magnifier tracks via startPoint/currentPoint; created on mouseUp

            case .text, .counter, .colorPicker:
                break
            }

            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        // End resize
        if isResizing {
            isResizing = false
            activeHandleIndex = -1
            needsDisplay = true
            return
        }

        // End drag
        if isDragging {
            isDragging = false
            needsDisplay = true
            return
        }

        // Handle magnifier: create annotation from startPoint (source) to release point (display)
        if isDrawing && currentTool == .magnifier {
            let point = convert(event.locationInWindow, from: nil)
            let dx = point.x - startPoint.x
            let dy = point.y - startPoint.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance >= 10 {
                let sourceSize: CGFloat = 60
                let sourceRect = CGRect(
                    x: startPoint.x - sourceSize / 2,
                    y: startPoint.y - sourceSize / 2,
                    width: sourceSize,
                    height: sourceSize
                )
                let magnifier = MagnifierAnnotation(sourceRect: sourceRect, displayCenter: point)
                addAnnotation(magnifier)
            }
            isDrawing = false
            needsDisplay = true
            return
        }

        // Finalize the in-progress annotation
        if isDrawing, let annotation = activeAnnotation {
            let minSize: CGFloat = 3

            var shouldAdd = true
            switch currentTool {
            case .pencil, .highlighter:
                shouldAdd = pencilPoints.count >= 2
            case .arrow, .line, .ruler:
                let dx = currentPoint.x - startPoint.x
                let dy = currentPoint.y - startPoint.y
                shouldAdd = sqrt(dx * dx + dy * dy) >= minSize
            case .rectangle, .ellipse, .blur, .pixelate, .smartBlur, .spotlight, .crop, .blackOut:
                shouldAdd = annotation.bounds.width >= minSize || annotation.bounds.height >= minSize
            case .text, .counter, .colorPicker, .magnifier:
                shouldAdd = false
            }

            if shouldAdd {
                addAnnotation(annotation)
            }

            activeAnnotation = nil
            isDrawing = false
            pencilPoints = []
            needsDisplay = true
        }
    }

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51: // Delete key
            if let selected = selectedAnnotation {
                removeAnnotation(selected)
                selectedAnnotation = nil
            }
        case 53: // Escape key
            deselectAll()
            needsDisplay = true
        default:
            if event.modifierFlags.contains(.command) {
                if event.charactersIgnoringModifiers == "z" {
                    if event.modifierFlags.contains(.shift) {
                        undoManager?.redo()
                    } else {
                        undoManager?.undo()
                    }
                    needsDisplay = true
                    return
                }
            }
            super.keyDown(with: event)
        }
    }

    // MARK: - Undo / Redo

    func addAnnotation(_ annotation: AnnotationItem) {
        annotations.append(annotation)
        undoManager?.registerUndo(withTarget: self) { [weak self] canvas in
            canvas.removeAnnotation(annotation)
            self?.onAnnotationsChanged?()
        }
        undoManager?.setActionName("Add Annotation")
        onAnnotationsChanged?()
        needsDisplay = true
        logger.debug("Added annotation: \(annotation.id)")
    }

    func removeAnnotation(_ annotation: AnnotationItem) {
        annotations.removeAll { $0.id == annotation.id }
        undoManager?.registerUndo(withTarget: self) { [weak self] canvas in
            canvas.addAnnotation(annotation)
            self?.onAnnotationsChanged?()
        }
        undoManager?.setActionName("Remove Annotation")
        onAnnotationsChanged?()
        needsDisplay = true
        logger.debug("Removed annotation: \(annotation.id)")
    }

    func performUndo() {
        undoManager?.undo()
        needsDisplay = true
    }

    func performRedo() {
        undoManager?.redo()
        needsDisplay = true
    }

    // MARK: - Selection

    private func deselectAll() {
        for annotation in annotations {
            annotation.isSelected = false
        }
        selectedAnnotation = nil
    }

    // MARK: - Image Export

    /// Returns a composited NSImage of the background screenshot with all annotations rendered.
    /// Called by AnnotationWindow for save/copy operations.
    func compositedImage() -> NSImage? {
        let wasSelected = selectedAnnotation
        deselectAll()

        let wasDrawing = isDrawing
        isDrawing = false

        let image = NSImage(size: bounds.size)
        image.lockFocus()
        draw(bounds)
        image.unlockFocus()

        // Restore state
        isDrawing = wasDrawing
        if let prev = wasSelected {
            prev.isSelected = true
            selectedAnnotation = prev
        }

        needsDisplay = true
        logger.info("Composited annotated image: \(self.bounds.size.width)x\(self.bounds.size.height)")
        return image
    }

    /// Returns a composited CGImage for higher-fidelity operations.
    func compositedCGImage() -> CGImage? {
        guard let image = compositedImage() else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    // MARK: - Clear

    /// Removes all annotations with undo support. Called by AnnotationWindow's reset action.
    func clearAnnotations() {
        let previousAnnotations = annotations
        let previousCounter = counterValue
        annotations.removeAll()
        counterValue = 1
        undoManager?.registerUndo(withTarget: self) { canvas in
            canvas.annotations = previousAnnotations
            canvas.counterValue = previousCounter
            canvas.needsDisplay = true
        }
        undoManager?.setActionName("Clear All")
        onAnnotationsChanged?()
        needsDisplay = true
        logger.info("All annotations cleared")
    }

    /// Resets the counter value (e.g., when starting a new annotation session).
    func resetCounter() {
        counterValue = 1
    }

    // MARK: - Color Picker

    /// Picks the color at the given point from the background image and copies it to the clipboard.
    private func pickColor(at point: CGPoint) {
        guard let image = backgroundImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let scaleX = CGFloat(cgImage.width) / bounds.width
        let scaleY = CGFloat(cgImage.height) / bounds.height
        let pixelX = Int(point.x * scaleX)
        let pixelY = Int(point.y * scaleY)

        guard pixelX >= 0, pixelX < cgImage.width, pixelY >= 0, pixelY < cgImage.height else { return }

        // Create a 1x1 bitmap context to read the pixel
        let bytesPerPixel = 4
        var pixelData = [UInt8](repeating: 0, count: bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let bitmapContext = CGContext(
            data: &pixelData,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        bitmapContext.draw(cgImage, in: CGRect(x: -pixelX, y: -(cgImage.height - 1 - pixelY), width: cgImage.width, height: cgImage.height))

        let r = CGFloat(pixelData[0]) / 255.0
        let g = CGFloat(pixelData[1]) / 255.0
        let b = CGFloat(pixelData[2]) / 255.0
        let color = NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)

        ColorInspector.copyToClipboard(color, format: .hex)
        logger.info("Picked color: \(ColorInspector.hex(from: color))")
    }

    // MARK: - Helpers

    /// Returns a normalized rect from two corner points.
    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGRect {
        CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
    }
}
