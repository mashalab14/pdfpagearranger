import CoreImage
import UIKit

enum SignatureAppearanceEngine {
    static func renderDisplayImage(
        source: UIImage,
        inkColor: SignatureInkColor,
        thickness: SignatureInkThickness,
        baselineThickness: SignatureInkThickness
    ) -> UIImage {
        let recolored = recolor(source, to: inkColor)
        return adjustThickness(recolored, from: baselineThickness, to: thickness)
    }

    static func recolor(_ image: UIImage, to color: SignatureInkColor) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return image }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return image }

        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let target = color.uiColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        target.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let targetRed = UInt8(red * 255)
        let targetGreen = UInt8(green * 255)
        let targetBlue = UInt8(blue * 255)

        for index in 0..<(width * height) {
            let offset = index * 4
            let pixelAlpha = pixels[offset + 3]
            guard pixelAlpha > 0 else { continue }

            let alphaScale = CGFloat(pixelAlpha) / 255
            pixels[offset] = UInt8(CGFloat(targetRed) * alphaScale)
            pixels[offset + 1] = UInt8(CGFloat(targetGreen) * alphaScale)
            pixels[offset + 2] = UInt8(CGFloat(targetBlue) * alphaScale)
        }

        guard let output = context.makeImage() else { return image }
        return UIImage(cgImage: output, scale: image.scale, orientation: image.imageOrientation)
    }

    static func adjustThickness(
        _ image: UIImage,
        from baseline: SignatureInkThickness,
        to target: SignatureInkThickness
    ) -> UIImage {
        let delta = target.strokeWidth - baseline.strokeWidth
        guard abs(delta) > 0.01 else { return image }
        guard let ciImage = CIImage(image: image) else { return image }

        let radius = abs(delta) / 2
        let filterName = delta > 0 ? "CIMorphologyMaximum" : "CIMorphologyMinimum"
        guard let filter = CIFilter(name: filterName) else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let outputImage = filter.outputImage,
              let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
