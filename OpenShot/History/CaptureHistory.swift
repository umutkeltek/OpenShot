// CaptureHistory.swift
// OpenShot
//
// SwiftData-based capture history for tracking all screenshots,
// recordings, GIFs, and OCR captures with thumbnails.

import SwiftData
import AppKit
import os

// MARK: - SwiftData Model

@Model
final class CaptureRecord {
    var id: UUID
    var timestamp: Date
    var captureType: String  // "screenshot", "recording", "gif", "ocr"
    var filePath: String
    var thumbnailPath: String
    var width: Int
    var height: Int
    var fileSize: Int64
    var tags: String  // comma-separated for simplicity

    init(
        captureType: String,
        filePath: String,
        thumbnailPath: String = "",
        width: Int = 0,
        height: Int = 0,
        fileSize: Int64,
        tags: String = ""
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.captureType = captureType
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.tags = tags
    }
}

// MARK: - History Manager

@Observable
final class CaptureHistoryManager {

    static let shared = CaptureHistoryManager()

    private let logger = Logger(subsystem: "com.openshot", category: "history")
    /// Not `private` so `@testable import` can verify capture archiving
    /// always lands here regardless of `preferences.saveLocation`.
    let capturesDirectory: URL
    private let thumbnailsDirectory: URL
    private let modelContainer: ModelContainer?

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support")
        capturesDirectory = appSupport
            .appendingPathComponent("OpenShot/Captures", isDirectory: true)
        thumbnailsDirectory = appSupport
            .appendingPathComponent("OpenShot/Thumbnails", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create captures directory: \(error.localizedDescription)")
        }
        do {
            try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create thumbnails directory: \(error.localizedDescription)")
        }

        do {
            self.modelContainer = try ModelContainer(for: CaptureRecord.self)
        } catch {
            self.modelContainer = nil
            logger.error("Failed to create ModelContainer: \(error)")
        }

        logger.info("CaptureHistoryManager initialized – captures: \(self.capturesDirectory.path(percentEncoded: false))")
    }

    /// The single shared `ModelContainer` for `CaptureRecord`. Always create a
    /// fresh `ModelContext` per task/thread from this container via
    /// `makeContext()` — never share or pass a `ModelContext` instance across
    /// actor boundaries, and never call `ModelContainer(for:)`/
    /// `.modelContainer(for:)` elsewhere for this model type.
    var sharedContainer: ModelContainer {
        get throws {
            guard let modelContainer else {
                throw OpenShotError.fileIOFailed("ModelContainer not available")
            }
            return modelContainer
        }
    }

    /// Returns a new ModelContext from the shared container.
    func makeContext() throws -> ModelContext {
        return ModelContext(try sharedContainer)
    }

    // MARK: - Save Capture

    /// Saves a captured image to disk, generates a thumbnail, creates a
    /// `CaptureRecord`, inserts it into the provided model context, and
    /// returns the record.
    func saveCapture(
        image: NSImage,
        type: String,
        preferences: Preferences,
        modelContext: ModelContext
    ) throws -> CaptureRecord {
        let dateString = Self.dateFormatter.string(from: Date())

        // Determine file format and extension from preferences.
        let ext: String
        let imageData: Data

        switch preferences.imageFormat {
        case .png:
            ext = "png"
            guard let data = image.pngData() else {
                throw OpenShotError.fileIOFailed("Failed to create PNG data")
            }
            imageData = data

        case .jpeg:
            ext = "jpeg"
            guard let data = image.jpegData(quality: preferences.jpegQuality) else {
                throw OpenShotError.fileIOFailed("Failed to create JPEG data")
            }
            imageData = data

        case .tiff:
            ext = "tiff"
            guard let data = image.tiffRepresentation else {
                throw OpenShotError.fileIOFailed("Failed to create TIFF data")
            }
            imageData = data

        case .webp:
            ext = "webp"
            guard let data = image.webpData(quality: preferences.jpegQuality) else {
                throw OpenShotError.fileIOFailed("Failed to create WebP data")
            }
            imageData = data

        case .heic:
            ext = "heic"
            guard let data = image.heicData(quality: preferences.jpegQuality) else {
                throw OpenShotError.fileIOFailed("Failed to create HEIC data")
            }
            imageData = data
        }

        // Always archive to our own Application Support directory — never to
        // the user's configured save location. That directory is reserved
        // for explicit user "Save" actions (see QuickAccessOverlay.saveToFile),
        // which use their own naming template. Keeping these two writes fully
        // decoupled means History's retention cleanup (`cleanupOldCaptures`)
        // never deletes a file sitting in the user's visible folder.
        let filename = "OpenShot_\(dateString).\(ext)"
        let fileURL = capturesDirectory.appendingPathComponent(filename)
        let thumbFilename = "thumb_\(dateString).png"
        let thumbURL = thumbnailsDirectory.appendingPathComponent(thumbFilename)

        // Write full image.
        try imageData.write(to: fileURL)
        logger.debug("Saved capture to \(fileURL.path(percentEncoded: false))")

        // Generate and write thumbnail (200px max width).
        let thumbImage = Self.resizedForThumbnail(image, maxWidth: 200)
        if let thumbData = thumbImage.pngData() {
            try? thumbData.write(to: thumbURL)
        }

        // Create record.
        let record = CaptureRecord(
            captureType: type,
            filePath: fileURL.path,
            thumbnailPath: thumbURL.path,
            width: Int(image.size.width),
            height: Int(image.size.height),
            fileSize: Int64(imageData.count)
        )

        modelContext.insert(record)
        try modelContext.save()

        logger.info("CaptureRecord saved – type: \(type), size: \(imageData.count) bytes")
        return record
    }

    // MARK: - Save with Raw Data

    /// Saves raw file data (e.g. a video or GIF) and creates a history record.
    func saveCapture(
        data: Data,
        fileExtension: String,
        type: String,
        width: Int,
        height: Int,
        modelContext: ModelContext
    ) throws -> CaptureRecord {
        let dateString = Self.dateFormatter.string(from: Date())
        let filename = "OpenShot_\(dateString).\(fileExtension)"
        let fileURL = capturesDirectory.appendingPathComponent(filename)

        try data.write(to: fileURL)

        let record = CaptureRecord(
            captureType: type,
            filePath: fileURL.path,
            thumbnailPath: "",
            width: width,
            height: height,
            fileSize: Int64(data.count)
        )

        modelContext.insert(record)
        try modelContext.save()

        logger.info("CaptureRecord saved – type: \(type), extension: \(fileExtension)")
        return record
    }

    /// Moves a recording/GIF out of the temporary directory into the user's
    /// configured save location, then archives it via `saveRecording`. Used
    /// by both the MP4 and GIF stop-recording paths so the "file left behind
    /// in the temp directory, later auto-deleted" bug can only be fixed (or
    /// broken) in one place.
    ///
    /// If the move fails, the recording is archived at its original temp URL
    /// instead of throwing — losing the recording entirely would be worse
    /// than leaving it in temp. Likewise, if the history record itself fails
    /// to save, that's logged rather than thrown — by that point the file
    /// has already been physically relocated (or not), and callers need that
    /// real, on-disk location back regardless of whether the history entry
    /// could be recorded.
    @discardableResult
    func archiveRecording(
        tempURL: URL,
        type: String,
        preferences: Preferences,
        modelContext: ModelContext
    ) throws -> URL {
        let saveDir = preferences.saveLocation
        var finalURL = tempURL

        do {
            try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
            let destinationURL = saveDir.appendingPathComponent(tempURL.lastPathComponent)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            finalURL = destinationURL
        } catch {
            logger.warning("Failed to move \(type) to save location, archiving from temp instead: \(error.localizedDescription)")
        }

        do {
            try saveRecording(url: finalURL, type: type, modelContext: modelContext)
        } catch {
            logger.warning("Failed to save \(type) history record: \(error.localizedDescription)")
        }
        return finalURL
    }

    /// Creates a history record for a recording or GIF that was already
    /// written to disk elsewhere in the app.
    func saveRecording(url: URL, type: String, modelContext: ModelContext) throws {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? Int64) ?? 0
        let record = CaptureRecord(
            captureType: type,
            filePath: url.path,
            fileSize: fileSize
        )

        modelContext.insert(record)
        try modelContext.save()

        logger.info("CaptureRecord saved – type: \(type), path: \(url.path(percentEncoded: false))")
    }

    // MARK: - Fetch Records

    /// Fetches all records sorted by timestamp descending.
    func fetchAll(modelContext: ModelContext) throws -> [CaptureRecord] {
        let descriptor = FetchDescriptor<CaptureRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches records filtered by capture type.
    func fetch(
        type: String,
        modelContext: ModelContext
    ) throws -> [CaptureRecord] {
        let predicate = #Predicate<CaptureRecord> { $0.captureType == type }
        let descriptor = FetchDescriptor<CaptureRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Cleanup

    /// Deletes records and their associated files that are older than the
    /// specified number of days. Pass 0 to skip cleanup (keep forever).
    func cleanupOldCaptures(olderThan days: Int, modelContext: ModelContext) throws {
        guard days > 0 else {
            logger.debug("Cleanup skipped – retention set to forever")
            return
        }

        guard let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: Date()
        ) else { return }

        let predicate = #Predicate<CaptureRecord> { $0.timestamp < cutoff }
        let descriptor = FetchDescriptor<CaptureRecord>(predicate: predicate)

        let oldRecords = try modelContext.fetch(descriptor)
        logger.info("Cleanup: found \(oldRecords.count) records older than \(days) days")

        for record in oldRecords {
            // Remove image file.
            let filePath = record.filePath
            if FileManager.default.fileExists(atPath: filePath) {
                try? FileManager.default.removeItem(atPath: filePath)
            }
            // Remove thumbnail.
            let thumbPath = record.thumbnailPath
            if !thumbPath.isEmpty && FileManager.default.fileExists(atPath: thumbPath) {
                try? FileManager.default.removeItem(atPath: thumbPath)
            }
            modelContext.delete(record)
        }

        try modelContext.save()
        logger.info("Cleanup: removed \(oldRecords.count) old records")
    }

    /// Deletes a single record and its associated files.
    func deleteRecord(_ record: CaptureRecord, modelContext: ModelContext) throws {
        if FileManager.default.fileExists(atPath: record.filePath) {
            try? FileManager.default.removeItem(atPath: record.filePath)
        }
        if !record.thumbnailPath.isEmpty &&
            FileManager.default.fileExists(atPath: record.thumbnailPath) {
            try? FileManager.default.removeItem(atPath: record.thumbnailPath)
        }
        modelContext.delete(record)
        try modelContext.save()
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    /// Resize an image for thumbnail purposes, capping the width.
    private static func resizedForThumbnail(_ image: NSImage, maxWidth: CGFloat) -> NSImage {
        let scale = min(maxWidth / image.size.width, 1.0)
        let newSize = NSSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }
}
