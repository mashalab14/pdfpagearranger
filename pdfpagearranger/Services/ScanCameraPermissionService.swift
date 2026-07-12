import Foundation

enum ScanCameraAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

protocol ScanCameraPermissionChecking: Sendable {
    func authorizationStatus() -> ScanCameraAuthorizationStatus
    func requestAccess() async -> ScanCameraAuthorizationStatus
}

enum ScanCameraImportContext: Equatable, Sendable {
    case newDocument
    case addToExistingDraft
}

enum ScanCameraAcquisitionOutcome: Equatable, Sendable {
    case cancelled
    case completed(pageCount: Int)
    case failed(ScanDraftError)
}
