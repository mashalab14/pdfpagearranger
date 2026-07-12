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
                sessionViewModel: sessionViewModel,
                onCamera: {
                    Task {
                        let ready = await sessionViewModel.requestCameraScan(context: .newDocument)
                        if ready {
                            sessionViewModel.navigateToCameraAcquisition()
                        }
                    }
                },
                onPhotos: { sessionViewModel.navigateToPhotosAcquisition() },
                onCancel: cancelFlow
            )

        case .cameraAcquisition:
            ScanDraftCameraAcquisitionView(sessionViewModel: sessionViewModel)

        case .photosAcquisition:
            ScanDraftAcquisitionPlaceholderView(
                title: "Photos",
                message: "Photos picker import will be implemented in a later milestone.",
                onCancel: { sessionViewModel.handleAcquisitionCancelled() }
            )

        case .draftReview:
            ScanDraftReviewPlaceholderView(
                sessionViewModel: sessionViewModel,
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

private struct ScanDraftReviewPlaceholderView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    let onClose: () -> Void

    private var document: ScanDraftDocument? { sessionViewModel.document }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Draft review placeholder")
                .font(.headline)

            if let document {
                Text("Pages: \(document.pages.count)")
                Text("Selected page: \(document.selectedPageID?.uuidString.prefix(8) ?? "none")")
                Text("All sources camera: \(document.pages.allSatisfy { $0.sourceType == .camera })")
                Text(
                    "Page order preserved: \(document.pages.map { String($0.id.uuidString.prefix(4)) }.joined(separator: ", "))"
                )

                ForEach(Array(document.pages.enumerated()), id: \.element.id) { index, page in
                    Text("Page \(index + 1): \(page.originalImage.relativePath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Scan More Pages") {
                Task {
                    _ = await sessionViewModel.beginAddPagesCameraScan()
                }
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Scan More Pages")
            .accessibilityHint("Adds more scanned pages to this draft.")

            Button("Close", action: onClose)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .navigationTitle("Review Pages")
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
