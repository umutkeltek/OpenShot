// CaptureHistoryManagerTests.swift
// OpenShotTests
//
// Regression tests: capture archiving always targets the app's own
// storage directory (never the user's configured save location), the
// shared SwiftData container is a true singleton, and recordings get
// moved out of the temp directory before being archived.

import Testing
import SwiftData
import AppKit
@testable import OpenShot

// Serialized: tests mutate the shared `Preferences.shared.saveLocation`
// singleton, which is unsafe to do concurrently across parallel tests.
@Suite("CaptureHistoryManager Tests", .serialized)
struct CaptureHistoryManagerTests {

    /// A small, actually-drawn image — `NSImage(size:)` alone has no bitmap
    /// representation and produces `nil` from `pngData()`/`tiffRepresentation`.
    private static func makeTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        return image
    }

    @Test("saveCapture always archives to capturesDirectory, never saveLocation")
    func testSaveCaptureNeverWritesToSaveLocation() throws {
        let manager = CaptureHistoryManager.shared
        let preferences = Preferences.shared

        let originalSaveLocation = preferences.saveLocation
        defer { preferences.saveLocation = originalSaveLocation }

        let tempSaveLocation = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenShotTests_SaveLocation_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempSaveLocation, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempSaveLocation) }
        preferences.saveLocation = tempSaveLocation

        let context = try manager.makeContext()
        let record = try manager.saveCapture(
            image: Self.makeTestImage(),
            type: "screenshot",
            preferences: preferences,
            modelContext: context
        )
        defer { try? manager.deleteRecord(record, modelContext: context) }

        #expect(record.filePath.hasPrefix(manager.capturesDirectory.path))
        #expect(!record.filePath.hasPrefix(tempSaveLocation.path))

        let saveLocationContents = (try? FileManager.default.contentsOfDirectory(atPath: tempSaveLocation.path)) ?? []
        #expect(saveLocationContents.isEmpty)
    }

    @Test("sharedContainer returns the same instance across repeated calls")
    func testSharedContainerIsSingleton() throws {
        let manager = CaptureHistoryManager.shared
        let first = try manager.sharedContainer
        let second = try manager.sharedContainer
        #expect(first === second)
    }

    @Test("archiveRecording moves the temp file into saveLocation")
    func testArchiveRecordingMovesTempFile() throws {
        let manager = CaptureHistoryManager.shared
        let preferences = Preferences.shared

        let originalSaveLocation = preferences.saveLocation
        defer { preferences.saveLocation = originalSaveLocation }

        let tempSaveLocation = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenShotTests_SaveLocation_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempSaveLocation) }
        preferences.saveLocation = tempSaveLocation

        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenShot_test_\(UUID().uuidString).gif")
        try Data("fake gif bytes".utf8).write(to: tempFileURL)

        let context = try manager.makeContext()
        let finalURL = try manager.archiveRecording(
            tempURL: tempFileURL,
            type: "gif",
            preferences: preferences,
            modelContext: context
        )

        #expect(finalURL.deletingLastPathComponent().path == tempSaveLocation.path)
        #expect(FileManager.default.fileExists(atPath: finalURL.path))
        #expect(!FileManager.default.fileExists(atPath: tempFileURL.path))

        let records = try manager.fetch(type: "gif", modelContext: context)
        if let record = records.first(where: { $0.filePath == finalURL.path }) {
            try? manager.deleteRecord(record, modelContext: context)
        }
    }

    @Test("archiveRecording falls back to the temp URL if the move fails")
    func testArchiveRecordingFallsBackOnMoveFailure() throws {
        let manager = CaptureHistoryManager.shared
        let preferences = Preferences.shared

        let originalSaveLocation = preferences.saveLocation
        defer { preferences.saveLocation = originalSaveLocation }

        // Point saveLocation at a path that is actually a file, so
        // createDirectory/moveItem fail deterministically.
        let blockerFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenShotTests_Blocker_\(UUID().uuidString)")
        try Data().write(to: blockerFile)
        defer { try? FileManager.default.removeItem(at: blockerFile) }
        preferences.saveLocation = blockerFile

        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenShot_test_\(UUID().uuidString).gif")
        try Data("fake gif bytes".utf8).write(to: tempFileURL)
        defer { try? FileManager.default.removeItem(at: tempFileURL) }

        let context = try manager.makeContext()
        let finalURL = try manager.archiveRecording(
            tempURL: tempFileURL,
            type: "gif",
            preferences: preferences,
            modelContext: context
        )

        #expect(finalURL == tempFileURL)
        #expect(FileManager.default.fileExists(atPath: tempFileURL.path))

        let records = try manager.fetch(type: "gif", modelContext: context)
        if let record = records.first(where: { $0.filePath == finalURL.path }) {
            try? manager.deleteRecord(record, modelContext: context)
        }
    }
}
