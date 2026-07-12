import SwiftUI

/// Root navigation shell for the unified scan-to-PDF workflow.
struct ScanDraftRootView: View {
    let entryMode: ScanDraftEntryMode
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    @Bindable var editorViewModel: PDFEditorViewModel
    let onEditorHandoffSucceeded: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $sessionViewModel.navigationPath) {
            ScanDraftFlowRootPlaceholder(onCancel: cancelFlow)
                .navigationDestination(for: ScanDraftRoute.self) { route in
                    destination(for: route)
                }
        }
        .task(id: entryMode) {
            await startEntryFlow()
        }
        .interactiveDismissDisabled(
            sessionViewModel.document?.hasUnsavedChanges == true
            || sessionViewModel.isGeneratingPDF
        )
        .onChange(of: sessionViewModel.document?.id) { oldValue, newValue in
            guard oldValue != nil, newValue == nil, sessionViewModel.navigationPath.isEmpty else { return }
            dismiss()
        }
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
    }

    @ViewBuilder
    private func destination(for route: ScanDraftRoute) -> some View {
        switch route {
        case .cameraAcquisition:
            ScanDraftCameraAcquisitionView(sessionViewModel: sessionViewModel)

        case .photosAcquisition:
            ScanDraftPhotosAcquisitionView(sessionViewModel: sessionViewModel)

        case .draftReview:
            ScanDraftReviewView(
                sessionViewModel: sessionViewModel,
                editorViewModel: editorViewModel,
                onClose: dismissReview,
                onPDFHandoffSucceeded: handleEditorHandoffSucceeded
            )

        case .pageAdjustment(let pageID):
            ScanDraftPageAdjustmentView(
                sessionViewModel: sessionViewModel,
                pageID: pageID
            )

        case .pdfGenerationProgress:
            ScanDraftPDFGenerationProgressView(sessionViewModel: sessionViewModel)
        }
    }

    private func startEntryFlow() async {
        switch entryMode {
        case .camera:
            _ = await sessionViewModel.beginCameraScanFlow()
        case .photos:
            _ = sessionViewModel.beginPhotosImportFlow()
        }
    }

    private func handleEditorHandoffSucceeded() {
        sessionViewModel.navigateToDraftReview()
        onEditorHandoffSucceeded()
    }

    private func cancelFlow() {
        if sessionViewModel.discardDraftSessionWithCleanup() {
            dismiss()
        }
    }

    private func dismissReview() {
        if sessionViewModel.discardDraftSessionWithCleanup() {
            dismiss()
        }
    }
}

private struct ScanDraftFlowRootPlaceholder: View {
    let onCancel: () -> Void

    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
    }
}
