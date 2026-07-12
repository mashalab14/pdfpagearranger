import Foundation

enum ScanDraftPDFGenerationPhase: Equatable, Sendable {
    case idle
    case preparingPages
    case recognizingText
    case generatingPDF
    case openingEditor
}

struct ScanDraftPDFGenerationProgress: Equatable, Sendable {
    var phase: ScanDraftPDFGenerationPhase
    var currentPage: Int
    var totalPages: Int
    var isCancelling: Bool

    static let idle = ScanDraftPDFGenerationProgress(
        phase: .idle,
        currentPage: 0,
        totalPages: 0,
        isCancelling: false
    )

    var label: String {
        switch phase {
        case .idle:
            return "Preparing…"
        case .preparingPages:
            if totalPages > 0 {
                return "Preparing pages: page \(currentPage) of \(totalPages)"
            }
            return "Preparing pages…"
        case .recognizingText:
            if totalPages > 0 {
                return "Recognizing text: page \(currentPage) of \(totalPages)"
            }
            return "Recognizing text…"
        case .generatingPDF:
            if totalPages > 0 {
                return "Creating PDF: page \(currentPage) of \(totalPages)"
            }
            return "Creating PDF…"
        case .openingEditor:
            return "Opening editor…"
        }
    }
}

struct ScanDraftPDFGenerationUpdate: Sendable {
    let phase: ScanDraftPDFGenerationPhase
    let currentPage: Int
    let totalPages: Int
}
