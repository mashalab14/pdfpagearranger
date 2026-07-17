import Foundation

/// Kind of entry in the recent list. Drafts can be added later without reshaping persistence.
enum RecentDocumentKind: String, Codable, Equatable, Sendable {
    case document
}

/// Persisted metadata for a recently opened or created PDF document.
struct RecentDocumentRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var displayName: String
    var lastOpenedAt: Date
    /// Path relative to the Recent Documents store root (e.g. `files/{id}.pdf`).
    var relativeFilePath: String
    /// Content fingerprint used for duplicate detection.
    var contentFingerprint: String
    var pageCount: Int
    var kind: RecentDocumentKind
    /// Optional thumbnail path relative to the store root.
    var thumbnailRelativePath: String?

    init(
        id: UUID = UUID(),
        displayName: String,
        lastOpenedAt: Date = Date(),
        relativeFilePath: String,
        contentFingerprint: String,
        pageCount: Int,
        kind: RecentDocumentKind = .document,
        thumbnailRelativePath: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.lastOpenedAt = lastOpenedAt
        self.relativeFilePath = relativeFilePath
        self.contentFingerprint = contentFingerprint
        self.pageCount = pageCount
        self.kind = kind
        self.thumbnailRelativePath = thumbnailRelativePath
    }
}
