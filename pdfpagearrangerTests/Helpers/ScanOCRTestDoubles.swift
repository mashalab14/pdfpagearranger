import Foundation
@testable import pdfpagearranger

final class FakeScanTextRecognizer: ScanTextRecognizing, @unchecked Sendable {
    var configuredLines: [OCRLine] = []
    var shouldThrow = false
    private(set) var callCount = 0

    func recognizeLines(
        in imageData: Data,
        configuration: ScanOCRConfiguration
    ) async throws -> [OCRLine] {
        callCount += 1
        try Task.checkCancellation()
        if shouldThrow {
            throw ScanOCRRecognitionError.requestFailed
        }
        return configuredLines
    }
}

enum ScanOCRTestFactory {
    static func makeLine(
        text: String,
        box: CGRect,
        confidence: Float = 0.9,
        recognitionOrder: Int = 0
    ) -> OCRLine {
        OCRLine(
            text: text,
            normalizedBoundingBox: OCRNormalizedRect(box),
            confidence: confidence,
            recognitionOrder: recognitionOrder
        )
    }

    static func makeProcessedPageWithFingerprint(
        pageID: UUID = UUID(),
        fingerprint: String? = nil
    ) -> ScanDraftPage {
        var page = ScanDraftPage(
            id: pageID,
            sourceType: .camera,
            originalImage: ScanDraftImageReference(relativePath: "originals/\(pageID.uuidString).jpg"),
            processedImage: ScanDraftImageReference(relativePath: "processed/\(pageID.uuidString).jpg"),
            originalPixelSize: CGSize(width: 400, height: 600),
            processingState: .ready
        )
        page.processingFingerprint = fingerprint ?? ScanProcessingFingerprint.value(for: page)
        return page
    }
}
