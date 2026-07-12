import UIKit
import XCTest
@testable import pdfpagearranger

final class ScanVisualAdjustmentsEngineRegressionTests: XCTestCase {
    func testEnhancedModeProducesDifferentOutputThanOriginal() throws {
        let sourceData = makeGradientTestImageData(size: CGSize(width: 240, height: 320))

        let original = try processedData(from: sourceData, adjustments: .neutral)
        var enhanced = ScanVisualAdjustments.neutral
        enhanced.mode = .enhanced
        let enhancedData = try processedData(from: sourceData, adjustments: enhanced)

        XCTAssertNotEqual(original, enhancedData)
    }

    func testGrayscaleModeProducesDifferentOutputThanOriginal() throws {
        let sourceData = ScanDraftTestFactory.makeTestImageData(
            size: CGSize(width: 240, height: 320),
            color: .red
        )

        let original = try processedData(from: sourceData, adjustments: .neutral)
        var grayscale = ScanVisualAdjustments.neutral
        grayscale.mode = .grayscale
        let grayscaleData = try processedData(from: sourceData, adjustments: grayscale)

        XCTAssertNotEqual(original, grayscaleData)
    }

    func testBlackAndWhiteModeDiffersFromGrayscale() throws {
        let sourceData = ScanDraftTestFactory.makeTestImageData(
            size: CGSize(width: 240, height: 320),
            color: .darkGray
        )

        var grayscale = ScanVisualAdjustments.neutral
        grayscale.mode = .grayscale
        var blackAndWhite = ScanVisualAdjustments.neutral
        blackAndWhite.mode = .blackAndWhite
        blackAndWhite.blackAndWhiteThreshold = 0.5

        let grayscaleData = try processedData(from: sourceData, adjustments: grayscale)
        let blackAndWhiteData = try processedData(from: sourceData, adjustments: blackAndWhite)

        XCTAssertNotEqual(grayscaleData, blackAndWhiteData)
    }

    private func processedData(
        from sourceData: Data,
        adjustments: ScanVisualAdjustments
    ) throws -> Data {
        try ScanDraftPageImageProcessor.process(
            sourceData: sourceData,
            geometry: .default,
            visualAdjustments: adjustments,
            pixelSize: CGSize(width: 240, height: 320),
            maxOutputPixelDimension: 480
        ).data
    }

    private func makeGradientTestImageData(size: CGSize) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [UIColor.white.cgColor, UIColor.gray.cgColor, UIColor.black.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1])!
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}
