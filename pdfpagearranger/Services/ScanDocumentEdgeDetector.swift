import Foundation
import Vision

struct ScanDocumentEdgeDetectionResult: Equatable, Sendable {
    let corners: [ScanNormalizedPoint]
    let confidence: Float
}

protocol ScanDocumentEdgeDetecting: Sendable {
    func detectDocument(in imageData: Data) async throws -> ScanDocumentEdgeDetectionResult?
}

struct VisionScanDocumentEdgeDetector: ScanDocumentEdgeDetecting {
    func detectDocument(in imageData: Data) async throws -> ScanDocumentEdgeDetectionResult? {
        try await Task.detached(priority: .userInitiated) {
            let request = VNDetectRectanglesRequest()
            request.minimumAspectRatio = 0.2
            request.maximumAspectRatio = 1.0
            request.minimumSize = 0.15
            request.minimumConfidence = 0.4
            request.maximumObservations = 1
            request.quadratureTolerance = 25

            let handler = VNImageRequestHandler(data: imageData, options: [:])
            try handler.perform([request])

            guard let observation = request.results?.max(by: { $0.confidence < $1.confidence }) else {
                return nil
            }

            let corners = [
                visionCornerToNormalized(observation.topLeft),
                visionCornerToNormalized(observation.topRight),
                visionCornerToNormalized(observation.bottomRight),
                visionCornerToNormalized(observation.bottomLeft)
            ]

            switch ScanPageGeometryEngine.validateCorners(corners) {
            case .success(let validated):
                return ScanDocumentEdgeDetectionResult(corners: validated, confidence: observation.confidence)
            case .failure:
                return nil
            }
        }.value
    }

    private func visionCornerToNormalized(_ point: CGPoint) -> ScanNormalizedPoint {
        ScanNormalizedPoint(x: point.x, y: 1 - point.y)
    }
}

final class InMemoryScanDocumentEdgeDetector: ScanDocumentEdgeDetecting, @unchecked Sendable {
    var result: ScanDocumentEdgeDetectionResult?
    var delayNanoseconds: UInt64 = 0
    var shouldThrow = false
    private(set) var callCount = 0

    func detectDocument(in imageData: Data) async throws -> ScanDocumentEdgeDetectionResult? {
        callCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if shouldThrow {
            throw ScanDraftError.processingFailure(stage: .detectBoundaries)
        }
        return result
    }
}
