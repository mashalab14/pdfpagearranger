import PDFKit
import XCTest

enum CompressionAssertions {
    static func assertFileSizeReduced(
        originalURL: URL,
        compressedURL: URL,
        minimumReduction: Double = 0.05,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let originalSize = try fileSize(at: originalURL)
        let compressedSize = try fileSize(at: compressedURL)
        XCTAssertLessThan(
            compressedSize,
            Int64(Double(originalSize) * (1 - minimumReduction)),
            "Expected at least \(Int(minimumReduction * 100))% reduction. Original: \(originalSize), compressed: \(compressedSize)",
            file: file,
            line: line
        )
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

    static func extractedPageStrings(from url: URL) throws -> [String] {
        let document = try XCTUnwrap(PDFDocument(url: url), "Could not open PDF at \(url.lastPathComponent)")
        return (0..<document.pageCount).map { index in
            document.page(at: index)?.string ?? ""
        }
    }

    static func assertIdenticalPDFKitStringExtraction(
        sourceURL: URL,
        compressedURL: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let originalStrings = try extractedPageStrings(from: sourceURL)
        let compressedStrings = try extractedPageStrings(from: compressedURL)

        XCTAssertEqual(
            compressedStrings.count,
            originalStrings.count,
            "Compressed PDF must preserve page count for text extraction",
            file: file,
            line: line
        )

        for index in originalStrings.indices {
            XCTAssertEqual(
                compressedStrings[index],
                originalStrings[index],
                "PDFKit string extraction must match exactly on page \(index)",
                file: file,
                line: line
            )
        }
    }

    static func assertTextOnlyPDFWasNotRasterized(
        sourceURL: URL,
        compressedURL: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try assertIdenticalPDFKitStringExtraction(
            sourceURL: sourceURL,
            compressedURL: compressedURL,
            file: file,
            line: line
        )

        let compressedStrings = try extractedPageStrings(from: compressedURL)
        XCTAssertTrue(
            compressedStrings.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
            "Text-only PDF compression must preserve extractable text instead of rasterizing pages",
            file: file,
            line: line
        )
    }

    private static func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}
