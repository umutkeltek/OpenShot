// AnnotationTool.swift
// OpenShot
//
// Defines the annotation tool types, protocol, base class, and all concrete annotation subclasses.

import AppKit
import CoreImage
import os

private let logger = Logger(subsystem: "com.openshot.app", category: "Annotation")

// MARK: - Tool Type Enum

enum AnnotationToolType: String, CaseIterable, Identifiable {
    case arrow, rectangle, ellipse, line, text, counter, pencil, highlighter, blur, pixelate, smartBlur, spotlight, crop, blackOut, ruler, colorPicker, magnifier

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .line: return "Line"
        case .text: return "Text"
        case .counter: return "Counter"
        case .pencil: return "Pencil"
        case .highlighter: return "Highlighter"
        case .blur: return "Blur"
        case .pixelate: return "Pixelate"
        case .spotlight: return "Spotlight"
        case .crop: return "Crop"
        case .blackOut: return "Black Out"
        case .smartBlur: return "Smart Blur"
        case .ruler: return "Ruler"
        case .colorPicker: return "Color Picker"
        case .magnifier: return "Magnifier"
        }
    }

    var systemImage: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .counter: return "number.circle"
        case .pencil: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .blur: return "drop.halffull"
        case .pixelate: return "squareshape.split.3x3"
        case .spotlight: return "lightbulb.circle"
        case .crop: return "crop"
        case .blackOut: return "eye.slash.fill"
        case .smartBlur: return "text.redaction"
        case .ruler: return "ruler"
        case .colorPicker: return "eyedropper"
        case .magnifier: return "plus.magnifyingglass"
        }
    }
}

// MARK: - Annotation Protocol

protocol AnnotationItem: AnyObject {
    var id: UUID { get }
    var bounds: CGRect { get set }
    var isSelected: Bool { get set }
    var strokeColor: NSColor { get set }
    var strokeWidth: CGFloat { get set }
    func draw(in context: CGContext)
    func hitTest(point: CGPoint) -> Bool
    func selectionHandles() -> [CGRect]
}

// MARK: - Base Annotation Class

class BaseAnnotation: AnnotationItem {
    let id = UUID()
    var bounds: CGRect
    var isSelected = false
    var strokeColor: NSColor = .red
    var strokeWidth: CGFloat = 2.0

    init(bounds: CGRect) {
        self.bounds = bounds
    }

    func draw(in context: CGContext) {
        // Override in subclasses
    }

    func hitTest(point: CGPoint) -> Bool {
        bounds.insetBy(dx: -4, dy: -4).contains(point)
    }

    func selectionHandles() -> [CGRect] {
        let s: CGFloat = 8
        let r = bounds
        return [
            CGRect(x: r.minX - s / 2, y: r.minY - s / 2, width: s, height: s),
            CGRect(x: r.midX - s / 2, y: r.minY - s / 2, width: s, height: s),
            CGRect(x: r.maxX - s / 2, y: r.minY - s / 2, width: s, height: s),
            CGRect(x: r.maxX - s / 2, y: r.midY - s / 2, width: s, height: s),
            CGRect(x: r.maxX - s / 2, y: r.maxY - s / 2, width: s, height: s),
            CGRect(x: r.midX - s / 2, y: r.maxY - s / 2, width: s, height: s),
            CGRect(x: r.minX - s / 2, y: r.maxY - s / 2, width: s, height: s),
            CGRect(x: r.minX - s / 2, y: r.midY - s / 2, width: s, height: s),
        ]
    }
}

// MARK: - Arrow Annotation

class ArrowAnnotation: BaseAnnotation {
    var startPoint: CGPoint
    var endPoint: CGPoint

    init(start: CGPoint, end: CGPoint, color: NSColor = .red, width: CGFloat = 2.0) {
        self.startPoint = start
        self.endPoint = end
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)
        super.init(bounds: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
        self.strokeColor = color
        self.strokeWidth = width
    }

    override func draw(in context: CGContext) {
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw the line
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()

        // Draw arrowhead
        let headLength: CGFloat = max(12, strokeWidth * 5)
        let headAngle: CGFloat = .pi / 6
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)

        let arrowPoint1 = CGPoint(
            x: endPoint.x - headLength * cos(angle - headAngle),
            y: endPoint.y - headLength * sin(angle - headAngle)
        )
        let arrowPoint2 = CGPoint(
            x: endPoint.x - headLength * cos(angle + headAngle),
            y: endPoint.y - headLength * sin(angle + headAngle)
        )

        context.setFillColor(strokeColor.cgColor)
        context.move(to: endPoint)
        context.addLine(to: arrowPoint1)
        context.addLine(to: arrowPoint2)
        context.closePath()
        context.fillPath()
    }

    override func hitTest(point: CGPoint) -> Bool {
        let threshold: CGFloat = max(8, strokeWidth + 4)
        return distanceFromPointToLineSegment(point: point, start: startPoint, end: endPoint) < threshold
    }
}

// MARK: - Rectangle Annotation

class RectAnnotation: BaseAnnotation {
    var cornerRadius: CGFloat = 0
    var isFilled: Bool = false

    override func draw(in context: CGContext) {
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)

        if isFilled {
            context.setFillColor(strokeColor.withAlphaComponent(0.3).cgColor)
        }

        let path: CGPath
        if cornerRadius > 0 {
            path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        } else {
            path = CGPath(rect: bounds, transform: nil)
        }

        context.addPath(path)

        if isFilled {
            context.drawPath(using: .fillStroke)
        } else {
            context.strokePath()
        }
    }
}

// MARK: - Ellipse Annotation

class EllipseAnnotation: BaseAnnotation {
    var isFilled: Bool = false

    override func draw(in context: CGContext) {
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)

        if isFilled {
            context.setFillColor(strokeColor.withAlphaComponent(0.3).cgColor)
            context.fillEllipse(in: bounds)
        }

        context.strokeEllipse(in: bounds)
    }

    override func hitTest(point: CGPoint) -> Bool {
        // Ellipse hit test: check if point is within the ellipse equation
        let cx = bounds.midX
        let cy = bounds.midY
        let rx = bounds.width / 2 + 4
        let ry = bounds.height / 2 + 4
        guard rx > 0, ry > 0 else { return false }
        let dx = point.x - cx
        let dy = point.y - cy
        return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0
    }
}

// MARK: - Line Annotation

class LineAnnotation: BaseAnnotation {
    var startPoint: CGPoint
    var endPoint: CGPoint

    init(start: CGPoint, end: CGPoint, color: NSColor = .red, width: CGFloat = 2.0) {
        self.startPoint = start
        self.endPoint = end
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)
        super.init(bounds: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
        self.strokeColor = color
        self.strokeWidth = width
    }

    override func draw(in context: CGContext) {
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
    }

    override func hitTest(point: CGPoint) -> Bool {
        let threshold: CGFloat = max(8, strokeWidth + 4)
        return distanceFromPointToLineSegment(point: point, start: startPoint, end: endPoint) < threshold
    }
}

// MARK: - Text Annotation

class TextAnnotationItem: BaseAnnotation {
    var text: String = ""
    var font: NSFont = .systemFont(ofSize: 16, weight: .bold)
    var textColor: NSColor = .white
    var backgroundColor: NSColor = .red
    var style: TextStyle = .whitePillRed

    enum TextStyle: String, CaseIterable {
        case whitePillRed
        case blackYellow
        case whiteDark
        case largeBoldShadow
        case monoDark
        case handwriting
        case plainBlack
    }

    init(at point: CGPoint, text: String = "", style: TextStyle = .whitePillRed) {
        self.text = text
        self.style = style
        super.init(bounds: CGRect(x: point.x, y: point.y, width: 200, height: 30))
        applyStyle(style)
    }

    func applyStyle(_ style: TextStyle) {
        self.style = style
        switch style {
        case .whitePillRed:
            font = .systemFont(ofSize: 16, weight: .bold)
            textColor = .white
            backgroundColor = .red
        case .blackYellow:
            font = .systemFont(ofSize: 16, weight: .bold)
            textColor = .black
            backgroundColor = .yellow
        case .whiteDark:
            font = .systemFont(ofSize: 16, weight: .medium)
            textColor = .white
            backgroundColor = NSColor(white: 0.15, alpha: 0.9)
        case .largeBoldShadow:
            font = .systemFont(ofSize: 28, weight: .heavy)
            textColor = .white
            backgroundColor = .clear
        case .monoDark:
            font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
            textColor = NSColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 1.0)
            backgroundColor = NSColor(white: 0.1, alpha: 0.9)
        case .handwriting:
            if let hFont = NSFont(name: "Bradley Hand", size: 18) {
                font = hFont
            } else {
                font = .systemFont(ofSize: 18, weight: .regular)
            }
            textColor = .black
            backgroundColor = .clear
        case .plainBlack:
            font = .systemFont(ofSize: 16, weight: .regular)
            textColor = .black
            backgroundColor = .clear
        }
    }

    override func draw(in context: CGContext) {
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attrString.size()
        let padding: CGFloat = 8

        // Recalculate bounds to fit text
        bounds = CGRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )

        // Draw background
        if backgroundColor != .clear {
            context.saveGState()
            let bgRect = bounds
            let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            context.setFillColor(backgroundColor.cgColor)
            context.addPath(bgPath)
            context.fillPath()
            context.restoreGState()
        }

        // Draw shadow for largeBoldShadow style
        if style == .largeBoldShadow {
            let shadowAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black.withAlphaComponent(0.6),
            ]
            let shadowString = NSAttributedString(string: text, attributes: shadowAttributes)
            let shadowPoint = CGPoint(x: bounds.origin.x + padding + 2, y: bounds.origin.y + padding + 2)
            NSGraphicsContext.saveGraphicsState()
            do { let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
                NSGraphicsContext.current = nsContext
                shadowString.draw(at: shadowPoint)
            }
            NSGraphicsContext.restoreGraphicsState()
        }

        // Draw text
        let textPoint = CGPoint(x: bounds.origin.x + padding, y: bounds.origin.y + padding)
        NSGraphicsContext.saveGraphicsState()
        do { let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.current = nsContext
            attrString.draw(at: textPoint)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}

// MARK: - Counter Annotation

class CounterAnnotation: BaseAnnotation {
    var number: Int

    init(at center: CGPoint, number: Int, color: NSColor = .red) {
        self.number = number
        let diameter: CGFloat = 32
        super.init(bounds: CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        self.strokeColor = color
    }

    override func draw(in context: CGContext) {
        let diameter = min(bounds.width, bounds.height)
        let circleRect = CGRect(
            x: bounds.midX - diameter / 2,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        )

        // Draw filled circle
        context.setFillColor(strokeColor.cgColor)
        context.fillEllipse(in: circleRect)

        // Draw white number centered
        let text = "\(number)"
        let font = NSFont.systemFont(ofSize: diameter * 0.55, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attrString.size()
        let textPoint = CGPoint(
            x: circleRect.midX - textSize.width / 2,
            y: circleRect.midY - textSize.height / 2
        )

        NSGraphicsContext.saveGraphicsState()
        do { let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.current = nsContext
            attrString.draw(at: textPoint)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    override func hitTest(point: CGPoint) -> Bool {
        let cx = bounds.midX
        let cy = bounds.midY
        let r = min(bounds.width, bounds.height) / 2 + 4
        let dx = point.x - cx
        let dy = point.y - cy
        return dx * dx + dy * dy <= r * r
    }
}

// MARK: - Pencil / Highlighter Annotation

class PencilAnnotation: BaseAnnotation {
    var points: [CGPoint] = []
    var isHighlighter: Bool = false

    init(points: [CGPoint], color: NSColor = .red, width: CGFloat = 2.0, isHighlighter: Bool = false) {
        self.points = points
        self.isHighlighter = isHighlighter
        let calculatedBounds = PencilAnnotation.computeBounds(from: points)
        super.init(bounds: calculatedBounds)
        self.strokeColor = color
        self.strokeWidth = isHighlighter ? max(width, 12) : width
    }

    static func computeBounds(from points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func recalculateBounds() {
        bounds = PencilAnnotation.computeBounds(from: points)
    }

    override func draw(in context: CGContext) {
        guard points.count >= 2 else { return }

        context.saveGState()

        if isHighlighter {
            context.setBlendMode(.multiply)
            context.setAlpha(0.4)
        }

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw smooth path using Catmull-Rom interpolation via cubic Bezier approximation
        context.move(to: points[0])

        if points.count == 2 {
            context.addLine(to: points[1])
        } else {
            for i in 1..<points.count {
                let p0 = points[max(0, i - 2)]
                let p1 = points[i - 1]
                let p2 = points[i]
                let p3 = points[min(points.count - 1, i + 1)]

                // Catmull-Rom to cubic Bezier control points
                let cp1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / 6.0,
                    y: p1.y + (p2.y - p0.y) / 6.0
                )
                let cp2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / 6.0,
                    y: p2.y - (p3.y - p1.y) / 6.0
                )

                context.addCurve(to: p2, control1: cp1, control2: cp2)
            }
        }

        context.strokePath()
        context.restoreGState()
    }

    override func hitTest(point: CGPoint) -> Bool {
        let threshold: CGFloat = max(8, strokeWidth + 4)
        for i in 1..<points.count {
            if distanceFromPointToLineSegment(point: point, start: points[i - 1], end: points[i]) < threshold {
                return true
            }
        }
        return false
    }
}

// MARK: - Blur Annotation

class BlurAnnotation: BaseAnnotation {
    var radius: CGFloat = 10
    var isPixelate: Bool = false

    init(bounds: CGRect, isPixelate: Bool = false) {
        self.isPixelate = isPixelate
        super.init(bounds: bounds)
        self.strokeColor = .gray
    }

    override func draw(in context: CGContext) {
        // Draw a subtle dashed border to indicate the blur region
        // The actual blur rendering is handled in AnnotationCanvas
        context.setStrokeColor(NSColor.systemGray.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.0)
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.stroke(bounds)
        context.setLineDash(phase: 0, lengths: [])
    }
}

// MARK: - Spotlight Annotation

class SpotlightAnnotation: BaseAnnotation {
    init(spotlightBounds: CGRect) {
        super.init(bounds: spotlightBounds)
        self.strokeColor = .clear
    }

    override func draw(in context: CGContext) {
        // The spotlight effect (dark overlay with cutout) is rendered by AnnotationCanvas.
        // Here we just draw a subtle border around the spotlight region for feedback.
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.5)
        context.stroke(bounds)
    }
}

// MARK: - Crop Annotation

class CropAnnotation: BaseAnnotation {
    override func draw(in context: CGContext) {
        // Draw the crop region border
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.0)
        context.stroke(bounds)

        // Draw rule-of-thirds grid lines
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(0.5)

        let thirdW = bounds.width / 3
        let thirdH = bounds.height / 3

        for i in 1...2 {
            let x = bounds.origin.x + thirdW * CGFloat(i)
            context.move(to: CGPoint(x: x, y: bounds.minY))
            context.addLine(to: CGPoint(x: x, y: bounds.maxY))

            let y = bounds.origin.y + thirdH * CGFloat(i)
            context.move(to: CGPoint(x: bounds.minX, y: y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }
        context.strokePath()

        // Draw dark overlay outside the crop region
        // We draw 4 rectangles around the crop area
        context.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)

        let canvasBounds = context.boundingBoxOfClipPath

        // Top
        let topRect = CGRect(x: canvasBounds.minX, y: canvasBounds.minY,
                             width: canvasBounds.width, height: bounds.minY - canvasBounds.minY)
        if topRect.height > 0 { context.fill(topRect) }

        // Bottom
        let bottomRect = CGRect(x: canvasBounds.minX, y: bounds.maxY,
                                width: canvasBounds.width, height: canvasBounds.maxY - bounds.maxY)
        if bottomRect.height > 0 { context.fill(bottomRect) }

        // Left
        let leftRect = CGRect(x: canvasBounds.minX, y: bounds.minY,
                              width: bounds.minX - canvasBounds.minX, height: bounds.height)
        if leftRect.width > 0 { context.fill(leftRect) }

        // Right
        let rightRect = CGRect(x: bounds.maxX, y: bounds.minY,
                               width: canvasBounds.maxX - bounds.maxX, height: bounds.height)
        if rightRect.width > 0 { context.fill(rightRect) }
    }
}

// MARK: - Black Out Annotation

class BlackOutAnnotation: BaseAnnotation {
    override func draw(in context: CGContext) {
        // Fill the bounds rect with solid strokeColor (default black)
        context.setFillColor(strokeColor.cgColor)
        context.fill(bounds)
    }
}

// MARK: - Magnifier Annotation

class MagnifierAnnotation: BaseAnnotation {
    /// The region of the background image to zoom into
    var sourceRect: CGRect
    /// Zoom factor (2x, 3x, etc.)
    var zoomFactor: CGFloat = 2.0
    /// Where to draw the magnified view (circle position)
    var displayCenter: CGPoint
    var displayRadius: CGFloat = 60

    init(sourceRect: CGRect, displayCenter: CGPoint) {
        self.sourceRect = sourceRect
        self.displayCenter = displayCenter
        super.init(bounds: CGRect(
            x: displayCenter.x - 60,
            y: displayCenter.y - 60,
            width: 120,
            height: 120
        ))
    }

    override func draw(in context: CGContext) {
        // The actual magnified content is drawn by AnnotationCanvas
        // which has access to the background image. Here we just draw
        // the border/frame of the magnifier callout.

        let circleRect = CGRect(
            x: displayCenter.x - displayRadius,
            y: displayCenter.y - displayRadius,
            width: displayRadius * 2,
            height: displayRadius * 2
        )

        // Draw white border
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: circleRect)

        // Draw shadow (dark outer ring)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: circleRect.insetBy(dx: -2, dy: -2))

        // Draw zoom label
        let text = "\(Int(zoomFactor))x"
        let font = NSFont.systemFont(ofSize: 10, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.6)
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrString.size()

        NSGraphicsContext.saveGraphicsState()
        do { let nsCtx = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.current = nsCtx
            attrString.draw(at: CGPoint(
                x: circleRect.midX - textSize.width / 2,
                y: circleRect.maxY + 4
            ))
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    override func hitTest(point: CGPoint) -> Bool {
        let dx = point.x - displayCenter.x
        let dy = point.y - displayCenter.y
        return sqrt(dx * dx + dy * dy) <= displayRadius
    }
}

// MARK: - Image Annotation

class ImageAnnotation: BaseAnnotation {
    var image: NSImage

    init(image: NSImage, at point: CGPoint) {
        self.image = image
        let size = image.size
        super.init(bounds: CGRect(x: point.x, y: point.y, width: size.width, height: size.height))
    }

    override func draw(in context: CGContext) {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            // In flipped coordinate system, flip the image drawing within bounds
            context.saveGState()
            context.translateBy(x: bounds.origin.x, y: bounds.origin.y + bounds.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))
            context.restoreGState()
        }
    }
}

// MARK: - Geometry Helpers

/// Computes the distance from a point to a line segment defined by two endpoints.
func distanceFromPointToLineSegment(point: CGPoint, start: CGPoint, end: CGPoint) -> CGFloat {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let lengthSquared = dx * dx + dy * dy

    if lengthSquared == 0 {
        // start == end
        let px = point.x - start.x
        let py = point.y - start.y
        return sqrt(px * px + py * py)
    }

    // Parameter t of the closest point on the segment
    var t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
    t = max(0, min(1, t))

    let closestX = start.x + t * dx
    let closestY = start.y + t * dy
    let px = point.x - closestX
    let py = point.y - closestY
    return sqrt(px * px + py * py)
}
