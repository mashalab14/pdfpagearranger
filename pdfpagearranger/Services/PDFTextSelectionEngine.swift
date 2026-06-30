import CoreGraphics
import PDFKit

enum PDFTextSelectionEngine {
    static func makeTextSelection(
        from pdfSelection: PDFSelection,
        page: PDFPage,
        displaySize: CGSize
    ) -> PDFTextSelection? {
        let text = pdfSelection.string?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }

        guard let anchorRect = anchorRect(
            for: pdfSelection,
            page: page,
            displaySize: displaySize
        ) else {
            return nil
        }

        return PDFTextSelection(text: text, anchorRect: anchorRect)
    }

    static func anchorRect(
        for pdfSelection: PDFSelection,
        page: PDFPage,
        displaySize: CGSize
    ) -> CGRect? {
        guard displaySize.width > 0, displaySize.height > 0 else { return nil }

        let mediaBox = page.bounds(for: .mediaBox)
        guard mediaBox.width > 0, mediaBox.height > 0 else { return nil }

        let selectionBounds = pdfSelection.bounds(for: page)
        guard !selectionBounds.isNull, !selectionBounds.isEmpty else { return nil }

        let scaleX = displaySize.width / mediaBox.width
        let scaleY = displaySize.height / mediaBox.height

        let x = (selectionBounds.minX - mediaBox.minX) * scaleX
        let width = selectionBounds.width * scaleX
        let height = selectionBounds.height * scaleY
        let y = (mediaBox.maxY - selectionBounds.maxY) * scaleY

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
