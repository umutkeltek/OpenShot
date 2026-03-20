// TextAnnotation.swift
// OpenShot
//
// Provides inline text editing on the annotation canvas via an NSTextField.
// When the user selects the text tool and clicks the canvas, this editor appears
// as a floating text field. On commit (Enter or focus loss), the text is passed
// back via a completion handler so the canvas can create a TextAnnotationItem.

import AppKit
import os

private let logger = Logger(subsystem: "com.openshot.app", category: "TextAnnotationEditor")

class TextAnnotationEditor: NSObject {

    /// Tracks the currently active text field so we can clean it up if needed.
    private static weak var activeField: NSTextField?
    private static var activeDelegate: TextFieldDelegate?

    /// Creates and presents an inline text editing field on the annotation canvas.
    ///
    /// - Parameters:
    ///   - point: The location in the canvas view to place the editor.
    ///   - view: The parent NSView (AnnotationCanvas) to add the field to.
    ///   - style: The text style preset to configure appearance.
    ///   - completion: Called with the entered text when editing finishes. Empty string means cancelled.
    /// - Returns: The created NSTextField (caller typically ignores this).
    @discardableResult
    static func createEditor(
        at point: CGPoint,
        in view: NSView,
        style: TextAnnotationItem.TextStyle,
        completion: @escaping (String) -> Void
    ) -> NSTextField {
        // Remove any existing active editor first
        dismissActiveEditor()

        let field = NSTextField(frame: CGRect(x: point.x, y: point.y, width: 240, height: 32))
        configureField(field, style: style)

        let delegate = TextFieldDelegate(field: field, parentView: view, completion: completion)
        activeDelegate = delegate
        field.delegate = delegate

        view.addSubview(field)
        view.window?.makeFirstResponder(field)

        activeField = field
        logger.debug("Text editor created at (\(point.x), \(point.y))")

        return field
    }

    /// Dismisses any currently active text editor field.
    static func dismissActiveEditor() {
        if let field = activeField {
            field.removeFromSuperview()
            activeField = nil
            activeDelegate = nil
            logger.debug("Dismissed active text editor")
        }
    }

    // MARK: - Field Configuration

    private static func configureField(_ field: NSTextField, style: TextAnnotationItem.TextStyle) {
        field.isBordered = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.allowsEditingTextAttributes = false
        field.lineBreakMode = .byClipping
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.placeholderString = "Type text..."
        field.usesSingleLineMode = true

        switch style {
        case .whitePillRed:
            field.font = .systemFont(ofSize: 16, weight: .bold)
            field.textColor = .white
            field.drawsBackground = true
            field.backgroundColor = .red.withAlphaComponent(0.9)

        case .blackYellow:
            field.font = .systemFont(ofSize: 16, weight: .bold)
            field.textColor = .black
            field.drawsBackground = true
            field.backgroundColor = .yellow.withAlphaComponent(0.9)

        case .whiteDark:
            field.font = .systemFont(ofSize: 16, weight: .medium)
            field.textColor = .white
            field.drawsBackground = true
            field.backgroundColor = NSColor(white: 0.15, alpha: 0.9)

        case .largeBoldShadow:
            field.font = .systemFont(ofSize: 28, weight: .heavy)
            field.textColor = .white
            field.drawsBackground = true
            field.backgroundColor = NSColor.black.withAlphaComponent(0.4)

        case .monoDark:
            field.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
            field.textColor = NSColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 1.0)
            field.drawsBackground = true
            field.backgroundColor = NSColor(white: 0.1, alpha: 0.9)

        case .handwriting:
            if let hFont = NSFont(name: "Bradley Hand", size: 18) {
                field.font = hFont
            } else {
                field.font = .systemFont(ofSize: 18, weight: .regular)
            }
            field.textColor = .black
            field.drawsBackground = true
            field.backgroundColor = .white.withAlphaComponent(0.9)

        case .plainBlack:
            field.font = .systemFont(ofSize: 16, weight: .regular)
            field.textColor = .black
            field.drawsBackground = true
            field.backgroundColor = .white.withAlphaComponent(0.9)
        }
    }
}

// MARK: - Text Field Delegate

/// Internal delegate that handles Enter-to-commit and focus-loss-to-commit.
private class TextFieldDelegate: NSObject, NSTextFieldDelegate {
    private let field: NSTextField
    private weak var parentView: NSView?
    private let completion: (String) -> Void
    private var hasFinished = false

    init(field: NSTextField, parentView: NSView, completion: @escaping (String) -> Void) {
        self.field = field
        self.parentView = parentView
        self.completion = completion
        super.init()

        // Monitor for focus loss via notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidEndEditing(_:)),
            name: NSTextField.textDidEndEditingNotification,
            object: field
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Called when the user presses Enter (action sent by NSTextField).
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            finishEditing()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // Escape cancels editing — return empty string
            cancelEditing()
            return true
        }
        return false
    }

    /// Called when the text field loses focus.
    @objc func textDidEndEditing(_ notification: Notification) {
        finishEditing()
    }

    /// Auto-resize the field as user types.
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        let text = field.stringValue
        let attributes: [NSAttributedString.Key: Any] = [.font: field.font as Any]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 16
        let newWidth = max(80, textSize.width + padding)
        field.frame.size.width = newWidth
    }

    private func finishEditing() {
        guard !hasFinished else { return }
        hasFinished = true

        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        field.removeFromSuperview()
        completion(text)
        TextAnnotationEditor.dismissActiveEditor()
    }

    private func cancelEditing() {
        guard !hasFinished else { return }
        hasFinished = true

        field.removeFromSuperview()
        completion("")
        TextAnnotationEditor.dismissActiveEditor()
    }
}
