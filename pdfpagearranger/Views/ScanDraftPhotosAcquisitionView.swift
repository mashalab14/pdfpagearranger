import SwiftUI
import PhotosUI

struct ScanDraftPhotosAcquisitionView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    @State private var isPhotosPickerPresented = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if let progress = sessionViewModel.photosImportProgress {
                    ProgressView(progress.label)
                } else if sessionViewModel.isImportingPhotos {
                    ProgressView("Importing photos…")
                } else {
                    Text("Choose one or more photos to import.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Import Photos") {
                        presentPhotosPickerIfNeeded()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sessionViewModel.isImportingPhotos)
                    .accessibilityLabel("Import Photos")
                    .accessibilityHint("Opens the system photo picker to import one or more images.")

                    if sessionViewModel.isImportingPhotos {
                        Button("Cancel Import", role: .cancel) {
                            sessionViewModel.cancelPhotosImport()
                        }
                    } else {
                        Button("Cancel", role: .cancel) {
                            sessionViewModel.handlePhotosPickerCancelled()
                        }
                    }
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
        }
        .navigationTitle("Import Photos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presentPhotosPickerIfNeeded()
        }
        .photosPicker(
            isPresented: $isPhotosPickerPresented,
            selection: $selectedPhotoItems,
            maxSelectionCount: ScanPhotosImportLimits.maxSelectionCount,
            matching: .images
        )
        .onChange(of: isPhotosPickerPresented) { _, isPresented in
            guard !isPresented else { return }
            guard selectedPhotoItems.isEmpty else { return }
            guard !sessionViewModel.isImportingPhotos else { return }
            sessionViewModel.handlePhotosPickerCancelled()
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            let items = newItems
            selectedPhotoItems = []
            isPhotosPickerPresented = false
            Task {
                await sessionViewModel.handlePhotosSelection(items)
            }
        }
        .alert(
            "Import Error",
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

    private func presentPhotosPickerIfNeeded() {
        guard !sessionViewModel.isImportingPhotos else { return }
        guard !sessionViewModel.photosSelectionHandled else { return }
        isPhotosPickerPresented = true
    }
}
