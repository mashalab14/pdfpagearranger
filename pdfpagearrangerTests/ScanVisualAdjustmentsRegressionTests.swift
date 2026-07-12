import XCTest
@testable import pdfpagearranger

final class ScanVisualAdjustmentsRegressionTests: XCTestCase {
    func testDefaultsAreNeutral() {
        let adjustments = ScanVisualAdjustments.neutral

        XCTAssertEqual(adjustments.mode, .original)
        XCTAssertEqual(adjustments.brightness, 0)
        XCTAssertEqual(adjustments.contrast, 0)
        XCTAssertNil(adjustments.saturation)
        XCTAssertNil(adjustments.blackAndWhiteThreshold)
        XCTAssertFalse(adjustments.requiresProcessing)
    }

    func testResetRestoresDefaults() {
        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .enhanced
        adjustments.brightness = 0.5
        adjustments.contrast = -0.3
        adjustments.saturation = 0.2
        adjustments.blackAndWhiteThreshold = 0.7

        let reset = adjustments.resetToDefaults()

        XCTAssertEqual(reset, .neutral)
    }

    func testModeChangeRequiresProcessing() {
        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .grayscale
        XCTAssertTrue(adjustments.requiresProcessing)
    }

    func testThresholdDefaultWhenNormalizedForBlackAndWhite() {
        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .blackAndWhite

        let normalized = adjustments.normalizedForProcessing()

        XCTAssertEqual(normalized.resolvedBlackAndWhiteThreshold, ScanVisualAdjustments.defaultBlackAndWhiteThreshold)
    }

    func testSaturationRemovedForGrayscaleMode() {
        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .grayscale
        adjustments.saturation = 0.2

        let normalized = adjustments.normalizedForProcessing()

        XCTAssertNil(normalized.saturation)
    }
}
