import SwiftUI

struct PageAddOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                addOption(icon: "textformat", title: "Text", subtitle: "Coming soon")
                addOption(icon: "photo", title: "Image", subtitle: "Coming soon")
                addOption(icon: "signature", title: "Signature", subtitle: "Coming soon")
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

    private func addOption(icon: String, title: String, subtitle: String) -> some View {
        Button {
            // Placeholder — overlay tools will be added later.
        } label: {
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
    }
}

#Preview {
    PageAddOptionsSheet()
}
