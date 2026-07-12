import CoreGraphics
import XCTest
@testable import pdfpagearranger

final class ScanOCRModelsRegressionTests: XCTestCase {
    func testLinesPreserveTextConfidenceAndNormalizedBounds() {
        let box = CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.04)
        let line = ScanOCRTestFactory.makeLine(text: "Hello", box: box, confidence: 0.88, recognitionOrder: 3)

        XCTAssertEqual(line.text, "Hello")
        XCTAssertEqual(line.confidence, 0.88, accuracy: 0.001)
        XCTAssertEqual(line.normalizedBoundingBox.x, 0.1, accuracy: 0.0001)
        XCTAssertEqual(line.normalizedBoundingBox.y, 0.2, accuracy: 0.0001)
        XCTAssertEqual(line.recognitionOrder, 3)
    }

    func testEmptyObservationsAreIgnoredDuringPageBuild() {
        let page = ScanOCRLayoutEngine.buildPage(
            pageID: UUID(),
            imagePixelSize: CGSize(width: 100, height: 100),
            rawLines: [],
            status: .succeeded,
            errorMessage: nil
        )

        XCTAssertTrue(page.paragraphs.isEmpty)
        XCTAssertTrue(page.lines.isEmpty)
    }

    func testSingleColumnParagraphGrouping() {
        let lines = [
            ScanOCRTestFactory.makeLine(text: "First line", box: CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.04), recognitionOrder: 0),
            ScanOCRTestFactory.makeLine(text: "Second line", box: CGRect(x: 0.1, y: 0.655, width: 0.8, height: 0.04), recognitionOrder: 1),
            ScanOCRTestFactory.makeLine(text: "Third block", box: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.04), recognitionOrder: 2)
        ]

        let ordered = ScanOCRLayoutEngine.assignReadingOrder(lines)
        let paragraphs = ScanOCRLayoutEngine.groupIntoParagraphs(ordered)

        XCTAssertEqual(paragraphs.count, 2)
        XCTAssertEqual(paragraphs[0].lines.map(\.text), ["First line", "Second line"])
        XCTAssertEqual(paragraphs[1].lines.map(\.text), ["Third block"])
    }

    func testTwoColumnReadingOrderIsLeftThenRightTopToBottom() {
        let lines = [
            ScanOCRTestFactory.makeLine(text: "Left top", box: CGRect(x: 0.05, y: 0.8, width: 0.35, height: 0.04), recognitionOrder: 0),
            ScanOCRTestFactory.makeLine(text: "Right top", box: CGRect(x: 0.55, y: 0.78, width: 0.35, height: 0.04), recognitionOrder: 1),
            ScanOCRTestFactory.makeLine(text: "Left bottom", box: CGRect(x: 0.05, y: 0.5, width: 0.35, height: 0.04), recognitionOrder: 2),
            ScanOCRTestFactory.makeLine(text: "Right bottom", box: CGRect(x: 0.55, y: 0.48, width: 0.35, height: 0.04), recognitionOrder: 3)
        ]

        let ordered = ScanOCRLayoutEngine.assignReadingOrder(lines)
        XCTAssertEqual(ordered.map(\.text), ["Left top", "Left bottom", "Right top", "Right bottom"])
    }

    func testParagraphSeparationPreservesLineBoxes() {
        let firstBox = OCRNormalizedRect(CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.04))
        let secondBox = OCRNormalizedRect(CGRect(x: 0.1, y: 0.655, width: 0.8, height: 0.04))
        let lines = [
            OCRLine(text: "A", normalizedBoundingBox: firstBox, confidence: 1, recognitionOrder: 0),
            OCRLine(text: "B", normalizedBoundingBox: secondBox, confidence: 1, recognitionOrder: 1)
        ]

        let paragraphs = ScanOCRLayoutEngine.groupIntoParagraphs(lines)
        XCTAssertEqual(paragraphs.first?.lines.first?.normalizedBoundingBox, firstBox)
        XCTAssertEqual(paragraphs.first?.lines.last?.normalizedBoundingBox, secondBox)
    }
}
