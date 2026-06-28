import Foundation
import PDFKit
import UIKit

enum CompressionError: LocalizedError, Equatable {
    case unreadableInput
    case encrypted
    case empty
    case compressionFailed
    case insufficientSavings
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unreadableInput:
            return "The PDF could not be read for compression."
        case .encrypted:
            return "Password-protected PDFs cannot be compressed."
        case .empty:
            return "This PDF has no pages to compress."
        case .compressionFailed:
            return "Compression failed. Please try again."
        case .insufficientSavings:
            return "This PDF is already optimized and cannot be meaningfully compressed."
        case .cancelled:
            return "Compression was cancelled."
        }
    }
}

protocol CompressionStrategy {
    func compressDocument(
        _ document: PDFDocument,
        settings: CompressionSettings,
        progress: (Double) -> Void,
        isCancelled: () -> Bool
    ) throws -> PDFDocument
}

/// Recompresses image-dominant pages with JPEG downsampling while preserving text pages via vector redraw.
struct ImageDownsampleCompressionStrategy: CompressionStrategy {
    private let minimumTextLengthForVectorPreservation = 24

    func compressDocument(
        _ document: PDFDocument,
        settings: CompressionSettings,
        progress: (Double) -> Void,
        isCancelled: () -> Bool
    ) throws -> PDFDocument {
        let pageCount = document.pageCount
        guard pageCount > 0 else { throw CompressionError.empty }

        let outputDocument = PDFDocument()

        for index in 0..<pageCount {
            if isCancelled() {
                throw CompressionError.cancelled
            }

            guard let sourcePage = document.page(at: index)?.copy() as? PDFPage else {
                continue
            }

            let rebuiltPage: PDFPage?
            if settings.preset.usesImageDownsampling, isImageDominantPage(sourcePage) {
                rebuiltPage = rasterizedPage(from: sourcePage, preset: settings.preset)
            } else {
                rebuiltPage = sourcePage.copy() as? PDFPage
            }

            guard let rebuiltPage else {
                throw CompressionError.compressionFailed
            }

            if rebuiltPage.rotation != sourcePage.rotation {
                rebuiltPage.rotation = sourcePage.rotation
            }
            outputDocument.insert(rebuiltPage, at: outputDocument.pageCount)
            progress(Double(index + 1) / Double(pageCount))
        }

        guard outputDocument.pageCount > 0 else {
            throw CompressionError.compressionFailed
        }

        return outputDocument
    }

    private func isImageDominantPage(_ page: PDFPage) -> Bool {
        let text = page.string?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.count < minimumTextLengthForVectorPreservation
    }

    private func vectorCopiedPage(from page: PDFPage) -> PDFPage? {
        guard let drawPage = page.copy() as? PDFPage else { return nil }

        let rotation = drawPage.rotation
        drawPage.rotation = 0

        var mediaBox = drawPage.bounds(for: .mediaBox)
        guard mediaBox.width > 0, mediaBox.height > 0 else { return nil }

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        var pageInfo: [CFString: Any] = [kCGPDFContextMediaBox: mediaBox]
        if rotation != 0 {
            pageInfo["Rotate" as CFString] = rotation
        }

        context.beginPDFPage(pageInfo as CFDictionary)
        drawPage.draw(with: .mediaBox, to: context)
        context.endPDFPage()
        context.closePDF()

        guard let document = PDFDocument(data: data as Data),
              let copiedPage = document.page(at: 0)?.copy() as? PDFPage else {
            return nil
        }

        copiedPage.rotation = rotation
        return copiedPage
    }

    private func rasterizedPage(from page: PDFPage, preset: CompressionPreset) -> PDFPage? {
        guard let drawPage = page.copy() as? PDFPage else { return nil }

        let rotation = drawPage.rotation
        drawPage.rotation = 0

        let mediaBox = drawPage.bounds(for: .mediaBox)
        guard mediaBox.width > 0, mediaBox.height > 0 else { return nil }

        let scale = min(1, preset.maxImageDimension / max(mediaBox.width, mediaBox.height))
        let renderSize = CGSize(width: mediaBox.width * scale, height: mediaBox.height * scale)
        let rendered = drawPage.thumbnail(of: renderSize, for: .mediaBox)

        guard let jpegData = rendered.jpegData(compressionQuality: preset.jpegQuality),
              let compressedImage = UIImage(data: jpegData) else {
            drawPage.rotation = rotation
            return vectorCopiedPage(from: page)
        }

        var pageMediaBox = mediaBox
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &pageMediaBox, nil) else {
            drawPage.rotation = rotation
            return vectorCopiedPage(from: page)
        }

        var pageInfo: [CFString: Any] = [kCGPDFContextMediaBox: pageMediaBox]
        if rotation != 0 {
            pageInfo["Rotate" as CFString] = rotation
        }

        context.beginPDFPage(pageInfo as CFDictionary)
        compressedImage.draw(in: pageMediaBox)
        context.endPDFPage()
        context.closePDF()

        guard let document = PDFDocument(data: data as Data),
              let rasterPage = document.page(at: 0)?.copy() as? PDFPage else {
            drawPage.rotation = rotation
            return vectorCopiedPage(from: page)
        }

        rasterPage.rotation = rotation
        return rasterPage
    }
}

final class CompressionCancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func reset() {
        lock.lock()
        cancelled = false
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func isCancelled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

actor CompressionService {
    private let strategy: CompressionStrategy
    private let fileManager = FileManager.default
    private let cancellationFlag = CompressionCancellationFlag()

    init(strategy: CompressionStrategy = ImageDownsampleCompressionStrategy()) {
        self.strategy = strategy
    }

    func cancel() {
        cancellationFlag.cancel()
    }

    func compress(
        inputURL: URL,
        settings: CompressionSettings,
        outputName: String,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> CompressionResult {
        cancellationFlag.reset()
        let flag = cancellationFlag

        return try await Task.detached(priority: .userInitiated) { [strategy, fileManager, flag] in
            guard let document = PDFDocument(url: inputURL) else {
                throw CompressionError.unreadableInput
            }

            if document.isEncrypted, !document.unlock(withPassword: "") {
                throw CompressionError.encrypted
            }

            guard document.pageCount > 0 else {
                throw CompressionError.empty
            }

            let originalByteCount = CompressionService.fileSize(at: inputURL, fileManager: fileManager)

            let compressedDocument = try strategy.compressDocument(
                document,
                settings: settings,
                progress: { value in
                    progress?(value)
                },
                isCancelled: {
                    flag.isCancelled()
                }
            )

            let sanitizedName = outputName
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let outputURL = fileManager.temporaryDirectory
                .appendingPathComponent("\(sanitizedName)-compressed.pdf")

            if fileManager.fileExists(atPath: outputURL.path) {
                try fileManager.removeItem(at: outputURL)
            }

            guard compressedDocument.write(to: outputURL) else {
                throw CompressionError.compressionFailed
            }

            let compressedByteCount = CompressionService.fileSize(at: outputURL, fileManager: fileManager)
            let result = CompressionResult(
                outputURL: outputURL,
                originalByteCount: originalByteCount,
                compressedByteCount: compressedByteCount
            )

            if !result.meaningfulCompression {
                try? fileManager.removeItem(at: outputURL)
                throw CompressionError.insufficientSavings
            }

            return result
        }.value
    }

    private static func fileSize(at url: URL, fileManager: FileManager) -> Int64 {
        (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    }
}
