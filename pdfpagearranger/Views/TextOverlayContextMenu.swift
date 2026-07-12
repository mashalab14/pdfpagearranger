import SwiftUI

struct TextOverlayContextMenu: View {
    let anchorPoint: CGPoint
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: ContextualControlMetrics.toolbarCellSpacing) {
            toolbarButton(
                systemName: "pencil",
                foregroundStyle: Color.primary,
                accessibilityLabel: "Edit Text",
                accessibilityIdentifier: "textMenuEdit",
                action: onEdit
            )
            divider
            toolbarButton(
                systemName: "plus.square.on.square",
                foregroundStyle: Color.primary,
                accessibilityLabel: "Duplicate Text",
                accessibilityIdentifier: "textMenuDuplicate",
                action: onDuplicate
            )
            divider
            toolbarButton(
                systemName: "trash",
                foregroundStyle: Color.red,
                accessibilityLabel: "Delete Text",
                accessibilityIdentifier: "textMenuDelete",
                action: onDelete
            )
        }
        .frame(height: ContextualControlMetrics.toolbarVisibleHeight)
        .contextualGlassContainer()
        .fixedSize(horizontal: true, vertical: true)
        .position(anchorPoint)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("textOverlayContextMenu")
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
