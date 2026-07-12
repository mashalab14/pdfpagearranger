import UIKit

/// Encodes VisionKit page images into app-controlled working JPEG files.
/// Uses high-quality JPEG to preserve color for later grayscale and black-and-white modes.
enum ScanWorkingImageEncoder {
    static let defaultJPEGQuality: CGFloat = 0.92

    static func normalizedJPEGData(
        from image: UIImage,
        compressionQuality: CGFloat = defaultJPEGQuality
    ) throws -> Data {
        guard let normalized = normalizedImage(from: image) else {
            throw ScanDraftError.imageEncodingFailure
        }
        guard let data = normalized.jpegData(compressionQuality: compressionQuality),
              !data.isEmpty else {
            throw ScanDraftError.imageEncodingFailure
        }
        return data
    }

    static func normalizedPixelSize(for image: UIImage) -> CGSize {
        normalizedImage(from: image)?.size ?? image.size
    }

    private static func normalizedImage(from image: UIImage) -> UIImage? {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
