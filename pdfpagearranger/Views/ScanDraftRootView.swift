import SwiftUI

/// Draft review navigation shell for the scan-to-PDF workflow. Home presents acquisition; this view opens only after pages exist.
struct ScanDraftRootView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    @Bindable var editorViewModel: PDFEditorViewModel
    let onEditorHandoffSucceeded: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $sessionViewModel.navigationPath) {
            ScanDraftReviewView(
                sessionViewModel: sessionViewModel,
                editorViewModel: editorViewModel,
                onClose: dismissReview,
                onPDFHandoffSucceeded: handleEditorHandoffSucceeded
            )
            .navigationDestination(for: ScanDraftRoute.self) { route in
                destination(for: route)
            }
        }
        .interactiveDismissDisabled(
            sessionViewModel.document?.hasUnsavedChanges == true
            || sessionViewModel.isGeneratingPDF
        )
        .alert(
            "Scan Error",
            isPresented: Binding(
                get: { sessionViewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        sessionViewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                sessionViewModel.errorMessage = nil
            }
        } message: {
            Text(sessionViewModel.errorMessage ?? "")
        }
        .alert(
            "PDF Created",
            isPresented: Binding(
                get: { sessionViewModel.pdfGenerationNotice != nil },
                set: { isPresented in
                    if !isPresented {
                        sessionViewModel.pdfGenerationNotice = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                sessionViewModel.pdfGenerationNotice = nil
            }
        } message: {
            Text(sessionViewModel.pdfGenerationNotice ?? "")
        }
    }

    @ViewBuilder
    private func destination(for route: ScanDraftRoute) -> some View {
        switch route {
        case .cameraAcquisition:
            ScanDraftCameraAcquisitionView(sessionViewModel: sessionViewModel)

        case .photosAcquisition:
            ScanDraftPhotosAcquisitionView(sessionViewModel: sessionViewModel)

        case .pageAdjustment(let pageID):
            ScanDraftPageAdjustmentView(
                sessionViewModel: sessionViewModel,
                pageID: pageID
            )

        case .pdfGenerationProgress:
            ScanDraftPDFGenerationProgressView(sessionViewModel: sessionViewModel)
        }
    }

    private func handleEditorHandoffSucceeded() {
        sessionViewModel.navigateToDraftReview()
        onEditorHandoffSucceeded()
    }

    private func dismissReview() {
        if sessionViewModel.discardDraftSessionWithCleanup() {
            dismiss()
        }
    }
}
