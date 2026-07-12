import CoreImage
import UIKit

enum ScanPerspectiveCorrectionEngine {
    static let maxOutputPixelDimension: CGFloat = 4_096
    static let processedJPEGQuality: CGFloat = 0.92

    static func process(
        sourceData: Data,
        geometry: ScanPageGeometry,
        pixelSize: CGSize
    ) throws -> (data: Data, outputSize: CGSize) {
        guard let sourceImage = UIImage(data: sourceData) else {
            throw ScanDraftError.imageCannotBeLoaded
        }

        let normalizedSource = ScanWorkingImageEncoder.orientationNormalizedImage(from: sourceImage) ?? sourceImage
        let imageSize = normalizedSource.size

        guard let correctedImage = try correctedUIImage(
            from: normalizedSource,
            geometry: geometry,
            imageSize: imageSize
        ) else {
            throw ScanDraftError.processingFailure(stage: .applyPerspectiveCorrection)
        }

        let data = try ScanWorkingImageEncoder.normalizedJPEGData(
            from: correctedImage,
            compressionQuality: processedJPEGQuality
        )
        return (data, correctedImage.size)
    }

    private static func correctedUIImage(
        from sourceImage: UIImage,
        geometry: ScanPageGeometry,
        imageSize: CGSize
    ) throws -> UIImage? {
        guard let cgImage = sourceImage.cgImage else {
            throw ScanDraftError.imageCannotBeLoaded
        }

        let ciImage = CIImage(cgImage: cgImage)
        let workingImage: CIImage

        if geometry.perspectiveCorrectionEnabled,
           let corners = geometry.effectiveCorners,
           case .success(let validatedCorners) = ScanPageGeometryEngine.validateCorners(corners) {
            workingImage = try perspectiveCorrectedImage(
                ciImage,
                corners: validatedCorners,
                imageSize: imageSize
            )
        } else {
            workingImage = ciImage
        }

        let rotated = rotatedImage(workingImage, rotation: geometry.rotation)
        let scaled = scaledImageIfNeeded(rotated)
        return renderUIImage(from: scaled)
    }

    private static func perspectiveCorrectedImage(
        _ image: CIImage,
        corners: [ScanNormalizedPoint],
        imageSize: CGSize
    ) throws -> CIImage {
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            throw ScanDraftError.processingFailure(stage: .applyPerspectiveCorrection)
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(
            CIVector(cgPoint: ScanPageGeometryEngine.normalizedToCoreImage(corners[0], imageSize: imageSize)),
            forKey: "inputTopLeft"
        )
        filter.setValue(
            CIVector(cgPoint: ScanPageGeometryEngine.normalizedToCoreImage(corners[1], imageSize: imageSize)),
            forKey: "inputTopRight"
        )
        filter.setValue(
            CIVector(cgPoint: ScanPageGeometryEngine.normalizedToCoreImage(corners[2], imageSize: imageSize)),
            forKey: "inputBottomRight"
        )
        filter.setValue(
            CIVector(cgPoint: ScanPageGeometryEngine.normalizedToCoreImage(corners[3], imageSize: imageSize)),
            forKey: "inputBottomLeft"
        )

        guard let output = filter.outputImage else {
            throw ScanDraftError.processingFailure(stage: .applyPerspectiveCorrection)
        }
        return output
    }

    private static func rotatedImage(_ image: CIImage, rotation: Int) -> CIImage {
        let normalized = PageThumbnailLayout.normalizedRotation(rotation)
        guard normalized != 0 else { return image }

        let extent = image.extent
        let transform: CGAffineTransform
        switch normalized {
        case 90:
            transform = CGAffineTransform(translationX: extent.height, y: 0)
                .rotated(by: .pi / 2)
        case 180:
            transform = CGAffineTransform(translationX: extent.width, y: extent.height)
                .rotated(by: .pi)
        case 270:
            transform = CGAffineTransform(translationX: 0, y: extent.width)
                .rotated(by: -.pi / 2)
        default:
            return image
        }

        return image.transformed(by: transform)
    }

    private static func scaledImageIfNeeded(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let maxDimension = max(extent.width, extent.height)
        guard maxDimension > maxOutputPixelDimension, maxDimension > 0 else {
            return image
        }

        let scale = maxOutputPixelDimension / maxDimension
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private static func renderUIImage(from image: CIImage) -> UIImage? {
        let context = CIContext(options: nil)
        let extent = image.extent.integral
        guard let cgImage = context.createCGImage(image, from: extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
