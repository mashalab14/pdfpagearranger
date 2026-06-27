import PencilKit
import UIKit

enum SignatureRenderer {
    static let defaultPadding: CGFloat = 8

    static func image(from drawing: PKDrawing, padding: CGFloat = defaultPadding) -> UIImage? {
        let inkBounds = drawing.bounds
        guard !inkBounds.isEmpty else { return nil }

        let scale: CGFloat = 2.0
        let renderBounds = inkBounds.insetBy(dx: -padding, dy: -padding)
        let strokeImage = renderDrawingImage(from: drawing, bounds: renderBounds, scale: scale)
        guard let trimmedImage = trimTransparentEdges(from: strokeImage) else { return nil }

        let paddedSize = CGSize(
            width: trimmedImage.size.width + padding * 2,
            height: trimmedImage.size.height + padding * 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(size: paddedSize, format: format)
        let image = renderer.image { _ in
            trimmedImage.draw(at: CGPoint(x: padding, y: padding))
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

    private static func trimTransparentEdges(from image: UIImage, alphaThreshold: UInt8 = 2) -> UIImage? {
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

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
