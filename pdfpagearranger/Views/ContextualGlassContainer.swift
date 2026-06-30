import SwiftUI

enum ContextualGlassShape {
    case capsule
    case roundedRectangle(cornerRadius: CGFloat)

    var shadowOpacity: CGFloat {
        switch self {
        case .capsule:
            ContextualControlMetrics.toolbarShadowOpacity
        case .roundedRectangle:
            ContextualControlMetrics.popoverShadowOpacity
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .capsule:
            ContextualControlMetrics.toolbarShadowRadius
        case .roundedRectangle:
            ContextualControlMetrics.popoverShadowRadius
        }
    }

    var shadowYOffset: CGFloat {
        switch self {
        case .capsule:
            ContextualControlMetrics.toolbarShadowYOffset
        case .roundedRectangle:
            ContextualControlMetrics.popoverShadowYOffset
        }
    }
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
            .background {
                glassBackground
            }
            .overlay {
                glassHighlight
            }
            .shadow(
                color: .black.opacity(shape.shadowOpacity),
                radius: shape.shadowRadius,
                y: shape.shadowYOffset
            )
            .shadow(
                color: .black.opacity(shape.shadowOpacity * 0.45),
                radius: shape.shadowRadius * 0.45,
                y: shape.shadowYOffset * 0.5
            )
    }

    @ViewBuilder
    private var glassBackground: some View {
        switch shape {
        case .capsule:
            Capsule()
                .fill(.clear)
                .glassEffect(.regular, in: .capsule)
        case .roundedRectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(
                    .regular,
                    in: .rect(cornerRadius: cornerRadius, style: .continuous)
                )
        }
    }

    @ViewBuilder
    private var glassHighlight: some View {
        switch shape {
        case .capsule:
            Capsule()
                .strokeBorder(highlightGradient, lineWidth: ContextualControlMetrics.glassBorderWidth)
                .allowsHitTesting(false)
        case .roundedRectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(highlightGradient, lineWidth: ContextualControlMetrics.glassBorderWidth)
                .allowsHitTesting(false)
        }
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
