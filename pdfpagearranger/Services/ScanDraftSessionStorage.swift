import Foundation
import UIKit

/// File-backed storage for scan draft sessions.
///
/// Lifecycle:
/// - Each `ScanDraftDocument.id` maps to `tmp/ScanDraftSessions/{id}/`.
/// - Original working copies live in `originals/` (Photos library originals are never modified).
/// - Processed outputs live in `processed/`.
/// - Thumbnails live in `thumbnails/`.
/// - `deleteSession` removes the entire session directory when the draft is discarded.
final class ScanDraftSessionStorage: Sendable {
    static let sessionsDirectoryName = "ScanDraftSessions"
    static let originalsDirectoryName = "originals"
    static let processedDirectoryName = "processed"
    static let thumbnailsDirectoryName = "thumbnails"

    private let fileManager: FileManager
    private let sessionsRoot: URL

    init(fileManager: FileManager = .default, sessionsRoot: URL? = nil) {
        self.fileManager = fileManager
        if let sessionsRoot {
            self.sessionsRoot = sessionsRoot
        } else {
            self.sessionsRoot = fileManager.temporaryDirectory
                .appendingPathComponent(Self.sessionsDirectoryName, isDirectory: true)
        }
    }

    func sessionDirectory(for documentID: UUID) -> URL {
        sessionsRoot.appendingPathComponent(documentID.uuidString, isDirectory: true)
    }

    @discardableResult
    func createSessionDirectory(for documentID: UUID) throws -> URL {
        let directory = sessionDirectory(for: documentID)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        for subdirectory in [
            Self.originalsDirectoryName,
            Self.processedDirectoryName,
            Self.thumbnailsDirectoryName
        ] {
            try fileManager.createDirectory(
                at: directory.appendingPathComponent(subdirectory, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        return directory
    }

    func importOriginalImage(
        data: Data,
        pageID: UUID,
        sourceType: ScanPageSource,
        sessionDirectory: URL,
        fileExtension: String = "jpg"
    ) throws -> ScanDraftPage {
        guard !data.isEmpty else {
            throw ScanDraftError.unsupportedImageData
        }
        guard let image = UIImage(data: data) else {
            throw ScanDraftError.imageCannotBeLoaded
        }

        let relativePath = "\(Self.originalsDirectoryName)/\(pageID.uuidString).\(fileExtension)"
        let destinationURL = sessionDirectory.appendingPathComponent(relativePath)
        let parent = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            if (error as NSError).domain == NSPOSIXErrorDomain,
               (error as NSError).code == Int(POSIXErrorCode.ENOSPC.rawValue) {
                throw ScanDraftError.insufficientStorage
            }
            throw ScanDraftError.temporaryFileWriteFailure
        }

        return ScanDraftPage(
            id: pageID,
            sourceType: sourceType,
            originalImage: ScanDraftImageReference(relativePath: relativePath),
            originalPixelSize: image.size
        )
    }

    func writeProcessedImage(
        data: Data,
        pageID: UUID,
        sessionDirectory: URL,
        fileExtension: String = "jpg"
    ) throws -> ScanDraftImageReference {
        let relativePath = "\(Self.processedDirectoryName)/\(pageID.uuidString).\(fileExtension)"
        let destinationURL = sessionDirectory.appendingPathComponent(relativePath)
        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            throw ScanDraftError.temporaryFileWriteFailure
        }
        return ScanDraftImageReference(relativePath: relativePath)
    }

    func writeThumbnailImage(
        data: Data,
        pageID: UUID,
        sessionDirectory: URL,
        fileExtension: String = "jpg"
    ) throws -> ScanDraftImageReference {
        let relativePath = "\(Self.thumbnailsDirectoryName)/\(pageID.uuidString).\(fileExtension)"
        let destinationURL = sessionDirectory.appendingPathComponent(relativePath)
        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            throw ScanDraftError.temporaryFileWriteFailure
        }
        return ScanDraftImageReference(relativePath: relativePath)
    }

    func loadImageData(at reference: ScanDraftImageReference, sessionDirectory: URL) throws -> Data {
        let url = reference.url(in: sessionDirectory)
        guard fileManager.fileExists(atPath: url.path) else {
            throw ScanDraftError.imageCannotBeLoaded
        }
        return try Data(contentsOf: url)
    }

    func deleteSession(for documentID: UUID) throws {
        let directory = sessionDirectory(for: documentID)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    func deleteOriginalImages(
        _ references: [ScanDraftImageReference],
        sessionDirectory: URL
    ) {
        for reference in references {
            let url = reference.url(in: sessionDirectory)
            try? fileManager.removeItem(at: url)
        }
    }

    func sessionExists(for documentID: UUID) -> Bool {
        fileManager.fileExists(atPath: sessionDirectory(for: documentID).path)
    }
}
