import SwiftUI

struct SignatureLibraryView: View {
    @Environment(\.dismiss) private var dismiss

    let store: SignatureLibraryStore
    let onSelectSignature: (UIImage) -> Void

    @State private var signatures: [SignatureAsset] = []
    @State private var showCapture = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if signatures.isEmpty {
                    emptyState
                } else {
                    signatureList
                }
            }
            .navigationTitle("Signature Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                reloadSignatures()
            }
            .sheet(isPresented: $showCapture) {
                SignatureCaptureView { image in
                    saveAndUse(image)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("signatureLibraryView")
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "signature")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No saved signatures")
                .font(.title3.weight(.semibold))

            Button {
                showCapture = true
            } label: {
                Text("Create Signature")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("signatureLibraryCreateButton")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("signatureLibraryEmptyState")
    }

    private var signatureList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button {
                    showCapture = true
                } label: {
                    Label("Create New Signature", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("signatureLibraryCreateNewButton")

                LazyVGrid(columns: gridColumns, spacing: 20) {
                    ForEach(signatures) { asset in
                        signatureTile(for: asset)
                    }
                }
            }
            .padding()
        }
    }

    private func signatureTile(for asset: SignatureAsset) -> some View {
        Button {
            selectAsset(asset)
        } label: {
            VStack(spacing: 8) {
                signatureThumbnail(for: asset)
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(.separator), lineWidth: 1)
                    }

                Text(asset.displayName)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("signatureLibraryItem_\(asset.id.uuidString)")
    }

    @ViewBuilder
    private func signatureThumbnail(for asset: SignatureAsset) -> some View {
        if let data = store.loadThumbnailData(for: asset) ?? store.loadImageData(for: asset),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            Image(systemName: "signature")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func reloadSignatures() {
        signatures = store.listSignatures()
    }

    private func selectAsset(_ asset: SignatureAsset) {
        guard let data = store.loadImageData(for: asset),
              let image = UIImage(data: data) else {
            return
        }
        onSelectSignature(image)
        dismiss()
    }

    private func saveAndUse(_ image: UIImage) {
        if let pngData = image.pngData() {
            try? store.saveSignature(imageData: pngData, sourceType: .drawn)
            reloadSignatures()
        }
        onSelectSignature(image)
        dismiss()
    }
}

#Preview("Empty") {
    SignatureLibraryView(
        store: SignatureLibraryStore(
            rootDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("PreviewSignatureLibrary", isDirectory: true)
        ),
        onSelectSignature: { _ in }
    )
}
