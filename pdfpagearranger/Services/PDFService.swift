import Foundation
import PDFKit
import UIKit
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
            } else if let overlayPage = pageWithOverlays(
                for: item,
                sourceDocument: sourceDocument,
                overlays: overlays,
                imageAssets: imageAssets
            ) {
                outputDocument.insert(overlayPage, at: outputDocument.pageCount)
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

    private func pageWithOverlays(
        for item: PageItem,
        sourceDocument: PDFDocument,
        overlays: [PageObject],
        imageAssets: [UUID: UIImage]
    ) -> PDFPage? {
        guard let sourcePage = sourceDocument.page(at: item.originalPageIndex)?.copy() as? PDFPage else {
            return nil
        }

        sourcePage.rotation = item.rotation
        var mediaBox = sourcePage.bounds(for: .mediaBox)
        guard mediaBox.width > 0, mediaBox.height > 0 else { return nil }

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        context.beginPDFPage(nil)

        // Draw original page content as vector PDF (preserves selectable text).
        sourcePage.draw(with: .mediaBox, to: context)

        // Draw image overlays on top in mapped PDF coordinates.
        OverlayPDFExporter.drawOverlays(
            overlays,
            images: imageAssets,
            in: mediaBox,
            pageRotation: item.rotation,
            context: context
        )

        context.endPDFPage()
        context.closePDF()

        guard let document = PDFDocument(data: data as Data),
              let page = document.page(at: 0) else {
            return nil
        }

        return page
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
