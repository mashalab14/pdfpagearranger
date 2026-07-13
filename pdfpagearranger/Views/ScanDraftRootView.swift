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
            ScanDraftFlowEntryHost(
                entryMode: entryMode,
                sessionViewModel: sessionViewModel,
                onCancel: cancelFlow
            )
            .navigationDestination(for: ScanDraftRoute.self) { route in
                destination(for: route)
            }
        }
        .task(id: entryMode) {
            await startEntryFlow()
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
                if sessionViewModel.document == nil {
                    dismiss()
                }
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

/// Imperceptible host for scan entry while VisionKit or import overlays are active.
private struct ScanDraftFlowEntryHost: View {
    let entryMode: ScanDraftEntryMode
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .accessibilityHidden(true)

            if sessionViewModel.isImportingCameraScan {
                ProgressView("Importing scanned pages…")
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("scanImportProgress")
            }
        }
        .toolbar {
            if showsCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var showsCancelButton: Bool {
        entryMode == .photos
            && sessionViewModel.navigationPath.isEmpty
            && !sessionViewModel.isImportingCameraScan
    }
}
