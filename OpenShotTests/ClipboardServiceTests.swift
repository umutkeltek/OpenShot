// ClipboardServiceTests.swift
// OpenShotTests
//
// Regression test for the clipboard temp-file leak: copying twice in a row
// must clean up the first temp file, not just leave it behind.

import Testing
import AppKit
@testable import OpenShot

@Suite("ClipboardService Tests")
struct ClipboardServiceTests {

    private static func makeTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        return image
    }

    @Test("copyImage writes image data and a readable file URL to the pasteboard")
    @MainActor
    func testCopyImageWritesPasteboardContent() throws {
        ClipboardService.copyImage(Self.makeTestImage(), showToast: false)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.tiff.rawValue]))

        guard let fileURLString = pasteboard.string(forType: .fileURL),
              let fileURL = URL(string: fileURLString) else {
            Issue.record("Expected a file URL on the pasteboard")
            return
        }
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(NSImage(contentsOfFile: fileURL.path) != nil)
    }

    @Test("copyImage cleans up the previous temp file on the next copy")
    @MainActor
    func testCopyImageCleansUpPreviousTempFile() throws {
        ClipboardService.copyImage(Self.makeTestImage(), showToast: false)
        guard let firstURLString = NSPasteboard.general.string(forType: .fileURL),
              let firstURL = URL(string: firstURLString) else {
            Issue.record("Expected a file URL after the first copy")
            return
        }
        #expect(FileManager.default.fileExists(atPath: firstURL.path))

        ClipboardService.copyImage(Self.makeTestImage(), showToast: false)
        guard let secondURLString = NSPasteboard.general.string(forType: .fileURL),
              let secondURL = URL(string: secondURLString) else {
            Issue.record("Expected a file URL after the second copy")
            return
        }

        #expect(secondURL != firstURL)
        #expect(!FileManager.default.fileExists(atPath: firstURL.path))
        #expect(FileManager.default.fileExists(atPath: secondURL.path))

        try? FileManager.default.removeItem(at: secondURL)
    }
}
