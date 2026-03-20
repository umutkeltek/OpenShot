// BlurTool.swift
// OpenShot
//
// CIFilter-based blur and pixelate rendering helper.
// Provides static methods to apply Gaussian blur or pixelation to a CGImage region.

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import os

private let logger = Logger(subsystem: "com.openshot.app", category: "BlurRenderer")

struct BlurRenderer {

    /// Shared CIContext for efficient reuse across calls.
    private static let ciContext: CIContext = {
        CIContext(options: [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false,
        ])
    }()

    /// Applies a Gaussian blur to a rectangular region of the source image.
    ///
    /// - Parameters:
    ///   - image: The full source CGImage.
    ///   - rect: The region to blur, in image pixel coordinates.
    ///   - radius: The blur radius in pixels.
    /// - Returns: A CGImage containing only the blurred region, or nil if the operation fails.
    static func applyBlur(to image: CGImage, in rect: CGRect, radius: CGFloat) -> CGImage? {
        guard rect.width > 0, rect.height > 0, radius > 0 else {
            logger.warning("Invalid blur parameters: rect=\(rect.debugDescription), radius=\(radius)")
            return nil
        }

        let ciImage = CIImage(cgImage: image)

        // Clamp the image first so blur edge artifacts don't create transparent borders
        let clampFilter = CIFilter.affineClamp()
        clampFilter.inputImage = ciImage
        clampFilter.transform = CGAffineTransform.identity

        guard let clamped = clampFilter.outputImage else {
            logger.error("Failed to create clamped image for blur")
            return nil
        }

        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = clamped
        blurFilter.radius = Float(radius)

        guard let blurredFull = blurFilter.outputImage else {
            logger.error("Gaussian blur filter produced no output")
            return nil
        }

        // Crop back to the requested rect
        let cropped = blurredFull.cropped(to: rect)

        return ciContext.createCGImage(cropped, from: rect)
    }

    /// Applies pixelation to a rectangular region of the source image.
    ///
    /// - Parameters:
    ///   - image: The full source CGImage.
    ///   - rect: The region to pixelate, in image pixel coordinates.
    ///   - blockSize: The size of each pixel block.
    /// - Returns: A CGImage containing only the pixelated region, or nil if the operation fails.
    static func applyPixelate(to image: CGImage, in rect: CGRect, blockSize: CGFloat) -> CGImage? {
        guard rect.width > 0, rect.height > 0, blockSize > 0 else {
            logger.warning("Invalid pixelate parameters: rect=\(rect.debugDescription), blockSize=\(blockSize)")
            return nil
        }

        let ciImage = CIImage(cgImage: image)
        let cropped = ciImage.cropped(to: rect)

        let pixelateFilter = CIFilter.pixellate()
        pixelateFilter.inputImage = cropped
        pixelateFilter.scale = Float(blockSize)
        pixelateFilter.center = CGPoint(x: rect.midX, y: rect.midY)

        guard let output = pixelateFilter.outputImage else {
            logger.error("Pixellate filter produced no output")
            return nil
        }

        // Crop to exact rect in case pixelation shifts the output
        let finalOutput = output.cropped(to: rect)
        return ciContext.createCGImage(finalOutput, from: rect)
    }

    /// Applies the appropriate effect (blur or pixelate) based on a BlurAnnotation's configuration.
    ///
    /// - Parameters:
    ///   - image: The full source CGImage (background screenshot).
    ///   - annotation: The BlurAnnotation describing the region and effect type.
    ///   - viewBounds: The size of the annotation canvas view (for coordinate conversion).
    /// - Returns: A tuple of (processedImage, destinationRect in view coordinates), or nil.
    static func applyEffect(
        from image: CGImage,
        annotation: BlurAnnotation,
        viewBounds: CGSize
    ) -> (CGImage, CGRect)? {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let scaleX = imageWidth / viewBounds.width
        let scaleY = imageHeight / viewBounds.height

        // Convert view-space bounds to image-space (Core Image uses bottom-left origin)
        let imageRect = CGRect(
            x: annotation.bounds.origin.x * scaleX,
            y: (viewBounds.height - annotation.bounds.maxY) * scaleY,
            width: annotation.bounds.width * scaleX,
            height: annotation.bounds.height * scaleY
        )

        let result: CGImage?
        if annotation.isPixelate {
            result = applyPixelate(to: image, in: imageRect, blockSize: annotation.radius * scaleX)
        } else {
            result = applyBlur(to: image, in: imageRect, radius: annotation.radius * scaleX)
        }

        guard let processedImage = result else { return nil }

        return (processedImage, annotation.bounds)
    }
}
