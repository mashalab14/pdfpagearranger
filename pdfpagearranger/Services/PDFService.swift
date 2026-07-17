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
        annotationsByPage: [UUID: [PageAnnotation]] = [:],
        imageAssets: [UUID: UIImage] = [:],
        pageNumberSettings: PageNumberSettings = .default,
        watermarkSettings: WatermarkSettings = .default,
        watermarkImage: UIImage? = nil
    ) throws -> URL {
        let outputDocument = PDFDocument()
        let totalPages = pages.count

        for (exportIndex, item) in pages.enumerated() {
            let overlays = overlaysByPage[item.id] ?? []
            let annotations = annotationsByPage[item.id] ?? []
            let needsDecoration = Self.pageNeedsDecoration(
                overlays: overlays,
                annotations: annotations,
                exportIndex: exportIndex,
                pageNumberSettings: pageNumberSettings,
                watermarkSettings: watermarkSettings
            )

            if !needsDecoration {
                guard let sourcePage = sourceDocument.page(at: item.originalPageIndex)?.copy() as? PDFPage else {
                    continue
                }
                sourcePage.rotation = item.rotation
                outputDocument.insert(sourcePage, at: outputDocument.pageCount)
            } else if let decoratedPage = pageWithDecorations(
                for: item,
                exportIndex: exportIndex,
                totalPages: totalPages,
                sourceDocument: sourceDocument,
                overlays: overlays,
                annotations: annotations,
                imageAssets: imageAssets,
                pageNumberSettings: pageNumberSettings,
                watermarkSettings: watermarkSettings,
                watermarkImage: watermarkImage
            ) {
                outputDocument.insert(decoratedPage, at: outputDocument.pageCount)
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

    private func pageWithDecorations(
        for item: PageItem,
        exportIndex: Int,
        totalPages: Int,
        sourceDocument: PDFDocument,
        overlays: [PageObject],
        annotations: [PageAnnotation],
        imageAssets: [UUID: UIImage],
        pageNumberSettings: PageNumberSettings,
        watermarkSettings: WatermarkSettings,
        watermarkImage: UIImage?
    ) -> PDFPage? {
        guard let sourcePage = sourceDocument.page(at: item.originalPageIndex)?.copy() as? PDFPage else {
            return nil
        }

        // Draw the source content stream without baking /Rotate into the new PDF.
        // PDFPage.draw(with:to:) flattens text when the page carries a non-zero rotation;
        // decorations are mapped with pageRotation and /Rotate is set on the output page.
        let pageRotation = item.rotation
        sourcePage.rotation = 0
        var mediaBox = sourcePage.bounds(for: .mediaBox)
        guard mediaBox.width > 0, mediaBox.height > 0 else { return nil }

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        context.beginPDFPage(nil)

        let appliesWatermark = watermarkSettings.shouldApply(toExportIndex: exportIndex)
        if appliesWatermark, watermarkSettings.layer == .behindContent {
            WatermarkRenderer.drawInPDFContext(
                context: context,
                mediaBox: mediaBox,
                pageRotation: pageRotation,
                settings: watermarkSettings,
                watermarkImage: watermarkImage
            )
        }

        // Draw original page content as vector PDF (preserves selectable text).
        sourcePage.draw(with: .mediaBox, to: context)

        let highlights = annotations.filter { $0.kind == .highlight }
        if !highlights.isEmpty {
            AnnotationPDFExporter.drawAnnotations(highlights, in: mediaBox, pageRotation: pageRotation, context: context)
        }

        let drawings = annotations.filter { $0.kind == .drawing }
        if !drawings.isEmpty {
            AnnotationPDFExporter.drawAnnotations(drawings, in: mediaBox, pageRotation: pageRotation, context: context)
        }

        let comments = annotations.filter { $0.kind == .textComment }
        if !comments.isEmpty {
            AnnotationPDFExporter.drawAnnotations(comments, in: mediaBox, pageRotation: pageRotation, context: context)
        }

        let stickyNotes = annotations.filter { $0.kind == .stickyNote }
        if !stickyNotes.isEmpty {
            AnnotationPDFExporter.drawAnnotations(stickyNotes, in: mediaBox, pageRotation: pageRotation, context: context)
        }

        if appliesWatermark, watermarkSettings.layer == .aboveContent {
            WatermarkRenderer.drawInPDFContext(
                context: context,
                mediaBox: mediaBox,
                pageRotation: pageRotation,
                settings: watermarkSettings,
                watermarkImage: watermarkImage
            )
        }

        if !overlays.isEmpty {
            // Draw image overlays on top in mapped PDF coordinates.
            OverlayPDFExporter.drawOverlays(
                overlays,
                images: imageAssets,
                in: mediaBox,
                pageRotation: pageRotation,
                context: context
            )
        }

        if pageNumberSettings.shouldApply(toExportIndex: exportIndex) {
            let displayNumber = pageNumberSettings.displayNumber(forExportIndex: exportIndex)
            PageNumberRenderer.drawInPDFContext(
                context: context,
                mediaBox: mediaBox,
                pageRotation: pageRotation,
                settings: pageNumberSettings,
                displayNumber: displayNumber,
                totalPages: totalPages
            )
        }

        context.endPDFPage()
        context.closePDF()

        guard let document = PDFDocument(data: data as Data),
              let page = document.page(at: 0) else {
            return nil
        }

        page.rotation = pageRotation
        return page
    }

    private static func pageNeedsDecoration(
        overlays: [PageObject],
        annotations: [PageAnnotation],
        exportIndex: Int,
        pageNumberSettings: PageNumberSettings,
        watermarkSettings: WatermarkSettings
    ) -> Bool {
        !overlays.isEmpty
            || !annotations.isEmpty
            || pageNumberSettings.shouldApply(toExportIndex: exportIndex)
            || watermarkSettings.shouldApply(toExportIndex: exportIndex)
    }

    func page(at index: Int, in document: PDFDocument) -> PDFPage? {
        document.page(at: index)
    }

    /// Creates a blank single-page US Letter PDF and returns a temp file URL ready for `importPDF`.
    func createBlankPDF(displayName: String = "Untitled") throws -> URL {
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = NSMutableData()
        var box = mediaBox
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else {
            throw PDFServiceError.exportFailed
        }

        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()

        let importsDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PDFImports", isDirectory: true)
        let sessionDirectory = importsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? "Untitled" : trimmed
        let flatURL = sessionDirectory.appendingPathComponent(baseName).appendingPathExtension("pdf")

        do {
            try (data as Data).write(to: flatURL, options: .atomic)
        } catch {
            throw PDFServiceError.copyFailed
        }

        guard let document = PDFDocument(url: flatURL), document.pageCount > 0 else {
            try? fileManager.removeItem(at: sessionDirectory)
            throw PDFServiceError.unreadable
        }

        return flatURL
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
