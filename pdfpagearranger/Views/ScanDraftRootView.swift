import SwiftUI

/// Root navigation shell for the unified scan-to-PDF workflow.
/// Screens are placeholders until camera, Photos, review, and adjustment UI are implemented.
struct ScanDraftRootView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    @Bindable var editorViewModel: PDFEditorViewModel
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
    }

    @ViewBuilder
    private func destination(for route: ScanDraftRoute) -> some View {
        switch route {
        case .entry:
            ScanDraftEntryView(onStart: startFlow, onCancel: cancelFlow)

        case .sourceSelection:
            ScanDraftSourceSelectionView(
                onCamera: { sessionViewModel.navigateToCameraAcquisition() },
                onPhotos: { sessionViewModel.navigateToPhotosAcquisition() },
                onCancel: cancelFlow
            )

        case .cameraAcquisition:
            ScanDraftAcquisitionPlaceholderView(
                title: "Camera",
                message: "Document camera capture will be implemented in a later milestone.",
                onCancel: { sessionViewModel.handleAcquisitionCancelled() }
            )

        case .photosAcquisition:
            ScanDraftAcquisitionPlaceholderView(
                title: "Photos",
                message: "Photos picker import will be implemented in a later milestone.",
                onCancel: { sessionViewModel.handleAcquisitionCancelled() }
            )

        case .draftReview:
            ScanDraftReviewPlaceholderView(
                pageCount: sessionViewModel.document?.pages.count ?? 0,
                onClose: cancelFlow
            )

        case .pageAdjustment(let pageID):
            ScanDraftPageAdjustmentPlaceholderView(
                pageID: pageID,
                onClose: { sessionViewModel.navigateToDraftReview() }
            )

        case .pdfGenerationProgress:
            ScanDraftPDFProgressPlaceholderView(
                isGenerating: sessionViewModel.isGeneratingPDF,
                onClose: { sessionViewModel.navigateToDraftReview() }
            )
        }
    }

    private func startFlow() {
        do {
            try sessionViewModel.beginNewDocumentFlow()
        } catch {
            sessionViewModel.errorMessage = error.localizedDescription
        }
    }

    private func cancelFlow() {
        sessionViewModel.discardDraftSession()
        dismiss()
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
    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button("Scan with Camera", action: onCamera)
                .buttonStyle(.borderedProminent)
            Button("Import from Photos", action: onPhotos)
                .buttonStyle(.bordered)
            Button("Cancel", action: onCancel)
        }
        .padding()
        .navigationTitle("Choose Source")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScanDraftAcquisitionPlaceholderView: View {
    let title: String
    let message: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Cancel", action: onCancel)
        }
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScanDraftReviewPlaceholderView: View {
    let pageCount: Int
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Draft review will host \(pageCount) page(s).")
                .foregroundStyle(.secondary)
            Button("Close", action: onClose)
        }
        .padding()
        .navigationTitle("Review Pages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScanDraftPageAdjustmentPlaceholderView: View {
    let pageID: UUID
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Page adjustment for \(pageID.uuidString.prefix(8))…")
                .foregroundStyle(.secondary)
            Button("Back to Review", action: onClose)
        }
        .padding()
        .navigationTitle("Adjust Page")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScanDraftPDFProgressPlaceholderView: View {
    let isGenerating: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isGenerating {
                ProgressView("Generating PDF…")
            } else {
                Text("PDF generation UI will appear here.")
                    .foregroundStyle(.secondary)
            }
            Button("Back", action: onClose)
        }
        .padding()
        .navigationTitle("Create PDF")
        .navigationBarTitleDisplayMode(.inline)
    }
}
