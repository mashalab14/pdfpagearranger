import SwiftUI

struct PaywallView: View {
    let pageCount: Int
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "doc.richtext")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Unlock PDF Pages Pro")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("You're exporting \(pageCount) pages. Free exports are limited to \(ProGate.freePageExportLimit) pages.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    benefitRow(icon: "infinity", text: "Unlimited pages")
                    benefitRow(icon: "doc.on.doc", text: "Merge & split (coming soon)")
                    benefitRow(icon: "square.stack.3d.up", text: "Batch tools (coming soon)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Spacer()

                Button("Continue for now") {
                    onContinue()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    PaywallView(pageCount: 42) {}
}
