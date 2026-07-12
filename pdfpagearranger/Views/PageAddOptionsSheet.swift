import SwiftUI

struct PageAddOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onTextTapped: () -> Void
    let onImageTapped: () -> Void
    let onQuickSignatureTapped: () -> Void
    let onSignatureLibraryTapped: () -> Void

    var body: some View {
        NavigationStack {
            List {
                addOption(
                    icon: "textformat",
                    title: "Text",
                    subtitle: "Add editable text",
                    isEnabled: true,
                    accessibilityIdentifier: "addTextOption"
                ) {
                    dismiss()
                    onTextTapped()
                }
                addOption(icon: "photo", title: "Image", subtitle: "Import from Photos or Files", isEnabled: true) {
                    dismiss()
                    onImageTapped()
                }
                addOption(
                    icon: "signature",
                    title: "Quick Signature",
                    subtitle: "Place your default signature",
                    isEnabled: true,
                    accessibilityIdentifier: "addQuickSignatureOption"
                ) {
                    dismiss()
                    onQuickSignatureTapped()
                }
                addOption(
                    icon: "books.vertical",
                    title: "Signature Library",
                    subtitle: "Choose, create, or manage signatures",
                    isEnabled: true,
                    accessibilityIdentifier: "addSignatureLibraryOption"
                ) {
                    dismiss()
                    onSignatureLibraryTapped()
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func addOption(
        icon: String,
        title: String,
        subtitle: String,
        isEnabled: Bool,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let button = Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(!isEnabled)

        if let accessibilityIdentifier {
            button.accessibilityIdentifier(accessibilityIdentifier)
        } else {
            button
        }
    }
}

#Preview {
    PageAddOptionsSheet(onTextTapped: {}, onImageTapped: {}, onQuickSignatureTapped: {}, onSignatureLibraryTapped: {})
}
