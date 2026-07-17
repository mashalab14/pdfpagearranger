import CryptoKit
import Foundation
import PDFKit
import UIKit

enum RecentDocumentsStoreError: LocalizedError, Equatable {
    case unreadableSource
    case writeFailed
    case recordNotFound

    var errorDescription: String? {
        switch self {
        case .unreadableSource:
            return "The document could not be saved to Recent Documents."
        case .writeFailed:
            return "Could not update Recent Documents."
        case .recordNotFound:
            return "That recent document is no longer available."
        }
    }
}

/// Persistent recent-documents library independent of the live editor session.
///
/// Stores durable PDF copies under Application Support so entries survive
/// closing the working `PDFImports` temp file. Designed so a future Drafts
/// kind can share the same index without a major refactor.
final class RecentDocumentsStore: @unchecked Sendable {
    static let indexFileName = "index.json"
    static let filesDirectoryName = "files"
    static let thumbnailsDirectoryName = "thumbnails"
    static let homePreviewLimit = 5
    static let maxStoredDocuments = 50
    static let thumbnailMaxPixelWidth: CGFloat = 160

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let indexURL: URL
    private let filesDirectory: URL
    private let thumbnailsDirectory: URL
    private let lock = NSLock()

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        indexURL = rootDirectory.appendingPathComponent(Self.indexFileName)
        filesDirectory = rootDirectory.appendingPathComponent(Self.filesDirectoryName, isDirectory: true)
        thumbnailsDirectory = rootDirectory.appendingPathComponent(Self.thumbnailsDirectoryName, isDirectory: true)
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

    /// Returns available recent documents, most recent first. Missing files are pruned.
    func loadAvailableDocuments() -> [RecentDocumentRecord] {
        lock.lock()
        defer { lock.unlock() }
        return loadAndPruneLocked()
    }

    func homePreviewDocuments(limit: Int = RecentDocumentsStore.homePreviewLimit) -> [RecentDocumentRecord] {
        Array(loadAvailableDocuments().prefix(limit))
    }

    func fileURL(for record: RecentDocumentRecord) -> URL {
        rootDirectory.appendingPathComponent(record.relativeFilePath)
    }

    func thumbnailURL(for record: RecentDocumentRecord) -> URL? {
        guard let relative = record.thumbnailRelativePath else { return nil }
        return rootDirectory.appendingPathComponent(relative)
    }

    func loadThumbnailImage(for record: RecentDocumentRecord) -> UIImage? {
        guard let url = thumbnailURL(for: record) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Records a successfully opened or created PDF. Deduplicates by content fingerprint.
    @discardableResult
    func recordOpenedDocument(
        sourceFileURL: URL,
        displayName: String,
        pageCount: Int,
        document: PDFDocument? = nil
    ) throws -> RecentDocumentRecord {
        lock.lock()
        defer { lock.unlock() }

        try ensureDirectoriesExistLocked()

        guard let data = try? Data(contentsOf: sourceFileURL), !data.isEmpty else {
            throw RecentDocumentsStoreError.unreadableSource
        }

        let fingerprint = Self.fingerprint(for: data)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Document" : trimmedName

        var entries = loadIndexLocked()
        if let existingIndex = entries.firstIndex(where: { $0.contentFingerprint == fingerprint }) {
            var existing = entries.remove(at: existingIndex)
            existing.lastOpenedAt = Date()
            existing.displayName = resolvedName
            existing.pageCount = pageCount
            try refreshStoredFileLocked(for: existing, data: data)
            if existing.thumbnailRelativePath == nil {
                existing.thumbnailRelativePath = try writeThumbnailIfPossibleLocked(
                    documentID: existing.id,
                    document: document ?? PDFDocument(data: data)
                )
            }
            entries.insert(existing, at: 0)
            try saveIndexLocked(entries)
            return existing
        }

        let id = UUID()
        let relativeFilePath = "\(Self.filesDirectoryName)/\(id.uuidString).pdf"
        let destination = rootDirectory.appendingPathComponent(relativeFilePath)
        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            throw RecentDocumentsStoreError.writeFailed
        }

        let thumbnailPath = try writeThumbnailIfPossibleLocked(
            documentID: id,
            document: document ?? PDFDocument(data: data)
        )

        let record = RecentDocumentRecord(
            id: id,
            displayName: resolvedName,
            lastOpenedAt: Date(),
            relativeFilePath: relativeFilePath,
            contentFingerprint: fingerprint,
            pageCount: pageCount,
            kind: .document,
            thumbnailRelativePath: thumbnailPath
        )
        entries.insert(record, at: 0)
        if entries.count > Self.maxStoredDocuments {
            let removed = entries.suffix(from: Self.maxStoredDocuments)
            entries = Array(entries.prefix(Self.maxStoredDocuments))
            for stale in removed {
                removeFilesLocked(for: stale)
            }
        }
        try saveIndexLocked(entries)
        return record
    }

    func removeDocument(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        var entries = loadIndexLocked()
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw RecentDocumentsStoreError.recordNotFound
        }
        let removed = entries.remove(at: index)
        removeFilesLocked(for: removed)
        try saveIndexLocked(entries)
    }

    func clear() throws {
        lock.lock()
        defer { lock.unlock() }

        let entries = loadIndexLocked()
        for entry in entries {
            removeFilesLocked(for: entry)
        }
        try saveIndexLocked([])
    }

    // MARK: - Private

    private func loadAndPruneLocked() -> [RecentDocumentRecord] {
        var entries = loadIndexLocked()
        let before = entries
        entries = entries.filter { fileManager.fileExists(atPath: fileURL(for: $0).path) }
        let missing = before.filter { entry in !entries.contains(where: { $0.id == entry.id }) }
        for stale in missing {
            removeFilesLocked(for: stale)
        }
        if missing.isEmpty == false {
            try? saveIndexLocked(entries)
        }
        return entries.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    private func loadIndexLocked() -> [RecentDocumentRecord] {
        guard fileManager.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([RecentDocumentRecord].self, from: data)) ?? []
    }

    private func saveIndexLocked(_ entries: [RecentDocumentRecord]) throws {
        try ensureDirectoriesExistLocked()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(entries)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            throw RecentDocumentsStoreError.writeFailed
        }
    }

    private func ensureDirectoriesExistLocked() throws {
        for directory in [rootDirectory, filesDirectory, thumbnailsDirectory] {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    throw RecentDocumentsStoreError.writeFailed
                }
            }
        }
    }

    private func refreshStoredFileLocked(for record: RecentDocumentRecord, data: Data) throws {
        let destination = fileURL(for: record)
        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            throw RecentDocumentsStoreError.writeFailed
        }
    }

    private func removeFilesLocked(for record: RecentDocumentRecord) {
        try? fileManager.removeItem(at: fileURL(for: record))
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

    static func fingerprint(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
