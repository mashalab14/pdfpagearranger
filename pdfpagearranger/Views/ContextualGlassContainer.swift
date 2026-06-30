import SwiftUI

enum ContextualGlassShape {
    case capsule
}

/// Shared Liquid Glass container for all floating contextual controls.
struct ContextualGlassContainerModifier: ViewModifier {
    let shape: ContextualGlassShape
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    init(
        shape: ContextualGlassShape = .capsule,
        horizontalPadding: CGFloat = ContextualControlMetrics.toolbarHorizontalPadding,
        verticalPadding: CGFloat = ContextualControlMetrics.toolbarVerticalPadding
    ) {
        self.shape = shape
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .glassEffect(.regular, in: .capsule)
            .overlay {
                Capsule()
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
        shape: ContextualGlassShape = .capsule,
        horizontalPadding: CGFloat = ContextualControlMetrics.toolbarHorizontalPadding,
        verticalPadding: CGFloat = ContextualControlMetrics.toolbarVerticalPadding
    ) -> some View {
        modifier(
            ContextualGlassContainerModifier(
                shape: shape,
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
