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

    func testDashedListPrefixesLines() {
        let formatted = TextOverlayFormattingEngine.applyDashedList(to: "One\nTwo")
        XCTAssertEqual(formatted, "– One\n– Two")
    }

    func testInsertTodayUsesLocalizedEditableText() {
        let value = TextOverlayFormattingEngine.localizedTodayString(
            date: Date(timeIntervalSince1970: 1_735_689_600),
            locale: Locale(identifier: "en_US")
        )
        XCTAssertFalse(value.isEmpty)
    }

    func testAppendTodayPreservesExistingText() {
        let result = TextOverlayFormattingEngine.appendToday(
            to: "Hello",
            date: Date(timeIntervalSince1970: 1_735_689_600),
            locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(result.hasPrefix("Hello "))
        XCTAssertGreaterThan(result.count, "Hello ".count)
    }

    func testSwitchingListModeIsPredictable() {
        let bulleted = TextOverlayFormattingEngine.switchingListMode(
            from: .plain,
            to: .bulleted,
            text: "Alpha\nBeta"
        )
        XCTAssertTrue(bulleted.contains("• Alpha"))
    }

    func testIndentationPrefixesLines() {
        let indented = TextOverlayFormattingEngine.applyIndent(to: "A\nB", indent: 2)
        XCTAssertTrue(indented.hasPrefix("        A"))
    }

    func testAttributedStringAppliesAlignmentAndStyles() throws {
        let draft = TextOverlayDraft(
            text: "Styled",
            isBold: true,
            isItalic: true,
            isUnderline: true,
            isStrikethrough: true,
            alignment: .center,
            listMode: .plain,
            fontFamily: .serif
        )
        let attributed = TextOverlayLayoutEngine.attributedString(for: draft)
        XCTAssertEqual(attributed.string, "Styled")
        let attrs = attributed.attributes(at: 0, effectiveRange: nil)
        XCTAssertNotNil(attrs[.font])
        XCTAssertEqual(attrs[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(attrs[.strikethroughStyle] as? Int, NSUnderlineStyle.single.rawValue)
        let paragraph = try XCTUnwrap(attrs[.paragraphStyle] as? NSParagraphStyle)
        XCTAssertEqual(paragraph.alignment, .center)
    }

    func testPlaceholderAttributedStringIsDisplayOnly() {
        let empty = TextOverlayLayoutEngine.attributedString(
            for: .default,
            placeholderWhenEmpty: true
        )
        XCTAssertEqual(empty.string, TextOverlayDraft.placeholderHint)

        let exportEmpty = TextOverlayLayoutEngine.attributedString(
            for: .default,
            placeholderWhenEmpty: false
        )
        XCTAssertTrue(exportEmpty.string.isEmpty)
    }
}
