import CoreGraphics
import UIKit

enum OverlayPlacementSizing {
    static let signatureWidthFraction: CGFloat = 0.30
    static let imageWidthFraction: CGFloat = 0.35
    static let maxNormalizedHeightFraction: CGFloat = 0.6

    static func imageAspectRatio(for image: UIImage) -> CGFloat {
        image.size.width / max(image.size.height, 1)
    }

    /// Signature frame height follows the saved PNG aspect ratio:
    /// physical height = physical width × imageHeight / imageWidth.
    static func normalizedSignatureSize(
        image: UIImage,
        pageAspectRatio: CGFloat,
        widthFraction: CGFloat = signatureWidthFraction
    ) -> CGSize {
        let imageAspect = imageAspectRatio(for: image)
        let heightFraction = min(
            widthFraction * pageAspectRatio / imageAspect,
            maxNormalizedHeightFraction
        )
        return CGSize(width: widthFraction, height: heightFraction)
    }

    /// Image overlays keep the prior sizing behaviour.
    static func normalizedImageSize(
        image: UIImage,
        pageAspectRatio: CGFloat,
        widthFraction: CGFloat = imageWidthFraction
    ) -> CGSize {
        let imageAspect = imageAspectRatio(for: image)
        let heightFraction = min(
            (widthFraction / imageAspect) / max(pageAspectRatio, 0.01),
            maxNormalizedHeightFraction
        )
        return CGSize(width: widthFraction, height: heightFraction)
    }

    /// Aspect ratio of the overlay frame on the page in physical coordinates.
    static func frameAspectRatio(normalizedSize: CGSize, pageAspectRatio: CGFloat) -> CGFloat {
        let frameWidth = normalizedSize.width * pageAspectRatio
        let frameHeight = normalizedSize.height
        return frameWidth / max(frameHeight, 0.0001)
    }

    /// Ratio of scaledToFit display height to frame height (1.0 means no letterboxing).
    static func scaledToFitHeightRatio(frameSize: CGSize, imageSize: CGSize) -> CGFloat {
        guard frameSize.width > 0, frameSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return 0
        }

        let imageAspect = imageSize.width / imageSize.height
        let frameAspect = frameSize.width / frameSize.height
        let displayHeight: CGFloat
        if frameAspect > imageAspect {
            displayHeight = frameSize.height
        } else {
            displayHeight = frameSize.width / imageAspect
        }
        return displayHeight / frameSize.height
    }
}
