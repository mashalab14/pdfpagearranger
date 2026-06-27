import CoreGraphics

/// Maps overlay geometry between unrotated page storage and rotated display/export space.
///
/// Storage uses normalized coordinates on the page at rotation 0°:
/// - `position` is the center, (0,0) top-left through (1,1) bottom-right
/// - `size` is width/height as fractions of the unrotated page width and height
enum OverlayPageGeometry {
    struct Transformed {
        var position: CGPoint
        var size: CGSize
        var rotation: CGFloat
    }

    /// Converts stored overlay geometry into the coordinate space of a rotated page preview/export.
    static func displayTransform(
        position: CGPoint,
        size: CGSize,
        objectRotation: CGFloat,
        pageRotation: Int
    ) -> Transformed {
        let normalized = normalizeRotation(pageRotation)
        let transformedPosition = transformPosition(position, pageRotation: normalized)
        let transformedSize = transformSize(size, pageRotation: normalized)
        return Transformed(
            position: transformedPosition,
            size: transformedSize,
            rotation: objectRotation + CGFloat(normalized)
        )
    }

    /// Converts geometry edited in rotated display space back into unrotated storage.
    static func storageTransform(
        displayPosition: CGPoint,
        displaySize: CGSize,
        objectRotation: CGFloat,
        pageRotation: Int
    ) -> Transformed {
        let normalized = normalizeRotation(pageRotation)
        let storedPosition = inverseTransformPosition(displayPosition, pageRotation: normalized)
        let storedSize = inverseTransformSize(displaySize, pageRotation: normalized)
        return Transformed(
            position: storedPosition,
            size: storedSize,
            rotation: objectRotation - CGFloat(normalized)
        )
    }

    static func displaySize(for pageRotation: Int, mediaBox: CGRect) -> CGSize {
        let normalized = normalizeRotation(pageRotation)
        switch normalized {
        case 90, 270:
            return CGSize(width: mediaBox.height, height: mediaBox.width)
        default:
            return mediaBox.size
        }
    }

    // MARK: - Position

    private static func transformPosition(_ position: CGPoint, pageRotation: Int) -> CGPoint {
        let x = position.x
        let y = position.y
        switch pageRotation {
        case 90:
            return CGPoint(x: 1 - y, y: x)
        case 180:
            return CGPoint(x: 1 - x, y: 1 - y)
        case 270:
            return CGPoint(x: y, y: 1 - x)
        default:
            return position
        }
    }

    private static func inverseTransformPosition(_ position: CGPoint, pageRotation: Int) -> CGPoint {
        let x = position.x
        let y = position.y
        switch pageRotation {
        case 90:
            return CGPoint(x: y, y: 1 - x)
        case 180:
            return CGPoint(x: 1 - x, y: 1 - y)
        case 270:
            return CGPoint(x: 1 - y, y: x)
        default:
            return position
        }
    }

    // MARK: - Size

    private static func transformSize(_ size: CGSize, pageRotation: Int) -> CGSize {
        switch pageRotation {
        case 90, 270:
            return CGSize(width: size.height, height: size.width)
        default:
            return size
        }
    }

    private static func inverseTransformSize(_ size: CGSize, pageRotation: Int) -> CGSize {
        transformSize(size, pageRotation: pageRotation)
    }

    private static func normalizeRotation(_ rotation: Int) -> Int {
        let value = rotation % 360
        return value < 0 ? value + 360 : value
    }
}

extension PageObject {
    func displayGeometry(pageRotation: Int) -> OverlayPageGeometry.Transformed {
        OverlayPageGeometry.displayTransform(
            position: position,
            size: size,
            objectRotation: rotation,
            pageRotation: pageRotation
        )
    }

    func applyingStorageGeometry(
        _ geometry: OverlayPageGeometry.Transformed,
        pageRotation: Int
    ) -> PageObject {
        var copy = self
        let stored = OverlayPageGeometry.storageTransform(
            displayPosition: geometry.position,
            displaySize: geometry.size,
            objectRotation: geometry.rotation,
            pageRotation: pageRotation
        )
        copy.position = stored.position
        copy.size = stored.size
        copy.rotation = stored.rotation
        return copy
    }
}
