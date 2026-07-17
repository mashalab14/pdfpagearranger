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
    @State private var showFontMenu = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    fontMenu
                    sizeStepper
                    colorPicker
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
                    draft.fontFamily = family
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
                draft.fontSizePoints = TextOverlayLayoutEngine.clampedFontSize(draft.fontSizePoints - 1)
                onChange()
            } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .accessibilityIdentifier("textFontSizeDecrease")

            Text("\(Int(draft.fontSizePoints))")
                .font(.caption.monospacedDigit().weight(.medium))
                .frame(minWidth: 24)

            Button {
                draft.fontSizePoints = TextOverlayLayoutEngine.clampedFontSize(draft.fontSizePoints + 1)
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
                    draft.colorRGBA = SignatureInkRGBA(uiColor: UIColor($0))
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

    private var styleToggles: some View {
        HStack(spacing: 6) {
            formatToggle("bold", isOn: draft.isBold, id: "textBoldToggle") {
                draft.isBold.toggle()
                onChange()
            }
            formatToggle("italic", isOn: draft.isItalic, id: "textItalicToggle") {
                draft.isItalic.toggle()
                onChange()
            }
            formatToggle("underline", isOn: draft.isUnderline, id: "textUnderlineToggle") {
                draft.isUnderline.toggle()
                onChange()
            }
            formatToggle("strikethrough", isOn: draft.isStrikethrough, id: "textStrikethroughToggle") {
                draft.isStrikethrough.toggle()
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
            draft.text = TextOverlayFormattingEngine.appendToday(to: draft.text)
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
