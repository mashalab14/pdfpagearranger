import PencilKit
import UIKit

enum SignatureRenderer {
    static func image(from drawing: PKDrawing, padding: CGFloat = 8) -> UIImage? {
        let bounds = drawing.bounds
        guard !bounds.isEmpty else { return nil }

        let paddedBounds = bounds.insetBy(dx: -padding, dy: -padding)
        let scale: CGFloat = 2.0
        let size = paddedBounds.size

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            let strokeImage = renderDrawingImage(from: drawing, bounds: paddedBounds, scale: scale)
            strokeImage.draw(in: CGRect(origin: .zero, size: size))
        }

        return image.withRenderingMode(.alwaysOriginal)
    }

    private static func renderDrawingImage(from drawing: PKDrawing, bounds: CGRect, scale: CGFloat) -> UIImage {
        var strokeImage = UIImage()
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        lightTraits.performAsCurrent {
            strokeImage = drawing.image(from: bounds, scale: scale)
        }
        return strokeImage
    }
}
