import SwiftUI

enum ContextualPanelShape {
    case capsule
    case roundedRectangle(cornerRadius: CGFloat)
}

/// Shared floating container for contextual editing controls.
struct ContextualGlassContainerModifier: ViewModifier {
    let shape: ContextualPanelShape
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    init(
        shape: ContextualPanelShape = .capsule,
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
            .fixedSize(horizontal: true, vertical: true)
            .background {
                panelBackground
            }
            .overlay {
                panelBorder
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(ContextualControlMetrics.floatingPanelShadowOpacity),
                radius: ContextualControlMetrics.floatingPanelShadowRadius,
                y: ContextualControlMetrics.floatingPanelShadowYOffset
            )
    }

    @ViewBuilder
    private var panelBackground: some View {
        switch shape {
        case .capsule:
            Capsule()
                .fill(Color.white.opacity(ContextualControlMetrics.floatingPanelBackgroundOpacity))
        case .roundedRectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(ContextualControlMetrics.floatingPanelBackgroundOpacity))
        }
    }

    @ViewBuilder
    private var panelBorder: some View {
        switch shape {
        case .capsule:
            Capsule()
                .strokeBorder(
                    Color.white.opacity(ContextualControlMetrics.panelBorderOpacity),
                    lineWidth: ContextualControlMetrics.panelBorderWidth
                )
        case .roundedRectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(ContextualControlMetrics.panelBorderOpacity),
                    lineWidth: ContextualControlMetrics.panelBorderWidth
                )
        }
    }
}

extension View {
    func contextualGlassContainer(
        shape: ContextualPanelShape = .capsule,
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
