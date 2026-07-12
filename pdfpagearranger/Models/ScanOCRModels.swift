import CoreGraphics
import Foundation

/// Normalized bounding box in Vision coordinate space (origin bottom-left, unit square).
struct OCRNormalizedRect: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.size.width)
        height = Double(rect.size.height)
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

enum ScanOCRRecognitionStatus: String, Codable, Equatable, Sendable {
    case notStarted
    case succeeded
    case failed
    case skipped
}

struct OCRLine: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let text: String
    let normalizedBoundingBox: OCRNormalizedRect
    let confidence: Float
    let recognitionOrder: Int

    init(
        id: UUID = UUID(),
        text: String,
        normalizedBoundingBox: OCRNormalizedRect,
        confidence: Float,
        recognitionOrder: Int
    ) {
        self.id = id
        self.text = text
        self.normalizedBoundingBox = normalizedBoundingBox
        self.confidence = confidence
        self.recognitionOrder = recognitionOrder
    }
}

struct OCRParagraph: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    var lines: [OCRLine]

    init(id: UUID = UUID(), lines: [OCRLine]) {
        self.id = id
        self.lines = lines
    }
}

struct OCRPage: Codable, Equatable, Sendable {
    let pageID: UUID
    let imagePixelSize: CGSize
    let recognitionRevision: String
    let status: ScanOCRRecognitionStatus
    let errorMessage: String?
    var paragraphs: [OCRParagraph]

    var lines: [OCRLine] {
        paragraphs.flatMap(\.lines).sorted { $0.recognitionOrder < $1.recognitionOrder }
    }
}

struct ScanDraftOCRCacheEntry: Codable, Equatable, Sendable {
    var relativePath: String
    var fingerprint: String
    var imagePixelSize: CGSize
    var status: ScanOCRRecognitionStatus
    var errorMessage: String?

    func url(in sessionDirectory: URL) -> URL {
        sessionDirectory.appendingPathComponent(relativePath)
    }
}
