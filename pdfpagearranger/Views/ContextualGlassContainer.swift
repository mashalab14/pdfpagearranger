import SwiftUI

/// Shared Liquid Glass container for all floating contextual controls.
struct ContextualGlassContainerModifier: ViewModifier {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    init(
        horizontalPadding: CGFloat = ContextualControlMetrics.toolbarHorizontalPadding,
        verticalPadding: CGFloat = ContextualControlMetrics.toolbarVerticalPadding
    ) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    private var cornerRadius: CGFloat {
        ContextualControlMetrics.floatingPanelCornerRadius
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(
                        ContextualControlMetrics.floatingPanelGlass,
                        in: .rect(cornerRadius: cornerRadius, style: .continuous)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(highlightGradient, lineWidth: ContextualControlMetrics.glassBorderWidth)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(ContextualControlMetrics.floatingPanelShadowOpacity),
                radius: ContextualControlMetrics.floatingPanelShadowRadius,
                y: ContextualControlMetrics.floatingPanelShadowYOffset
            )
            .shadow(
                color: .black.opacity(ContextualControlMetrics.floatingPanelShadowOpacity * 0.5),
                radius: ContextualControlMetrics.floatingPanelShadowRadius * 0.55,
                y: ContextualControlMetrics.floatingPanelShadowYOffset * 0.45
            )
    }

    private var highlightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(ContextualControlMetrics.glassHighlightOpacity),
                Color.white.opacity(ContextualControlMetrics.glassHighlightFadeOpacity),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension View {
    func contextualGlassContainer(
        horizontalPadding: CGFloat = ContextualControlMetrics.toolbarHorizontalPadding,
        verticalPadding: CGFloat = ContextualControlMetrics.toolbarVerticalPadding
    ) -> some View {
        modifier(
            ContextualGlassContainerModifier(
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            )
        )
    }

    /// Expands the tap target without increasing the visible layout footprint.
    func contextualExpandedTapTarget(
        visibleWidth: CGFloat,
        visibleHeight: CGFloat,
        target: CGFloat = ContextualControlMetrics.minimumTapTarget
    ) -> some View {
        let horizontalOutset = max(0, (target - visibleWidth) / 2)
        let verticalOutset = max(0, (target - visibleHeight) / 2)

        return frame(width: visibleWidth, height: visibleHeight)
            .padding(.horizontal, horizontalOutset)
            .padding(.vertical, verticalOutset)
            .contentShape(Rectangle())
            .padding(.horizontal, -horizontalOutset)
            .padding(.vertical, -verticalOutset)
    }
}

enum ContextualGlassAnimation {
    static let presentation = Animation.spring(response: 0.34, dampingFraction: 0.86)
    static let dismissal = Animation.easeOut(duration: 0.22)
}

extension AnyTransition {
    static var contextualGlass: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)),
            removal: .opacity
        )
    }
}
