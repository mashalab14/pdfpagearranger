import SwiftUI

struct PageAddOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onImageTapped: () -> Void

    var body: some View {
        NavigationStack {
            List {
                addOption(icon: "textformat", title: "Text", subtitle: "Coming soon", isEnabled: false) {}
                addOption(icon: "photo", title: "Image", subtitle: "Import from Photos or Files", isEnabled: true) {
                    dismiss()
                    onImageTapped()
                }
                addOption(icon: "signature", title: "Signature", subtitle: "Coming soon", isEnabled: false) {}
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

    private func addOption(
        icon: String,
        title: String,
        subtitle: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
    }
}

#Preview {
    PageAddOptionsSheet(onImageTapped: {})
}
