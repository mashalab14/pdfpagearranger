import Foundation

struct DocumentSearchMatch: Identifiable, Equatable, Sendable {
    let id: UUID
    let globalIndex: Int
    let pageItemID: UUID
    let pageNumber: Int
    let matchedText: String
    let contextSnippet: String
    let normalizedRects: [PageNormalizedRect]

    init(
        id: UUID = UUID(),
        globalIndex: Int,
        pageItemID: UUID,
        pageNumber: Int,
        matchedText: String,
        contextSnippet: String,
        normalizedRects: [PageNormalizedRect]
    ) {
        self.id = id
        self.globalIndex = globalIndex
        self.pageItemID = pageItemID
        self.pageNumber = pageNumber
        self.matchedText = matchedText
        self.contextSnippet = contextSnippet
        self.normalizedRects = normalizedRects
    }
}

struct DocumentSearchResults: Equatable, Sendable {
    var query: String = ""
    var matches: [DocumentSearchMatch] = []

    var isEmptyQuery: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasMatches: Bool {
        !matches.isEmpty
    }

    var matchCount: Int {
        matches.count
    }

    func matches(on pageItemID: UUID) -> [DocumentSearchMatch] {
        matches.filter { $0.pageItemID == pageItemID }
    }

    func groupedByPage() -> [(pageNumber: Int, pageItemID: UUID, matches: [DocumentSearchMatch])] {
        var order: [UUID] = []
        var groups: [UUID: (pageNumber: Int, matches: [DocumentSearchMatch])] = [:]

        for match in matches {
            if groups[match.pageItemID] == nil {
                order.append(match.pageItemID)
                groups[match.pageItemID] = (match.pageNumber, [])
            }
            groups[match.pageItemID]?.matches.append(match)
        }

        return order.compactMap { pageItemID in
            guard let group = groups[pageItemID] else { return nil }
            return (group.pageNumber, pageItemID, group.matches)
        }
    }
}

struct DocumentSearchState: Equatable, Sendable {
    var isActive = false
    var results = DocumentSearchResults()
    var currentMatchIndex: Int?

    var currentMatch: DocumentSearchMatch? {
        guard let currentMatchIndex,
              results.matches.indices.contains(currentMatchIndex) else {
            return nil
        }
        return results.matches[currentMatchIndex]
    }

    var positionLabel: String? {
        guard let currentMatchIndex, results.hasMatches else { return nil }
        return "\(currentMatchIndex + 1) of \(results.matchCount)"
    }
}

enum SearchHighlightStyle {
    static let inactiveFill = SignatureInkRGBA(red: 1, green: 0.72, blue: 0.2, alpha: 1)
    static let activeFill = SignatureInkRGBA(red: 1, green: 0.45, blue: 0.05, alpha: 1)
    static let inactiveOpacity: CGFloat = 0.35
    static let activeOpacity: CGFloat = 0.55
}
