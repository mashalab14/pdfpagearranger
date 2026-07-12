import Foundation
import PDFKit

enum DocumentSearchEngine {
    static let searchOptions: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    static func search(
        query: String,
        in document: PDFDocument,
        pages: [PageItem]
    ) -> DocumentSearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return DocumentSearchResults(query: query, matches: [])
        }

        var allMatches: [DocumentSearchMatch] = []
        var globalIndex = 0

        for (displayIndex, pageItem) in pages.enumerated() {
            guard let sourcePage = document.page(at: pageItem.originalPageIndex),
                  let pageCopy = sourcePage.copy() as? PDFPage else {
                continue
            }

            pageCopy.rotation = pageItem.rotation
            let pageMatches = matches(
                on: pageCopy,
                query: trimmed,
                pageItemID: pageItem.id,
                pageNumber: displayIndex + 1
            )

            for match in pageMatches {
                allMatches.append(
                    DocumentSearchMatch(
                        globalIndex: globalIndex,
                        pageItemID: match.pageItemID,
                        pageNumber: match.pageNumber,
                        matchedText: match.matchedText,
                        contextSnippet: match.contextSnippet,
                        normalizedRects: match.normalizedRects
                    )
                )
                globalIndex += 1
            }
        }

        return DocumentSearchResults(query: query, matches: allMatches)
    }

    static func cacheKey(
        query: String,
        document: PDFDocument,
        pages: [PageItem]
    ) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pagesKey = pages.map { "\($0.id.uuidString):\($0.originalPageIndex):\($0.rotation)" }.joined(separator: "|")
        return "\(ObjectIdentifier(document).hashValue)|\(pagesKey)|\(trimmed)"
    }

    private static func matches(
        on page: PDFPage,
        query: String,
        pageItemID: UUID,
        pageNumber: Int
    ) -> [DocumentSearchMatch] {
        let pageText = page.string ?? ""
        let nsText = pageText as NSString
        guard nsText.length > 0 else { return [] }

        var results: [DocumentSearchMatch] = []
        var searchRange = NSRange(location: 0, length: nsText.length)

        while searchRange.location < nsText.length {
            let foundRange = nsText.range(
                of: query,
                options: searchOptions,
                range: searchRange
            )
            guard foundRange.location != NSNotFound else { break }

            guard let selection = page.selection(for: foundRange) else {
                searchRange.location = foundRange.location + max(foundRange.length, 1)
                searchRange.length = nsText.length - searchRange.location
                continue
            }

            let normalizedRects = PDFTextSelectionEngine.normalizedRects(from: selection, page: page)
            guard !normalizedRects.isEmpty else {
                searchRange.location = foundRange.location + max(foundRange.length, 1)
                searchRange.length = nsText.length - searchRange.location
                continue
            }

            let matchedText = nsText.substring(with: foundRange)
            let snippet = contextSnippet(
                in: pageText,
                matchRange: foundRange,
                matchedText: matchedText
            )

            results.append(
                DocumentSearchMatch(
                    globalIndex: 0,
                    pageItemID: pageItemID,
                    pageNumber: pageNumber,
                    matchedText: matchedText,
                    contextSnippet: snippet,
                    normalizedRects: normalizedRects
                )
            )

            searchRange.location = foundRange.location + max(foundRange.length, 1)
            searchRange.length = nsText.length - searchRange.location
        }

        return results
    }

    static func contextSnippet(
        in pageText: String,
        matchRange: NSRange,
        matchedText: String,
        prefixLength: Int = 24,
        suffixLength: Int = 24
    ) -> String {
        guard matchRange.location != NSNotFound else {
            return matchedText
        }

        let nsText = pageText as NSString
        let start = max(0, matchRange.location - prefixLength)
        let end = min(nsText.length, matchRange.location + matchRange.length + suffixLength)
        let snippetRange = NSRange(location: start, length: max(0, end - start))
        var snippet = nsText.substring(with: snippetRange)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        if start > 0 {
            snippet = "…" + snippet
        }
        if end < nsText.length {
            snippet += "…"
        }

        return snippet.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
