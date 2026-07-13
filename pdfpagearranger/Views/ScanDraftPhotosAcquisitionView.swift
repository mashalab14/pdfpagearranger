import SwiftUI

/// Host for add-pages photo imports and post-selection import progress. The Photos picker is presented from `ContentView`.
struct ScanDraftPhotosAcquisitionView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .accessibilityHidden(true)

            if sessionViewModel.isImportingPhotos {
                if let progress = sessionViewModel.photosImportProgress {
                    ProgressView(progress.label)
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("photosImportProgress")
                } else {
                    ProgressView("Importing photos…")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("photosImportProgress")
                }
            }
        }
        .navigationBarHidden(true)
    }
}
