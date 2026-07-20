import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var viewModel: PDFEditorViewModel
    @State private var scanSessionViewModel = ScanDraftSessionViewModel()
    @State private var isScanDraftReviewPresented = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showImporter = false
    @State private var showSettings = false
    @State private var showError = false
    @State private var importErrorMessage: String?
    @State private var showAllRecentDocuments = false
    @State private var recentDocuments: [RecentDocumentRecord] = []

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasDocument {
                    EditorView(viewModel: viewModel)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier(UITestLaunchConfiguration.documentReadyIdentifier)
                } else {
                    emptyState
                }
            }
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                } else if showsHomeAcquisitionImportOverlay {
                    homeAcquisitionImportOverlay
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    settingsButton
                }
            }
            .navigationDestination(isPresented: $showAllRecentDocuments) {
                RecentDocumentsListView(viewModel: viewModel) { record in
                    Task { await viewModel.openRecentDocument(record) }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $scanSessionViewModel.isDocumentScannerPresented) {
            ScanDocumentCameraScannerPresenter(
                onFinish: { scan in
                    Task {
                        await scanSessionViewModel.handleVisionKitScanCompleted(scan)
                        updateDraftReviewPresentationIfNeeded()
                    }
                },
                onCancel: {
                    scanSessionViewModel.handleVisionKitScanCancelled()
                },
                onFailure: { error in
                    scanSessionViewModel.handleVisionKitScanFailed(error)
                }
            )
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $scanSessionViewModel.isPhotosPickerPresented,
            selection: $selectedPhotoItems,
            maxSelectionCount: ScanPhotosImportLimits.maxSelectionCount,
            matching: .images
        )
        .onChange(of: scanSessionViewModel.isPhotosPickerPresented) { _, isPresented in
            guard !isPresented else { return }
            guard selectedPhotoItems.isEmpty else { return }
            guard !scanSessionViewModel.isImportingPhotos else { return }
            scanSessionViewModel.handlePhotosPickerCancelled()
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            let items = newItems
            selectedPhotoItems = []
            scanSessionViewModel.isPhotosPickerPresented = false
            Task {
                await scanSessionViewModel.handlePhotosSelection(items)
                updateDraftReviewPresentationIfNeeded()
            }
        }
        .fullScreenCover(isPresented: $isScanDraftReviewPresented) {
            ScanDraftRootView(
                sessionViewModel: scanSessionViewModel,
                editorViewModel: viewModel,
                onEditorHandoffSucceeded: {
                    isScanDraftReviewPresented = false
                }
            )
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    await viewModel.importPDF(from: url)
                    refreshRecentDocuments()
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
        .alert("Import Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert(
            "Scan Error",
            isPresented: Binding(
                get: { !isScanDraftReviewPresented && scanSessionViewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        scanSessionViewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                scanSessionViewModel.errorMessage = nil
            }
        } message: {
            Text(scanSessionViewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            if let newValue, !viewModel.isLoading {
                importErrorMessage = newValue
                showError = true
            }
        }
        .onChange(of: scanSessionViewModel.document?.id) { _, newValue in
            if newValue == nil {
                isScanDraftReviewPresented = false
            } else {
                updateDraftReviewPresentationIfNeeded()
            }
        }
        .onChange(of: scanSessionViewModel.isImportingCameraScan) { _, _ in
            updateDraftReviewPresentationIfNeeded()
        }
        .onChange(of: scanSessionViewModel.isImportingPhotos) { _, _ in
            updateDraftReviewPresentationIfNeeded()
        }
        .onChange(of: viewModel.hasDocument) { _, hasDocument in
            if !hasDocument {
                refreshRecentDocuments()
            }
        }
    }

    private var showsHomeAcquisitionImportOverlay: Bool {
        !isScanDraftReviewPresented
            && (scanSessionViewModel.isImportingCameraScan || scanSessionViewModel.isImportingPhotos)
    }

    private var homeAcquisitionImportOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            Group {
                if let progress = scanSessionViewModel.photosImportProgress {
                    ProgressView(progress.label)
                } else if scanSessionViewModel.isImportingCameraScan {
                    ProgressView("Importing scanned pages…")
                } else {
                    ProgressView("Importing photos…")
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("homeAcquisitionImportProgress")
        }
    }

    private func updateDraftReviewPresentationIfNeeded() {
        guard scanSessionViewModel.document?.isEmpty == false else { return }
        guard !scanSessionViewModel.isImportingCameraScan else { return }
        guard !scanSessionViewModel.isImportingPhotos else { return }
        isScanDraftReviewPresented = true
    }

    private func refreshRecentDocuments() {
        recentDocuments = viewModel.recentDocumentsForHome()
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                homeHeader
                acquisitionActions
                recentDocumentsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("emptyStateView")
        .onAppear {
            refreshRecentDocuments()
        }
    }

    private var homeHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(HomeScreenCopy.appTitle)
                    .font(.title2.bold())

                Text(HomeScreenCopy.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("homeHeader")
    }

    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(HomeScreenCopy.recentDocuments)
                    .font(.headline)

                Spacer()

                if !recentDocuments.isEmpty {
                    Button(HomeScreenCopy.recentDocumentsMore) {
                        showAllRecentDocuments = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHint(HomeScreenCopy.recentDocumentsMoreAccessibilityHint)
                    .accessibilityIdentifier("recentDocumentsMoreButton")
                }
            }

            if recentDocuments.isEmpty {
                Text(HomeScreenCopy.recentDocumentsEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("recentDocumentsEmptyLabel")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentDocuments.enumerated()), id: \.element.id) { index, record in
                        Button {
                            Task { await viewModel.openRecentDocument(record) }
                        } label: {
                            RecentDocumentRow(
                                record: record,
                                thumbnail: viewModel.loadRecentThumbnail(for: record),
                                style: .compact
                            )
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("homeRecentDocument-\(index)")

                        if index < recentDocuments.count - 1 {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("recentDocumentsHomeList")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recentDocumentsSection")
    }

    private var acquisitionActions: some View {
        VStack(spacing: 10) {
            primaryActionButton(
                title: HomeScreenCopy.scanToPDF,
                hint: HomeScreenCopy.scanToPDFAccessibilityHint,
                identifier: "scanDocumentButton"
            ) {
                Task { @MainActor in
                    await scanSessionViewModel.beginCameraScanFlow()
                }
            }

            HStack(spacing: 10) {
                primaryActionButton(
                    title: HomeScreenCopy.photoToPDF,
                    hint: HomeScreenCopy.photoToPDFAccessibilityHint,
                    identifier: "importPhotosButton"
                ) {
                    _ = scanSessionViewModel.beginPhotosImportFlow()
                }

                primaryActionButton(
                    title: HomeScreenCopy.openDocument,
                    hint: HomeScreenCopy.openDocumentAccessibilityHint,
                    identifier: "openPDFButton"
                ) {
                    showImporter = true
                }
            }

            primaryActionButton(
                title: HomeScreenCopy.createDocument,
                hint: HomeScreenCopy.createDocumentAccessibilityHint,
                identifier: "createDocumentButton"
            ) {
                Task { await viewModel.createBlankDocument() }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homePrimaryActions")
    }

    private func primaryActionButton(
        title: String,
        hint: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(title)
            .accessibilityHint(hint)
            .accessibilityIdentifier(identifier)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            ProgressView("Importing PDF…")
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("settingsButton")
    }
}

#Preview {
    ContentView(viewModel: PDFEditorViewModel())
}
