import UIKit
@testable import pdfpagearranger

final class MockScanCameraPermissionChecker: ScanCameraPermissionChecking, @unchecked Sendable {
    var status: ScanCameraAuthorizationStatus = .authorized
    var requestResult: ScanCameraAuthorizationStatus = .authorized
    private(set) var requestAccessCallCount = 0

    func authorizationStatus() -> ScanCameraAuthorizationStatus {
        status
    }

    func requestAccess() async -> ScanCameraAuthorizationStatus {
        requestAccessCallCount += 1
        return requestResult
    }
}

struct MockScanDocumentScannerAvailabilityChecker: ScanDocumentScannerAvailabilityChecking, Sendable {
    var isDocumentScannerSupported: Bool
}

enum ScanCameraScanTestSupport {
    static func makeScanBridge(pageCount: Int) -> InMemoryDocumentCameraScanBridge {
        let images = (0..<pageCount).map { _ in
            UIImage(data: ScanDraftTestFactory.makeTestImageData()) ?? UIImage()
        }
        return InMemoryDocumentCameraScanBridge(images: images)
    }
}
