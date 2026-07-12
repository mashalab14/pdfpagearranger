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

    /// Prepares app-owned working image bytes while preserving quality where practical.
    static func preparedImportPayload(from data: Data) throws -> (data: Data, fileExtension: String) {
        guard !data.isEmpty else {
            throw ScanDraftError.unsupportedImageData
        }
        guard let image = UIImage(data: data) else {
            throw ScanDraftError.imageCannotBeLoaded
        }

        if isPNG(data) {
            if image.imageOrientation == .up {
                return (data, "png")
            }
            guard let pngData = normalizedImage(from: image)?.pngData(), !pngData.isEmpty else {
                throw ScanDraftError.imageEncodingFailure
            }
            return (pngData, "png")
        }

        if isJPEG(data), image.imageOrientation == .up {
            return (data, "jpg")
        }

        return (try normalizedJPEGData(from: image), "jpg")
    }

    private static func isPNG(_ data: Data) -> Bool {
        data.count >= 8
            && data[0] == 0x89
            && data[1] == 0x50
            && data[2] == 0x4E
            && data[3] == 0x47
    }

    private static func isJPEG(_ data: Data) -> Bool {
        data.count >= 3
            && data[0] == 0xFF
            && data[1] == 0xD8
            && data[2] == 0xFF
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
