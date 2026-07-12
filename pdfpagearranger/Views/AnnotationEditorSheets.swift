import SwiftUI

struct TextCommentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let confirmTitle: String
    let selectedText: String
    @Binding var commentText: String
    let onConfirm: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                if !selectedText.isEmpty {
                    Section("Selected Text") {
                        Text(selectedText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("textCommentSelectedTextPreview")
                    }
                }

                Section("Comment") {
                    TextEditor(text: $commentText)
                        .frame(minHeight: 120)
                        .focused($isFocused)
                        .accessibilityLabel("Comment")
                        .accessibilityIdentifier("textCommentEditorInput")
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
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("textCommentEditorConfirm")
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct StickyNoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let confirmTitle: String
    @Binding var noteText: String
    let onConfirm: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 120)
                        .focused($isFocused)
                        .accessibilityLabel("Sticky Note")
                        .accessibilityIdentifier("stickyNoteEditorInput")
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
                        .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("stickyNoteEditorConfirm")
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}
