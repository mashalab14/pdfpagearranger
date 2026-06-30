import SwiftUI

struct EditSignaturePlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Label("Color", systemImage: "paintpalette")
                        .foregroundStyle(.secondary)
                    Label("Thickness", systemImage: "lineweight")
                        .foregroundStyle(.secondary)
                    Label("Opacity", systemImage: "circle.lefthalf.filled")
                        .foregroundStyle(.secondary)
                }

                Section("Signature") {
                    Label("Replace Signature", systemImage: "signature")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("editSignaturePlaceholderDone")
                }
            }
            .accessibilityIdentifier("editSignaturePlaceholderSheet")
        }
    }
}
