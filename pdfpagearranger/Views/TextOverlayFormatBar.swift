import SwiftUI
import UIKit

/// Compact formatting controls shown above the keyboard while editing text overlays.
struct TextOverlayFormatBar: View {
    @Binding var draft: TextOverlayDraft
    let recentTexts: [String]
    let onChange: () -> Void
    let onInsertRecent: (String) -> Void
    let onRemoveRecent: (String) -> Void
    let onDone: () -> Void

    @State private var showRecentTexts = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    fontMenu
                    sizeStepper
                    colorPicker
                    opacityControl
                    styleToggles
                    alignmentControls
                    listControls
                    indentControls
                    recentButton
                    insertTodayButton
                    doneButton
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .accessibilityIdentifier("textOverlayFormatBar")
        }
        .background(.bar)
        .sheet(isPresented: $showRecentTexts) {
            recentTextsSheet
        }
    }

    private var fontMenu: some View {
        Menu {
            ForEach(TextOverlayFontFamily.allCases, id: \.self) { family in
                Button(family.displayName) {
                    draft.applyFormatting(
                        updateDefaults: { $0.fontFamily = family },
                        updateSpan: { $0.fontFamily = family }
                    )
                    onChange()
                }
            }
        } label: {
            Label(draft.fontFamily.displayName, systemImage: "textformat")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
        }
        .accessibilityIdentifier("textFontFamilyMenu")
    }

    private var sizeStepper: some View {
        HStack(spacing: 4) {
            Button {
                let next = TextOverlayLayoutEngine.clampedFontSize(draft.fontSizePoints - 1)
                draft.applyFormatting(
                    updateDefaults: { $0.fontSizePoints = next },
                    updateSpan: { $0.fontSizePoints = next }
                )
                onChange()
            } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .accessibilityIdentifier("textFontSizeDecrease")

            Text("\(Int(draft.fontSizePoints))")
                .font(.caption.monospacedDigit().weight(.medium))
                .frame(minWidth: 24)

            Button {
                let next = TextOverlayLayoutEngine.clampedFontSize(draft.fontSizePoints + 1)
                draft.applyFormatting(
                    updateDefaults: { $0.fontSizePoints = next },
                    updateSpan: { $0.fontSizePoints = next }
                )
                onChange()
            } label: {
                Image(systemName: "textformat.size.larger")
            }
            .accessibilityIdentifier("textFontSizeIncrease")
        }
        .accessibilityIdentifier("textFontSizeStepper")
    }

    private var colorPicker: some View {
        ColorPicker(
            "",
            selection: Binding(
                get: { Color(draft.colorRGBA.uiColor) },
                set: {
                    let rgba = SignatureInkRGBA(uiColor: UIColor($0))
                    draft.applyFormatting(
                        updateDefaults: { $0.colorRGBA = rgba },
                        updateSpan: { $0.colorRGBA = rgba }
                    )
                    onChange()
                }
            ),
            supportsOpacity: false
        )
        .labelsHidden()
        .frame(width: 28, height: 28)
        .accessibilityLabel("Text Color")
        .accessibilityIdentifier("textColorPicker")
    }

    private var opacityControl: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.caption)
            Slider(
                value: Binding(
                    get: { Double(draft.opacity) },
                    set: {
                        draft.opacity = TextOverlayDraft.clampedOpacity(CGFloat($0))
                        onChange()
                    }
                ),
                in: Double(TextOverlayDraft.minOpacity)...Double(TextOverlayDraft.maxOpacity)
            )
            .frame(width: 88)
            Text("\(Int((draft.opacity * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .frame(minWidth: 36, alignment: .trailing)
        }
        .accessibilityIdentifier("textOpacitySlider")
    }

    private var styleToggles: some View {
        HStack(spacing: 6) {
            formatToggle("bold", isOn: draft.isBold, id: "textBoldToggle") {
                let next = !draft.isBold
                draft.applyFormatting(
                    updateDefaults: { $0.isBold = next },
                    updateSpan: { $0.isBold = next }
                )
                onChange()
            }
            formatToggle("italic", isOn: draft.isItalic, id: "textItalicToggle") {
                let next = !draft.isItalic
                draft.applyFormatting(
                    updateDefaults: { $0.isItalic = next },
                    updateSpan: { $0.isItalic = next }
                )
                onChange()
            }
            formatToggle("underline", isOn: draft.isUnderline, id: "textUnderlineToggle") {
                let next = !draft.isUnderline
                draft.applyFormatting(
                    updateDefaults: { $0.isUnderline = next },
                    updateSpan: { $0.isUnderline = next }
                )
                onChange()
            }
            formatToggle("strikethrough", isOn: draft.isStrikethrough, id: "textStrikethroughToggle") {
                let next = !draft.isStrikethrough
                draft.applyFormatting(
                    updateDefaults: { $0.isStrikethrough = next },
                    updateSpan: { $0.isStrikethrough = next }
                )
                onChange()
            }
        }
    }

    private var alignmentControls: some View {
        HStack(spacing: 4) {
            alignButton(.left, icon: "text.alignleft", id: "textAlignLeft")
            alignButton(.center, icon: "text.aligncenter", id: "textAlignCenter")
            alignButton(.right, icon: "text.alignright", id: "textAlignRight")
        }
    }

    private var listControls: some View {
        HStack(spacing: 4) {
            listButton(.plain, icon: "text.justify.left", id: "textListNone")
            listButton(.bulleted, icon: "list.bullet", id: "textBulletedListToggle")
            listButton(.numbered, icon: "list.number", id: "textNumberedListToggle")
            listButton(.dashed, icon: "list.dash", id: "textDashedListToggle")
        }
    }

    private var indentControls: some View {
        HStack(spacing: 4) {
            Button {
                draft.listIndent = max(0, draft.listIndent - 1)
                onChange()
            } label: {
                Image(systemName: "decrease.indent")
            }
            .disabled(draft.listIndent <= 0)
            .accessibilityIdentifier("textIndentDecrease")

            Button {
                draft.listIndent = min(TextOverlayDraft.maxListIndent, draft.listIndent + 1)
                onChange()
            } label: {
                Image(systemName: "increase.indent")
            }
            .disabled(draft.listIndent >= TextOverlayDraft.maxListIndent)
            .accessibilityIdentifier("textIndentIncrease")
        }
    }

    private var recentButton: some View {
        Button {
            showRecentTexts = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .accessibilityLabel("Recent Texts")
        .accessibilityIdentifier("textRecentTextsButton")
    }

    private var insertTodayButton: some View {
        Button {
            let updated = TextOverlayFormattingEngine.appendToday(to: draft.text)
            let appended = String(updated.dropFirst(draft.text.count))
            draft.text = updated
            draft.synchronizeSpansWithTextIfNeeded()
            if !appended.isEmpty {
                let defaults = TextOverlayRichTextEngine.StyleDefaults(from: draft)
                draft.spans.append(
                    TextOverlayTextSpan(
                        text: appended,
                        fontSizePoints: defaults.fontSizePoints,
                        colorRGBA: defaults.colorRGBA,
                        isBold: defaults.isBold,
                        isItalic: defaults.isItalic,
                        isUnderline: defaults.isUnderline,
                        isStrikethrough: defaults.isStrikethrough,
                        fontFamily: defaults.fontFamily
                    )
                )
                draft.spans = TextOverlayRichTextEngine.mergeAdjacent(draft.spans)
            }
            onChange()
        } label: {
            Image(systemName: "calendar")
        }
        .accessibilityLabel("Insert Today")
        .accessibilityIdentifier("insertTodayButton")
    }

    private var doneButton: some View {
        Button("Done", action: onDone)
            .font(.caption.weight(.semibold))
            .accessibilityIdentifier("textOverlayEditingDone")
    }

    private var recentTextsSheet: some View {
        NavigationStack {
            List {
                if recentTexts.isEmpty {
                    Text("No recent texts yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentTexts, id: \.self) { entry in
                        Button {
                            onInsertRecent(entry)
                            showRecentTexts = false
                        } label: {
                            Text(entry)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                        .accessibilityIdentifier("recentTextEntry")
                        .swipeActions {
                            Button(role: .destructive) {
                                onRemoveRecent(entry)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recent Texts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showRecentTexts = false }
                }
            }
            .accessibilityIdentifier("recentTextsSection")
        }
        .presentationDetents([.medium])
    }

    private func formatToggle(
        _ systemName: String,
        isOn: Bool,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
                .padding(6)
                .background(isOn ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityIdentifier(id)
    }

    private func alignButton(_ alignment: TextOverlayAlignment, icon: String, id: String) -> some View {
        formatToggle(icon, isOn: draft.alignment == alignment, id: id) {
            draft.alignment = alignment
            onChange()
        }
    }

    private func listButton(_ mode: TextOverlayListMode, icon: String, id: String) -> some View {
        formatToggle(icon, isOn: draft.listMode == mode, id: id) {
            draft.listMode = mode
            onChange()
        }
    }
}
