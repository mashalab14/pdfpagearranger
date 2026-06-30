import SwiftUI

struct SignatureOverlayContextMenu: View {
    let anchorPoint: CGPoint
    let showReset: Bool
    let showSaveToLibrary: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onReset: () -> Void
    let onSaveToLibrary: () -> Void

    private let cellSize = SignatureContextualUIMetrics.minimumTapTarget

    var body: some View {
        HStack(spacing: SignatureContextualUIMetrics.toolbarCellSpacing) {
            toolbarButton(
                systemName: "pencil",
                foregroundStyle: Color.primary,
                accessibilityLabel: "Edit Signature",
                accessibilityIdentifier: "signatureMenuEdit",
                action: onEdit
            )
            divider
            toolbarButton(
                systemName: "trash",
                foregroundStyle: Color.red,
                accessibilityLabel: "Delete Signature",
                accessibilityIdentifier: "signatureMenuDelete",
                action: onDelete
            )
            divider
            Menu {
                if showReset {
                    Button("Reset") {
                        onReset()
                    }
                    .accessibilityIdentifier("signatureMenuReset")
                }
                if showSaveToLibrary {
                    Button("Save to Library") {
                        onSaveToLibrary()
                    }
                    .accessibilityIdentifier("signatureMenuSaveToLibrary")
                }
                if showReset || showSaveToLibrary {
                    Divider()
                }
                Button("Duplicate") {}.disabled(true)
                Button("Replace Signature") {}.disabled(true)
                Button("Bring Forward") {}.disabled(true)
                Button("Send Backward") {}.disabled(true)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: cellSize, height: cellSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: cellSize, height: cellSize)
            .accessibilityLabel("More Signature Actions")
            .accessibilityIdentifier("signatureMenuMore")
        }
        .font(.subheadline)
        .padding(.horizontal, SignatureContextualUIMetrics.toolbarHorizontalPadding)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.75), in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .position(anchorPoint)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("signatureOverlayContextMenu")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1, height: 28)
    }

    private func toolbarButton(
        systemName: String,
        foregroundStyle: Color,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foregroundStyle)
                .frame(width: cellSize, height: cellSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: cellSize, height: cellSize)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
