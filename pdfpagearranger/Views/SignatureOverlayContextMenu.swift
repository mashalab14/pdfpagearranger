import SwiftUI

struct SignatureOverlayContextMenu: View {
    let anchorPoint: CGPoint
    let showReset: Bool
    let showSaveToLibrary: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onReset: () -> Void
    let onSaveToLibrary: () -> Void

    var body: some View {
        HStack(spacing: ContextualControlMetrics.toolbarCellSpacing) {
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
                    .font(ContextualControlMetrics.toolbarSymbolFont)
                    .foregroundStyle(Color.primary)
                    .frame(
                        width: ContextualControlMetrics.toolbarVisibleIconWidth,
                        height: ContextualControlMetrics.toolbarVisibleIconHeight
                    )
            }
            .buttonStyle(.plain)
            .contextualExpandedTapTarget(
                visibleWidth: ContextualControlMetrics.toolbarVisibleCellWidth,
                visibleHeight: ContextualControlMetrics.toolbarVisibleHeight
            )
            .accessibilityLabel("More Signature Actions")
            .accessibilityIdentifier("signatureMenuMore")
        }
        .frame(height: ContextualControlMetrics.toolbarVisibleHeight)
        .contextualGlassContainer()
        .fixedSize(horizontal: true, vertical: true)
        .position(anchorPoint)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("signatureOverlayContextMenu")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(ContextualControlMetrics.toolbarDividerOpacity))
            .frame(width: 1, height: ContextualControlMetrics.toolbarDividerHeight)
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
                .font(ContextualControlMetrics.toolbarSymbolFont)
                .foregroundStyle(foregroundStyle)
                .frame(
                    width: ContextualControlMetrics.toolbarVisibleIconWidth,
                    height: ContextualControlMetrics.toolbarVisibleIconHeight
                )
        }
        .buttonStyle(.plain)
        .contextualExpandedTapTarget(
            visibleWidth: ContextualControlMetrics.toolbarVisibleCellWidth,
            visibleHeight: ContextualControlMetrics.toolbarVisibleHeight
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
