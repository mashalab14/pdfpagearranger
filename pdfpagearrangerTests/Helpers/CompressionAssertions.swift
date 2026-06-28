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

    private static func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}
