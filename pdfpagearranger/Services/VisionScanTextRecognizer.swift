import Foundation
import UIKit
import Vision

final class VisionScanTextRecognizer: ScanTextRecognizing, @unchecked Sendable {
    func recognizeLines(
        in imageData: Data,
        configuration: ScanOCRConfiguration
    ) async throws -> [OCRLine] {
        try Task.checkCancellation()
        return try await Task.detached(priority: .userInitiated) {
            try Self.performRecognition(imageData: imageData, configuration: configuration)
        }.value
    }

    private static func performRecognition(
        imageData: Data,
        configuration: ScanOCRConfiguration
    ) throws -> [OCRLine] {
        guard let image = UIImage(data: imageData),
              let cgImage = (ScanWorkingImageEncoder.orientationNormalizedImage(from: image) ?? image).cgImage else {
            throw ScanOCRRecognitionError.imageCannotBeLoaded
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.recognitionLanguages = configuration.recognitionLanguages

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }

        var lines: [OCRLine] = []
        lines.reserveCapacity(observations.count)

        for (index, observation) in observations.enumerated() {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let trimmed = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard candidate.confidence >= configuration.minimumConfidence else { continue }

            lines.append(
                OCRLine(
                    text: trimmed,
                    normalizedBoundingBox: OCRNormalizedRect(observation.boundingBox),
                    confidence: candidate.confidence,
                    recognitionOrder: index
                )
            )
        }

        return lines
    }
}
