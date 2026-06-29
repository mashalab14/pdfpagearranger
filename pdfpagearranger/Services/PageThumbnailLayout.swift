import CoreGraphics
import Foundation

enum PageThumbnailOrientation: Equatable {
    case portraitStyle
    case landscapeStyle
}

enum PageThumbnailLayout {
    static let standardPortraitHeight: CGFloat = 200
    static let standardLandscapeWidth: CGFloat = 200

    static func normalizedRotation(_ rotation: Int) -> Int {
        let value = rotation % 360
        return value >= 0 ? value : value + 360
    }

    static func orientation(for rotation: Int) -> PageThumbnailOrientation {
        switch normalizedRotation(rotation) {
        case 90, 270:
            return .landscapeStyle
        default:
            return .portraitStyle
        }
    }

    static func displayAspectRatio(
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        rotation: Int
    ) -> CGFloat {
        guard pageWidth > 0, pageHeight > 0 else {
            return 0.72
        }

        let isSwapped = orientation(for: rotation) == .landscapeStyle
        let displayWidth = isSwapped ? pageHeight : pageWidth
        let displayHeight = isSwapped ? pageWidth : pageHeight
        return displayWidth / displayHeight
    }

    static func displaySize(
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        rotation: Int
    ) -> CGSize {
        let aspectRatio = displayAspectRatio(
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            rotation: rotation
        )

        switch orientation(for: rotation) {
        case .portraitStyle:
            let height = standardPortraitHeight
            return CGSize(width: height * aspectRatio, height: height)
        case .landscapeStyle:
            let width = standardLandscapeWidth
            return CGSize(width: width, height: width / aspectRatio)
        }
    }
}
