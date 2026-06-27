import PDFKit
import XCTest
@testable import pdfpagearranger

enum ExportAssertions {
  static func assertPageCount(
    _ expected: Int,
    in exportURL: URL,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let document = try XCTUnwrap(PDFDocument(url: exportURL), file: file, line: line)
    XCTAssertEqual(document.pageCount, expected, file: file, line: line)
  }

  static func assertPageContainsText(
    _ text: String,
    at pageIndex: Int,
    in exportURL: URL,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let document = try XCTUnwrap(PDFDocument(url: exportURL), file: file, line: line)
    let pageText = document.page(at: pageIndex)?.string ?? ""
    XCTAssertTrue(pageText.contains(text), "Expected '\(text)' in page \(pageIndex). Got: \(pageText)", file: file, line: line)
  }

  static func assertExportDoesNotUseRasterizedPageInitializer(
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("pdfpagearranger/Services/PDFService.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    XCTAssertFalse(source.contains("PDFPage(image:"), file: file, line: line)
    XCTAssertTrue(source.contains("sourcePage.draw(with: .mediaBox, to: context)"), file: file, line: line)
    XCTAssertTrue(source.contains("OverlayPDFExporter.drawOverlays"), file: file, line: line)
  }

  static func assertOriginalPDFUnchanged(
    originalData: Data,
    currentURL: URL,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let currentData = try Data(contentsOf: currentURL)
    XCTAssertEqual(originalData, currentData, file: file, line: line)
  }
}
