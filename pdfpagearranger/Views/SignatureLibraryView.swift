import SwiftUI

struct SignatureLibraryView: View {
    @Environment(\.dismiss) private var dismiss

    let store: SignatureLibraryStore
    let showDefaultGuidanceBanner: Bool
    let onSelectSignature: (UIImage) -> Void

    @State private var signatures: [SignatureAsset] = []
    @State private var defaultSignatureID: UUID?
    @State private var showCapture = false
    @State private var assetPendingRename: SignatureAsset?
    @State private var renameDraftName = ""
    @State private var showDefaultSignatureError = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    init(
        store: SignatureLibraryStore,
        showDefaultGuidanceBanner: Bool = false,
        onSelectSignature: @escaping (UIImage) -> Void
    ) {
        self.store = store
        self.showDefaultGuidanceBanner = showDefaultGuidanceBanner
        self.onSelectSignature = onSelectSignature
    }

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
                syncDefaultSignatureIDFromStore()
            }
            .sheet(isPresented: $showCapture) {
                SignatureCaptureView { image, strokeThickness in
                    saveAndUse(image, strokeThickness: strokeThickness)
                }
            }
            .alert("Rename Signature", isPresented: renameAlertIsPresented) {
                TextField("Name", text: $renameDraftName)
                Button("Save") {
                    saveRename()
                }
                Button("Cancel", role: .cancel) {
                    assetPendingRename = nil
                }
            } message: {
                Text("Enter a name for this signature.")
            }
            .alert("Default Signature", isPresented: $showDefaultSignatureError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not save the default signature. Please try again.")
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
                if showDefaultGuidanceBanner {
                    defaultGuidanceBanner
                }

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

    private var defaultGuidanceBanner: some View {
        Text("Choose a default signature for one-tap signing.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("signatureLibraryDefaultGuidanceBanner")
    }

    @ViewBuilder
    private func signatureTile(for asset: SignatureAsset) -> some View {
        let isDefault = defaultSignatureID == asset.id

        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Button {
                    selectAsset(asset)
                } label: {
                    signatureThumbnail(for: asset)
                        .frame(maxWidth: .infinity)
                        .frame(height: 88)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isDefault ? Color.accentColor : Color(.separator),
                                    lineWidth: isDefault ? 2 : 1
                                )
                        }
                }
                .buttonStyle(.plain)

                Button {
                    setDefault(asset)
                } label: {
                    Image(systemName: isDefault ? "star.fill" : "star")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isDefault ? Color.yellow : Color.secondary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel(isDefault ? "Default Signature" : "Set as Default Signature")
                .accessibilityIdentifier("signatureLibraryDefaultButton_\(asset.id.uuidString)")
            }

            HStack(spacing: 4) {
                Text(asset.displayName)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if isDefault {
                    Text("Default Signature")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                        .accessibilityIdentifier("signatureLibraryDefaultBadge_\(asset.id.uuidString)")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .contextMenu {
            Button("Rename") {
                beginRename(for: asset)
            }
            .accessibilityIdentifier("signatureLibraryRenameOption_\(asset.id.uuidString)")

            Button("Delete", role: .destructive) {
                deleteAsset(asset)
            }
            .accessibilityIdentifier("signatureLibraryDeleteOption_\(asset.id.uuidString)")
        }
        .accessibilityIdentifier("signatureLibraryItem_\(asset.id.uuidString)")
    }

    private var renameAlertIsPresented: Binding<Bool> {
        Binding(
            get: { assetPendingRename != nil },
            set: { isPresented in
                if !isPresented {
                    assetPendingRename = nil
                }
            }
        )
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

    private func syncDefaultSignatureIDFromStore() {
        defaultSignatureID = store.defaultSignatureID()
    }

    private func selectAsset(_ asset: SignatureAsset) {
        guard let data = store.loadImageData(for: asset),
              let image = UIImage(data: data) else {
            return
        }
        onSelectSignature(image)
        dismiss()
    }

    private func saveAndUse(_ image: UIImage, strokeThickness: SignatureInkThickness) {
        if let pngData = image.pngData() {
            try? store.saveSignature(
                imageData: pngData,
                sourceType: .drawn,
                strokeThickness: strokeThickness
            )
            reloadSignatures()
        }
        onSelectSignature(image)
        dismiss()
    }

    private func beginRename(for asset: SignatureAsset) {
        assetPendingRename = asset
        renameDraftName = asset.displayName
    }

    private func saveRename() {
        guard let asset = assetPendingRename else { return }
        defer { assetPendingRename = nil }

        do {
            _ = try store.renameSignature(id: asset.id, newDisplayName: renameDraftName)
            reloadSignatures()
        } catch {
            return
        }
    }

    private func deleteAsset(_ asset: SignatureAsset) {
        if defaultSignatureID == asset.id {
            defaultSignatureID = nil
        }
        store.deleteSignature(id: asset.id)
        reloadSignatures()
        syncDefaultSignatureIDFromStore()
    }

    private func setDefault(_ asset: SignatureAsset) {
        let previousDefaultID = defaultSignatureID
        defaultSignatureID = asset.id

        do {
            try store.setDefaultSignature(id: asset.id)
        } catch {
            defaultSignatureID = previousDefaultID
            showDefaultSignatureError = true
        }
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
