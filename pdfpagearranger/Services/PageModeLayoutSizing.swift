import CoreGraphics

/// Page Mode document sizing: maximize horizontal width while preserving aspect ratio.
enum PageModeLayoutSizing {
    static let horizontalMargin: CGFloat = 16

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
