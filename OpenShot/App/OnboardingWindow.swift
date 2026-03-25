import SwiftUI
import os

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    let onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                // Page 1: Welcome
                welcomePage.tag(0)
                // Page 2: Permissions
                permissionsPage.tag(1)
                // Page 3: Shortcuts
                shortcutsPage.tag(2)
            }
            .tabViewStyle(.automatic)

            // Navigation
            HStack {
                if currentPage > 0 {
                    Button("Back") { withAnimation { currentPage -= 1 } }
                        .buttonStyle(.plain)
                }
                Spacer()
                if currentPage < 2 {
                    Button("Next") { withAnimation { currentPage += 1 } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .frame(width: 520, height: 420)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("Welcome to OpenShot")
                .font(.largeTitle.bold())
            Text("A free, open-source screenshot and screen recording tool for macOS.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var permissionsPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Screen Recording Permission")
                .font(.title2.bold())
            Text("OpenShot needs screen recording permission to capture screenshots and record your screen.\n\nAll processing happens locally on your Mac — nothing is sent to the cloud.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Grant Permission") {
                Permissions.requestScreenRecording()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Grant screen recording permission")
            .accessibilityHint("Opens the macOS system dialog to grant screen recording access")
            Spacer()
        }
    }

    private var shortcutsPage: some View {
        VStack(spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.title2.bold())
                .padding(.top, 20)

            VStack(spacing: 10) {
                shortcutRow("Capture Area", "Shift+Cmd+4")
                shortcutRow("Capture Window", "Shift+Cmd+5")
                shortcutRow("Capture Fullscreen", "Shift+Cmd+3")
                shortcutRow("Scrolling Capture", "Shift+Cmd+6")
                shortcutRow("Record Screen", "Shift+Cmd+R")
                shortcutRow("Record GIF", "Shift+Cmd+G")
                shortcutRow("OCR - Capture Text", "Shift+Cmd+T")
                shortcutRow("All-in-One", "Shift+Cmd+A")
            }
            .padding(.horizontal, 40)

            Text("All shortcuts are customizable in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private func shortcutRow(_ name: String, _ shortcut: String) -> some View {
        HStack {
            Text(name)
                .font(.body)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary)
                .cornerRadius(4)
        }
    }
}

// MARK: - OnboardingWindow Manager

struct OnboardingWindowManager {
    private static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private static let logger = Logger(subsystem: "com.openshot", category: "onboarding")

    static var shouldShowOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }

    @MainActor
    static func showIfNeeded() {
        guard shouldShowOnboarding else {
            logger.debug("Onboarding already completed, skipping")
            return
        }

        logger.info("Showing first-run onboarding")

        var onboardingWindow: NSWindow?

        let onboardingView = OnboardingView {
            UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
            onboardingWindow?.close()
            logger.info("Onboarding completed")
        }

        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to OpenShot"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 420))
        window.minSize = NSSize(width: 520, height: 420)
        window.center()
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
