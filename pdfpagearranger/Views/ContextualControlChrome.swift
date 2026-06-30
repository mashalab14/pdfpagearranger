import SwiftUI

/// Shared floating container for all contextual editing controls.
struct ContextualControlChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, ContextualControlMetrics.horizontalPadding)
            .padding(.vertical, ContextualControlMetrics.verticalPadding)
            .background(
                .regularMaterial,
                in: RoundedRectangle(
                    cornerRadius: ContextualControlMetrics.cornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: ContextualControlMetrics.cornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    Color.primary.opacity(ContextualControlMetrics.borderOpacity),
                    lineWidth: ContextualControlMetrics.borderWidth
                )
            }
            .shadow(
                color: .black.opacity(ContextualControlMetrics.shadowOpacity),
                radius: ContextualControlMetrics.shadowRadius,
                y: ContextualControlMetrics.shadowYOffset
            )
    }
}

extension View {
    func contextualControlChrome() -> some View {
        modifier(ContextualControlChrome())
    }
}
