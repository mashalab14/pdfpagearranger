import SwiftUI

struct ScanDraftPDFGenerationProgressView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(sessionViewModel.pdfGenerationProgress.label)
                .accessibilityLabel(sessionViewModel.pdfGenerationProgress.label)

            if sessionViewModel.isGeneratingPDF {
                Button("Cancel") {
                    sessionViewModel.cancelPDFGeneration()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel PDF Generation")
                .accessibilityIdentifier("cancelPDFGenerationButton")
            }
        }
        .padding()
        .navigationTitle("Create PDF")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(sessionViewModel.isGeneratingPDF)
    }
}
