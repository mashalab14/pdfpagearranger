import Foundation

/// Stable fingerprint of page inputs that affect processed output.
/// Used to reuse cached processed images and skip duplicate work.
enum ScanProcessingFingerprint {
    static func value(for page: ScanDraftPage) -> String {
        let payload = FingerprintPayload(
            originalImagePath: page.originalImage.relativePath,
            geometry: page.geometry,
            visualAdjustments: page.visualAdjustments
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload) else {
            return page.id.uuidString
        }
        return data.base64EncodedString()
    }

    static func isProcessedOutputValid(for page: ScanDraftPage) -> Bool {
        guard page.processingState == .ready,
              page.processedImage != nil,
              let cached = page.processingFingerprint else {
            return false
        }
        return cached == value(for: page)
    }

    private struct FingerprintPayload: Codable {
        let originalImagePath: String
        let geometry: ScanPageGeometry
        let visualAdjustments: ScanVisualAdjustments
    }
}
