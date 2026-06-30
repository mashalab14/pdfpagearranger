import CoreGraphics
import SwiftUI

/// Shared visual language for floating contextual controls (signatures, highlights, comments, etc.).
enum ContextualControlMetrics {
    static let glassCornerRadius: CGFloat = 20
    static let glassBorderWidth: CGFloat = 0.5
    static let glassHighlightOpacity: CGFloat = 0.42
    static let glassHighlightFadeOpacity: CGFloat = 0.10
    static let glassShadowOpacity: CGFloat = 0.14
    static let glassShadowRadius: CGFloat = 10
    static let glassShadowYOffset: CGFloat = 4

    /// Layout anchor calculations use the glass corner radius.
    static let cornerRadius: CGFloat = glassCornerRadius
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 10
    static let symbolFont: Font = .body
    static let symbolWeight: Font.Weight = .semibold

    static let minimumTapTarget: CGFloat = 52
    static let presetColorDiameter: CGFloat = 26
    static let selectedColorRingDiameter: CGFloat = 30
    static let toolbarCellSpacing: CGFloat = 6
    static let toolbarDividerHeight: CGFloat = 28

    static var signatureToolbarWidth: CGFloat {
        horizontalPadding * 2
            + minimumTapTarget * 3
            + toolbarCellSpacing * 2
            + 2
    }

    static let popoverRowSpacing: CGFloat = 8
    static let popoverColorRowSpacing: CGFloat = 4
    static let thicknessRowColumnCount: CGFloat = 10
    static let thicknessRowPaletteColumns: CGFloat = 3
    static let thicknessRowMinusColumns: CGFloat = 2
    static let thicknessRowLabelColumns: CGFloat = 3
    static let thicknessRowPlusColumns: CGFloat = 2
    static let thicknessRowVerticalInset: CGFloat = 6

    static var popoverContentWidth: CGFloat {
        minimumTapTarget * CGFloat(SignatureInkColor.presetDisplayOrder.count)
            + popoverColorRowSpacing * CGFloat(SignatureInkColor.presetDisplayOrder.count - 1)
    }

    static var thicknessRowColumnUnit: CGFloat {
        popoverContentWidth / thicknessRowColumnCount
    }

    static var popoverWidth: CGFloat {
        horizontalPadding * 2 + popoverContentWidth
    }

    static var thicknessRowHeight: CGFloat {
        minimumTapTarget + thicknessRowVerticalInset * 2
    }

    static var popoverHeight: CGFloat {
        verticalPadding * 2
            + minimumTapTarget
            + popoverRowSpacing
            + thicknessRowHeight
    }
}

/// Backward-compatible alias while signature call sites migrate to the shared metrics type.
typealias SignatureContextualUIMetrics = ContextualControlMetrics
