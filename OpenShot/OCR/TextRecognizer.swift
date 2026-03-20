// TextRecognizer.swift
// OpenShot
//
// On-device OCR using the Vision framework. Performs accurate text
// recognition on NSImage inputs, preserving spatial layout (line breaks
// and reading order), and optionally copies results to the clipboard.

import Vision
import AppKit
import os

// MARK: - TextRecognizer

final class TextRecognizer {

    private let logger = Logger(subsystem: "com.openshot", category: "ocr")

    /// Recognize all text in the given image and return it as a plain string,
    /// preserving approximate line breaks based on bounding-box Y positions.
    func recognizeText(in image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OpenShotError.ocrFailed("Failed to obtain CGImage from NSImage")
        }

        return try await recognizeText(in: cgImage)
    }

    /// Recognize all text in the given CGImage.
    func recognizeText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OpenShotError.ocrFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = Self.buildText(from: observations)
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OpenShotError.ocrFailed(error.localizedDescription))
            }
        }
    }

    /// Recognize text and copy it to the system clipboard.
    /// Returns the recognized text string.
    @discardableResult
    func recognizeAndCopy(from image: NSImage) async throws -> String {
        let text = try await recognizeText(in: image)

        guard !text.isEmpty else {
            logger.info("OCR produced no text")
            return ""
        }

        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }

        logger.info("OCR result copied to clipboard: \(text.count) characters")
        return text
    }

    /// Return structured observations with bounding boxes for more advanced use.
    func recognizeTextWithBounds(in image: NSImage) async throws -> [(text: String, bounds: CGRect)] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OpenShotError.ocrFailed("Failed to obtain CGImage from NSImage")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OpenShotError.ocrFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results: [(text: String, bounds: CGRect)] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return (text: candidate.string, bounds: observation.boundingBox)
                }

                continuation.resume(returning: results)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OpenShotError.ocrFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Text Assembly

    /// Build a readable string from Vision observations, grouping text
    /// by Y position to reconstruct lines in reading order.
    private static func buildText(from observations: [VNRecognizedTextObservation]) -> String {
        guard !observations.isEmpty else { return "" }

        // Sort observations top-to-bottom (VNRecognizedTextObservation uses normalized
        // coordinates where Y=1 is top, Y=0 is bottom).
        let sorted = observations.sorted { a, b in
            let ay = a.boundingBox.origin.y + a.boundingBox.height / 2
            let by = b.boundingBox.origin.y + b.boundingBox.height / 2
            // If on roughly the same line, sort left to right
            if abs(ay - by) < 0.008 {
                return a.boundingBox.origin.x < b.boundingBox.origin.x
            }
            // Otherwise sort top to bottom (higher Y = higher on screen)
            return ay > by
        }

        // Group into lines based on Y proximity
        var lines: [[VNRecognizedTextObservation]] = []
        var currentLine: [VNRecognizedTextObservation] = []
        var lastCenterY: CGFloat = -1

        for observation in sorted {
            let centerY = observation.boundingBox.origin.y + observation.boundingBox.height / 2

            if lastCenterY >= 0 && abs(centerY - lastCenterY) > 0.008 {
                // New line
                if !currentLine.isEmpty {
                    // Sort current line left to right
                    currentLine.sort { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
                    lines.append(currentLine)
                }
                currentLine = []
            }

            currentLine.append(observation)
            lastCenterY = centerY
        }

        // Don't forget the last line
        if !currentLine.isEmpty {
            currentLine.sort { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
            lines.append(currentLine)
        }

        // Build the final string
        let textLines: [String] = lines.map { lineObservations in
            lineObservations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: " ")
        }

        return textLines.joined(separator: "\n")
    }
}
