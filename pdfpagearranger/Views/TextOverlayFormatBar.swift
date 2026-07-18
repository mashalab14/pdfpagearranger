import SwiftUI
import UIKit

enum TextOverlayFormatMenu: String, Equatable, CaseIterable {
    case appearance
    case style
    case alignment
    case lists
    case more
    case insertDate
}

/// Freeform-style compact formatting bar. A single persistent toolbar morphs into contextual controls.
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
    @State private var selectedDate = Date()

    var body: some View {
        HStack(spacing: 6) {
            toolbarContent
                .animation(.easeInOut(duration: 0.2), value: openMenu)

            Spacer(minLength: 6)

            Button("Done", action: {
                openMenu = nil
                onDone()
            })
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("textOverlayEditingDone")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .accessibilityIdentifier("textOverlayFormatBar")
        .sheet(isPresented: $showRecentTexts, onDismiss: {
            if openMenu == .more { openMenu = nil }
        }) {
            recentTextsSheet
        }
        .onDisappear {
            showRecentTexts = false
            openMenu = nil
        }
    }

    @ViewBuilder
    private var toolbarContent: some View {
        if let openMenu {
            contextualToolbar(for: openMenu)
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .accessibilityIdentifier("textOverlayFormatMenuPanel")
        } else {
            rootToolbar
                .transition(.opacity)
                .accessibilityIdentifier("textOverlayCompactToolbar")
        }
    }

    private var rootToolbar: some View {
        HStack(spacing: 4) {
            menuToggle(.appearance, title: "Aa", systemImage: nil, id: "textFormatAppearanceButton")
            menuToggle(.style, title: nil, systemImage: "bold.italic.underline", id: "textFormatStyleButton")
            menuToggle(.alignment, title: nil, systemImage: alignmentIcon, id: "textFormatAlignmentButton")
            menuToggle(.lists, title: nil, systemImage: "list.bullet", id: "textFormatListsButton")
            menuToggle(.more, title: nil, systemImage: "ellipsis", id: "textFormatMoreButton")
        }
    }

    private var alignmentIcon: String {
        switch draft.alignment {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }

    @ViewBuilder
    private func contextualToolbar(for menu: TextOverlayFormatMenu) -> some View {
        HStack(spacing: 6) {
            backButton

            switch menu {
            case .appearance:
                appearanceControls
            case .style:
                styleControls
            case .alignment:
                alignmentControls
            case .lists:
                listsControls
            case .more:
                moreControls
            case .insertDate:
                insertDateControls
            }
        }
    }

    private var backButton: some View {
        Button {
            if openMenu == .insertDate {
                openMenu = .more
            } else {
                openMenu = nil
            }
        } label: {
            Image(systemName: "chevron.backward")
                .font(.body.weight(.semibold))
                .frame(width: 28, height: 28)
        }
        .accessibilityIdentifier("textFormatBackButton")
        .accessibilityLabel("Back")
    }

    private func menuToggle(
        _ menu: TextOverlayFormatMenu,
        title: String?,
        systemImage: String?,
        id: String
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                openMenu = menu
            }
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
            .foregroundStyle(Color.primary)
            .frame(minWidth: 32, minHeight: 28)
            .padding(.horizontal, 4)
        }
        .accessibilityIdentifier(id)
    }

    private var appearanceControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TextOverlayFontFamily.allCases, id: \.self) { family in
                    Button(family.displayName) {
                        draft.applyFormatting(
                            updateDefaults: { $0.fontFamily = family },
                            updateSpan: { $0.fontFamily = family }
                        )
                        onChange()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(draft.fontFamily == family ? Color.accentColor : Color.primary)
                    .accessibilityIdentifier("textFontFamily_\(family.rawValue)")
                }
                .accessibilityIdentifier("textFontFamilyMenu")

                Divider().frame(height: 18)

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
                    .frame(width: 84)
                    Text("\(Int((draft.opacity * 100).rounded()))%")
                        .font(.caption2.monospacedDigit())
                        .frame(minWidth: 28, alignment: .trailing)
                }
                .accessibilityIdentifier("textOpacitySlider")
            }
            .accessibilityIdentifier("textFontSizeStepper")
        }
        .accessibilityIdentifier("textFormatAppearancePanel")
    }

    private var styleControls: some View {
        HStack(spacing: 6) {
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
        .accessibilityIdentifier("textFormatStylePanel")
    }

    private var alignmentControls: some View {
        HStack(spacing: 6) {
            alignButton(.left, icon: "text.alignleft", id: "textAlignLeft")
            alignButton(.center, icon: "text.aligncenter", id: "textAlignCenter")
            alignButton(.right, icon: "text.alignright", id: "textAlignRight")
        }
        .accessibilityIdentifier("textFormatAlignmentPanel")
    }

    private var listsControls: some View {
        HStack(spacing: 6) {
            listButton(.plain, icon: "text.justify.left", id: "textListNone")
            listButton(.bulleted, icon: "list.bullet", id: "textBulletedListToggle")
            listButton(.numbered, icon: "list.number", id: "textNumberedListToggle")
            listButton(.dashed, icon: "list.dash", id: "textDashedListToggle")

            Divider().frame(height: 18)

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
        .accessibilityIdentifier("textFormatListsPanel")
    }

    private var moreControls: some View {
        HStack(spacing: 8) {
            Button {
                selectedDate = Date()
                withAnimation(.easeInOut(duration: 0.2)) {
                    openMenu = .insertDate
                }
            } label: {
                Label("Insert Date", systemImage: "calendar")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
            }
            .accessibilityIdentifier("insertDateButton")

            Button {
                showRecentTexts = true
            } label: {
                Label("Recent", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
            }
            .accessibilityIdentifier("textRecentTextsButton")

            Button {
                onDuplicate()
                openMenu = nil
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            .accessibilityIdentifier("textFormatDuplicateButton")

            Button {
                onResetFormatting()
                openMenu = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("textFormatResetButton")
        }
        .accessibilityIdentifier("textFormatMorePanel")
    }

    private var insertDateControls: some View {
        HStack(spacing: 8) {
            DatePicker(
                "Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .accessibilityIdentifier("textInsertDatePicker")

            Button("Today") {
                selectedDate = Date()
            }
            .font(.caption.weight(.semibold))
            .accessibilityIdentifier("textInsertDateTodayButton")

            Button("Insert") {
                insertSelectedDate()
                openMenu = nil
            }
            .font(.caption.weight(.bold))
            .accessibilityIdentifier("textInsertDateConfirmButton")
        }
        .accessibilityIdentifier("textFormatInsertDatePanel")
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

    private func insertSelectedDate() {
        let value = TextOverlayFormattingEngine.localizedDateString(date: selectedDate)
        draft.insertTextAtSelection(value)
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
                .frame(width: 32, height: 28)
                .background(isOn ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
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
