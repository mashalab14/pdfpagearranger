import SwiftUI
import UIKit

/// On-page UITextView editor with selection-aware rich text, visible list markers, and never-committed placeholder text.
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

        private var usesListMarkers: Bool {
            parent.draft.listMode != .plain || parent.draft.listIndent > 0
        }

        func applyAttributedText(to textView: UITextView, force: Bool) {
            let signature = draftSignature(parent.draft, scale: parent.renderScale)
            guard force || signature != lastAppliedSignature else { return }

            // Keep list markers visible while editing so edit/display/export match.
            let attributed = TextOverlayLayoutEngine.attributedString(
                for: parent.draft,
                renderScale: parent.renderScale,
                placeholderWhenEmpty: parent.draft.listMode == .plain && parent.draft.listIndent == 0,
                includeListMarkers: true
            )
            let plainSelection = NSRange(
                location: parent.draft.selectedUTF16Location,
                length: parent.draft.selectedUTF16Length
            )
            isUpdatingFromUI = true
            textView.attributedText = attributed
            textView.alpha = CGFloat(parent.draft.opacity)
            if parent.draft.isEmpty, !usesListMarkers {
                textView.selectedRange = NSRange(location: 0, length: 0)
            } else {
                let displaySelection = TextOverlayListEditingEngine.displayRange(
                    plainRange: plainSelection,
                    plainText: parent.draft.text,
                    listMode: parent.draft.listMode,
                    listIndent: parent.draft.listIndent
                )
                let maxLocation = attributed.length
                let location = min(displaySelection.location, maxLocation)
                let length = min(displaySelection.length, max(0, maxLocation - location))
                textView.selectedRange = NSRange(location: location, length: length)
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

            let displaySelection = textView.selectedRange
            let raw = textView.text ?? ""

            if raw == TextOverlayDraft.placeholderHint, parent.draft.isEmpty, !usesListMarkers {
                parent.draft.text = ""
                parent.draft.spans = []
            } else {
                let bodyAttributed = TextOverlayListEditingEngine.attributedBodyStrippingMarkers(
                    from: textView.attributedText,
                    listMode: parent.draft.listMode,
                    listIndent: parent.draft.listIndent
                )
                let defaults = TextOverlayRichTextEngine.StyleDefaults(from: parent.draft)
                let spans = TextOverlayRichTextEngine.spans(from: bodyAttributed, defaults: defaults)
                parent.draft.spans = spans
                parent.draft.text = TextOverlayRichTextEngine.plainText(from: spans)
            }

            let plainSelection = TextOverlayListEditingEngine.plainRange(
                displayRange: displaySelection,
                plainText: parent.draft.text,
                listMode: parent.draft.listMode,
                listIndent: parent.draft.listIndent
            )
            parent.draft.selectedUTF16Location = plainSelection.location
            parent.draft.selectedUTF16Length = plainSelection.length

            // Re-apply markers so they never disappear after typing/deleting.
            let refreshed = TextOverlayLayoutEngine.attributedString(
                for: parent.draft,
                renderScale: parent.renderScale,
                placeholderWhenEmpty: parent.draft.listMode == .plain && parent.draft.listIndent == 0,
                includeListMarkers: true
            )
            textView.attributedText = refreshed
            let restored = TextOverlayListEditingEngine.displayRange(
                plainRange: plainSelection,
                plainText: parent.draft.text,
                listMode: parent.draft.listMode,
                listIndent: parent.draft.listIndent
            )
            let maxLocation = refreshed.length
            let location = min(restored.location, maxLocation)
            let length = min(restored.length, max(0, maxLocation - location))
            textView.selectedRange = NSRange(location: location, length: length)
            updateTypingAttributes(on: textView)

            lastAppliedSignature = draftSignature(parent.draft, scale: parent.renderScale)
            parent.onEditingChanged()
            isUpdatingFromUI = false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingFromUI else { return }
            syncSelection(from: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if parent.draft.isEmpty, !usesListMarkers {
                textView.selectedRange = NSRange(location: 0, length: textView.attributedText.length)
            } else if parent.draft.isEmpty, usesListMarkers {
                // Place caret after the visible marker on an empty list row.
                let display = TextOverlayListEditingEngine.displayUTF16Location(
                    plainLocation: 0,
                    plainText: "",
                    listMode: parent.draft.listMode,
                    listIndent: parent.draft.listIndent
                )
                textView.selectedRange = NSRange(location: min(display, textView.attributedText.length), length: 0)
            }
            updateTypingAttributes(on: textView)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if parent.draft.isEmpty,
               !usesListMarkers,
               textView.attributedText.string == TextOverlayDraft.placeholderHint {
                textView.text = ""
                parent.draft.text = ""
                parent.draft.spans = []
            }

            guard usesListMarkers else { return true }

            let markerRanges = TextOverlayListEditingEngine.markerRanges(
                plainText: parent.draft.text,
                listMode: parent.draft.listMode,
                listIndent: parent.draft.listIndent
            )

            // Block direct edits inside marker prefixes; handle backspace at body start as item removal.
            if markerRanges.contains(where: { TextOverlayListEditingEngine.rangesIntersect(range, $0) }) {
                if text.isEmpty {
                    return handleListBackspace(textView: textView, requestedRange: range)
                }
                // Redirect insertions that land in a marker to the body start of that line.
                if let marker = markerRanges.first(where: { TextOverlayListEditingEngine.rangesIntersect(range, $0) }) {
                    let bodyStart = marker.location + marker.length
                    textView.selectedRange = NSRange(location: bodyStart, length: 0)
                    if !text.isEmpty {
                        textView.insertText(text)
                    }
                    return false
                }
                return false
            }

            // Backspace at the very start of a list body deletes the previous line break.
            if text.isEmpty,
               range.length == 1,
               markerRanges.contains(where: { $0.location + $0.length == range.location }) {
                return handleListBackspace(textView: textView, requestedRange: range)
            }

            return true
        }

        private func handleListBackspace(textView: UITextView, requestedRange: NSRange) -> Bool {
            let plainRange = TextOverlayListEditingEngine.plainRange(
                displayRange: requestedRange,
                plainText: parent.draft.text,
                listMode: parent.draft.listMode,
                listIndent: parent.draft.listIndent
            )
            let ns = parent.draft.text as NSString
            // At start of a non-first line: remove the preceding newline (drops empty list item).
            if plainRange.location > 0,
               plainRange.length <= 1,
               ns.substring(with: NSRange(location: plainRange.location - 1, length: 1)) == "\n" {
                let deletion = NSRange(location: plainRange.location - 1, length: 1)
                parent.draft.text = ns.replacingCharacters(in: deletion, with: "")
                parent.draft.synchronizeSpansWithTextIfNeeded()
                parent.draft.selectedUTF16Location = deletion.location
                parent.draft.selectedUTF16Length = 0
                applyAttributedText(to: textView, force: true)
                parent.onEditingChanged()
                return false
            }
            // At start of first line: ignore marker deletion.
            if plainRange.location == 0, requestedRange.length > 0 {
                return false
            }
            return true
        }

        private func syncSelection(from textView: UITextView) {
            let plain = TextOverlayListEditingEngine.plainRange(
                displayRange: textView.selectedRange,
                plainText: parent.draft.text,
                listMode: parent.draft.listMode,
                listIndent: parent.draft.listIndent
            )
            parent.draft.selectedUTF16Location = plain.location
            parent.draft.selectedUTF16Length = plain.length
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
