import Foundation
import PDFKit
import UniformTypeIdentifiers

enum PDFServiceError: LocalizedError {
    case accessDenied
    case copyFailed
    case unreadable
    case encrypted
    case empty
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Could not access the selected file."
        case .copyFailed:
            return "Could not copy the PDF for editing."
        case .unreadable:
            return "This file could not be read as a PDF."
        case .encrypted:
            return "This PDF is password-protected and cannot be opened."
        case .empty:
            return "This PDF has no pages."
        case .exportFailed:
            return "Could not export the PDF."
        }
    }
}

struct ImportedPDF {
    let localURL: URL
    let document: PDFDocument
    let displayName: String
    let pageCount: Int
}

final class PDFService {
    private let fileManager = FileManager.default

    func importPDF(from sourceURL: URL) throws -> ImportedPDF {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let localURL = try copyToLocalStorage(sourceURL: sourceURL)
        guard let document = PDFDocument(url: localURL) else {
            try? fileManager.removeItem(at: localURL)
            throw PDFServiceError.unreadable
        }

        if document.isEncrypted, !document.unlock(withPassword: "") {
            try? fileManager.removeItem(at: localURL)
            throw PDFServiceError.encrypted
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            try? fileManager.removeItem(at: localURL)
            throw PDFServiceError.empty
        }

        let displayName = sourceURL.deletingPathExtension().lastPathComponent
        return ImportedPDF(
            localURL: localURL,
            document: document,
            displayName: displayName,
            pageCount: pageCount
        )
    }

    func makeInitialPages(pageCount: Int) -> [PageItem] {
        (0..<pageCount).map { PageItem(originalPageIndex: $0) }
    }

    func exportPDF(
        pages: [PageItem],
        sourceDocument: PDFDocument,
        outputName: String,
        overlaysByPage: [UUID: [PageObject]] = [:],
        imageAssets: [UUID: UIImage] = [:]
    ) throws -> URL {
        let outputDocument = PDFDocument()

        for item in pages {
            let overlays = overlaysByPage[item.id] ?? []

            if overlays.isEmpty {
                guard let sourcePage = sourceDocument.page(at: item.originalPageIndex)?.copy() as? PDFPage else {
                    continue
                }
                sourcePage.rotation = item.rotation
                outputDocument.insert(sourcePage, at: outputDocument.pageCount)
            } else if let flattenedPage = flattenedPage(
                for: item,
                sourceDocument: sourceDocument,
                overlays: overlays,
                imageAssets: imageAssets
            ) {
                outputDocument.insert(flattenedPage, at: outputDocument.pageCount)
            }
        }

        guard outputDocument.pageCount > 0 else {
            throw PDFServiceError.exportFailed
        }

        let sanitizedName = outputName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "\(sanitizedName)-arranged.pdf"
        let outputURL = fileManager.temporaryDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        guard outputDocument.write(to: outputURL) else {
            throw PDFServiceError.exportFailed
        }

        return outputURL
    }

    private func flattenedPage(
        for item: PageItem,
        sourceDocument: PDFDocument,
        overlays: [PageObject],
        imageAssets: [UUID: UIImage]
    ) -> PDFPage? {
        guard let sourcePage = sourceDocument.page(at: item.originalPageIndex),
              let pageCopy = sourcePage.copy() as? PDFPage else {
            return nil
        }

        pageCopy.rotation = item.rotation
        let bounds = pageCopy.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let exportDimension = max(bounds.width, bounds.height) * 2
        guard let baseImage = PDFPreviewRenderer.image(
            from: pageCopy,
            rotation: item.rotation,
            maxDimension: exportDimension,
            maxScale: 4.0
        ) else {
            return nil
        }

        let composited = OverlayCompositor.composite(
            baseImage: baseImage,
            objects: overlays,
            images: imageAssets
        )

        return PDFPage(image: composited)
    }

    func page(at index: Int, in document: PDFDocument) -> PDFPage? {
        document.page(at: index)
    }

    private func copyToLocalStorage(sourceURL: URL) throws -> URL {
        let importsDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PDFImports", isDirectory: true)

        if !fileManager.fileExists(atPath: importsDirectory.path) {
            try fileManager.createDirectory(at: importsDirectory, withIntermediateDirectories: true)
        }

        let destinationURL = importsDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            throw PDFServiceError.copyFailed
        }
    }
}
