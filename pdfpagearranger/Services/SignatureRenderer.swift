import PencilKit
import UIKit

enum SignatureRenderer {
    static let defaultPadding: CGFloat = 8
    private static let renderScale: CGFloat = 2
    private static let renderBleed: CGFloat = 2

    static func image(from drawing: PKDrawing, padding: CGFloat = defaultPadding) -> UIImage? {
        let bounds = inkBounds(from: drawing)
        guard !bounds.isEmpty else { return nil }

        let renderBounds = bounds.insetBy(dx: -renderBleed, dy: -renderBleed)
        let strokeImage = renderDrawingImage(from: drawing, bounds: renderBounds, scale: renderScale)
        guard let trimmedImage = trimTransparentEdges(from: strokeImage) else { return nil }

        let paddedSize = CGSize(
            width: trimmedImage.size.width + padding * 2,
            height: trimmedImage.size.height + padding * 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = renderScale

        let renderer = UIGraphicsImageRenderer(size: paddedSize, format: format)
        let image = renderer.image { _ in
            trimmedImage.draw(at: CGPoint(x: padding, y: padding))
        }

        return image.withRenderingMode(.alwaysOriginal)
    }

    static func opaquePixelBounds(
        in image: UIImage,
        alphaThreshold: UInt8 = 2
    ) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var foundInk = false

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let alpha = pixelData[index + 3]
                guard alpha > alphaThreshold else { continue }

                foundInk = true
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard foundInk else { return nil }

        let pixelRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )

        return CGRect(
            x: pixelRect.origin.x / image.scale,
            y: pixelRect.origin.y / image.scale,
            width: pixelRect.width / image.scale,
            height: pixelRect.height / image.scale
        )
    }

    private static func inkBounds(from drawing: PKDrawing) -> CGRect {
        guard !drawing.strokes.isEmpty else { return .zero }

        var bounds = CGRect.null
        for stroke in drawing.strokes {
            bounds = bounds.union(stroke.renderBounds)

            for point in stroke.path {
                let radius = max(point.size.width, point.size.height) / 2
                let pointBounds = CGRect(
                    x: point.location.x - radius,
                    y: point.location.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                bounds = bounds.union(pointBounds)
            }
        }

        if bounds.isNull {
            return drawing.bounds
        }
        return bounds
    }

    private static func renderDrawingImage(from drawing: PKDrawing, bounds: CGRect, scale: CGFloat) -> UIImage {
        var strokeImage = UIImage()
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        lightTraits.performAsCurrent {
            strokeImage = drawing.image(from: bounds, scale: scale)
        }
        return strokeImage
    }

    private static func trimTransparentEdges(from image: UIImage, alphaThreshold: UInt8 = 2) -> UIImage? {
        guard let cgImage = image.cgImage,
              let bounds = opaquePixelBounds(in: image, alphaThreshold: alphaThreshold) else {
            return nil
        }

        let pixelRect = CGRect(
            x: bounds.origin.x * image.scale,
            y: bounds.origin.y * image.scale,
            width: bounds.width * image.scale,
            height: bounds.height * image.scale
        ).integral

        guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
