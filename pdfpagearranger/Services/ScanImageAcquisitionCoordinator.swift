import Foundation

/// Future home for Camera and Photos acquisition.
/// Both sources must converge into `ScanDraftPage` via `ScanDraftSessionStorage`.
protocol ScanImageAcquisitionCoordinating: AnyObject {
    /// Called when acquisition completes with raw image payloads.
    func acquisitionDidFinish(payloads: [ScanAcquiredImagePayload]) async
    /// Called when the user cancels acquisition before any pages are committed.
    func acquisitionDidCancel() async
}

struct ScanAcquiredImagePayload: Sendable {
    let data: Data
    let sourceType: ScanPageSource
}
