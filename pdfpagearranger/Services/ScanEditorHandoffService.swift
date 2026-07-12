import Foundation

/// Opens a generated PDF in the existing editor session.
/// Reuses `PDFEditorViewModel.importPDF(from:)` — no parallel document-opening path.
@MainActor
struct ScanEditorHandoffService {
    func handoff(pdfURL: URL, to editorViewModel: PDFEditorViewModel) async throws {
        await editorViewModel.importPDF(from: pdfURL)
        if let errorMessage = editorViewModel.errorMessage {
            throw ScanDraftError.editorHandoffFailure
        }
        guard editorViewModel.hasDocument else {
            throw ScanDraftError.editorHandoffFailure
        }
    }
}
