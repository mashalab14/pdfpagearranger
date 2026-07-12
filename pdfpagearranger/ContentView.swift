import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var viewModel: PDFEditorViewModel
    @State private var scanSessionViewModel = ScanDraftSessionViewModel()
    @State private var showImporter = false
    @State private var showScanDraftFlow = false
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
        .fullScreenCover(isPresented: $showScanDraftFlow) {
            ScanDraftRootView(
                sessionViewModel: scanSessionViewModel,
                editorViewModel: viewModel,
                onEditorHandoffSucceeded: {
                    showScanDraftFlow = false
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
        .onChange(of: viewModel.errorMessage) { _, newValue in
            if let newValue, !viewModel.isLoading {
                importErrorMessage = newValue
                showError = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.on.doc")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("PDF Pages")
                    .font(.largeTitle.bold())

                Text("Rearrange, delete, rotate, and export PDF pages.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Import PDF") {
                showImporter = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("importPDFButton")

            Button("New Document") {
                showScanDraftFlow = true
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("newDocumentButton")

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
