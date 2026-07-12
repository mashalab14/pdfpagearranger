import Foundation
import UIKit

/// Persists acquired scan pages into the active draft session with transactional rollback.
struct ScanCameraScanImporter: Sendable {
    let storage: ScanDraftSessionStorage

    init(storage: ScanDraftSessionStorage = ScanDraftSessionStorage()) {
        self.storage = storage
    }

    func importPages(
        pageCount: Int,
        sourceType: ScanPageSource,
        sessionDirectory: URL,
        sessionDefaults: ScanVisualAdjustments,
        pageDataProvider: @Sendable (Int) throws -> ScanImportPagePayload
    ) throws -> [ScanDraftPage] {
        guard pageCount > 0 else {
            throw ScanDraftError.emptyDraft
        }

        var importedPages: [ScanDraftPage] = []
        var stagedReferences: [ScanDraftImageReference] = []
        importedPages.reserveCapacity(pageCount)

        do {
            for index in 0..<pageCount {
                let payload = try pageDataProvider(index)
                let pageID = UUID()
                let page = try storage.importOriginalImage(
                    data: payload.data,
                    pageID: pageID,
                    sourceType: sourceType,
                    sessionDirectory: sessionDirectory,
                    fileExtension: payload.fileExtension
                )
                stagedReferences.append(page.originalImage)
                var pageWithDefaults = page
                pageWithDefaults.visualAdjustments = sessionDefaults.copied()
                importedPages.append(pageWithDefaults)
            }
            return importedPages
        } catch {
            storage.deleteOriginalImages(stagedReferences, sessionDirectory: sessionDirectory)
            throw error
        }
    }

    func importPages(
        pageCount: Int,
        sourceType: ScanPageSource,
        sessionDirectory: URL,
        sessionDefaults: ScanVisualAdjustments,
        progressHandler: @Sendable (Int, Int) -> Void = { _, _ in },
        isCancelled: @Sendable () -> Bool = { false },
        pageDataProvider: @Sendable (Int) async throws -> ScanImportPagePayload
    ) async throws -> [ScanDraftPage] {
        guard pageCount > 0 else {
            throw ScanDraftError.emptyDraft
        }

        var importedPages: [ScanDraftPage] = []
        var stagedReferences: [ScanDraftImageReference] = []
        importedPages.reserveCapacity(pageCount)

        do {
            for index in 0..<pageCount {
                if isCancelled() {
                    throw ScanDraftError.photosImportCancelled
                }

                progressHandler(index, pageCount)
                let payload = try await pageDataProvider(index)
                let pageID = UUID()
                let page = try storage.importOriginalImage(
                    data: payload.data,
                    pageID: pageID,
                    sourceType: sourceType,
                    sessionDirectory: sessionDirectory,
                    fileExtension: payload.fileExtension
                )
                stagedReferences.append(page.originalImage)
                var pageWithDefaults = page
                pageWithDefaults.visualAdjustments = sessionDefaults.copied()
                importedPages.append(pageWithDefaults)
                progressHandler(index + 1, pageCount)
            }
            return importedPages
        } catch {
            storage.deleteOriginalImages(stagedReferences, sessionDirectory: sessionDirectory)
            throw error
        }
    }

    func importVisionKitScan(
        _ scan: VNDocumentCameraScanBridge,
        sessionDirectory: URL,
        sessionDefaults: ScanVisualAdjustments
    ) throws -> [ScanDraftPage] {
        let pageCount = scan.pageCount
        return try importPages(
            pageCount: pageCount,
            sourceType: .camera,
            sessionDirectory: sessionDirectory,
            sessionDefaults: sessionDefaults
        ) { index in
            guard let image = scan.imageOfPage(at: index) else {
                throw ScanDraftError.imageExtractionFailure
            }
            return .jpeg(try ScanWorkingImageEncoder.normalizedJPEGData(from: image))
        }
    }
}

/// Testable abstraction over `VNDocumentCameraScan`.
protocol VNDocumentCameraScanBridge: Sendable {
    var pageCount: Int { get }
    func imageOfPage(at index: Int) -> UIImage?
}

#if canImport(VisionKit)
import VisionKit

struct VisionKitDocumentCameraScanBridge: VNDocumentCameraScanBridge {
    let scan: VNDocumentCameraScan

    var pageCount: Int { scan.pageCount }

    func imageOfPage(at index: Int) -> UIImage? {
        guard index >= 0, index < scan.pageCount else { return nil }
        return scan.imageOfPage(at: index)
    }
}
#endif

struct InMemoryDocumentCameraScanBridge: VNDocumentCameraScanBridge {
    let images: [UIImage]

    var pageCount: Int { images.count }

    func imageOfPage(at index: Int) -> UIImage? {
        guard images.indices.contains(index) else { return nil }
        return images[index]
    }
}
