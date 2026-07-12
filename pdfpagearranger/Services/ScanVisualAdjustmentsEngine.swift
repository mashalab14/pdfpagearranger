import CoreImage
import UIKit

enum ScanVisualAdjustmentsEngine {
    static func apply(
        _ adjustments: ScanVisualAdjustments,
        to image: CIImage
    ) throws -> CIImage {
        let normalized = adjustments.normalizedForProcessing()
        var working = image

        switch normalized.mode {
        case .original:
            working = applyOriginalMode(to: working)
        case .enhanced:
            working = applyEnhancedMode(to: working)
        case .grayscale:
            working = applyGrayscaleMode(to: working)
        case .blackAndWhite:
            working = applyBlackAndWhiteMode(to: working, threshold: normalized.resolvedBlackAndWhiteThreshold)
        }

        working = applyColorControls(
            to: working,
            brightness: normalized.coreImageBrightness,
            contrast: normalized.coreImageContrast,
            saturation: normalized.coreImageSaturation
        )

        return working
    }

    static func renderPreviewImage(from image: CIImage, maxDimension: CGFloat) -> UIImage? {
        let scaled = ScanPerspectiveCorrectionEngine.scaledImageIfNeeded(
            image,
            maxOutputPixelDimension: maxDimension
        )
        return ScanPerspectiveCorrectionEngine.renderUIImage(from: scaled)
    }

    // MARK: - Modes

    private static func applyOriginalMode(to image: CIImage) -> CIImage {
        image
    }

    /// Deterministic document enhancement: mild exposure lift, highlight/shadow balance, light contrast.
    private static func applyEnhancedMode(to image: CIImage) -> CIImage {
        var working = image

        if let exposure = CIFilter(name: "CIExposureAdjust") {
            exposure.setValue(working, forKey: kCIInputImageKey)
            exposure.setValue(0.12, forKey: kCIInputEVKey)
            working = exposure.outputImage ?? working
        }

        if let highlights = CIFilter(name: "CIHighlightShadowAdjust") {
            highlights.setValue(working, forKey: kCIInputImageKey)
            highlights.setValue(0.92, forKey: "inputHighlightAmount")
            highlights.setValue(0.10, forKey: "inputShadowAmount")
            working = highlights.outputImage ?? working
        }

        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(working, forKey: kCIInputImageKey)
            controls.setValue(1.08, forKey: kCIInputContrastKey)
            controls.setValue(1.04, forKey: kCIInputSaturationKey)
            working = controls.outputImage ?? working
        }

        return working
    }

    private static func applyGrayscaleMode(to image: CIImage) -> CIImage {
        desaturate(image)
    }

    /// Global luminance threshold binarization with adjustable pivot.
    private static func applyBlackAndWhiteMode(to image: CIImage, threshold: CGFloat) -> CIImage {
        let gray = desaturate(image)
        let pivot = min(max(threshold, ScanVisualAdjustments.minimumBlackAndWhiteThreshold), ScanVisualAdjustments.maximumBlackAndWhiteThreshold)
        let contrast = 40.0
        let brightness = (0.5 - pivot) * contrast

        guard let controls = CIFilter(name: "CIColorControls") else {
            return gray
        }
        controls.setValue(gray, forKey: kCIInputImageKey)
        controls.setValue(contrast, forKey: kCIInputContrastKey)
        controls.setValue(brightness, forKey: kCIInputBrightnessKey)
        controls.setValue(0, forKey: kCIInputSaturationKey)
        return controls.outputImage ?? gray
    }

    private static func applyColorControls(
        to image: CIImage,
        brightness: CGFloat,
        contrast: CGFloat,
        saturation: CGFloat?
    ) -> CIImage {
        guard brightness != 0 || contrast != 0 || saturation != nil else {
            return image
        }

        guard let controls = CIFilter(name: "CIColorControls") else {
            return image
        }

        controls.setValue(image, forKey: kCIInputImageKey)
        controls.setValue(brightness, forKey: kCIInputBrightnessKey)
        controls.setValue(1 + contrast, forKey: kCIInputContrastKey)
        if let saturation {
            controls.setValue(1 + saturation, forKey: kCIInputSaturationKey)
        }
        return controls.outputImage ?? image
    }

    private static func desaturate(_ image: CIImage) -> CIImage {
        guard let controls = CIFilter(name: "CIColorControls") else {
            return image
        }
        controls.setValue(image, forKey: kCIInputImageKey)
        controls.setValue(0, forKey: kCIInputSaturationKey)
        return controls.outputImage ?? image
    }
}
