import SwiftUI

struct SignatureOverlayContextMenu: View {
    let anchorPoint: CGPoint
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            iconButton(
                systemName: "pencil",
                accessibilityLabel: "Edit Signature",
                accessibilityIdentifier: "signatureMenuEdit",
                action: onEdit
            )
            divider
            iconButton(
                systemName: "trash",
                accessibilityLabel: "Delete Signature",
                accessibilityIdentifier: "signatureMenuDelete",
                action: onDelete
            )
            divider
            Menu {
                Button("Duplicate") {}.disabled(true)
                Button("Replace Signature") {}.disabled(true)
                Button("Bring Forward") {}.disabled(true)
                Button("Send Backward") {}.disabled(true)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More Signature Actions")
            .accessibilityIdentifier("signatureMenuMore")
        }
        .font(.subheadline)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .position(anchorPoint)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("signatureOverlayContextMenu")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 20)
    }

    private func iconButton(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.semibold))
                .frame(width: 36, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
