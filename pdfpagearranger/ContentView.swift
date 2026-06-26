import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = PDFEditorViewModel()
    @State private var showImporter = false
    @State private var showError = false
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasDocument, let _ = viewModel.sourceDocument {
                    EditorView(viewModel: viewModel)
                } else {
                    emptyState
                }
            }
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await viewModel.importPDF(from: url) }
            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showError = true
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

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
}

#Preview {
    ContentView()
}
