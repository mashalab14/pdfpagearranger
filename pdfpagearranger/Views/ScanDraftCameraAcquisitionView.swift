import SwiftUI

struct ScanDraftCameraAcquisitionView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if sessionViewModel.isImportingCameraScan {
                ProgressView("Importing scanned pages…")
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle("Scan Document")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sessionViewModel.presentDocumentScannerIfNeeded()
        }
        .fullScreenCover(isPresented: $sessionViewModel.isDocumentScannerPresented) {
            ScanDocumentCameraScannerPresenter(
                onFinish: { scan in
                    Task {
                        await sessionViewModel.handleVisionKitScanCompleted(scan)
                    }
                },
                onCancel: {
                    sessionViewModel.handleVisionKitScanCancelled()
                },
                onFailure: { error in
                    sessionViewModel.handleVisionKitScanFailed(error)
                }
            )
            .ignoresSafeArea()
        }
    }
}
