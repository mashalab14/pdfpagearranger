import CoreImage
import Foundation
import UIKit

/// Unified geometry-then-visual page processing pipeline.
enum ScanDraftPageImageProcessor {
    static let fullResolutionMaxDimension: CGFloat = 4_096
    static let previewMaxDimension: CGFloat = 1_200
    static let processedJPEGQuality: CGFloat = 0.92

    static func process(
        sourceData: Data,
        geometry: ScanPageGeometry,
        visualAdjustments: ScanVisualAdjustments,
        pixelSize: CGSize,
        maxOutputPixelDimension: CGFloat = fullResolutionMaxDimension
    ) throws -> (data: Data, outputSize: CGSize) {
        guard let sourceImage = UIImage(data: sourceData) else {
            throw ScanDraftError.imageCannotBeLoaded
        }

        let normalizedSource = ScanWorkingImageEncoder.orientationNormalizedImage(from: sourceImage) ?? sourceImage
        let imageSize = normalizedSource.size

        let geometryImage = try ScanPerspectiveCorrectionEngine.correctedCIImage(
            from: normalizedSource,
            geometry: geometry,
            imageSize: imageSize
        )

        let adjustedImage = try ScanVisualAdjustmentsEngine.apply(
            visualAdjustments,
            to: geometryImage
        )

        let scaled = ScanPerspectiveCorrectionEngine.scaledImageIfNeeded(
            adjustedImage,
            maxOutputPixelDimension: maxOutputPixelDimension
        )

        guard let outputImage = ScanPerspectiveCorrectionEngine.renderUIImage(from: scaled) else {
            throw ScanDraftError.processingFailure(stage: .generateProcessedImage)
        }

        let data = try ScanWorkingImageEncoder.normalizedJPEGData(
            from: outputImage,
            compressionQuality: processedJPEGQuality
        )
        return (data, outputImage.size)
    }

    static func needsProcessing(
        geometry: ScanPageGeometry,
        visualAdjustments: ScanVisualAdjustments
    ) -> Bool {
        let needsGeometry = geometry.perspectiveCorrectionEnabled
            || geometry.rotation != 0
            || geometry.effectiveCorners != nil
        return needsGeometry || visualAdjustments.requiresProcessing
    }
}
