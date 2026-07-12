import Foundation

/// Page Mode focus state: none, overlay, native PDF text, or page annotations.
enum PageModeSelection: Equatable {
    case none
    case overlay(UUID)
    case pdfText(PDFTextSelection)
    case highlight(UUID)
    case drawing(UUID)
    case stickyNote(UUID)
    case textComment(UUID)

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

    var selectedAnnotationID: UUID? {
        switch self {
        case .highlight(let id), .drawing(let id), .stickyNote(let id), .textComment(let id):
            return id
        default:
            return nil
        }
    }

    var selectedAnnotationKind: PageAnnotationKind? {
        switch self {
        case .highlight: return .highlight
        case .drawing: return .drawing
        case .stickyNote: return .stickyNote
        case .textComment: return .textComment
        default: return nil
        }
    }
}

struct PDFTextSelection: Equatable {
    let text: String
    /// Selection bounds in Page Mode display coordinates (top-left origin).
    let anchorRect: CGRect
    /// Line rectangles in unrotated normalized page coordinates (top-left origin).
    let normalizedRects: [PageNormalizedRect]
}
