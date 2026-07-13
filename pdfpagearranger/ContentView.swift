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

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.on.doc")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(HomeScreenCopy.appTitle)
                    .font(.largeTitle.bold())

                Text(HomeScreenCopy.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button(HomeScreenCopy.openPDF) {
                    showImporter = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(HomeScreenCopy.openPDF)
                .accessibilityHint(HomeScreenCopy.openPDFAccessibilityHint)
                .accessibilityIdentifier("openPDFButton")

                Button(HomeScreenCopy.scanToPDF) {
                    Task { @MainActor in
                        await scanSessionViewModel.beginCameraScanFlow()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(HomeScreenCopy.scanToPDF)
                .accessibilityHint(HomeScreenCopy.scanToPDFAccessibilityHint)
                .accessibilityIdentifier("scanDocumentButton")

                Button(HomeScreenCopy.photoToPDF) {
                    _ = scanSessionViewModel.beginPhotosImportFlow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(HomeScreenCopy.photoToPDF)
                .accessibilityHint(HomeScreenCopy.photoToPDFAccessibilityHint)
                .accessibilityIdentifier("importPhotosButton")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("emptyStateView")
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
