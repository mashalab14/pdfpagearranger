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
        options: ScanDraftPDFGenerationOptions,
        onProgress: ProgressHandler?,
        onPagePrepared: (@Sendable (ScanDraftPage) -> Void)?
    ) async throws -> ScanDraftPDFGenerationResult
}

/// Assembles a multi-page PDF from file-backed processed page images.
struct ScanDraftPDFGenerator: ScanDraftPDFGenerating {
    private let storage: ScanDraftSessionStorage
    private let processingOrchestrator: ScanPageProcessingOrchestrator
    private let ocrService: ScanOCRService

    init(
        storage: ScanDraftSessionStorage,
        processingOrchestrator: ScanPageProcessingOrchestrator? = nil,
        ocrService: ScanOCRService? = nil
    ) {
        self.storage = storage
        self.processingOrchestrator = processingOrchestrator ?? ScanPageProcessingOrchestrator(storage: storage)
        self.ocrService = ocrService ?? ScanOCRService(storage: storage)
    }

    func generatePDF(
        from pages: [ScanDraftPage],
        sessionDirectory: URL,
        displayName: String,
        options: ScanDraftPDFGenerationOptions = .default,
        onProgress: ProgressHandler?,
        onPagePrepared: (@Sendable (ScanDraftPage) -> Void)?
    ) async throws -> ScanDraftPDFGenerationResult {
        guard !pages.isEmpty else {
            throw ScanDraftError.emptyDraft
        }

        storage.deleteGeneratedPDFStaging(in: sessionDirectory)

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

        var ocrResultsByPageID: [UUID: OCRPage] = [:]
        var nonSearchablePageIDs: [UUID] = []

        if options.makeSearchable {
            for (index, page) in preparedPages.enumerated() {
                try Task.checkCancellation()
                onProgress?(
                    ScanDraftPDFGenerationUpdate(
                        phase: .recognizingText,
                        currentPage: index + 1,
                        totalPages: totalPages
                    )
                )

                guard let processedReference = page.processedImage else {
                    nonSearchablePageIDs.append(page.id)
                    continue
                }

                let imageData = try storage.loadImageData(
                    at: processedReference,
                    sessionDirectory: sessionDirectory
                )

                let (ocrPage, updatedPage) = try await ocrService.recognizePageIfNeeded(
                    page: page,
                    processedImageData: imageData,
                    sessionDirectory: sessionDirectory,
                    configuration: options.ocrConfiguration
                )
                preparedPages[index] = updatedPage
                onPagePrepared?(updatedPage)

                if ocrPage.status == .succeeded, !ocrPage.lines.isEmpty {
                    ocrResultsByPageID[page.id] = ocrPage
                } else {
                    nonSearchablePageIDs.append(page.id)
                }
            }
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
            let ocrPage = options.makeSearchable ? ocrResultsByPageID[page.id] : nil
            let pdfPage = try makePDFPage(from: imageData, ocrPage: ocrPage)
            pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
        }

        guard pdfDocument.pageCount == totalPages else {
            throw ScanDraftError.pdfGenerationFailure
        }

        let fileName = Self.sanitizedFileName(from: displayName)
        let url = try storage.writeGeneratedPDF(
            pdfDocument,
            sessionDirectory: sessionDirectory,
            fileName: fileName
        )

        return ScanDraftPDFGenerationResult(
            url: url,
            nonSearchablePageIDs: nonSearchablePageIDs
        )
    }

    private func makePDFPage(from imageData: Data, ocrPage: OCRPage?) throws -> PDFPage {
        guard let image = UIImage(data: imageData) else {
            throw ScanDraftError.imageCannotBeLoaded
        }

        let normalizedImage = ScanWorkingImageEncoder.orientationNormalizedImage(from: image) ?? image
        guard let cgImage = normalizedImage.cgImage else {
            throw ScanDraftError.imageCannotBeLoaded
        }

        let pagePixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let pageRect = CGRect(origin: .zero, size: pagePixelSize)

        let pageData = UIGraphicsPDFRenderer(bounds: pageRect).pdfData { context in
            context.beginPage()
            normalizedImage.draw(in: pageRect)
            if let ocrPage {
                ScanOCRPDFTextRenderer.drawInvisibleText(
                    for: ocrPage,
                    in: context,
                    pagePixelSize: pagePixelSize
                )
            }
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
        options: ScanDraftPDFGenerationOptions,
        onProgress: ProgressHandler?,
        onPagePrepared: (@Sendable (ScanDraftPage) -> Void)?
    ) async throws -> ScanDraftPDFGenerationResult {
        guard !pages.isEmpty else {
            throw ScanDraftError.emptyDraft
        }
        throw ScanDraftError.pdfGenerationFailure
    }
}
