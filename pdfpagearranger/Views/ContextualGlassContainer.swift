import SwiftUI

/// Shared Liquid Glass container for all floating contextual controls.
struct ContextualGlassContainerModifier: ViewModifier {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    init(
        horizontalPadding: CGFloat = ContextualControlMetrics.horizontalPadding,
        verticalPadding: CGFloat = ContextualControlMetrics.verticalPadding
    ) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    private var glassShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: ContextualControlMetrics.glassCornerRadius,
            style: .continuous
        )
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .glassEffect(
                .regular,
                in: .rect(
                    cornerRadius: ContextualControlMetrics.glassCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                glassShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(ContextualControlMetrics.glassHighlightOpacity),
                                Color.white.opacity(ContextualControlMetrics.glassHighlightFadeOpacity),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: ContextualControlMetrics.glassBorderWidth
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(ContextualControlMetrics.glassShadowOpacity),
                radius: ContextualControlMetrics.glassShadowRadius,
                y: ContextualControlMetrics.glassShadowYOffset
            )
    }
}

extension View {
    func contextualGlassContainer(
        horizontalPadding: CGFloat = ContextualControlMetrics.horizontalPadding,
        verticalPadding: CGFloat = ContextualControlMetrics.verticalPadding
    ) -> some View {
        modifier(
            ContextualGlassContainerModifier(
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            )
        )
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
