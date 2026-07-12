import Foundation

/// How a draft page entered the unified scan-to-PDF pipeline.
enum ScanPageSource: String, Codable, CaseIterable, Equatable {
    case camera
    case photos
}
