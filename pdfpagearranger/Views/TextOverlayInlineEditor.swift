import SwiftUI
import UIKit

/// On-page UITextView editor with selection-aware rich text and never-committed placeholder text.
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
        context.coordinator.updateTypingAttributes(on: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        if !context.coordinator.isUpdatingFromUI {
            context.coordinator.applyAttributedText(to: textView, force: false)
            context.coordinator.updateTypingAttributes(on: textView)
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

            // Editor shows rich plain body without list markers so range formatting stays stable.
            let attributed = TextOverlayLayoutEngine.attributedString(
                for: parent.draft,
                renderScale: parent.renderScale,
                placeholderWhenEmpty: true,
                includeListMarkers: false
            )
            let selected = textView.selectedRange
            isUpdatingFromUI = true
            textView.attributedText = attributed
            textView.alpha = CGFloat(parent.draft.opacity)
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
            syncSelection(from: textView)
        }

        func updateTypingAttributes(on textView: UITextView) {
            let defaults = TextOverlayRichTextEngine.StyleDefaults(from: parent.draft)
            let sample = TextOverlayRichTextEngine.attributedString(
                spans: [TextOverlayTextSpan(text: "A")],
                defaults: defaults,
                alignment: parent.draft.alignment,
                listMode: .plain,
                listIndent: 0,
                renderScale: parent.renderScale,
                placeholderWhenEmpty: false
            )
            textView.typingAttributes = sample.attributes(at: 0, effectiveRange: nil)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingFromUI else { return }
            isUpdatingFromUI = true
            let raw = textView.text ?? ""
            if raw == TextOverlayDraft.placeholderHint, parent.draft.isEmpty {
                parent.draft.text = ""
                parent.draft.spans = []
            } else {
                let defaults = TextOverlayRichTextEngine.StyleDefaults(from: parent.draft)
                let spans = TextOverlayRichTextEngine.spans(from: textView.attributedText, defaults: defaults)
                parent.draft.spans = spans
                parent.draft.text = TextOverlayRichTextEngine.plainText(from: spans)
            }
            syncSelection(from: textView)
            lastAppliedSignature = draftSignature(parent.draft, scale: parent.renderScale)
            parent.onEditingChanged()
            isUpdatingFromUI = false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingFromUI else { return }
            syncSelection(from: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if parent.draft.isEmpty {
                textView.selectedRange = NSRange(location: 0, length: textView.attributedText.length)
            }
            updateTypingAttributes(on: textView)
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
                parent.draft.spans = []
            }
            return true
        }

        private func syncSelection(from textView: UITextView) {
            parent.draft.selectedUTF16Location = textView.selectedRange.location
            parent.draft.selectedUTF16Length = textView.selectedRange.length
        }

        private func draftSignature(_ draft: TextOverlayDraft, scale: CGFloat) -> String {
            let spanSignature = draft.spans.map {
                [
                    $0.text,
                    "\($0.fontSizePoints ?? -1)",
                    $0.colorRGBA?.uiColor.description ?? "-",
                    "\($0.isBold ?? false)",
                    "\($0.isItalic ?? false)",
                    "\($0.isUnderline ?? false)",
                    "\($0.isStrikethrough ?? false)",
                    $0.fontFamily?.rawValue ?? "-"
                ].joined(separator: ",")
            }.joined(separator: ";")
            return [
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
                "\(draft.opacity)",
                spanSignature,
                "\(scale)"
            ].joined(separator: "|")
        }
    }
}
