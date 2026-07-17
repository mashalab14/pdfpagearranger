import SwiftUI
import UIKit

/// On-page UITextView editor that mirrors overlay formatting and never commits placeholder text.
struct TextOverlayInlineEditor: UIViewRepresentable {
    @Binding var draft: TextOverlayDraft
    var renderScale: CGFloat
    var isFocused: Bool
    var onEditingChanged: () -> Void
    var onRequestEndEditing: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.returnKeyType = .default
        textView.autocorrectionType = .yes
        textView.accessibilityIdentifier = "textOverlayInlineEditor"
        textView.accessibilityLabel = "Text Overlay Editor"
        context.coordinator.applyAttributedText(to: textView, force: true)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        if !context.coordinator.isUpdatingFromUI {
            context.coordinator.applyAttributedText(to: textView, force: false)
        }
        if isFocused, !textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        } else if !isFocused, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextOverlayInlineEditor
        var isUpdatingFromUI = false
        private var lastAppliedSignature: String = ""

        init(_ parent: TextOverlayInlineEditor) {
            self.parent = parent
        }

        func applyAttributedText(to textView: UITextView, force: Bool) {
            let signature = draftSignature(parent.draft, scale: parent.renderScale)
            guard force || signature != lastAppliedSignature else { return }

            let attributed = TextOverlayLayoutEngine.attributedString(
                for: parent.draft,
                renderScale: parent.renderScale,
                placeholderWhenEmpty: true
            )
            let selected = textView.selectedRange
            isUpdatingFromUI = true
            textView.attributedText = attributed
            if !parent.draft.isEmpty {
                let maxLocation = attributed.length
                let location = min(selected.location, maxLocation)
                let length = min(selected.length, max(0, maxLocation - location))
                textView.selectedRange = NSRange(location: location, length: length)
            } else {
                textView.selectedRange = NSRange(location: 0, length: 0)
            }
            isUpdatingFromUI = false
            lastAppliedSignature = signature
        }

        func textViewDidChange(_ textView: UITextView) {
            isUpdatingFromUI = true
            let raw = textView.text ?? ""
            // Placeholder is display-only; treat it as empty body text.
            if raw == TextOverlayDraft.placeholderHint, parent.draft.isEmpty {
                parent.draft.text = ""
            } else {
                let plain = TextOverlayFormattingEngine.plainText(
                    from: raw,
                    listMode: parent.draft.listMode
                )
                parent.draft.text = plain
            }
            lastAppliedSignature = draftSignature(parent.draft, scale: parent.renderScale)
            parent.onEditingChanged()
            // Re-apply formatting attributes while preserving caret when list markers change.
            applyAttributedText(to: textView, force: true)
            isUpdatingFromUI = false
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if parent.draft.isEmpty {
                // Clear placeholder selection so typing replaces the hint.
                textView.selectedRange = NSRange(location: 0, length: textView.attributedText.length)
            }
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if parent.draft.isEmpty,
               textView.attributedText.string == TextOverlayDraft.placeholderHint {
                textView.text = ""
                parent.draft.text = ""
            }
            return true
        }

        private func draftSignature(_ draft: TextOverlayDraft, scale: CGFloat) -> String {
            [
                draft.text,
                "\(draft.fontSizePoints)",
                draft.colorRGBA.uiColor.description,
                "\(draft.isBold)",
                "\(draft.isItalic)",
                "\(draft.isUnderline)",
                "\(draft.isStrikethrough)",
                draft.alignment.rawValue,
                draft.listMode.rawValue,
                "\(draft.listIndent)",
                draft.fontFamily.rawValue,
                "\(scale)"
            ].joined(separator: "|")
        }
    }
}
