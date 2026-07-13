import SwiftUI
import PhotosUI

/// Root navigation shell for the unified scan-to-PDF workflow.
struct ScanDraftRootView: View {
    let entryMode: ScanDraftEntryMode
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    @Bindable var editorViewModel: PDFEditorViewModel
    let onEditorHandoffSucceeded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack(path: $sessionViewModel.navigationPath) {
            ScanDraftFlowEntryHost(sessionViewModel: sessionViewModel)
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
        .photosPicker(
            isPresented: $sessionViewModel.isPhotosPickerPresented,
            selection: $selectedPhotoItems,
            maxSelectionCount: ScanPhotosImportLimits.maxSelectionCount,
            matching: .images
        )
        .onChange(of: sessionViewModel.isPhotosPickerPresented) { _, isPresented in
            guard !isPresented else { return }
            guard selectedPhotoItems.isEmpty else { return }
            guard !sessionViewModel.isImportingPhotos else { return }
            sessionViewModel.handlePhotosPickerCancelled()
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            let items = newItems
            selectedPhotoItems = []
            sessionViewModel.isPhotosPickerPresented = false
            Task {
                await sessionViewModel.handlePhotosSelection(items)
            }
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

    private func dismissReview() {
        if sessionViewModel.discardDraftSessionWithCleanup() {
            dismiss()
        }
    }
}

/// Imperceptible host for scan entry while VisionKit, Photos picker, or import overlays are active.
private struct ScanDraftFlowEntryHost: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel

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
            } else if sessionViewModel.isImportingPhotos {
                if let progress = sessionViewModel.photosImportProgress {
                    ProgressView(progress.label)
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("photosImportProgress")
                } else {
                    ProgressView("Importing photos…")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("photosImportProgress")
                }
            }
        }
        .navigationBarHidden(true)
    }
}
