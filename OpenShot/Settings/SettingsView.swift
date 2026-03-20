// SettingsView.swift
// OpenShot
//
// Full Settings window with tabbed navigation. Each tab binds directly
// to Preferences.shared so changes take effect immediately.

import SwiftUI
import AppKit

// MARK: - Root Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }

            CaptureSettingsTab()
                .tabItem { Label("Capture", systemImage: "camera") }

            RecordingSettingsTab()
                .tabItem { Label("Recording", systemImage: "record.circle") }

            OverlaySettingsTab()
                .tabItem { Label("Overlay", systemImage: "rectangle.on.rectangle") }

            ShortcutsSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            HistorySettingsTab()
                .tabItem { Label("History", systemImage: "clock") }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General

struct GeneralSettingsTab: View {
    @Bindable private var preferences = Preferences.shared

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { LaunchAtLogin.isEnabled },
                    set: { LaunchAtLogin.update(enabled: $0) }
                ))
            }

            Section("Sound") {
                Toggle("Play capture sound", isOn: $preferences.captureSound)
            }

            Section("Save Location") {
                HStack {
                    Text(preferences.saveLocation.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(preferences.saveLocation.path(percentEncoded: false))
                    Spacer()
                    Button("Choose\u{2026}") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            preferences.saveLocation = url
                        }
                    }
                }
            }

            Section("Image Format") {
                Picker("Format", selection: $preferences.imageFormat) {
                    ForEach(Preferences.ImageFormat.allCases, id: \.self) { format in
                        Text(format.rawValue.uppercased()).tag(format)
                    }
                }

                if preferences.imageFormat == .jpeg {
                    HStack {
                        Text("JPEG Quality: \(Int(preferences.jpegQuality * 100))%")
                        Slider(
                            value: $preferences.jpegQuality,
                            in: 0.1...1.0,
                            step: 0.1
                        )
                    }
                }
            }

            Section("Desktop") {
                Toggle("Hide Desktop Icons During Capture", isOn: $preferences.hideDesktopIconsDuringCapture)
            }

            Section("File Naming") {
                TextField("Template", text: $preferences.fileNamingTemplate)
                    .textFieldStyle(.roundedBorder)
                Text("Tokens: {date}, {time}, {datetime}, {mode}, {counter}, {app}, {title}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Self-Timer") {
                Picker("Duration", selection: $preferences.selfTimerDuration) {
                    Text("3 seconds").tag(3)
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                }
            }
        }
        .padding()
    }
}

// MARK: - Capture

struct CaptureSettingsTab: View {
    @Bindable private var preferences = Preferences.shared
    @State private var selectedPreset: WindowBackgroundRenderer.PresetBackground = .oceanBlue

    var body: some View {
        Form {
            Section("Crosshair & Magnifier") {
                Toggle("Show crosshair during selection", isOn: $preferences.showCrosshair)
                Toggle("Show magnifier during selection", isOn: $preferences.showMagnifier)
            }

            Section("Screen Freeze") {
                Toggle(
                    "Freeze screen during area capture",
                    isOn: $preferences.freezeScreen
                )
            }

            Section("Cursor") {
                Toggle(
                    "Include cursor in screenshots",
                    isOn: $preferences.includeCursor
                )
            }

            Section("Window Capture") {
                Toggle("Include window shadow", isOn: $preferences.windowShadow)

                Stepper(
                    "Padding: \(Int(preferences.windowPadding))px",
                    value: $preferences.windowPadding,
                    in: 0...64,
                    step: 4
                )

                Picker("Background", selection: $preferences.windowBackground) {
                    ForEach(Preferences.WindowBackground.allCases, id: \.self) { bg in
                        Text(bg.rawValue.capitalized).tag(bg)
                    }
                }

                if preferences.windowBackground == .gradient {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preset Gradients")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            ForEach(WindowBackgroundRenderer.PresetBackground.allCases) { preset in
                                let colors = preset.colors
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(nsColor: colors.0), Color(nsColor: colors.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 30)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(
                                                selectedPreset == preset ? Color.accentColor : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .help(preset.displayName)
                                    .onTapGesture {
                                        selectedPreset = preset
                                    }
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Recording

struct RecordingSettingsTab: View {
    @Bindable private var preferences = Preferences.shared

    var body: some View {
        Form {
            Section("Video") {
                Picker("Frame Rate", selection: $preferences.recordingFPS) {
                    Text("30 FPS").tag(30)
                    Text("60 FPS").tag(60)
                }

                Picker("Resolution", selection: $preferences.recordingResolution) {
                    ForEach(Preferences.RecordingResolution.allCases, id: \.self) { res in
                        Text(res.displayName).tag(res)
                    }
                }
            }

            Section("Overlays") {
                Toggle("Show mouse clicks", isOn: $preferences.showClicks)
                Toggle("Show keystrokes", isOn: $preferences.showKeystrokes)
            }
        }
        .padding()
    }
}

// MARK: - Overlay

struct OverlaySettingsTab: View {
    @Bindable private var preferences = Preferences.shared

    var body: some View {
        Form {
            Section("Quick Access Overlay") {
                Picker("Position", selection: $preferences.overlayPosition) {
                    ForEach(Preferences.OverlayPosition.allCases, id: \.self) { pos in
                        Text(pos.displayName).tag(pos)
                    }
                }

                Picker("Auto-close delay", selection: $preferences.overlayAutoCloseDelay) {
                    Text("3 seconds").tag(TimeInterval(3))
                    Text("5 seconds").tag(TimeInterval(5))
                    Text("10 seconds").tag(TimeInterval(10))
                    Text("Never").tag(TimeInterval(0))
                }
            }
        }
        .padding()
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            Section("Capture Shortcuts") {
                ShortcutRow(label: "Capture Area", shortcut: "\u{21E7}\u{2318}4")
                ShortcutRow(label: "Capture Window", shortcut: "\u{21E7}\u{2318}5")
                ShortcutRow(label: "Capture Fullscreen", shortcut: "\u{21E7}\u{2318}3")
                ShortcutRow(label: "Scrolling Capture", shortcut: "\u{21E7}\u{2318}6")
            }

            Section("Recording Shortcuts") {
                ShortcutRow(label: "Record Screen", shortcut: "\u{21E7}\u{2318}R")
                ShortcutRow(label: "Record GIF", shortcut: "\u{21E7}\u{2318}G")
            }

            Section("Other") {
                ShortcutRow(label: "OCR \u{2013} Capture Text", shortcut: "\u{21E7}\u{2318}T")
                ShortcutRow(label: "Capture Previous Area", shortcut: "\u{21E7}\u{2318}7")
                ShortcutRow(label: "Self-Timer Capture", shortcut: "\u{21E7}\u{2318}8")
                ShortcutRow(label: "All-in-One", shortcut: "\u{21E7}\u{2318}A")
                ShortcutRow(label: "Restore Recently Closed", shortcut: "\u{21E7}\u{2318}Z")
                ShortcutRow(label: "Toggle Desktop Icons", shortcut: "\u{21E7}\u{2318}D")
            }
        }
        .padding()
    }
}

struct ShortcutRow: View {
    let label: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(shortcut)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - History

struct HistorySettingsTab: View {
    @Bindable private var preferences = Preferences.shared

    var body: some View {
        Form {
            Section("Retention") {
                Picker("Keep captures for", selection: $preferences.historyRetentionDays) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("Forever").tag(0)
                }
            }

            Section("Storage") {
                LabeledContent("Captures folder") {
                    HStack {
                        let capturesPath = FileManager.default.urls(
                            for: .applicationSupportDirectory,
                            in: .userDomainMask
                        ).first!.appendingPathComponent("OpenShot/Captures").path(percentEncoded: false)

                        Text(capturesPath)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button("Reveal") {
                            let url = FileManager.default.urls(
                                for: .applicationSupportDirectory,
                                in: .userDomainMask
                            ).first!.appendingPathComponent("OpenShot/Captures")
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding()
    }
}
