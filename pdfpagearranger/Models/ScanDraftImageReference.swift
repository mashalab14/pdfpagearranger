import Foundation

/// File-backed image reference within a draft session directory.
/// Models store paths only — never full-resolution `UIImage` payloads.
struct ScanDraftImageReference: Equatable, Codable, Hashable, Sendable {
    let relativePath: String

    func url(in sessionDirectory: URL) -> URL {
        sessionDirectory.appendingPathComponent(relativePath)
    }
}
