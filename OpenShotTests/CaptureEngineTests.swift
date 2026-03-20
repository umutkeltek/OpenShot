// CaptureEngineTests.swift
// OpenShotTests
//
// Unit tests for CaptureEngine, CaptureMode, OpenShotError, and
// Preferences using Swift Testing.

import Testing
@testable import OpenShot

@Suite("CaptureEngine Tests")
struct CaptureEngineTests {

    @Test("CaptureEngine singleton exists")
    func testSingletonExists() {
        let engine = CaptureEngine.shared
        #expect(engine != nil)
    }

    @Test("CaptureEngine starts with nil lastCapturedImage")
    func testInitialState() {
        let engine = CaptureEngine.shared
        #expect(engine.lastCapturedImage == nil)
    }
}

@Suite("CaptureMode Tests")
struct CaptureModeTests {

    @Test("CaptureMode has all four cases")
    func testAllCases() {
        let modes = CaptureMode.allCases
        #expect(modes.count == 4)
        #expect(modes.contains(.area))
        #expect(modes.contains(.window))
        #expect(modes.contains(.fullscreen))
        #expect(modes.contains(.scrolling))
    }

    @Test("CaptureMode display names are non-empty")
    func testDisplayNames() {
        for mode in CaptureMode.allCases {
            #expect(!mode.displayName.isEmpty)
        }
    }

    @Test("CaptureMode system image names are non-empty")
    func testSystemImageNames() {
        for mode in CaptureMode.allCases {
            #expect(!mode.systemImageName.isEmpty)
        }
    }

    @Test("CaptureMode raw values are unique")
    func testUniqueRawValues() {
        let rawValues = CaptureMode.allCases.map(\.rawValue)
        let uniqueValues = Set(rawValues)
        #expect(rawValues.count == uniqueValues.count)
    }
}

@Suite("OpenShotError Tests")
struct OpenShotErrorTests {

    @Test("captureNotPermitted has a description")
    func testCaptureNotPermitted() {
        let error = OpenShotError.captureNotPermitted
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("permission"))
    }

    @Test("captureFailedNoImage has a description")
    func testCaptureFailedNoImage() {
        let error = OpenShotError.captureFailedNoImage
        #expect(error.errorDescription != nil)
    }

    @Test("captureFailedNoContent has a description")
    func testCaptureFailedNoContent() {
        let error = OpenShotError.captureFailedNoContent
        #expect(error.errorDescription != nil)
    }

    @Test("screenNotFound has a description")
    func testScreenNotFound() {
        let error = OpenShotError.screenNotFound
        #expect(error.errorDescription != nil)
    }

    @Test("windowNotFound has a description")
    func testWindowNotFound() {
        let error = OpenShotError.windowNotFound
        #expect(error.errorDescription != nil)
    }

    @Test("recordingAlreadyInProgress has a description")
    func testRecordingAlreadyInProgress() {
        let error = OpenShotError.recordingAlreadyInProgress
        #expect(error.errorDescription != nil)
    }

    @Test("recordingNotInProgress has a description")
    func testRecordingNotInProgress() {
        let error = OpenShotError.recordingNotInProgress
        #expect(error.errorDescription != nil)
    }

    @Test("assetWriterFailed includes detail")
    func testAssetWriterFailed() {
        let detail = "Buffer overflow"
        let error = OpenShotError.assetWriterFailed(detail)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains(detail))
    }

    @Test("gifExportFailed includes detail")
    func testGifExportFailed() {
        let detail = "Frame limit exceeded"
        let error = OpenShotError.gifExportFailed(detail)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains(detail))
    }

    @Test("ocrFailed includes detail")
    func testOcrFailed() {
        let detail = "No text found"
        let error = OpenShotError.ocrFailed(detail)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains(detail))
    }

    @Test("fileIOFailed includes detail")
    func testFileIOFailed() {
        let detail = "Disk full"
        let error = OpenShotError.fileIOFailed(detail)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains(detail))
    }

    @Test("invalidConfiguration includes detail")
    func testInvalidConfiguration() {
        let detail = "FPS out of range"
        let error = OpenShotError.invalidConfiguration(detail)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains(detail))
    }
}

@Suite("Preferences Tests")
struct PreferencesTests {

    @Test("Preferences singleton exists")
    func testSingletonExists() {
        let prefs = Preferences.shared
        #expect(prefs != nil)
    }

    @Test("Preferences default recordingFPS is 30")
    func testDefaultRecordingFPS() {
        let prefs = Preferences.shared
        #expect(prefs.recordingFPS == 30 || prefs.recordingFPS == 60)
    }

    @Test("Preferences default captureSound is true")
    func testDefaultCaptureSound() {
        let prefs = Preferences.shared
        #expect(prefs.captureSound == true)
    }

    @Test("Preferences default showCrosshair is true")
    func testDefaultShowCrosshair() {
        let prefs = Preferences.shared
        #expect(prefs.showCrosshair == true)
    }

    @Test("Preferences default showMagnifier is true")
    func testDefaultShowMagnifier() {
        let prefs = Preferences.shared
        #expect(prefs.showMagnifier == true)
    }

    @Test("Preferences default windowShadow is true")
    func testDefaultWindowShadow() {
        let prefs = Preferences.shared
        #expect(prefs.windowShadow == true)
    }

    @Test("Preferences default imageFormat is PNG")
    func testDefaultImageFormat() {
        let prefs = Preferences.shared
        #expect(prefs.imageFormat == .png)
    }

    @Test("Preferences default jpegQuality is 0.8")
    func testDefaultJpegQuality() {
        let prefs = Preferences.shared
        #expect(prefs.jpegQuality >= 0.1 && prefs.jpegQuality <= 1.0)
    }

    @Test("Preferences default overlayPosition is bottomRight")
    func testDefaultOverlayPosition() {
        let prefs = Preferences.shared
        #expect(prefs.overlayPosition == .bottomRight)
    }

    @Test("Preferences default recordingResolution is native")
    func testDefaultRecordingResolution() {
        let prefs = Preferences.shared
        #expect(prefs.recordingResolution == .native)
    }

    @Test("Preferences saveLocation is a valid URL")
    func testSaveLocation() {
        let prefs = Preferences.shared
        #expect(!prefs.saveLocation.path.isEmpty)
    }

    @Test("ImageFormat allCases has 3 formats")
    func testImageFormatCases() {
        let formats = Preferences.ImageFormat.allCases
        #expect(formats.count == 3)
        #expect(formats.contains(.png))
        #expect(formats.contains(.jpeg))
        #expect(formats.contains(.tiff))
    }

    @Test("ImageFormat file extensions match raw values")
    func testImageFormatExtensions() {
        for format in Preferences.ImageFormat.allCases {
            #expect(format.fileExtension == format.rawValue)
        }
    }

    @Test("WindowBackground allCases has 4 options")
    func testWindowBackgroundCases() {
        let cases = Preferences.WindowBackground.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.none))
        #expect(cases.contains(.desktop))
        #expect(cases.contains(.solid))
        #expect(cases.contains(.gradient))
    }

    @Test("OverlayPosition allCases has 4 positions")
    func testOverlayPositionCases() {
        let positions = Preferences.OverlayPosition.allCases
        #expect(positions.count == 4)
        #expect(positions.contains(.bottomRight))
        #expect(positions.contains(.bottomLeft))
        #expect(positions.contains(.topRight))
        #expect(positions.contains(.topLeft))
    }

    @Test("OverlayPosition displayName is non-empty")
    func testOverlayPositionDisplayNames() {
        for position in Preferences.OverlayPosition.allCases {
            #expect(!position.displayName.isEmpty)
        }
    }

    @Test("RecordingResolution allCases has 2 options")
    func testRecordingResolutionCases() {
        let resolutions = Preferences.RecordingResolution.allCases
        #expect(resolutions.count == 2)
        #expect(resolutions.contains(.native))
        #expect(resolutions.contains(.half))
    }

    @Test("RecordingResolution scale factors are correct")
    func testRecordingResolutionScaleFactors() {
        #expect(Preferences.RecordingResolution.native.scaleFactor == 1.0)
        #expect(Preferences.RecordingResolution.half.scaleFactor == 0.5)
    }
}

@Suite("CaptureEngineError Tests")
struct CaptureEngineErrorTests {

    @Test("cancelled error has description")
    func testCancelledDescription() {
        let error = CaptureEngineError.cancelled
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("cancelled"))
    }

    @Test("noDisplayFound error has description")
    func testNoDisplayFoundDescription() {
        let error = CaptureEngineError.noDisplayFound
        #expect(error.errorDescription != nil)
    }

    @Test("stitchingFailed error has description")
    func testStitchingFailedDescription() {
        let error = CaptureEngineError.stitchingFailed
        #expect(error.errorDescription != nil)
    }
}
