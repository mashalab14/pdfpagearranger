import Foundation
import PDFKit

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

/// Rewrites PDFs using vector page copies and document metadata cleanup.
/// Never rasterizes page content or converts pages into image-only PDFs.
struct MetadataOptimizationCompressionStrategy: CompressionStrategy {
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

            guard let originalPage = document.page(at: index),
                  let copiedPage = originalPage.copy() as? PDFPage else {
                continue
            }

            if copiedPage.rotation != originalPage.rotation {
                copiedPage.rotation = originalPage.rotation
            }

            outputDocument.insert(copiedPage, at: outputDocument.pageCount)
            progress(Double(index + 1) / Double(pageCount))
        }

        guard outputDocument.pageCount > 0 else {
            throw CompressionError.compressionFailed
        }

        applyMetadataOptimization(to: outputDocument, preset: settings.preset)

        return outputDocument
    }

    private func applyMetadataOptimization(to document: PDFDocument, preset: CompressionPreset) {
        var attributes = document.documentAttributes ?? [:]

        for key in preset.metadataKeysToRemove {
            attributes.removeValue(forKey: key)
        }

        if preset.stripsLargeCustomMetadata {
            attributes = attributes.filter { _, value in
                guard let string = value as? String else { return true }
                return string.count <= 256
            }
        }

        document.documentAttributes = attributes
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

    init(strategy: CompressionStrategy = MetadataOptimizationCompressionStrategy()) {
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
