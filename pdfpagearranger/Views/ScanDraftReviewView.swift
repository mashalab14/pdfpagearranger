import SwiftUI

struct ScanDraftReviewView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    let onClose: () -> Void

    @State private var showAddPagesDialog = false
    @State private var showDiscardConfirmation = false
    @State private var previewReloadToken = UUID()

    private let imageLoader: ScanDraftPreviewImageLoader

    init(
        sessionViewModel: ScanDraftSessionViewModel,
        onClose: @escaping () -> Void,
        imageLoader: ScanDraftPreviewImageLoader = ScanDraftPreviewImageLoader()
    ) {
        self.sessionViewModel = sessionViewModel
        self.onClose = onClose
        self.imageLoader = imageLoader
    }

    var body: some View {
        Group {
            if let document = sessionViewModel.document, !document.isEmpty {
                reviewContent(document: document)
            } else {
                emptyState
            }
        }
        .navigationTitle("Review Pages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", action: handleCloseTapped)
                    .accessibilityLabel("Close")
                    .accessibilityHint("Closes the draft review.")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if sessionViewModel.isMultiSelectionMode {
                    Button("Select All") {
                        sessionViewModel.selectAllPagesForBatch()
                    }
                    .accessibilityLabel("Select All")
                    Button("Done") {
                        sessionViewModel.exitMultiSelectionMode()
                    }
                    .accessibilityLabel("Exit Selection Mode")
                } else {
                    Button("Select") {
                        sessionViewModel.enterMultiSelectionMode()
                    }
                    .disabled(sessionViewModel.isBatchProcessing)
                    .accessibilityLabel("Enter Selection Mode")
                }
                Button("Create PDF") {}
                    .disabled(true)
                    .accessibilityLabel("Create PDF")
                    .accessibilityHint("PDF generation is not available yet.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if sessionViewModel.document?.isEmpty == false {
                bottomActions
            }
        }
        .overlay {
            if sessionViewModel.isImportingCameraScan || sessionViewModel.isImportingPhotos {
                acquisitionOverlay
            } else if sessionViewModel.isBatchProcessing {
                batchProcessingOverlay
            }
        }
        .confirmationDialog(
            "Add Pages",
            isPresented: $showAddPagesDialog,
            titleVisibility: .visible
        ) {
            Button("Scan Document") {
                Task {
                    _ = await sessionViewModel.beginAddPagesCameraScan()
                }
            }
            Button("Import Photos") {
                _ = sessionViewModel.beginAddPagesPhotosImport()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Discard Draft?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Draft", role: .destructive) {
                discardDraftAndClose()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("This draft has unsaved changes. Discarding removes imported pages from this device.")
        }
        .alert(
            "Review Error",
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
        .onAppear {
            sessionViewModel.repairSelectionIfNeeded()
        }
        .onChange(of: sessionViewModel.document?.selectedPageID) { _, _ in
            previewReloadToken = UUID()
        }
    }

    @ViewBuilder
    private func reviewContent(document: ScanDraftDocument) -> some View {
        VStack(spacing: 16) {
            if let selectedPage = document.currentPage,
               let pageNumber = sessionViewModel.pageNumber(for: selectedPage.id),
               let sessionDirectory = sessionViewModel.sessionDirectory {
                ScanDraftPagePreviewView(
                    page: selectedPage,
                    pageNumber: pageNumber,
                    totalPages: document.pages.count,
                    sessionDirectory: sessionDirectory,
                    imageLoader: imageLoader,
                    reloadToken: previewReloadToken.uuidString
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                thumbnailStrip(document: document, sessionDirectory: sessionDirectory)

                if sessionViewModel.isMultiSelectionMode {
                    Text("\(sessionViewModel.batchSelectionCount) pages selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("\(sessionViewModel.batchSelectionCount) pages selected")
                }
            } else {
                ProgressView("Loading draft…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .background(Color(.systemGroupedBackground))
    }

    private func thumbnailStrip(document: ScanDraftDocument, sessionDirectory: URL) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(document.pages.enumerated()), id: \.element.id) { index, page in
                        ScanDraftPageThumbnailView(
                            page: page,
                            pageNumber: index + 1,
                            isSelected: document.selectedPageID == page.id,
                            isBatchSelected: sessionViewModel.batchSelectionPageIDs.contains(page.id),
                            showsBatchSelection: sessionViewModel.isMultiSelectionMode,
                            sessionDirectory: sessionDirectory,
                            imageLoader: imageLoader,
                            onSelect: {
                                if sessionViewModel.isMultiSelectionMode {
                                    sessionViewModel.toggleBatchSelection(pageID: page.id)
                                }
                                sessionViewModel.selectPage(id: page.id)
                            }
                        )
                        .id(page.id)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .onChange(of: document.selectedPageID) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .onAppear {
                if let selected = document.selectedPageID {
                    proxy.scrollTo(selected, anchor: .center)
                }
            }
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button("Adjust Page") {
                sessionViewModel.openAdjustmentForSelectedPage()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(
                sessionViewModel.document?.selectedPageID == nil
                || sessionViewModel.isBatchProcessing
            )
            .accessibilityLabel("Adjust Page")
            .accessibilityHint("Opens detailed adjustment for the selected page.")

            Button("Add Pages") {
                showAddPagesDialog = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(sessionViewModel.isImportingCameraScan || sessionViewModel.isImportingPhotos || sessionViewModel.isBatchProcessing)
            .accessibilityLabel("Add Pages")
            .accessibilityHint("Adds more pages from the camera or Photos.")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Pages Yet", systemImage: "doc")
        } description: {
            Text("Scan a document or import photos to begin.")
        } actions: {
            Button("Scan Document") {
                Task {
                    let ready = await sessionViewModel.requestCameraScan(context: .newDocument)
                    if ready {
                        sessionViewModel.navigateToCameraAcquisition()
                    }
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Import Photos") {
                if sessionViewModel.requestPhotosImport(context: .newDocument) {
                    sessionViewModel.navigateToPhotosAcquisition()
                }
            }
            .buttonStyle(.bordered)

            Button("Cancel Draft", role: .cancel) {
                discardDraftAndClose()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var batchProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if sessionViewModel.batchProgress.isCancelling {
                    ProgressView("Cancelling…")
                } else if let pageNumber = sessionViewModel.batchProgress.currentPageNumber {
                    ProgressView(
                        "Applying settings to page \(pageNumber) of \(sessionViewModel.batchProgress.total)…"
                    )
                } else {
                    ProgressView("Applying visual settings…")
                }

                Button("Cancel") {
                    sessionViewModel.cancelBatchProcessing()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel Processing")
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
        }
    }

    private var acquisitionOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                if let progress = sessionViewModel.photosImportProgress {
                    ProgressView(progress.label)
                } else {
                    ProgressView(sessionViewModel.isImportingCameraScan ? "Importing scanned pages…" : "Importing photos…")
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
        }
    }

    private func handleCloseTapped() {
        switch sessionViewModel.closeDraftIntent() {
        case .dismissImmediately:
            discardDraftAndClose()
        case .confirmDiscard:
            showDiscardConfirmation = true
        }
    }

    private func discardDraftAndClose() {
        if sessionViewModel.discardDraftSessionWithCleanup() {
            onClose()
        }
    }
}
