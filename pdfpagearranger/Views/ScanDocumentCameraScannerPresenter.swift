import SwiftUI
import UIKit
import VisionKit

struct ScanDocumentCameraScannerPresenter: UIViewControllerRepresentable {
    let onFinish: (VNDocumentCameraScan) -> Void
    let onCancel: () -> Void
    let onFailure: (ScanDraftError) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(
        _ uiViewController: VNDocumentCameraViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel, onFailure: onFailure)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onFinish: (VNDocumentCameraScan) -> Void
        private let onCancel: () -> Void
        private let onFailure: (ScanDraftError) -> Void
        private var didComplete = false

        init(
            onFinish: @escaping (VNDocumentCameraScan) -> Void,
            onCancel: @escaping () -> Void,
            onFailure: @escaping (ScanDraftError) -> Void
        ) {
            self.onFinish = onFinish
            self.onCancel = onCancel
            self.onFailure = onFailure
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            finishOnce {
                self.onFinish(scan)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            finishOnce {
                self.onCancel()
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            finishOnce {
                self.onFailure(.visionKitScannerFailure)
            }
        }

        private func finishOnce(_ action: () -> Void) {
            guard !didComplete else { return }
            didComplete = true
            action()
        }
    }
}
