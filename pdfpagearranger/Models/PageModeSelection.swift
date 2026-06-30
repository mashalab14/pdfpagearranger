import Foundation

/// Page Mode focus state: none, a user overlay, or native PDF text.
enum PageModeSelection: Equatable {
    case none
    case overlay(UUID)
    case pdfText(PDFTextSelection)

    var selectedOverlayID: UUID? {
        if case .overlay(let id) = self {
            return id
        }
        return nil
    }

    var pdfTextSelection: PDFTextSelection? {
        if case .pdfText(let selection) = self {
            return selection
        }
        return nil
    }
}

struct PDFTextSelection: Equatable {
    let text: String
    /// Selection bounds in Page Mode display coordinates (top-left origin).
    let anchorRect: CGRect
}
