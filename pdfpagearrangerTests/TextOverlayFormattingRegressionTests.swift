import PDFKit
import XCTest
@testable import pdfpagearranger

final class TextOverlayFormattingRegressionTests: XCTestCase {
    func testBulletedListPrefixesLines() {
        let formatted = TextOverlayFormattingEngine.applyBulletedList(to: "One\nTwo")
        XCTAssertEqual(formatted, "• One\n• Two")
    }

    func testNumberedListPrefixesLines() {
        let formatted = TextOverlayFormattingEngine.applyNumberedList(to: "One\nTwo")
        XCTAssertEqual(formatted, "1. One\n2. Two")
    }

    func testInsertTodayUsesLocalizedEditableText() {
        let value = TextOverlayFormattingEngine.localizedTodayString(
            date: Date(timeIntervalSince1970: 1_735_689_600),
            locale: Locale(identifier: "en_US")
        )
        XCTAssertFalse(value.isEmpty)
    }

    func testSwitchingListModeIsPredictable() {
        let bulleted = TextOverlayFormattingEngine.switchingListMode(
            from: .plain,
            to: .bulleted,
            text: "Alpha\nBeta"
        )
        XCTAssertTrue(bulleted.contains("• Alpha"))
    }
}
