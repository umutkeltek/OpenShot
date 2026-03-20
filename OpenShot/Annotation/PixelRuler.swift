// PixelRuler.swift
// OpenShot
//
// Measurement annotation that shows pixel distance between two points.
// Inspired by Shottr's ruler tool — renders a line with dimension label.

import AppKit
import os

/// Annotation that measures pixel distance between two points.
/// Renders as a line with dimension label (red background, white text).
class RulerAnnotation: BaseAnnotation {
    var startPoint: CGPoint
    var endPoint: CGPoint
    var useRetinaPixels: Bool = true

    init(start: CGPoint, end: CGPoint) {
        self.startPoint = start
        self.endPoint = end
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)
        super.init(bounds: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
        self.strokeColor = .systemRed
        self.strokeWidth = 1
    }

    override func draw(in context: CGContext) {
        // 1. Draw measurement line with small perpendicular end caps
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)

        // Main line
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()

        // End caps (small perpendicular lines, 6px)
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let perpAngle = angle + .pi / 2
        let capLen: CGFloat = 6

        for point in [startPoint, endPoint] {
            let dx = cos(perpAngle) * capLen
            let dy = sin(perpAngle) * capLen
            context.move(to: CGPoint(x: point.x - dx, y: point.y - dy))
            context.addLine(to: CGPoint(x: point.x + dx, y: point.y + dy))
        }
        context.strokePath()

        // 2. Calculate pixel distance
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        let scaleFactor: CGFloat = useRetinaPixels ? (NSScreen.main?.backingScaleFactor ?? 2) : 1
        let pixelDistance = Int(distance * scaleFactor)

        // 3. Draw label at midpoint — red rounded rect with white text
        let midPoint = CGPoint(x: (startPoint.x + endPoint.x) / 2, y: (startPoint.y + endPoint.y) / 2)
        let text = "\(pixelDistance)px"
        let font = NSFont.systemFont(ofSize: 11, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrString.size()
        let padding: CGFloat = 4
        let labelRect = CGRect(
            x: midPoint.x - textSize.width / 2 - padding,
            y: midPoint.y - textSize.height / 2 - padding,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )

        // Draw red rounded background
        context.setFillColor(NSColor.systemRed.cgColor)
        let bgPath = CGPath(roundedRect: labelRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(bgPath)
        context.fillPath()

        // Draw text
        NSGraphicsContext.saveGraphicsState()
        do { let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.current = nsContext
            attrString.draw(at: CGPoint(x: labelRect.origin.x + padding, y: labelRect.origin.y + padding))
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    override func hitTest(point: CGPoint) -> Bool {
        // Check distance from point to line segment
        let dist = distanceFromPointToLineSegment(point: point, start: startPoint, end: endPoint)
        return dist < 8
    }
}
