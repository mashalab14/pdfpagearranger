import Foundation
import VisionKit

protocol ScanDocumentScannerAvailabilityChecking: Sendable {
    var isDocumentScannerSupported: Bool { get }
}

struct SystemScanDocumentScannerAvailabilityChecker: ScanDocumentScannerAvailabilityChecking {
    var isDocumentScannerSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }
}
