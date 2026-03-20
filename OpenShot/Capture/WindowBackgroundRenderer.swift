import AppKit
import CoreGraphics
import os

/// Renders window capture images onto beautiful styled backgrounds with
/// optional drop shadows and rounded corners, similar to CleanShot X.
struct WindowBackgroundRenderer {

    private static let logger = Logger(subsystem: "com.openshot", category: "background")

    // MARK: - Types

    /// The background style to render behind the window capture.
    enum BackgroundStyle {
        /// Transparent background (no fill).
        case none
        /// A single solid color fill.
        case solid(NSColor)
        /// A two-stop linear gradient in the given direction.
        case gradient(NSColor, NSColor, GradientDirection)
        /// One of the built-in preset gradients.
        case preset(PresetBackground)
    }

    /// Direction for linear gradient backgrounds.
    enum GradientDirection {
        case topToBottom
        case leftToRight
        case diagonal
    }

    /// Built-in gradient presets with curated color pairs.
    enum PresetBackground: String, CaseIterable, Identifiable {
        case oceanBlue
        case sunset
        case forest
        case midnight
        case rose
        case slate
        case lavender
        case aurora

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .oceanBlue: return "Ocean Blue"
            case .sunset:    return "Sunset"
            case .forest:    return "Forest"
            case .midnight:  return "Midnight"
            case .rose:      return "Rose"
            case .slate:     return "Slate"
            case .lavender:  return "Lavender"
            case .aurora:    return "Aurora"
            }
        }

        /// The two gradient stops for this preset.
        var colors: (NSColor, NSColor) {
            switch self {
            case .oceanBlue:
                return (
                    NSColor(calibratedRed: 0.11, green: 0.40, blue: 0.87, alpha: 1.0),  // #1C66DE
                    NSColor(calibratedRed: 0.23, green: 0.80, blue: 0.82, alpha: 1.0)   // #3BCCD1
                )
            case .sunset:
                return (
                    NSColor(calibratedRed: 0.96, green: 0.46, blue: 0.20, alpha: 1.0),  // #F57533
                    NSColor(calibratedRed: 0.69, green: 0.24, blue: 0.73, alpha: 1.0)   // #B03DBA
                )
            case .forest:
                return (
                    NSColor(calibratedRed: 0.13, green: 0.59, blue: 0.33, alpha: 1.0),  // #219654
                    NSColor(calibratedRed: 0.17, green: 0.73, blue: 0.67, alpha: 1.0)   // #2BBAAB
                )
            case .midnight:
                return (
                    NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.34, alpha: 1.0),  // #171C57
                    NSColor(calibratedRed: 0.36, green: 0.16, blue: 0.56, alpha: 1.0)   // #5C298F
                )
            case .rose:
                return (
                    NSColor(calibratedRed: 0.93, green: 0.35, blue: 0.47, alpha: 1.0),  // #ED5978
                    NSColor(calibratedRed: 0.87, green: 0.22, blue: 0.28, alpha: 1.0)   // #DE3847
                )
            case .slate:
                return (
                    NSColor(calibratedRed: 0.29, green: 0.33, blue: 0.39, alpha: 1.0),  // #4A5463
                    NSColor(calibratedRed: 0.55, green: 0.59, blue: 0.63, alpha: 1.0)   // #8C96A1
                )
            case .lavender:
                return (
                    NSColor(calibratedRed: 0.58, green: 0.34, blue: 0.87, alpha: 1.0),  // #9457DE
                    NSColor(calibratedRed: 0.89, green: 0.47, blue: 0.76, alpha: 1.0)   // #E378C2
                )
            case .aurora:
                return (
                    NSColor(calibratedRed: 0.18, green: 0.80, blue: 0.44, alpha: 1.0),  // #2ECC71
                    NSColor(calibratedRed: 0.36, green: 0.26, blue: 0.83, alpha: 1.0)   // #5C42D4
                )
            }
        }
    }

    // MARK: - Public API

    /// Apply a styled background to a window capture image.
    ///
    /// - Parameters:
    ///   - windowImage: The captured window image (typically with transparency around it).
    ///   - style: The background fill style.
    ///   - padding: Points of padding between the window edge and the background edge.
    ///   - shadowEnabled: Whether to render a drop shadow beneath the window.
    ///   - shadowOpacity: Opacity of the drop shadow (0.0 transparent to 1.0 fully opaque).
    ///   - cornerRadius: Corner radius applied to the window image for rounded corners.
    /// - Returns: A new composited image with the background, shadow, and window.
    static func apply(
        to windowImage: NSImage,
        style: BackgroundStyle,
        padding: CGFloat = 32,
        shadowEnabled: Bool = true,
        shadowOpacity: CGFloat = 0.3,
        cornerRadius: CGFloat = 10
    ) -> NSImage {
        let imageSize = windowImage.size
        let totalSize = NSSize(
            width: imageSize.width + padding * 2,
            height: imageSize.height + padding * 2
        )

        let result = NSImage(size: totalSize)
        result.lockFocus()

        guard let context = NSGraphicsContext.current else {
            result.unlockFocus()
            logger.error("Failed to obtain NSGraphicsContext for background rendering")
            return windowImage
        }

        let cgContext = context.cgContext
        context.imageInterpolation = .high

        // 1. Draw background fill.
        let bgRect = NSRect(origin: .zero, size: totalSize)
        drawBackground(style: style, in: bgRect)

        // 2. Calculate the rect where the window image will be drawn.
        let imageRect = NSRect(
            x: padding,
            y: padding,
            width: imageSize.width,
            height: imageSize.height
        )

        // 3. Draw drop shadow if enabled.
        //    We draw a filled rounded rect with the shadow applied, then
        //    draw the actual window image clipped to the same rounded rect.
        if shadowEnabled {
            cgContext.saveGState()

            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0, height: -4)
            shadow.shadowBlurRadius = 20
            shadow.shadowColor = NSColor.black.withAlphaComponent(shadowOpacity)
            shadow.set()

            // Draw an opaque rounded rect to cast the shadow.
            // This ensures the shadow shape matches the rounded corners.
            let shadowPath = NSBezierPath(roundedRect: imageRect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.black.setFill()
            shadowPath.fill()

            cgContext.restoreGState()
        }

        // 4. Draw the window image clipped to rounded corners.
        cgContext.saveGState()

        let clipPath = NSBezierPath(roundedRect: imageRect, xRadius: cornerRadius, yRadius: cornerRadius)
        clipPath.addClip()

        windowImage.draw(
            in: imageRect,
            from: NSRect(origin: .zero, size: imageSize),
            operation: .sourceOver,
            fraction: 1.0
        )

        cgContext.restoreGState()

        result.unlockFocus()

        logger.info("Background applied: \(Int(totalSize.width))x\(Int(totalSize.height)) with \(Int(padding))pt padding")
        return result
    }

    // MARK: - Private Helpers

    /// Draw the background fill for the given style into the specified rect.
    private static func drawBackground(style: BackgroundStyle, in rect: NSRect) {
        switch style {
        case .none:
            // Transparent — nothing to draw.
            break

        case .solid(let color):
            color.setFill()
            rect.fill()

        case .gradient(let color1, let color2, let direction):
            drawGradient(color1: color1, color2: color2, direction: direction, in: rect)

        case .preset(let preset):
            let (color1, color2) = preset.colors
            drawGradient(color1: color1, color2: color2, direction: .diagonal, in: rect)
        }
    }

    /// Draw a two-stop linear gradient in the given direction.
    private static func drawGradient(
        color1: NSColor,
        color2: NSColor,
        direction: GradientDirection,
        in rect: NSRect
    ) {
        guard let gradient = NSGradient(starting: color1, ending: color2) else {
            // Fallback to solid fill with the first color.
            color1.setFill()
            rect.fill()
            return
        }

        let angle: CGFloat
        switch direction {
        case .topToBottom: angle = 270
        case .leftToRight: angle = 0
        case .diagonal:    angle = 315
        }

        gradient.draw(in: rect, angle: angle)
    }
}
