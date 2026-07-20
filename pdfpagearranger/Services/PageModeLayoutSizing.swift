import CoreGraphics
import PDFKit

/// Page Mode document sizing: maximize horizontal width while preserving aspect ratio.
enum PageModeLayoutSizing {
    static let horizontalMargin: CGFloat = DocumentPageSheetStyle.stackHorizontalMargin

    static func availableContentWidth(
        containerWidth: CGFloat,
        leadingSafeAreaInset: CGFloat = 0,
        trailingSafeAreaInset: CGFloat = 0,
        horizontalMargin: CGFloat = horizontalMargin
    ) -> CGFloat {
        max(
            0,
            containerWidth
                - leadingSafeAreaInset
                - trailingSafeAreaInset
                - horizontalMargin * 2
        )
    }

    /// Shared slot width for active canvas and inactive preview in the unified vertical document.
    static func unifiedSlotDisplayWidth(containerWidth: CGFloat) -> CGFloat {
        availableContentWidth(containerWidth: containerWidth)
    }

    /// Shared slot size for active and inactive pages — one calculation for both.
    static func unifiedSlotDisplaySize(imageSize: CGSize, containerWidth: CGFloat) -> CGSize {
        displaySize(
            imageSize: imageSize,
            availableWidth: unifiedSlotDisplayWidth(containerWidth: containerWidth)
        )
    }

    /// Placeholder size before rasterization so lazy load does not shift scroll position.
    static func estimatedUnifiedSlotDisplaySize(
        pdfPage: PDFPage?,
        pageRotation: Int,
        containerWidth: CGFloat
    ) -> CGSize {
        let imageSize: CGSize
        if let pdfPage {
            imageSize = OverlayGeometryEngine.displayRenderSize(
                for: pageRotation,
                mediaBox: pdfPage.bounds(for: .mediaBox)
            )
        } else {
            imageSize = CGSize(width: 612, height: 792)
        }
        return unifiedSlotDisplaySize(imageSize: imageSize, containerWidth: containerWidth)
    }

    static func displaySize(
        imageSize: CGSize,
        availableWidth: CGFloat
    ) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0, availableWidth > 0 else {
            return .zero
        }

        let aspect = imageSize.height / imageSize.width
        return CGSize(width: availableWidth, height: availableWidth * aspect)
    }

    static func displaySize(
        imageSize: CGSize,
        containerSize: CGSize,
        leadingSafeAreaInset: CGFloat = 0,
        trailingSafeAreaInset: CGFloat = 0,
        horizontalMargin: CGFloat = horizontalMargin
    ) -> CGSize {
        let width = availableContentWidth(
            containerWidth: containerSize.width,
            leadingSafeAreaInset: leadingSafeAreaInset,
            trailingSafeAreaInset: trailingSafeAreaInset,
            horizontalMargin: horizontalMargin
        )
        return displaySize(imageSize: imageSize, availableWidth: width)
    }

    static func preservesAspectRatio(imageSize: CGSize, displaySize: CGSize) -> Bool {
        guard imageSize.width > 0, imageSize.height > 0,
              displaySize.width > 0, displaySize.height > 0 else {
            return false
        }

        let imageAspect = imageSize.height / imageSize.width
        let displayAspect = displaySize.height / displaySize.width
        return abs(imageAspect - displayAspect) < 0.0001
    }
}
