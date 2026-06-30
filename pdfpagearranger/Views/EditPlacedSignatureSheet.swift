import SwiftUI

struct EditPlacedSignatureSheet: View {
    @Environment(\.dismiss) private var dismiss

    let overlayID: UUID
    let pageItemID: UUID
    @Bindable var viewModel: PDFEditorViewModel
    let libraryStore: SignatureLibraryStore

    @State private var selectedColor: SignatureInkColor
    @State private var selectedThickness: SignatureInkThickness
    @State private var saveErrorMessage: String?

    init(
        overlayID: UUID,
        pageItemID: UUID,
        overlay: PageObject,
        viewModel: PDFEditorViewModel,
        libraryStore: SignatureLibraryStore
    ) {
        self.overlayID = overlayID
        self.pageItemID = pageItemID
        self._viewModel = Bindable(wrappedValue: viewModel)
        self.libraryStore = libraryStore
        _selectedColor = State(initialValue: overlay.effectiveSignatureInkColor)
        _selectedThickness = State(initialValue: overlay.effectiveSignatureStrokeThickness)
    }

    private var overlay: PageObject? {
        viewModel.overlayObjects(for: pageItemID).first(where: { $0.id == overlayID })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SignatureInkColorPicker(selectedColor: $selectedColor)
                } header: {
                    Text("Color")
                }

                Section {
                    SignatureInkThicknessPicker(selectedThickness: $selectedThickness)
                } header: {
                    Text("Thickness")
                }

                if overlay?.signatureAppearanceDiffersFromBaseline == true {
                    Section {
                        Button("Reset") {
                            viewModel.resetPlacedSignatureAppearance(
                                overlayID: overlayID,
                                pageItemID: pageItemID
                            )
                            syncSelectionFromOverlay()
                        }
                        .accessibilityIdentifier("editSignatureResetButton")

                        if overlay?.canSavePlacedSignatureToLibrary == true {
                            Button("Save to Library") {
                                saveToLibrary()
                            }
                            .accessibilityIdentifier("editSignatureSaveToLibraryButton")
                        }
                    }
                }
            }
            .navigationTitle("Edit Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("editSignatureDoneButton")
                }
            }
            .accessibilityIdentifier("editPlacedSignatureSheet")
            .alert("Could Not Save Signature", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: selectedColor) { _, newValue in
            applyAppearance(color: newValue, thickness: selectedThickness)
        }
        .onChange(of: selectedThickness) { _, newValue in
            applyAppearance(color: selectedColor, thickness: newValue)
        }
        .onChange(of: overlay?.effectiveSignatureInkColor) { _, _ in
            syncSelectionFromOverlay()
        }
        .onChange(of: overlay?.effectiveSignatureStrokeThickness) { _, _ in
            syncSelectionFromOverlay()
        }
    }

    private func applyAppearance(color: SignatureInkColor, thickness: SignatureInkThickness) {
        viewModel.updatePlacedSignatureAppearance(
            overlayID: overlayID,
            pageItemID: pageItemID,
            inkColor: color,
            strokeThickness: thickness
        )
    }

    private func syncSelectionFromOverlay() {
        guard let overlay else { return }
        selectedColor = overlay.effectiveSignatureInkColor
        selectedThickness = overlay.effectiveSignatureStrokeThickness
    }

    private func saveToLibrary() {
        do {
            _ = try viewModel.savePlacedSignatureToLibrary(
                overlayID: overlayID,
                pageItemID: pageItemID,
                store: libraryStore
            )
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

struct SignatureInkColorPicker: View {
    @Binding var selectedColor: SignatureInkColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(SignatureInkColor.allCases) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color.displayColor)
                                .frame(width: 30, height: 30)

                            if selectedColor == color {
                                Circle()
                                    .strokeBorder(Color.accentColor, lineWidth: 3)
                                    .frame(width: 38, height: 38)

                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.rawValue)
                    .accessibilityIdentifier(color.accessibilityIdentifier)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct SignatureInkThicknessPicker: View {
    @Binding var selectedThickness: SignatureInkThickness

    var body: some View {
        Picker("Thickness", selection: $selectedThickness) {
            ForEach(SignatureInkThickness.allCases) { thickness in
                Text(thickness.title).tag(thickness)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("editSignatureThicknessPicker")
    }
}
