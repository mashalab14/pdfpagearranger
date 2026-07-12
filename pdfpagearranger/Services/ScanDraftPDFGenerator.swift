import Foundation

/// Future PDF assembly from ordered processed page images.
protocol ScanDraftPDFGenerating: Sendable {
    func generatePDF(
        from pages: [ScanDraftPage],
        sessionDirectory: URL,
        displayName: String
    ) async throws -> URL
}

/// Placeholder implementation until page rendering and PDF assembly are built.
struct UnimplementedScanDraftPDFGenerator: ScanDraftPDFGenerating {
    func generatePDF(
        from pages: [ScanDraftPage],
        sessionDirectory: URL,
        displayName: String
    ) async throws -> URL {
        guard !pages.isEmpty else {
            throw ScanDraftError.emptyDraft
        }
        throw ScanDraftError.pdfGenerationFailure
    }
}
