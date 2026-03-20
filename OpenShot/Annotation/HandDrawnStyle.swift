// HandDrawnStyle.swift
// OpenShot
//
// Utility that adds hand-drawn/sketchy rendering to annotation paths.
// Inspired by Shottr's hand-drawn annotation style.

import AppKit

/// Adds a hand-drawn / sketchy appearance to geometric paths.
/// Works by adding small random perturbations to path control points.
struct HandDrawnStyle {

    /// Roughness of the hand-drawn effect (0 = clean, 1 = very rough)
    var roughness: CGFloat = 0.5

    /// Create a hand-drawn rectangle path
    func roughRect(_ rect: CGRect) -> NSBezierPath {
        let path = NSBezierPath()
        let jitter = roughness * 2

        let tl = jitteredPoint(CGPoint(x: rect.minX, y: rect.minY), amount: jitter)
        let tr = jitteredPoint(CGPoint(x: rect.maxX, y: rect.minY), amount: jitter)
        let br = jitteredPoint(CGPoint(x: rect.maxX, y: rect.maxY), amount: jitter)
        let bl = jitteredPoint(CGPoint(x: rect.minX, y: rect.maxY), amount: jitter)

        path.move(to: tl)
        addRoughLine(path, from: tl, to: tr, jitter: jitter)
        addRoughLine(path, from: tr, to: br, jitter: jitter)
        addRoughLine(path, from: br, to: bl, jitter: jitter)
        addRoughLine(path, from: bl, to: tl, jitter: jitter)
        path.close()

        return path
    }

    /// Create a hand-drawn ellipse path
    func roughEllipse(in rect: CGRect) -> NSBezierPath {
        let path = NSBezierPath()
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width / 2
        let ry = rect.height / 2
        let jitter = roughness * 1.5

        let segments = 32
        for i in 0...segments {
            let angle = CGFloat(i) / CGFloat(segments) * 2 * .pi
            let x = cx + rx * cos(angle) + CGFloat.random(in: -jitter...jitter)
            let y = cy + ry * sin(angle) + CGFloat.random(in: -jitter...jitter)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.line(to: CGPoint(x: x, y: y))
            }
        }
        path.close()
        return path
    }

    /// Create a hand-drawn line from start to end
    func roughLine(from start: CGPoint, to end: CGPoint) -> NSBezierPath {
        let path = NSBezierPath()
        let jitter = roughness * 1.5
        path.move(to: jitteredPoint(start, amount: jitter * 0.5))
        addRoughLine(path, from: start, to: end, jitter: jitter)
        return path
    }

    /// Create a hand-drawn arrow
    func roughArrow(from start: CGPoint, to end: CGPoint, headSize: CGFloat = 12) -> NSBezierPath {
        let path = roughLine(from: start, to: end)

        // Arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let jitter = roughness * 1
        let leftAngle = angle + .pi + .pi / 6
        let rightAngle = angle + .pi - .pi / 6

        let leftPoint = jitteredPoint(CGPoint(
            x: end.x + headSize * cos(leftAngle),
            y: end.y + headSize * sin(leftAngle)
        ), amount: jitter)

        let rightPoint = jitteredPoint(CGPoint(
            x: end.x + headSize * cos(rightAngle),
            y: end.y + headSize * sin(rightAngle)
        ), amount: jitter)

        let endJittered = jitteredPoint(end, amount: jitter * 0.3)
        path.move(to: leftPoint)
        path.line(to: endJittered)
        path.line(to: rightPoint)

        return path
    }

    // MARK: - Private

    private func jitteredPoint(_ point: CGPoint, amount: CGFloat) -> CGPoint {
        CGPoint(
            x: point.x + CGFloat.random(in: -amount...amount),
            y: point.y + CGFloat.random(in: -amount...amount)
        )
    }

    private func addRoughLine(_ path: NSBezierPath, from start: CGPoint, to end: CGPoint, jitter: CGFloat) {
        // Add 2-3 intermediate points with slight jitter for hand-drawn feel
        let segments = 3
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let x = start.x + (end.x - start.x) * t + CGFloat.random(in: -jitter...jitter)
            let y = start.y + (end.y - start.y) * t + CGFloat.random(in: -jitter...jitter)
            path.line(to: CGPoint(x: x, y: y))
        }
    }
}
