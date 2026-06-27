import UIKit

enum ImageTestHelpers {
    static func averageColor(in image: UIImage, rect: CGRect) -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        guard let cgImage = image.cgImage else { return nil }

        let scale = image.scale
        let pixelRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral

        guard pixelRect.width > 0, pixelRect.height > 0,
              let cropped = cgImage.cropping(to: pixelRect) else {
            return nil
        }

        let width = Int(pixelRect.width)
        let height = Int(pixelRect.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        let count = width * height

        for index in 0..<count {
            let offset = index * 4
            totalRed += CGFloat(pixels[offset]) / 255
            totalGreen += CGFloat(pixels[offset + 1]) / 255
            totalBlue += CGFloat(pixels[offset + 2]) / 255
        }

        let divisor = CGFloat(count)
        return (totalRed / divisor, totalGreen / divisor, totalBlue / divisor)
    }

    static func isMostlyRed(_ color: (red: CGFloat, green: CGFloat, blue: CGFloat)) -> Bool {
        color.red > 0.5 && color.red > color.green && color.red > color.blue
    }

    static func isMostlyBlue(_ color: (red: CGFloat, green: CGFloat, blue: CGFloat)) -> Bool {
        color.blue > 0.5 && color.blue > color.red && color.blue > color.green
    }

    static func isMostlyGreen(_ color: (red: CGFloat, green: CGFloat, blue: CGFloat)) -> Bool {
        color.green > 0.5 && color.green > color.red && color.green > color.blue
    }
}
