import SwiftUI

struct PDFTextSelectionContextMenu: View {
    let anchorRect: CGRect
    let onCopy: () -> Void
    let onHighlight: () -> Void
    let onComment: () -> Void
    let onMore: () -> Void

    private let horizontalPadding: CGFloat = 4
    private let verticalPadding: CGFloat = 2

    var body: some View {
        HStack(spacing: 0) {
            menuButton(title: "Copy", accessibilityIdentifier: "pdfTextMenuCopy", action: onCopy)
            divider
            menuButton(title: "Highlight", accessibilityIdentifier: "pdfTextMenuHighlight", action: onHighlight)
            divider
            menuButton(title: "Comment", accessibilityIdentifier: "pdfTextMenuComment", action: onComment)
            divider
            Button(action: onMore) {
                Image(systemName: "chevron.right")
                    .font(ContextualControlMetrics.symbolFont.weight(ContextualControlMetrics.symbolWeight))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More actions")
            .accessibilityIdentifier("pdfTextMenuMore")
        }
        .font(.subheadline)
        .contextualGlassContainer(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        )
        .position(
            x: anchorRect.midX,
            y: max(anchorRect.minY - 28, 24)
        )
        .accessibilityIdentifier("pdfTextSelectionContextMenu")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1, height: 20)
    }

    private func menuButton(
        title: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}
