// AnnotationToolbar.swift
// OpenShot
//
// SwiftUI toolbar for annotation tool selection, color picking, stroke width,
// undo/redo, and action buttons. Hosts state for the currently selected tool
// and color, and communicates changes to the AnnotationCanvas.

import SwiftUI

struct AnnotationToolbar: View {

    /// The canvas this toolbar controls. We read/write tool, color, and strokeWidth directly.
    private let canvas: AnnotationCanvas
    private let onSave: () -> Void
    private let onCopy: () -> Void
    private let onReset: () -> Void

    @State private var selectedTool: AnnotationToolType = .arrow
    @State private var selectedColor: Color = .red
    @State private var strokeWidth: Double = 2.0

    let presetColors: [Color] = [.red, .orange, .yellow, .green, .blue, .white]

    init(canvas: AnnotationCanvas, onSave: @escaping () -> Void, onCopy: @escaping () -> Void, onReset: @escaping () -> Void) {
        self.canvas = canvas
        self.onSave = onSave
        self.onCopy = onCopy
        self.onReset = onReset
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top row: Tool buttons in scrollable area
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    toolButtons
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 32)

            Divider()

            // Bottom row: Color, stroke, undo, actions
            HStack(spacing: 10) {
                // Color swatches
                colorSwatches

                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                    .frame(width: 24)
                    .onChange(of: selectedColor) { _, newValue in
                        canvas.currentColor = NSColor(newValue)
                    }

                Divider().frame(height: 20)

                // Stroke width slider
                strokeWidthSlider

                Divider().frame(height: 20)

                // Undo / Redo
                undoRedoButtons

                Spacer()

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Tool Buttons

    @ViewBuilder
    private var toolButtons: some View {
        ForEach(AnnotationToolType.allCases) { tool in
            Button {
                selectedTool = tool
                canvas.currentTool = tool
            } label: {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .background(selectedTool == tool ? Color.accentColor.opacity(0.8) : Color.clear)
                    .foregroundStyle(selectedTool == tool ? .white : .primary)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(tool.displayName)
        }
    }

    // MARK: - Color Swatches

    @ViewBuilder
    private var colorSwatches: some View {
        ForEach(presetColors, id: \.self) { color in
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(isColorSelected(color) ? Color.white : Color.clear, lineWidth: 2)
                )
                .shadow(color: isColorSelected(color) ? .white.opacity(0.4) : .clear, radius: 3)
                .onTapGesture {
                    selectedColor = color
                    canvas.currentColor = NSColor(color)
                }
        }
    }

    // MARK: - Stroke Width

    @ViewBuilder
    private var strokeWidthSlider: some View {
        HStack(spacing: 6) {
            Image(systemName: "lineweight")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Slider(value: $strokeWidth, in: 1...20, step: 1)
                .frame(width: 80)
                .onChange(of: strokeWidth) { _, newValue in
                    canvas.currentStrokeWidth = CGFloat(newValue)
                }
            Text("\(Int(strokeWidth))px")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }

    // MARK: - Undo / Redo

    @ViewBuilder
    private var undoRedoButtons: some View {
        Button {
            canvas.performUndo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .help("Undo")

        Button {
            canvas.performRedo()
        } label: {
            Image(systemName: "arrow.uturn.forward")
                .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .help("Redo")
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        Button("Copy", action: onCopy)

        Button("Save", action: onSave)

        Button(action: onReset) {
            Image(systemName: "arrow.counterclockwise")
        }
        .help("Reset all annotations")

        Button("Done") {
            canvas.window?.close()
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Helpers

    /// Approximate equality check for Color vs the preset color.
    private func isColorSelected(_ presetColor: Color) -> Bool {
        let resolved1 = presetColor.resolve(in: EnvironmentValues())
        let resolved2 = selectedColor.resolve(in: EnvironmentValues())
        let threshold: Float = 0.05
        return abs(resolved1.red - resolved2.red) < threshold
            && abs(resolved1.green - resolved2.green) < threshold
            && abs(resolved1.blue - resolved2.blue) < threshold
            && abs(resolved1.opacity - resolved2.opacity) < threshold
    }
}
