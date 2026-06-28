import PencilKit
import UIKit

enum SignatureRenderer {
    static let defaultHorizontalPadding: CGFloat = 4
    static let defaultVerticalPadding: CGFloat = 3
    static let defaultPadding: CGFloat = defaultHorizontalPadding

    private static let renderScale: CGFloat = 2
    private static let alphaThreshold: UInt8 = 0

    static func image(
        from drawing: PKDrawing,
        horizontalPadding: CGFloat = defaultHorizontalPadding,
        verticalPadding: CGFloat = defaultVerticalPadding
    ) -> UIImage? {
        var renderBounds = renderBounds(for: drawing)
        guard !renderBounds.isEmpty else { return nil }

        for _ in 0..<4 {
            let rendered = renderDrawingImage(from: drawing, bounds: renderBounds, scale: renderScale)
            guard let inkBounds = opaquePixelBounds(in: rendered, alphaThreshold: alphaThreshold) else {
                renderBounds = renderBounds.insetBy(dx: -16, dy: -16)
                continue
            }

            let cropRect = CGRect(
                x: inkBounds.origin.x - horizontalPadding,
                y: inkBounds.origin.y - verticalPadding,
                width: inkBounds.width + horizontalPadding * 2,
                height: inkBounds.height + verticalPadding * 2
            )

            if let cropped = cropImage(rendered, to: cropRect) {
                return cropped.withRenderingMode(.alwaysOriginal)
            }

            renderBounds = renderBounds.insetBy(dx: -16, dy: -16)
        }

        return nil
    }

    static func image(from drawing: PKDrawing, padding: CGFloat) -> UIImage? {
        image(from: drawing, horizontalPadding: padding, verticalPadding: padding)
    }

    /// Ink bounds detected from the rendered bitmap before crop padding is applied.
    static func renderedInkBounds(from drawing: PKDrawing) -> CGRect? {
        let bounds = renderBounds(for: drawing)
        guard !bounds.isEmpty else { return nil }

        let rendered = renderDrawingImage(from: drawing, bounds: bounds, scale: renderScale)
        return opaquePixelBounds(in: rendered)
    }

    static func opaquePixelBounds(
        in image: UIImage,
        alphaThreshold: UInt8 = alphaThreshold
    ) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        guard let pixelData = decodeRGBA8Pixels(from: cgImage) else { return nil }

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var foundInk = false

        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixelData[(y * width + x) * 4 + 3]
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

    private static func renderBounds(for drawing: PKDrawing) -> CGRect {
        guard !drawing.strokes.isEmpty else { return .zero }

        var bounds = drawing.bounds
        var maxStrokeRadius: CGFloat = 0
        for stroke in drawing.strokes {
            bounds = bounds.union(stroke.renderBounds)
            for point in stroke.path {
                let radius = max(point.size.width, point.size.height) / 2
                maxStrokeRadius = max(maxStrokeRadius, radius)
            }
        }

        let safetyMargin = max(defaultHorizontalPadding, defaultVerticalPadding) + 4
        let bleed = max(maxStrokeRadius * 3, 32) + safetyMargin
        return bounds.insetBy(dx: -bleed, dy: -bleed)
    }

    private static func renderDrawingImage(from drawing: PKDrawing, bounds: CGRect, scale: CGFloat) -> UIImage {
        var strokeImage = UIImage()
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        lightTraits.performAsCurrent {
            strokeImage = drawing.image(from: bounds, scale: scale)
        }
        return strokeImage
    }

    private static func cropImage(_ image: UIImage, to rectInPoints: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let pixelRect = CGRect(
            x: rectInPoints.origin.x * image.scale,
            y: rectInPoints.origin.y * image.scale,
            width: rectInPoints.width * image.scale,
            height: rectInPoints.height * image.scale
        ).integral

        let imagePixelRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let clamped = pixelRect.intersection(imagePixelRect)
        guard clamped.width > 0, clamped.height > 0 else { return nil }

        guard let cropped = cgImage.cropping(to: clamped) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func decodeRGBA8Pixels(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
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
        return pixelData
    }
}
