import Foundation

enum ScanDraftCloseIntent: Equatable, Sendable {
    case dismissImmediately
    case confirmDiscard
}

enum ScanAcquisitionImportContext: Equatable, Sendable {
    case newDocument
    case addToExistingDraft
}

enum ScanAcquisitionOutcome: Equatable, Sendable {
    case cancelled
    case completed(pageCount: Int)
    case failed(ScanDraftError)
}

struct ScanPhotosImportProgress: Equatable, Sendable {
    let total: Int
    let completed: Int

    var label: String {
        "Importing \(completed) of \(total)"
    }
}

/// App-owned ordered import descriptor. Framework picker items are not stored long-term.
struct ScanOrderedPhotoImportItem: Equatable, Sendable {
    let selectionIndex: Int
    let itemIdentifier: String
}

struct ScanImportPagePayload: Equatable, Sendable {
    let data: Data
    let fileExtension: String

    static func jpeg(_ data: Data) -> ScanImportPagePayload {
        ScanImportPagePayload(data: data, fileExtension: "jpg")
    }
}

final class ScanImportCancellationFlag: @unchecked Sendable {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}
