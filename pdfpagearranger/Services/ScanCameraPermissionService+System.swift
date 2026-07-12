import AVFoundation
import Foundation

struct SystemScanCameraPermissionChecker: ScanCameraPermissionChecking {
    func authorizationStatus() -> ScanCameraAuthorizationStatus {
        map(AVCaptureDevice.authorizationStatus(for: .video))
    }

    func requestAccess() async -> ScanCameraAuthorizationStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }

    private func map(_ status: AVAuthorizationStatus) -> ScanCameraAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
}
