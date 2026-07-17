import Foundation

/// Kind of entry in the recent index. Drafts can be added later without reshaping persistence.
enum RecentDocumentKind: String, Codable, Equatable, Sendable {
    case document
    /// Reserved for a future Drafts surface; not used by the current product.
    case draft
}

/// Who owns the authoritative PDF bytes for a recent entry.
///
/// - `external`: Files-first reference (bookmark / path). The app does not own a second copy.
/// - `appOwned`: Create Document (and future Drafts) — the app stores the authoritative file.
enum RecentDocumentOwnership: String, Codable, Equatable, Sendable {
    case external
    case appOwned
}

/// Persisted metadata for a recently opened or created PDF document.
///
/// Recent Documents is an **index**, not an application-managed library of external PDFs.
struct RecentDocumentRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var displayName: String
    var lastOpenedAt: Date
    var pageCount: Int
    var kind: RecentDocumentKind
    var ownership: RecentDocumentOwnership
    /// Stable document identity (not a content hash). Same file → same key; identical bytes at different paths → different keys.
    var identityKey: String
    /// Security-scoped (or plain) bookmark for externally owned documents.
    var bookmarkData: Data?
    /// Last known absolute path for external documents (fallback / diagnostics).
    var lastKnownPath: String?
    /// Path relative to the Recent Documents store root for **app-owned** PDFs only (e.g. `appOwned/{id}.pdf`).
    var relativeFilePath: String?
    /// Optional thumbnail path relative to the store root.
    var thumbnailRelativePath: String?

    init(
        id: UUID = UUID(),
        displayName: String,
        lastOpenedAt: Date = Date(),
        pageCount: Int,
        kind: RecentDocumentKind = .document,
        ownership: RecentDocumentOwnership,
        identityKey: String,
        bookmarkData: Data? = nil,
        lastKnownPath: String? = nil,
        relativeFilePath: String? = nil,
        thumbnailRelativePath: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.lastOpenedAt = lastOpenedAt
        self.pageCount = pageCount
        self.kind = kind
        self.ownership = ownership
        self.identityKey = identityKey
        self.bookmarkData = bookmarkData
        self.lastKnownPath = lastKnownPath
        self.relativeFilePath = relativeFilePath
        self.thumbnailRelativePath = thumbnailRelativePath
    }
}

/// Origin of the active editor session, used for save/write-back and Recent recording.
enum ActiveDocumentOrigin: Equatable, Sendable {
    case external(identityKey: String)
    case appOwned(id: UUID)
}
