import CoreGraphics
import SwiftUI

/// Shared visual language for floating contextual controls (signatures, highlights, comments, etc.).
enum ContextualControlMetrics {
    static let glassBorderWidth: CGFloat = 0.5
    static let glassHighlightOpacity: CGFloat = 0.32
    static let glassHighlightFadeOpacity: CGFloat = 0.08

    static let toolbarShadowOpacity: CGFloat = 0.18
    static let toolbarShadowRadius: CGFloat = 12
    static let toolbarShadowYOffset: CGFloat = 6

    static let popoverShadowOpacity: CGFloat = 0.15
    static let popoverShadowRadius: CGFloat = 10
    static let popoverShadowYOffset: CGFloat = 5
    static let popoverCornerRadius: CGFloat = 14

    static let minimumTapTarget: CGFloat = 52
    static let presetColorDiameter: CGFloat = 26
    static let selectedColorRingDiameter: CGFloat = 30

    static let toolbarHorizontalPadding: CGFloat = 6
    static let toolbarVerticalPadding: CGFloat = 4
    static let toolbarVisibleHeight: CGFloat = 32
    static let toolbarVisibleCellWidth: CGFloat = 44
    static let toolbarVisibleIconWidth: CGFloat = 28
    static let toolbarVisibleIconHeight: CGFloat = 24
    static let toolbarCellSpacing: CGFloat = 0
    static let toolbarDividerHeight: CGFloat = 20
    static let toolbarDividerOpacity: CGFloat = 0.18
    static let toolbarSymbolFont: Font = .system(size: 17, weight: .bold)
    static let symbolFont: Font = toolbarSymbolFont
    static let symbolWeight: Font.Weight = .bold

    static var toolbarCapsuleHeight: CGFloat {
        toolbarVisibleHeight + toolbarVerticalPadding * 2
    }

    /// Toolbar capsule ends use half the visible shell height.
    static var toolbarCapsuleRadius: CGFloat {
        toolbarCapsuleHeight / 2
    }

    static var glassCornerRadius: CGFloat {
        toolbarCapsuleRadius
    }

    static var cornerRadius: CGFloat {
        popoverCornerRadius
    }

    static var toolbarTapOutsetHorizontal: CGFloat {
        max(0, (minimumTapTarget - toolbarVisibleCellWidth) / 2)
    }

    static var toolbarTapOutsetVertical: CGFloat {
        max(0, (minimumTapTarget - toolbarVisibleHeight) / 2)
    }

    static var signatureToolbarWidth: CGFloat {
        toolbarHorizontalPadding * 2
            + toolbarVisibleCellWidth * 3
            + 2
    }

    static let popoverHorizontalPadding: CGFloat = 6
    static let popoverVerticalPadding: CGFloat = 4
    static let popoverRowSpacing: CGFloat = 4
    static let popoverColorRowSpacing: CGFloat = 2
    static let popoverColorCellWidth: CGFloat = 44
    static let popoverVisibleRowHeight: CGFloat = 32
    static let thicknessRowColumnCount: CGFloat = 10
    static let thicknessRowPaletteColumns: CGFloat = 3
    static let thicknessRowMinusColumns: CGFloat = 2
    static let thicknessRowLabelColumns: CGFloat = 3
    static let thicknessRowPlusColumns: CGFloat = 2
    static let thicknessRowVerticalInset: CGFloat = 0

    static var popoverTapOutsetHorizontal: CGFloat {
        max(0, (minimumTapTarget - popoverColorCellWidth) / 2)
    }

    static var popoverTapOutsetVertical: CGFloat {
        max(0, (minimumTapTarget - popoverVisibleRowHeight) / 2)
    }

    static var popoverContentWidth: CGFloat {
        popoverColorCellWidth * CGFloat(SignatureInkColor.presetDisplayOrder.count)
            + popoverColorRowSpacing * CGFloat(SignatureInkColor.presetDisplayOrder.count - 1)
    }

    static var thicknessRowColumnUnit: CGFloat {
        popoverContentWidth / thicknessRowColumnCount
    }

    static var popoverWidth: CGFloat {
        popoverHorizontalPadding * 2 + popoverContentWidth
    }

    static var popoverCapsuleHeight: CGFloat {
        popoverVerticalPadding * 2
            + popoverVisibleRowHeight
            + popoverRowSpacing
            + popoverVisibleRowHeight
            + thicknessRowVerticalInset * 2
    }

    static var popoverHeight: CGFloat {
        popoverCapsuleHeight
    }

    /// Legacy aliases used by shared container defaults.
    static let horizontalPadding: CGFloat = toolbarHorizontalPadding
    static let verticalPadding: CGFloat = toolbarVerticalPadding
}

/// Backward-compatible alias while signature call sites migrate to the shared metrics type.
typealias SignatureContextualUIMetrics = ContextualControlMetrics
