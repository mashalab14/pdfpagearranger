import Foundation

/// Opens a generated PDF in the existing editor session.
/// Reuses `PDFEditorViewModel.importPDF` — no parallel document-opening path.
/// Scan/Photo outputs are app-created documents (app-owned), not Files references.
@MainActor
struct ScanEditorHandoffService {
    func handoff(pdfURL: URL, to editorViewModel: PDFEditorViewModel) async throws {
        await editorViewModel.importPDF(from: pdfURL, ownership: .appOwned)
        if let errorMessage = editorViewModel.errorMessage {
            throw ScanDraftError.editorHandoffFailure
        }
        guard editorViewModel.hasDocument else {
            throw ScanDraftError.editorHandoffFailure
        }
    }
}
