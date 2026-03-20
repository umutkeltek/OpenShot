// SmartBlur.swift
// OpenShot
//
// Smart blur that uses Vision framework to detect text regions and only blurs
// those regions, leaving non-text content visible.

import AppKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import os

struct SmartBlur {
    private static let logger = Logger(subsystem: "com.openshot", category: "smart-blur")

    /// Detect text regions in the given image within the specified rect.
    /// Returns an array of rects (in image coordinates) where text was found.
    static func detectTextRegions(in image: CGImage, within rect: CGRect? = nil) -> [CGRect] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast  // fast is sufficient for detection
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])

        guard let observations = request.results else { return [] }

        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)

        var textRects: [CGRect] = []
        for observation in observations {
            // Vision returns normalized coordinates (0-1), bottom-left origin
            let bbox = observation.boundingBox
            let imageRect = CGRect(
                x: bbox.origin.x * imageWidth,
                y: (1 - bbox.origin.y - bbox.height) * imageHeight,  // flip Y for top-left origin
                width: bbox.width * imageWidth,
                height: bbox.height * imageHeight
            )

            // If a constraining rect is provided, only include text rects that intersect it
            if let constraint = rect {
                if imageRect.intersects(constraint) {
                    textRects.append(imageRect.intersection(constraint))
                }
            } else {
                textRects.append(imageRect)
            }
        }

        return textRects
    }

    /// Apply blur ONLY to text regions within the given area of the image.
    /// Non-text areas remain sharp.
    static func applyTextOnlyBlur(
        to image: CGImage,
        in selectionRect: CGRect,
        blurRadius: CGFloat = 10
    ) -> CGImage? {
        let textRects = detectTextRegions(in: image, within: selectionRect)

        guard !textRects.isEmpty else {
            logger.debug("No text detected in selection, falling back to full blur")
            return nil  // caller should fall back to standard blur
        }

        logger.info("Smart blur: detected \(textRects.count) text regions")

        let ciImage = CIImage(cgImage: image)
        let context = CIContext()

        // Create a blurred version of the full image
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = ciImage
        blur.radius = Float(blurRadius)

        guard let blurredImage = blur.outputImage else { return nil }

        // Composite: use blurred version only in text regions, original elsewhere
        // We build a mask from the text rects
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        // Create mask image: white where text is (blur applied), black elsewhere (original kept)
        let maskSize = CGSize(width: width, height: height)
        guard let maskContext = CGContext(
            data: nil, width: Int(width), height: Int(height),
            bitsPerComponent: 8, bytesPerRow: Int(width),
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        // Fill with black (keep original)
        maskContext.setFillColor(gray: 0, alpha: 1)
        maskContext.fill(CGRect(origin: .zero, size: maskSize))

        // Fill text rects with white (use blurred)
        maskContext.setFillColor(gray: 1, alpha: 1)
        for rect in textRects {
            // Add small padding around text for cleaner blur
            let padded = rect.insetBy(dx: -4, dy: -4)
            maskContext.fill(padded)
        }

        guard let maskCGImage = maskContext.makeImage() else { return nil }
        let maskCIImage = CIImage(cgImage: maskCGImage)

        // Blend: where mask is white use blurred, where black use original
        let blend = CIFilter.blendWithMask()
        blend.inputImage = blurredImage
        blend.backgroundImage = ciImage
        blend.maskImage = maskCIImage

        guard let output = blend.outputImage else { return nil }
        return context.createCGImage(output, from: CGRect(origin: .zero, size: maskSize))
    }
}

/// Annotation for smart text-only blur regions.
class SmartBlurAnnotation: BaseAnnotation {
    var blurRadius: CGFloat = 10

    override func draw(in context: CGContext) {
        // Draw a subtle dashed border to indicate the smart blur region
        context.setStrokeColor(NSColor.systemPurple.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.stroke(bounds)
        context.setLineDash(phase: 0, lengths: [])

        // Draw "Smart Blur" label
        let font = NSFont.systemFont(ofSize: 9, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.systemPurple
        ]
        let label = NSAttributedString(string: "Smart Blur", attributes: attrs)
        let labelSize = label.size()

        NSGraphicsContext.saveGraphicsState()
        let nsCtx = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsCtx
        label.draw(at: CGPoint(x: bounds.origin.x + 2, y: bounds.origin.y - labelSize.height - 2))
        NSGraphicsContext.restoreGraphicsState()
    }
}
