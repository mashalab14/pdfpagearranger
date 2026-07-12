import SwiftUI

struct TextOverlayEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let confirmTitle: String
    @Binding var draft: TextOverlayDraft
    let recentTexts: [String]
    let onRemoveRecent: (String) -> Void
    let onConfirm: () -> Void

    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draft.text)
                        .frame(minHeight: 120)
                        .focused($isEditorFocused)
                        .accessibilityLabel("Text")
                        .accessibilityIdentifier("textOverlayEditorInput")
                }

                if !recentTexts.isEmpty {
                    Section("Recent Texts") {
                        ForEach(recentTexts, id: \.self) { entry in
                            Button {
                                draft.text = entry
                                draft.listMode = .plain
                            } label: {
                                Text(entry)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            .accessibilityLabel("Recent Text")
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
                    .accessibilityIdentifier("recentTextsSection")
                }

                Section {
                    Button("Insert Today") {
                        insertToday()
                    }
                    .accessibilityLabel("Insert Today")
                    .accessibilityIdentifier("insertTodayButton")
                }

                Section("Formatting") {
                    Stepper(
                        value: $draft.fontSizePoints,
                        in: TextOverlayLayoutEngine.minFontSizePoints...TextOverlayLayoutEngine.maxFontSizePoints,
                        step: 1
                    ) {
                        Text("Font Size: \(Int(draft.fontSizePoints)) pt")
                    }
                    .accessibilityLabel("Font Size")
                    .accessibilityIdentifier("textFontSizeStepper")

                    ColorPicker(
                        "Text Color",
                        selection: Binding(
                            get: { Color(draft.colorRGBA.uiColor) },
                            set: { draft.colorRGBA = SignatureInkRGBA(uiColor: UIColor($0)) }
                        ),
                        supportsOpacity: false
                    )
                    .accessibilityLabel("Text Color")
                    .accessibilityIdentifier("textColorPicker")

                    Toggle("Bold", isOn: $draft.isBold)
                        .accessibilityLabel("Bold")
                        .accessibilityIdentifier("textBoldToggle")

                    Toggle("Bulleted List", isOn: bulletedBinding)
                        .accessibilityLabel("Bulleted List")
                        .accessibilityIdentifier("textBulletedListToggle")

                    Toggle("Numbered List", isOn: numberedBinding)
                        .accessibilityLabel("Numbered List")
                        .accessibilityIdentifier("textNumberedListToggle")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle, action: onConfirm)
                        .disabled(draft.isEmpty)
                        .accessibilityIdentifier("textOverlayEditorConfirm")
                }
            }
            .onAppear {
                isEditorFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var bulletedBinding: Binding<Bool> {
        Binding(
            get: { draft.listMode == .bulleted },
            set: { isOn in
                setListMode(isOn ? .bulleted : .plain)
            }
        )
    }

    private var numberedBinding: Binding<Bool> {
        Binding(
            get: { draft.listMode == .numbered },
            set: { isOn in
                setListMode(isOn ? .numbered : .plain)
            }
        )
    }

    private func setListMode(_ newMode: TextOverlayListMode) {
        draft.text = TextOverlayFormattingEngine.switchingListMode(
            from: draft.listMode,
            to: newMode,
            text: draft.text
        )
        draft.listMode = newMode
    }

    private func insertToday() {
        let today = TextOverlayFormattingEngine.localizedTodayString()
        if draft.text.isEmpty {
            draft.text = today
        } else if draft.text.hasSuffix("\n") {
            draft.text += today
        } else {
            draft.text += " \(today)"
        }
    }
}
