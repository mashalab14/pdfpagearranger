import SwiftUI
import UIKit

enum TextOverlayFormatMenu: String, Equatable, CaseIterable {
    case appearance
    case style
    case alignment
    case lists
    case more
}

/// Freeform-style compact formatting bar with progressive disclosure menus.
struct TextOverlayFormatBar: View {
    @Binding var draft: TextOverlayDraft
    let recentTexts: [String]
    let onChange: () -> Void
    let onInsertRecent: (String) -> Void
    let onRemoveRecent: (String) -> Void
    let onDuplicate: () -> Void
    let onResetFormatting: () -> Void
    let onDone: () -> Void

    @State private var openMenu: TextOverlayFormatMenu?
    @State private var showRecentTexts = false

    var body: some View {
        VStack(spacing: 8) {
            if let openMenu {
                focusedPanel(for: openMenu)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("textOverlayFormatMenuPanel")
            }

            compactBar
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
        .accessibilityIdentifier("textOverlayFormatBar")
        .animation(.easeInOut(duration: 0.18), value: openMenu)
        .sheet(isPresented: $showRecentTexts, onDismiss: {
            if openMenu == .more { openMenu = nil }
        }) {
            recentTextsSheet
        }
        .onChange(of: showRecentTexts) { _, isPresented in
            if isPresented {
                openMenu = .more
            }
        }
        .onDisappear {
            showRecentTexts = false
            openMenu = nil
        }
    }

    private var compactBar: some View {
        HStack(spacing: 6) {
            menuToggle(.appearance, title: "Aa", systemImage: nil, id: "textFormatAppearanceButton")
            menuToggle(.style, title: nil, systemImage: "bold.italic.underline", id: "textFormatStyleButton")
            menuToggle(.alignment, title: nil, systemImage: alignmentIcon, id: "textFormatAlignmentButton")
            menuToggle(.lists, title: nil, systemImage: "list.bullet", id: "textFormatListsButton")
            menuToggle(.more, title: nil, systemImage: "ellipsis", id: "textFormatMoreButton")

            Spacer(minLength: 8)

            Button("Done", action: {
                openMenu = nil
                onDone()
            })
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("textOverlayEditingDone")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityIdentifier("textOverlayCompactToolbar")
    }

    private var alignmentIcon: String {
        switch draft.alignment {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }

    private func menuToggle(
        _ menu: TextOverlayFormatMenu,
        title: String?,
        systemImage: String?,
        id: String
    ) -> some View {
        let isOpen = openMenu == menu
        return Button {
            openMenu = isOpen ? nil : menu
            if menu != .more {
                showRecentTexts = false
            }
        } label: {
            Group {
                if let title {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                }
            }
            .foregroundStyle(isOpen ? Color.accentColor : Color.primary)
            .frame(minWidth: 36, minHeight: 32)
            .padding(.horizontal, 6)
            .background(
                isOpen ? Color.accentColor.opacity(0.14) : Color.clear,
                in: Capsule()
            )
        }
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }

    @ViewBuilder
    private func focusedPanel(for menu: TextOverlayFormatMenu) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch menu {
            case .appearance:
                appearancePanel
            case .style:
                stylePanel
            case .alignment:
                alignmentPanel
            case .lists:
                listsPanel
            case .more:
                morePanel
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Font & Appearance")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("textFormatAppearanceTitle")

            HStack(spacing: 8) {
                ForEach(TextOverlayFontFamily.allCases, id: \.self) { family in
                    Button(family.displayName) {
                        draft.applyFormatting(
                            updateDefaults: { $0.fontFamily = family },
                            updateSpan: { $0.fontFamily = family }
                        )
                        onChange()
                    }
                    .buttonStyle(.bordered)
                    .tint(draft.fontFamily == family ? Color.accentColor : Color.secondary)
                    .accessibilityIdentifier("textFontFamily_\(family.rawValue)")
                }
            }
            .accessibilityIdentifier("textFontFamilyMenu")

            HStack(spacing: 8) {
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

                Text("\(Int(draft.fontSizePoints)) pt")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .frame(minWidth: 52)

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

            HStack(spacing: 12) {
                ColorPicker(
                    "Text Color",
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
                .accessibilityLabel("Text Color")
                .accessibilityIdentifier("textColorPicker")

                HStack(spacing: 8) {
                    Image(systemName: "circle.lefthalf.filled")
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
                    Text("\(Int((draft.opacity * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .frame(minWidth: 36, alignment: .trailing)
                }
                .accessibilityIdentifier("textOpacitySlider")
            }
        }
        .accessibilityIdentifier("textFormatAppearancePanel")
    }

    private var stylePanel: some View {
        HStack(spacing: 10) {
            styleToggle("bold", isOn: draft.isBold, id: "textBoldToggle") {
                let next = !draft.isBold
                draft.applyFormatting(
                    updateDefaults: { $0.isBold = next },
                    updateSpan: { $0.isBold = next }
                )
                onChange()
            }
            styleToggle("italic", isOn: draft.isItalic, id: "textItalicToggle") {
                let next = !draft.isItalic
                draft.applyFormatting(
                    updateDefaults: { $0.isItalic = next },
                    updateSpan: { $0.isItalic = next }
                )
                onChange()
            }
            styleToggle("underline", isOn: draft.isUnderline, id: "textUnderlineToggle") {
                let next = !draft.isUnderline
                draft.applyFormatting(
                    updateDefaults: { $0.isUnderline = next },
                    updateSpan: { $0.isUnderline = next }
                )
                onChange()
            }
            styleToggle("strikethrough", isOn: draft.isStrikethrough, id: "textStrikethroughToggle") {
                let next = !draft.isStrikethrough
                draft.applyFormatting(
                    updateDefaults: { $0.isStrikethrough = next },
                    updateSpan: { $0.isStrikethrough = next }
                )
                onChange()
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("textFormatStylePanel")
    }

    private var alignmentPanel: some View {
        HStack(spacing: 10) {
            alignButton(.left, icon: "text.alignleft", id: "textAlignLeft")
            alignButton(.center, icon: "text.aligncenter", id: "textAlignCenter")
            alignButton(.right, icon: "text.alignright", id: "textAlignRight")
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("textFormatAlignmentPanel")
    }

    private var listsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                listButton(.plain, icon: "text.justify.left", id: "textListNone")
                listButton(.bulleted, icon: "list.bullet", id: "textBulletedListToggle")
                listButton(.numbered, icon: "list.number", id: "textNumberedListToggle")
                listButton(.dashed, icon: "list.dash", id: "textDashedListToggle")
            }

            HStack(spacing: 8) {
                Button {
                    draft.listIndent = max(0, draft.listIndent - 1)
                    onChange()
                } label: {
                    Label("Decrease Indent", systemImage: "decrease.indent")
                }
                .disabled(draft.listIndent <= 0)
                .accessibilityIdentifier("textIndentDecrease")

                Button {
                    draft.listIndent = min(TextOverlayDraft.maxListIndent, draft.listIndent + 1)
                    onChange()
                } label: {
                    Label("Increase Indent", systemImage: "increase.indent")
                }
                .disabled(draft.listIndent >= TextOverlayDraft.maxListIndent)
                .accessibilityIdentifier("textIndentIncrease")
            }
        }
        .accessibilityIdentifier("textFormatListsPanel")
    }

    private var morePanel: some View {
        VStack(spacing: 8) {
            Button {
                insertToday()
                openMenu = nil
            } label: {
                Label("Insert Today", systemImage: "calendar")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("insertTodayButton")

            Button {
                showRecentTexts = true
            } label: {
                Label("Recent Texts", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("textRecentTextsButton")

            Button {
                onDuplicate()
                openMenu = nil
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("textFormatDuplicateButton")

            Button {
                onResetFormatting()
                openMenu = nil
            } label: {
                Label("Reset Formatting", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("textFormatResetButton")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("textFormatMorePanel")
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
                            openMenu = nil
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
                    Button("Close") {
                        showRecentTexts = false
                        openMenu = nil
                    }
                }
            }
            .accessibilityIdentifier("recentTextsSection")
        }
        .presentationDetents([.medium])
    }

    private func insertToday() {
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
    }

    private func styleToggle(
        _ systemName: String,
        isOn: Bool,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
                .frame(width: 44, height: 36)
                .background(isOn ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityIdentifier(id)
    }

    private func alignButton(_ alignment: TextOverlayAlignment, icon: String, id: String) -> some View {
        styleToggle(icon, isOn: draft.alignment == alignment, id: id) {
            draft.alignment = alignment
            onChange()
        }
    }

    private func listButton(_ mode: TextOverlayListMode, icon: String, id: String) -> some View {
        styleToggle(icon, isOn: draft.listMode == mode, id: id) {
            draft.listMode = mode
            onChange()
        }
    }
}
