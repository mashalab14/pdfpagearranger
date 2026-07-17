import Foundation
import PDFKit
import UIKit

enum RecentDocumentsStoreError: LocalizedError, Equatable {
    case unreadableSource
    case writeFailed
    case recordNotFound
    case bookmarkUnresolved

    var errorDescription: String? {
        switch self {
        case .unreadableSource:
            return "The document could not be added to Recent Documents."
        case .writeFailed:
            return "Could not update Recent Documents."
        case .recordNotFound:
            return "That recent document is no longer available."
        case .bookmarkUnresolved:
            return "That recent document is no longer available."
        }
    }
}

/// Files-first recent-documents **index**.
///
/// - Externally owned PDFs: security-scoped bookmark + metadata (+ optional thumbnail). No duplicate PDF library.
/// - App-owned PDFs (Create Document today; Drafts later): authoritative file under `appOwned/`.
/// - Identity is document location / stable id — never content fingerprint.
final class RecentDocumentsStore: @unchecked Sendable {
    static let schemaVersion = 2
    static let indexFileName = "index.json"
    static let appOwnedDirectoryName = "appOwned"
    static let legacyFilesDirectoryName = "files"
    static let thumbnailsDirectoryName = "thumbnails"
    static let homePreviewLimit = 5
    static let maxStoredDocuments = 50
    static let thumbnailMaxPixelWidth: CGFloat = 160

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let indexURL: URL
    private let appOwnedDirectory: URL
    private let thumbnailsDirectory: URL
    private let lock = NSLock()

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        indexURL = rootDirectory.appendingPathComponent(Self.indexFileName)
        appOwnedDirectory = rootDirectory.appendingPathComponent(Self.appOwnedDirectoryName, isDirectory: true)
        thumbnailsDirectory = rootDirectory.appendingPathComponent(Self.thumbnailsDirectoryName, isDirectory: true)
        migrateLegacyLibraryIfNeeded()
    }

    static func defaultRootDirectory(fileManager: FileManager = .default) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("RecentDocuments", isDirectory: true)
    }

    static func makeDefault(fileManager: FileManager = .default) throws -> RecentDocumentsStore {
        RecentDocumentsStore(rootDirectory: try defaultRootDirectory(fileManager: fileManager), fileManager: fileManager)
    }

    /// Returns available recent documents, most recent first. Missing/unresolvable entries are pruned.
    func loadAvailableDocuments() -> [RecentDocumentRecord] {
        lock.lock()
        defer { lock.unlock() }
        return loadAndPruneLocked()
    }

    func homePreviewDocuments(limit: Int = RecentDocumentsStore.homePreviewLimit) -> [RecentDocumentRecord] {
        Array(loadAvailableDocuments().prefix(limit))
    }

    func appOwnedFileURL(for record: RecentDocumentRecord) -> URL? {
        guard record.ownership == .appOwned, let relative = record.relativeFilePath else { return nil }
        return rootDirectory.appendingPathComponent(relative)
    }

    func appOwnedFileURL(id: UUID) -> URL {
        appOwnedDirectory.appendingPathComponent("\(id.uuidString).pdf")
    }

    func thumbnailURL(for record: RecentDocumentRecord) -> URL? {
        guard let relative = record.thumbnailRelativePath else { return nil }
        return rootDirectory.appendingPathComponent(relative)
    }

    func loadThumbnailImage(for record: RecentDocumentRecord) -> UIImage? {
        guard let url = thumbnailURL(for: record) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Resolves the authoritative file URL for opening. Caller must stop accessing when finished if `isSecurityScoped`.
    func resolveDocumentURL(for record: RecentDocumentRecord) throws -> (url: URL, isSecurityScoped: Bool) {
        lock.lock()
        defer { lock.unlock() }

        switch record.ownership {
        case .appOwned:
            guard let relative = record.relativeFilePath else {
                throw RecentDocumentsStoreError.recordNotFound
            }
            let url = rootDirectory.appendingPathComponent(relative)
            guard fileManager.fileExists(atPath: url.path) else {
                throw RecentDocumentsStoreError.recordNotFound
            }
            return (url, false)

        case .external:
            if let bookmarkData = record.bookmarkData {
                var isStale = false
                do {
                    let url = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: [.withoutUI],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    if isStale {
                        try refreshBookmarkLocked(for: record.id, url: url)
                    }
                    // On iOS, resolved document-picker bookmarks require startAccessingSecurityScopedResource.
                    return (url, true)
                } catch {
                    // Fall through to path fallback for non-scoped test fixtures.
                }
            }

            if let path = record.lastKnownPath {
                let url = URL(fileURLWithPath: path)
                if fileManager.fileExists(atPath: url.path) {
                    return (url, false)
                }
            }
            throw RecentDocumentsStoreError.bookmarkUnresolved
        }
    }

    /// Records that `sourceURL` became the active document.
    @discardableResult
    func recordActiveDocument(
        sourceURL: URL,
        displayName: String,
        pageCount: Int,
        ownership: RecentDocumentOwnership,
        document: PDFDocument? = nil,
        existingAppOwnedID: UUID? = nil
    ) throws -> RecentDocumentRecord {
        lock.lock()
        defer { lock.unlock() }

        try ensureDirectoriesExistLocked()

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Document" : trimmedName

        switch ownership {
        case .external:
            return try recordExternalLocked(
                sourceURL: sourceURL,
                displayName: resolvedName,
                pageCount: pageCount,
                document: document
            )
        case .appOwned:
            return try recordAppOwnedLocked(
                sourceURL: sourceURL,
                displayName: resolvedName,
                pageCount: pageCount,
                document: document,
                existingID: existingAppOwnedID
            )
        }
    }

    /// Creates a blank US Letter PDF under app-owned storage and indexes it.
    func createAppOwnedBlankDocument(displayName: String = "Untitled") throws -> RecentDocumentRecord {
        lock.lock()
        defer { lock.unlock() }

        try ensureDirectoriesExistLocked()

        let id = UUID()
        let relativeFilePath = "\(Self.appOwnedDirectoryName)/\(id.uuidString).pdf"
        let destination = rootDirectory.appendingPathComponent(relativeFilePath)
        let data = try Self.makeBlankPDFData()
        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            throw RecentDocumentsStoreError.writeFailed
        }

        guard let pdf = PDFDocument(data: data), pdf.pageCount > 0 else {
            try? fileManager.removeItem(at: destination)
            throw RecentDocumentsStoreError.unreadableSource
        }

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? "Untitled" : trimmed
        let thumbnailPath = try writeThumbnailIfPossibleLocked(documentID: id, document: pdf)

        let record = RecentDocumentRecord(
            id: id,
            displayName: resolvedName,
            lastOpenedAt: Date(),
            pageCount: 1,
            kind: .document,
            ownership: .appOwned,
            identityKey: Self.appOwnedIdentityKey(id: id),
            relativeFilePath: relativeFilePath,
            thumbnailRelativePath: thumbnailPath
        )

        var entries = loadIndexLocked()
        entries.insert(record, at: 0)
        try trimAndSaveLocked(&entries)
        return record
    }

    /// Replaces the authoritative app-owned PDF (e.g. after export or compression).
    func replaceAppOwnedFile(id: UUID, withContentsOf sourceURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        var entries = loadIndexLocked()
        guard let index = entries.firstIndex(where: { $0.id == id && $0.ownership == .appOwned }) else {
            throw RecentDocumentsStoreError.recordNotFound
        }

        let destination = appOwnedFileURL(id: id)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: sourceURL, to: destination)
        } catch {
            throw RecentDocumentsStoreError.writeFailed
        }

        var record = entries[index]
        if let document = PDFDocument(url: destination) {
            record.pageCount = document.pageCount
            if let thumb = try? writeThumbnailIfPossibleLocked(documentID: id, document: document) {
                record.thumbnailRelativePath = thumb
            }
        }
        record.lastOpenedAt = Date()
        entries.remove(at: index)
        entries.insert(record, at: 0)
        try saveIndexLocked(entries)
    }

    func removeDocument(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        var entries = loadIndexLocked()
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw RecentDocumentsStoreError.recordNotFound
        }
        let removed = entries.remove(at: index)
        removeSidecarsLocked(for: removed)
        try saveIndexLocked(entries)
    }

    func clear() throws {
        lock.lock()
        defer { lock.unlock() }

        let entries = loadIndexLocked()
        for entry in entries {
            removeSidecarsLocked(for: entry)
        }
        try saveIndexLocked([])
    }

    // MARK: - Identity

    static func externalIdentityKey(for url: URL) -> String {
        let standardized = url.resolvingSymlinksInPath().standardizedFileURL.path
        return "external:\(standardized)"
    }

    static func appOwnedIdentityKey(id: UUID) -> String {
        "appOwned:\(id.uuidString)"
    }

    // MARK: - Private

    private func recordExternalLocked(
        sourceURL: URL,
        displayName: String,
        pageCount: Int,
        document: PDFDocument?
    ) throws -> RecentDocumentRecord {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw RecentDocumentsStoreError.unreadableSource
        }

        let identityKey = Self.externalIdentityKey(for: sourceURL)
        let bookmark = try makeBookmarkLocked(for: sourceURL)
        let path = sourceURL.resolvingSymlinksInPath().standardizedFileURL.path

        var entries = loadIndexLocked()
        if let existingIndex = entries.firstIndex(where: { $0.identityKey == identityKey }) {
            var existing = entries.remove(at: existingIndex)
            existing.lastOpenedAt = Date()
            existing.displayName = displayName
            existing.pageCount = pageCount
            existing.bookmarkData = bookmark
            existing.lastKnownPath = path
            if existing.thumbnailRelativePath == nil {
                existing.thumbnailRelativePath = try writeThumbnailIfPossibleLocked(
                    documentID: existing.id,
                    document: document ?? PDFDocument(url: sourceURL)
                )
            }
            entries.insert(existing, at: 0)
            try saveIndexLocked(entries)
            return existing
        }

        let id = UUID()
        let thumbnailPath = try writeThumbnailIfPossibleLocked(
            documentID: id,
            document: document ?? PDFDocument(url: sourceURL)
        )
        let record = RecentDocumentRecord(
            id: id,
            displayName: displayName,
            lastOpenedAt: Date(),
            pageCount: pageCount,
            kind: .document,
            ownership: .external,
            identityKey: identityKey,
            bookmarkData: bookmark,
            lastKnownPath: path,
            thumbnailRelativePath: thumbnailPath
        )
        entries.insert(record, at: 0)
        try trimAndSaveLocked(&entries)
        return record
    }

    private func recordAppOwnedLocked(
        sourceURL: URL,
        displayName: String,
        pageCount: Int,
        document: PDFDocument?,
        existingID: UUID?
    ) throws -> RecentDocumentRecord {
        var entries = loadIndexLocked()

        if let existingID,
           let existingIndex = entries.firstIndex(where: { $0.id == existingID && $0.ownership == .appOwned }) {
            var existing = entries.remove(at: existingIndex)
            existing.lastOpenedAt = Date()
            existing.displayName = displayName
            existing.pageCount = pageCount
            if existing.thumbnailRelativePath == nil {
                existing.thumbnailRelativePath = try writeThumbnailIfPossibleLocked(
                    documentID: existing.id,
                    document: document ?? PDFDocument(url: sourceURL)
                )
            }
            entries.insert(existing, at: 0)
            try saveIndexLocked(entries)
            return existing
        }

        // Reopening an existing app-owned file by path.
        let sourceIdentity: String? = {
            if sourceURL.path.hasPrefix(appOwnedDirectory.path) {
                let name = sourceURL.deletingPathExtension().lastPathComponent
                if let uuid = UUID(uuidString: name) {
                    return Self.appOwnedIdentityKey(id: uuid)
                }
            }
            return nil
        }()

        if let sourceIdentity,
           let existingIndex = entries.firstIndex(where: { $0.identityKey == sourceIdentity }) {
            var existing = entries.remove(at: existingIndex)
            existing.lastOpenedAt = Date()
            existing.displayName = displayName
            existing.pageCount = pageCount
            entries.insert(existing, at: 0)
            try saveIndexLocked(entries)
            return existing
        }

        let id = existingID ?? UUID()
        let relativeFilePath = "\(Self.appOwnedDirectoryName)/\(id.uuidString).pdf"
        let destination = rootDirectory.appendingPathComponent(relativeFilePath)

        if destination.standardizedFileURL != sourceURL.resolvingSymlinksInPath().standardizedFileURL {
            do {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: sourceURL, to: destination)
            } catch {
                throw RecentDocumentsStoreError.writeFailed
            }
        }

        let thumbnailPath = try writeThumbnailIfPossibleLocked(
            documentID: id,
            document: document ?? PDFDocument(url: destination)
        )
        let record = RecentDocumentRecord(
            id: id,
            displayName: displayName,
            lastOpenedAt: Date(),
            pageCount: pageCount,
            kind: .document,
            ownership: .appOwned,
            identityKey: Self.appOwnedIdentityKey(id: id),
            relativeFilePath: relativeFilePath,
            thumbnailRelativePath: thumbnailPath
        )
        entries.insert(record, at: 0)
        try trimAndSaveLocked(&entries)
        return record
    }

    private func makeBookmarkLocked(for url: URL) throws -> Data {
        // iOS: security-scoped access is restored via startAccessingSecurityScopedResource
        // after resolving; BookmarkCreationOptions.withSecurityScope is macOS-only.
        do {
            return try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw RecentDocumentsStoreError.unreadableSource
        }
    }

    private func refreshBookmarkLocked(for id: UUID, url: URL) throws {
        let entries = loadIndexLocked()
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var mutable = entries
        mutable[index].bookmarkData = try makeBookmarkLocked(for: url)
        mutable[index].lastKnownPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        try saveIndexLocked(mutable)
    }

    private func loadAndPruneLocked() -> [RecentDocumentRecord] {
        var entries = loadIndexLocked()
        var kept: [RecentDocumentRecord] = []
        var removed: [RecentDocumentRecord] = []

        for entry in entries {
            if isAvailableLocked(entry) {
                kept.append(entry)
            } else {
                removed.append(entry)
            }
        }

        for stale in removed {
            removeSidecarsLocked(for: stale)
        }
        if removed.isEmpty == false {
            try? saveIndexLocked(kept)
        }
        return kept.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    private func isAvailableLocked(_ record: RecentDocumentRecord) -> Bool {
        switch record.ownership {
        case .appOwned:
            guard let relative = record.relativeFilePath else { return false }
            return fileManager.fileExists(atPath: rootDirectory.appendingPathComponent(relative).path)
        case .external:
            if let bookmarkData = record.bookmarkData {
                var isStale = false
                if let url = try? URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if didAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    if fileManager.fileExists(atPath: url.path) {
                        return true
                    }
                }
            }
            if let path = record.lastKnownPath {
                return fileManager.fileExists(atPath: path)
            }
            return false
        }
    }

    private struct IndexPayload: Codable {
        var schemaVersion: Int
        var documents: [RecentDocumentRecord]
    }

    private func loadIndexLocked() -> [RecentDocumentRecord] {
        guard fileManager.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let payload = try? decoder.decode(IndexPayload.self, from: data),
           payload.schemaVersion == Self.schemaVersion {
            return payload.documents
        }
        // Legacy v1 (content-fingerprint library) is incompatible with Files-first — discard.
        return []
    }

    private func saveIndexLocked(_ entries: [RecentDocumentRecord]) throws {
        try ensureDirectoriesExistLocked()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let payload = IndexPayload(schemaVersion: Self.schemaVersion, documents: entries)
        do {
            let data = try encoder.encode(payload)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            throw RecentDocumentsStoreError.writeFailed
        }
    }

    private func trimAndSaveLocked(_ entries: inout [RecentDocumentRecord]) throws {
        if entries.count > Self.maxStoredDocuments {
            let removed = entries.suffix(from: Self.maxStoredDocuments)
            entries = Array(entries.prefix(Self.maxStoredDocuments))
            for stale in removed {
                removeSidecarsLocked(for: stale)
            }
        }
        try saveIndexLocked(entries)
    }

    private func ensureDirectoriesExistLocked() throws {
        for directory in [rootDirectory, appOwnedDirectory, thumbnailsDirectory] {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    throw RecentDocumentsStoreError.writeFailed
                }
            }
        }
    }

    private func removeSidecarsLocked(for record: RecentDocumentRecord) {
        if record.ownership == .appOwned, let relative = record.relativeFilePath {
            try? fileManager.removeItem(at: rootDirectory.appendingPathComponent(relative))
        }
        if let thumb = thumbnailURL(for: record) {
            try? fileManager.removeItem(at: thumb)
        }
    }

    private func writeThumbnailIfPossibleLocked(documentID: UUID, document: PDFDocument?) throws -> String? {
        guard let document,
              let page = document.page(at: 0) else {
            return nil
        }

        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = Self.thumbnailMaxPixelWidth / bounds.width
        let size = CGSize(width: Self.thumbnailMaxPixelWidth, height: max(1, bounds.height * scale))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }

        guard let jpeg = image.jpegData(compressionQuality: 0.72) else { return nil }
        let relative = "\(Self.thumbnailsDirectoryName)/\(documentID.uuidString).jpg"
        let url = rootDirectory.appendingPathComponent(relative)
        do {
            try jpeg.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        return relative
    }

    private func migrateLegacyLibraryIfNeeded() {
        let legacyFiles = rootDirectory.appendingPathComponent(Self.legacyFilesDirectoryName, isDirectory: true)
        if fileManager.fileExists(atPath: legacyFiles.path) {
            try? fileManager.removeItem(at: legacyFiles)
        }
        // Drop unreadable/legacy index so the next save uses schema v2.
        if fileManager.fileExists(atPath: indexURL.path),
           let data = try? Data(contentsOf: indexURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if (try? decoder.decode(IndexPayload.self, from: data)) == nil {
                try? fileManager.removeItem(at: indexURL)
            }
        }
    }

    private static func makeBlankPDFData() throws -> Data {
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = NSMutableData()
        var box = mediaBox
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else {
            throw RecentDocumentsStoreError.writeFailed
        }
        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}
