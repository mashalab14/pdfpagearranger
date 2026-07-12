import SwiftUI
import UIKit
import VisionKit

struct ScanDocumentCameraScannerPresenter: UIViewControllerRepresentable {
    let onFinish: (VNDocumentCameraScan) -> Void
    let onCancel: () -> Void
    let onFailure: (ScanDraftError) -> Void

    func makeUIViewController(context: Context) -> ScanDocumentCameraScannerHostViewController {
        let host = ScanDocumentCameraScannerHostViewController()
        host.delegate = context.coordinator
        return host
    }

    func updateUIViewController(
        _ uiViewController: ScanDocumentCameraScannerHostViewController,
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
                controller.dismiss(animated: true) {
                    self.onFinish(scan)
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            finishOnce {
                controller.dismiss(animated: true) {
                    self.onCancel()
                }
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            finishOnce {
                controller.dismiss(animated: true) {
                    self.onFailure(.visionKitScannerFailure)
                }
            }
        }

        private func finishOnce(_ action: () -> Void) {
            guard !didComplete else { return }
            didComplete = true
            action()
        }
    }
}

final class ScanDocumentCameraScannerHostViewController: UIViewController {
    weak var delegate: ScanDocumentCameraScannerPresenter.Coordinator?
    private var didPresentScanner = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didPresentScanner else { return }
        didPresentScanner = true

        let scanner = VNDocumentCameraViewController()
        scanner.delegate = delegate
        present(scanner, animated: true)
    }
}
