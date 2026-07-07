// WindowPickerFilterTests.swift
// OpenShotTests
//
// Regression tests for the window picker filter: it must exclude our own
// windows and tiny/system-chrome windows, but must NOT exclude a normal,
// capturable window just because it happens to have an empty title (the
// bug being fixed here — the old code did the opposite of both).

import Testing
import Foundation
@testable import OpenShot

private struct FakeWindow: CandidateWindow {
    var windowTitle: String?
    var windowFrame: CGRect
    var windowLayerValue: Int
    var owningBundleIdentifier: String?
}

@Suite("WindowPickerFilter Tests")
struct WindowPickerFilterTests {

    private static let ownBundleID = "com.openshot.app"

    private static func normalWindow(title: String? = "Some Window") -> FakeWindow {
        FakeWindow(
            windowTitle: title,
            windowFrame: CGRect(x: 0, y: 0, width: 400, height: 300),
            windowLayerValue: 0,
            owningBundleIdentifier: "com.other.app"
        )
    }

    @Test("Excludes windows owned by our own app")
    func testExcludesOwnApp() {
        let window = FakeWindow(
            windowTitle: "WindowPickerOverlay",
            windowFrame: CGRect(x: 0, y: 0, width: 1000, height: 1000),
            windowLayerValue: 0,
            owningBundleIdentifier: Self.ownBundleID
        )
        #expect(!WindowPickerFilter.isCapturable(window, ownBundleID: Self.ownBundleID))
    }

    @Test("Excludes windows smaller than the minimum dimension")
    func testExcludesTinyWindows() {
        let window = FakeWindow(
            windowTitle: "Tiny",
            windowFrame: CGRect(x: 0, y: 0, width: 10, height: 10),
            windowLayerValue: 0,
            owningBundleIdentifier: "com.other.app"
        )
        #expect(!WindowPickerFilter.isCapturable(window, ownBundleID: Self.ownBundleID))
    }

    @Test("Excludes non-zero-layer windows (menu bar, dock, system chrome)")
    func testExcludesNonZeroLayer() {
        let window = FakeWindow(
            windowTitle: "Menu Bar",
            windowFrame: CGRect(x: 0, y: 0, width: 400, height: 300),
            windowLayerValue: 25,
            owningBundleIdentifier: "com.apple.systemuiserver"
        )
        #expect(!WindowPickerFilter.isCapturable(window, ownBundleID: Self.ownBundleID))
    }

    @Test("Includes a normal, appropriately-sized, layer-0 window with an empty title")
    func testIncludesUntitledNormalWindow() {
        let window = Self.normalWindow(title: nil)
        #expect(WindowPickerFilter.isCapturable(window, ownBundleID: Self.ownBundleID))

        let emptyTitled = Self.normalWindow(title: "")
        #expect(WindowPickerFilter.isCapturable(emptyTitled, ownBundleID: Self.ownBundleID))
    }

    @Test("Includes a normal titled window")
    func testIncludesNormalTitledWindow() {
        #expect(WindowPickerFilter.isCapturable(Self.normalWindow(), ownBundleID: Self.ownBundleID))
    }

    @Test("filtered(_:ownBundleID:) applies the same rules across a list")
    func testFilteredList() {
        let windows: [FakeWindow] = [
            Self.normalWindow(),
            FakeWindow(windowTitle: "Overlay", windowFrame: CGRect(x: 0, y: 0, width: 500, height: 500), windowLayerValue: 0, owningBundleIdentifier: Self.ownBundleID),
            FakeWindow(windowTitle: "Tiny", windowFrame: CGRect(x: 0, y: 0, width: 5, height: 5), windowLayerValue: 0, owningBundleIdentifier: "com.other.app"),
            Self.normalWindow(title: nil),
        ]
        let result = WindowPickerFilter.filtered(windows, ownBundleID: Self.ownBundleID)
        #expect(result.count == 2)
    }
}
