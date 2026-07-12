import SwiftUI

/// Root navigation shell for the unified scan-to-PDF workflow.
/// Screens are placeholders until camera, Photos, review, and adjustment UI are implemented.
struct ScanDraftRootView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    @Bindable var editorViewModel: PDFEditorViewModel
    let onEditorHandoffSucceeded: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $sessionViewModel.navigationPath) {
            ScanDraftEntryView(
                onStart: startFlow,
                onCancel: cancelFlow
            )
            .navigationDestination(for: ScanDraftRoute.self) { route in
                destination(for: route)
            }
        }
        .interactiveDismissDisabled(
            sessionViewModel.document?.hasUnsavedChanges == true
            || sessionViewModel.isGeneratingPDF
        )
    }

    @ViewBuilder
    private func destination(for route: ScanDraftRoute) -> some View {
        switch route {
        case .entry:
            ScanDraftEntryView(onStart: startFlow, onCancel: cancelFlow)

        case .sourceSelection:
            ScanDraftSourceSelectionView(
                sessionViewModel: sessionViewModel,
                onCamera: {
                    Task {
                        let ready = await sessionViewModel.requestCameraScan(context: .newDocument)
                        if ready {
                            sessionViewModel.navigateToCameraAcquisition()
                        }
                    }
                },
                onPhotos: {
                    if sessionViewModel.requestPhotosImport(context: .newDocument) {
                        sessionViewModel.navigateToPhotosAcquisition()
                    }
                },
                onCancel: cancelFlow
            )

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

    private func handleEditorHandoffSucceeded() {
        sessionViewModel.navigateToDraftReview()
        onEditorHandoffSucceeded()
    }

    private func startFlow() {
        do {
            try sessionViewModel.beginNewDocumentFlow()
        } catch {
            sessionViewModel.errorMessage = error.localizedDescription
        }
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

private struct ScanDraftEntryView: View {
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Create PDF")
                .font(.title2.bold())
            Text("Scan with Camera or import from Photos, then review pages before opening the editor.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Continue", action: onStart)
                .buttonStyle(.borderedProminent)

            Button("Cancel", action: onCancel)
        }
        .padding()
        .navigationTitle("New Document")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScanDraftSourceSelectionView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button("Scan Document") {
                onCamera()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Scan Document")
            .accessibilityHint("Opens the document camera to scan one or more pages.")
            Button("Import from Photos", action: onPhotos)
                .buttonStyle(.bordered)
                .disabled(sessionViewModel.isImportingPhotos || sessionViewModel.isImportingCameraScan)
                .accessibilityLabel("Import from Photos")
                .accessibilityHint("Opens the system photo picker to import one or more images.")
            Button("Cancel", action: onCancel)
        }
        .padding()
        .navigationTitle("Choose Source")
        .navigationBarTitleDisplayMode(.inline)
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
}
