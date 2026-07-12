import Foundation

enum ScanOCRFingerprint {
    static let recognitionRevision = "vision-accurate-v1"

    static func value(for page: ScanDraftPage, configuration: ScanOCRConfiguration) -> String {
        let payload = FingerprintPayload(
            processingFingerprint: ScanProcessingFingerprint.value(for: page),
            configuration: configuration,
            recognitionRevision: recognitionRevision
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload) else {
            return page.id.uuidString
        }
        return data.base64EncodedString()
    }

    static func isCacheValid(for page: ScanDraftPage, configuration: ScanOCRConfiguration) -> Bool {
        guard ScanProcessingFingerprint.isProcessedOutputValid(for: page),
              let cache = page.ocrCache else {
            return false
        }
        return cache.fingerprint == value(for: page, configuration: configuration)
    }

    private struct FingerprintPayload: Codable {
        let processingFingerprint: String
        let configuration: ScanOCRConfiguration
        let recognitionRevision: String
    }
}
