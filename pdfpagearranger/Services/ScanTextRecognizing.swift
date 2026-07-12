import Foundation

protocol ScanTextRecognizing: Sendable {
    func recognizeLines(
        in imageData: Data,
        configuration: ScanOCRConfiguration
    ) async throws -> [OCRLine]
}

enum ScanOCRRecognitionError: Error, Equatable {
    case imageCannotBeLoaded
    case requestFailed
}
