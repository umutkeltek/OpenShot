import AppKit
import CoreGraphics
import ImageIO

extension NSImage {

    /// Returns a new image resized to the specified dimensions.
    /// Uses high-quality interpolation for the resize operation.
    func resized(to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        self.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: self.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }

    /// Returns a new image cropped to the specified rectangle.
    /// The rect is in the image's coordinate system (origin bottom-left).
    func cropped(to rect: CGRect) -> NSImage {
        guard let sourceCGImage = self.cgImage else {
            return self
        }
        guard let croppedCGImage = sourceCGImage.cropping(to: rect) else {
            return self
        }
        return NSImage.fromCGImage(croppedCGImage)
    }

    /// Computed property that returns a CGImage representation of this NSImage.
    /// Returns nil if the conversion fails.
    var cgImage: CGImage? {
        var rect = NSRect(origin: .zero, size: self.size)
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// Returns PNG-encoded data for this image, or nil if encoding fails.
    func pngData() -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }

    /// Returns JPEG-encoded data for this image at the specified quality (0.0 to 1.0).
    func jpegData(quality: CGFloat = 0.8) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: quality]
        )
    }

    /// Returns TIFF-encoded data for this image using the existing tiffRepresentation.
    func tiffData() -> Data? {
        return self.tiffRepresentation
    }

    /// Rotate image by given degrees (90, -90, 180).
    func rotated(by degrees: CGFloat) -> NSImage {
        let radians = degrees * .pi / 180
        var newSize = size
        if abs(degrees).truncatingRemainder(dividingBy: 180) == 90 {
            newSize = NSSize(width: size.height, height: size.width)
        }
        let rotatedImage = NSImage(size: newSize)
        rotatedImage.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()
        draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
        rotatedImage.unlockFocus()
        return rotatedImage
    }

    /// Flip image horizontally (mirror along vertical axis).
    func flippedHorizontally() -> NSImage {
        let flipped = NSImage(size: size)
        flipped.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: size.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()
        draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
        flipped.unlockFocus()
        return flipped
    }

    /// Flip image vertically (mirror along horizontal axis).
    func flippedVertically() -> NSImage {
        let flipped = NSImage(size: size)
        flipped.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: size.height)
        transform.scaleX(by: 1, yBy: -1)
        transform.concat()
        draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
        flipped.unlockFocus()
        return flipped
    }

    /// Returns WebP-encoded data for this image at the specified quality (0.0 to 1.0).
    func webpData(quality: CGFloat = 0.8) -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "org.webmproject.webp" as CFString,
            1, nil
        ) else { return nil }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Returns HEIC-encoded data for this image at the specified quality (0.0 to 1.0).
    func heicData(quality: CGFloat = 0.8) -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.heic" as CFString,
            1, nil
        ) else { return nil }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Creates an NSImage from a CGImage, preserving the CGImage's pixel dimensions.
    static func fromCGImage(_ cgImage: CGImage) -> NSImage {
        let size = NSSize(
            width: cgImage.width,
            height: cgImage.height
        )
        return NSImage(cgImage: cgImage, size: size)
    }
}
