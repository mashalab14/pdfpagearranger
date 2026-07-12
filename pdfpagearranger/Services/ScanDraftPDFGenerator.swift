import Foundation
import PDFKit
import UIKit

/// Future PDF assembly from ordered processed page images.
protocol ScanDraftPDFGenerating: Sendable {
    typealias ProgressHandler = @Sendable (ScanDraftPDFGenerationUpdate) -> Void

    func generatePDF(
        from pages: [ScanDraftPage],
        sessionDirectory: URL,
        displayName: String,
        onProgress: ProgressHandler?,
        onPagePrepared: (@Sendable (ScanDraftPage) -> Void)?
    ) async throws -> URL
}

/// Assembles a multi-page PDF from file-backed processed page images.
struct ScanDraftPDFGenerator: ScanDraftPDFGenerating {
    private let storage: ScanDraftSessionStorage
    private let processingOrchestrator: ScanPageProcessingOrchestrator

    init(
        storage: ScanDraftSessionStorage,
        processingOrchestrator: ScanPageProcessingOrchestrator? = nil
    ) {
        self.storage = storage
        self.processingOrchestrator = processingOrchestrator ?? ScanPageProcessingOrchestrator(storage: storage)
    }

    func generatePDF(
        from pages: [ScanDraftPage],
        sessionDirectory: URL,
        displayName: String,
        onProgress: ProgressHandler?,
        onPagePrepared: (@Sendable (ScanDraftPage) -> Void)?
    ) async throws -> URL {
        guard !pages.isEmpty else {
            throw ScanDraftError.emptyDraft
        }

        let totalPages = pages.count
        var preparedPages: [ScanDraftPage] = []
        preparedPages.reserveCapacity(totalPages)

        for (index, page) in pages.enumerated() {
            try Task.checkCancellation()
            onProgress?(
                ScanDraftPDFGenerationUpdate(
                    phase: .preparingPages,
                    currentPage: index + 1,
                    totalPages: totalPages
                )
            )

            let result = try await processingOrchestrator.processPage(page, sessionDirectory: sessionDirectory)
            guard result.page.processedImage != nil else {
                throw ScanDraftError.processingFailure(stage: .generateProcessedImage)
            }
            preparedPages.append(result.page)
            onPagePrepared?(result.page)
        }

        let pdfDocument = PDFDocument()

        for (index, page) in preparedPages.enumerated() {
            try Task.checkCancellation()
            onProgress?(
                ScanDraftPDFGenerationUpdate(
                    phase: .generatingPDF,
                    currentPage: index + 1,
                    totalPages: totalPages
                )
            )

            guard let processedReference = page.processedImage else {
                throw ScanDraftError.processingFailure(stage: .generateProcessedImage)
            }
            let imageData = try storage.loadImageData(at: processedReference, sessionDirectory: sessionDirectory)
            let pdfPage = try makePDFPage(from: imageData)
            pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
        }

        guard pdfDocument.pageCount == totalPages else {
            throw ScanDraftError.pdfGenerationFailure
        }

        let fileName = Self.sanitizedFileName(from: displayName)
        return try storage.writeGeneratedPDF(
            pdfDocument,
            sessionDirectory: sessionDirectory,
            fileName: fileName
        )
    }

    private func makePDFPage(from imageData: Data) throws -> PDFPage {
        guard let image = UIImage(data: imageData) else {
            throw ScanDraftError.imageCannotBeLoaded
        }

        let normalizedImage = ScanWorkingImageEncoder.orientationNormalizedImage(from: image) ?? image
        guard let cgImage = normalizedImage.cgImage else {
            throw ScanDraftError.imageCannotBeLoaded
        }

        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        )

        let pageData = UIGraphicsPDFRenderer(bounds: pageRect).pdfData { context in
            context.beginPage()
            normalizedImage.draw(in: pageRect)
        }

        guard let pageDocument = PDFDocument(data: pageData),
              let page = pageDocument.page(at: 0)?.copy() as? PDFPage else {
            throw ScanDraftError.pdfGenerationFailure
        }

        return page
    }

    private static func sanitizedFileName(from displayName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = displayName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Scanned Document" : cleaned
    }
}

/// Placeholder implementation for tests that require explicit failure.
struct UnimplementedScanDraftPDFGenerator: ScanDraftPDFGenerating {
    func generatePDF(
        from pages: [ScanDraftPage],
        sessionDirectory: URL,
        displayName: String,
        onProgress: ProgressHandler?,
        onPagePrepared: (@Sendable (ScanDraftPage) -> Void)?
    ) async throws -> URL {
        guard !pages.isEmpty else {
            throw ScanDraftError.emptyDraft
        }
        throw ScanDraftError.pdfGenerationFailure
    }
}
