import Foundation

struct ScanOCRConfiguration: Codable, Equatable, Sendable {
    var recognitionLanguages: [String]
    var minimumConfidence: Float

    static let defaultLanguages = ["en-US"]

    /// Conservative minimum confidence for Vision observations.
    /// Observations below this threshold are ignored as noise; readable low-confidence
    /// lines above it are retained for search and selection.
    static let defaultMinimumConfidence: Float = 0.25

    static let `default` = ScanOCRConfiguration(
        recognitionLanguages: defaultLanguages,
        minimumConfidence: defaultMinimumConfidence
    )
}

enum ScanOCRSettings {
    static let searchablePDFEnabledKey = "scanDraftSearchablePDFEnabled"

    static func isSearchablePDFEnabled(in defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: searchablePDFEnabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: searchablePDFEnabledKey)
    }

    static func setSearchablePDFEnabled(_ enabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: searchablePDFEnabledKey)
    }
}

struct ScanDraftPDFGenerationOptions: Sendable {
    var makeSearchable: Bool
    var ocrConfiguration: ScanOCRConfiguration

    static var `default`: ScanDraftPDFGenerationOptions {
        ScanDraftPDFGenerationOptions(
            makeSearchable: ScanOCRSettings.isSearchablePDFEnabled(),
            ocrConfiguration: .default
        )
    }
}

struct ScanDraftPDFGenerationResult: Sendable {
    let url: URL
    let nonSearchablePageIDs: [UUID]
}
