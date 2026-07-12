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
