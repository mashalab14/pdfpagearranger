import SwiftUI

/// Host for add-pages camera scans and post-scan import progress. VisionKit is presented from `ContentView`.
struct ScanDraftCameraAcquisitionView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .accessibilityHidden(true)

            if sessionViewModel.isImportingCameraScan {
                ProgressView("Importing scanned pages…")
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("scanImportProgress")
            }
        }
        .navigationBarHidden(true)
    }
}
