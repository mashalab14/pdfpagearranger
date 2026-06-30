import CoreGraphics

enum SignatureContextualUIMetrics {
    static let minimumTapTarget: CGFloat = 52
    static let presetColorDiameter: CGFloat = 26
    static let selectedColorRingDiameter: CGFloat = 30
    static let toolbarCellSpacing: CGFloat = 6
    static let toolbarHorizontalPadding: CGFloat = 8

    static var signatureToolbarWidth: CGFloat {
        minimumTapTarget * 3
            + toolbarCellSpacing * 2
            + 2
            + toolbarHorizontalPadding * 2
    }

    static let popoverHorizontalPadding: CGFloat = 12
    static let popoverVerticalPadding: CGFloat = 8
    static let popoverRowSpacing: CGFloat = 6
    static let popoverControlSpacing: CGFloat = 4
    static let thicknessLabelMinWidth: CGFloat = 40

    static var popoverWidth: CGFloat {
        minimumTapTarget * CGFloat(SignatureInkColor.presetDisplayOrder.count)
            + popoverControlSpacing * CGFloat(SignatureInkColor.presetDisplayOrder.count - 1)
            + popoverHorizontalPadding * 2
    }

    static var popoverHeight: CGFloat {
        popoverVerticalPadding * 2
            + minimumTapTarget * 2
            + popoverRowSpacing
    }
}
