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

        let normalizedRects = normalizedRects(from: pdfSelection, page: page)
        guard !normalizedRects.isEmpty else { return nil }

        return PDFTextSelection(
            text: text,
            anchorRect: anchorRect,
            normalizedRects: normalizedRects
        )
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

    static func normalizedRects(from pdfSelection: PDFSelection, page: PDFPage) -> [PageNormalizedRect] {
        let mediaBox = page.bounds(for: .mediaBox)
        guard mediaBox.width > 0, mediaBox.height > 0 else { return [] }

        let lineSelections = pdfSelection.selectionsByLine()
        let selections = lineSelections.isEmpty ? [pdfSelection] : lineSelections

        return selections.compactMap { lineSelection in
            let bounds = lineSelection.bounds(for: page)
            guard !bounds.isNull, !bounds.isEmpty else { return nil }

            let x = (bounds.minX - mediaBox.minX) / mediaBox.width
            let width = bounds.width / mediaBox.width
            let height = bounds.height / mediaBox.height
            let y = (mediaBox.maxY - bounds.maxY) / mediaBox.height

            return AnnotationGeometryEngine.clampNormalizedRect(
                PageNormalizedRect(x: x, y: y, width: width, height: height)
            )
        }
    }
}
