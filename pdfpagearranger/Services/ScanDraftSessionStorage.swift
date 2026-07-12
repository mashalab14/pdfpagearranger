import Foundation
import PDFKit
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
    static let generatedDirectoryName = "generated"

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
            Self.thumbnailsDirectoryName,
            Self.generatedDirectoryName
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
            if (error as NSError).domain == NSPOSIXErrorDomain,
               (error as NSError).code == Int(POSIXErrorCode.ENOSPC.rawValue) {
                throw ScanDraftError.insufficientStorage
            }
            throw ScanDraftError.temporaryFileWriteFailure
        }
        return ScanDraftImageReference(relativePath: relativePath)
    }

    @discardableResult
    func replaceProcessedImage(
        data: Data,
        pageID: UUID,
        sessionDirectory: URL,
        previousReference: ScanDraftImageReference?,
        fileExtension: String = "jpg"
    ) throws -> ScanDraftImageReference {
        let stagingRelativePath = "\(Self.processedDirectoryName)/\(pageID.uuidString).staging.\(fileExtension)"
        let finalRelativePath = "\(Self.processedDirectoryName)/\(pageID.uuidString).\(fileExtension)"
        let stagingURL = sessionDirectory.appendingPathComponent(stagingRelativePath)
        let finalURL = sessionDirectory.appendingPathComponent(finalRelativePath)

        do {
            try data.write(to: stagingURL, options: .atomic)
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            try fileManager.moveItem(at: stagingURL, to: finalURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if (error as NSError).domain == NSPOSIXErrorDomain,
               (error as NSError).code == Int(POSIXErrorCode.ENOSPC.rawValue) {
                throw ScanDraftError.insufficientStorage
            }
            throw ScanDraftError.temporaryFileWriteFailure
        }

        if let previousReference, previousReference.relativePath != finalRelativePath {
            let previousURL = previousReference.url(in: sessionDirectory)
            try? fileManager.removeItem(at: previousURL)
        }

        return ScanDraftImageReference(relativePath: finalRelativePath)
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

    func deleteGeneratedPDFStaging(in sessionDirectory: URL) {
        let generatedDirectory = sessionDirectory
            .appendingPathComponent(Self.generatedDirectoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: generatedDirectory.path) else { return }

        if let files = try? fileManager.contentsOfDirectory(
            at: generatedDirectory,
            includingPropertiesForKeys: nil
        ) {
            for file in files where file.lastPathComponent.hasSuffix(".staging.pdf") {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    func writeGeneratedPDF(
        _ document: PDFDocument,
        sessionDirectory: URL,
        fileName: String
    ) throws -> URL {
        let generatedDirectory = sessionDirectory
            .appendingPathComponent(Self.generatedDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)

        let stagingURL = generatedDirectory.appendingPathComponent("\(fileName).staging.pdf")
        let finalURL = generatedDirectory.appendingPathComponent("\(fileName).pdf")

        try? fileManager.removeItem(at: stagingURL)

        guard document.write(to: stagingURL) else {
            try? fileManager.removeItem(at: stagingURL)
            throw ScanDraftError.pdfGenerationFailure
        }

        do {
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            try fileManager.moveItem(at: stagingURL, to: finalURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if (error as NSError).domain == NSPOSIXErrorDomain,
               (error as NSError).code == Int(POSIXErrorCode.ENOSPC.rawValue) {
                throw ScanDraftError.insufficientStorage
            }
            throw ScanDraftError.pdfGenerationFailure
        }

        return finalURL
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

    func deletePageAssets(for page: ScanDraftPage, sessionDirectory: URL) {
        var references = [page.originalImage]
        if let processedImage = page.processedImage {
            references.append(processedImage)
        }
        if let thumbnailImage = page.thumbnailImage {
            references.append(thumbnailImage)
        }
        deleteOriginalImages(references, sessionDirectory: sessionDirectory)
    }

    func duplicatePageAssets(
        from sourcePage: ScanDraftPage,
        newPageID: UUID,
        sessionDirectory: URL
    ) throws -> ScanDraftPage {
        let originalData = try loadImageData(at: sourcePage.originalImage, sessionDirectory: sessionDirectory)
        var duplicatedPage = try importOriginalImage(
            data: originalData,
            pageID: newPageID,
            sourceType: sourcePage.sourceType,
            sessionDirectory: sessionDirectory
        )

        duplicatedPage.geometry = sourcePage.geometry
        duplicatedPage.visualAdjustments = sourcePage.visualAdjustments.copied()
        duplicatedPage.originalPixelSize = sourcePage.originalPixelSize
        duplicatedPage.processingError = nil

        if let processedImage = sourcePage.processedImage {
            let processedData = try loadImageData(at: processedImage, sessionDirectory: sessionDirectory)
            duplicatedPage.processedImage = try writeProcessedImage(
                data: processedData,
                pageID: newPageID,
                sessionDirectory: sessionDirectory
            )
            duplicatedPage.processingState = sourcePage.processingState
        }

        if let thumbnailImage = sourcePage.thumbnailImage {
            let thumbnailData = try loadImageData(at: thumbnailImage, sessionDirectory: sessionDirectory)
            duplicatedPage.thumbnailImage = try writeThumbnailImage(
                data: thumbnailData,
                pageID: newPageID,
                sessionDirectory: sessionDirectory
            )
            duplicatedPage.thumbnailState = sourcePage.thumbnailState
        }

        duplicatedPage.processingFingerprint = ScanProcessingFingerprint.value(for: duplicatedPage)
        return duplicatedPage
    }

    func sessionExists(for documentID: UUID) -> Bool {
        fileManager.fileExists(atPath: sessionDirectory(for: documentID).path)
    }

    private static let batchStagingDirectoryName = ".batch"

    func writeBatchStagingProcessedImage(
        data: Data,
        pageID: UUID,
        operationID: UUID,
        sessionDirectory: URL,
        fileExtension: String = "jpg"
    ) throws -> ScanDraftImageReference {
        try writeBatchStagingImage(
            data: data,
            pageID: pageID,
            operationID: operationID,
            subdirectory: Self.processedDirectoryName,
            sessionDirectory: sessionDirectory,
            fileExtension: fileExtension
        )
    }

    func writeBatchStagingThumbnailImage(
        data: Data,
        pageID: UUID,
        operationID: UUID,
        sessionDirectory: URL,
        fileExtension: String = "jpg"
    ) throws -> ScanDraftImageReference {
        try writeBatchStagingImage(
            data: data,
            pageID: pageID,
            operationID: operationID,
            subdirectory: Self.thumbnailsDirectoryName,
            sessionDirectory: sessionDirectory,
            fileExtension: fileExtension
        )
    }

    func deleteBatchStagingFiles(operationID: UUID, sessionDirectory: URL) throws {
        let batchRoot = sessionDirectory
            .appendingPathComponent(Self.batchStagingDirectoryName, isDirectory: true)
            .appendingPathComponent(operationID.uuidString, isDirectory: true)
        guard fileManager.fileExists(atPath: batchRoot.path) else { return }
        try fileManager.removeItem(at: batchRoot)
    }

    private func writeBatchStagingImage(
        data: Data,
        pageID: UUID,
        operationID: UUID,
        subdirectory: String,
        sessionDirectory: URL,
        fileExtension: String
    ) throws -> ScanDraftImageReference {
        let relativeDirectory = "\(Self.batchStagingDirectoryName)/\(operationID.uuidString)/\(subdirectory)"
        let relativePath = "\(relativeDirectory)/\(pageID.uuidString).\(fileExtension)"
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

        return ScanDraftImageReference(relativePath: relativePath)
    }
}
