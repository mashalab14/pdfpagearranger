import Foundation

enum ScanPageProcessingState: Equatable, Codable, Sendable {
    case pending
    case processing
    case ready
    case failed
}

enum ScanThumbnailState: Equatable, Codable, Sendable {
    case notGenerated
    case generating
    case ready
    case failed
}

enum ScanDocumentProcessingStatus: Equatable, Codable, Sendable {
    case idle
    case processingPages(completed: Int, total: Int)
    case generatingPDF
    case pdfReady
    case failed
}
