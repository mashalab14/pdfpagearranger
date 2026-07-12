import Foundation
import UIKit

struct ScanOCRService: Sendable {
    let storage: ScanDraftSessionStorage
    let recognizer: any ScanTextRecognizing

    init(
        storage: ScanDraftSessionStorage,
        recognizer: (any ScanTextRecognizing)? = nil
    ) {
        self.storage = storage
        self.recognizer = recognizer ?? VisionScanTextRecognizer()
    }

    func recognizePageIfNeeded(
        page: ScanDraftPage,
        processedImageData: Data,
        sessionDirectory: URL,
        configuration: ScanOCRConfiguration
    ) async throws -> (OCRPage, ScanDraftPage) {
        try Task.checkCancellation()

        if ScanOCRFingerprint.isCacheValid(for: page, configuration: configuration),
           let cache = page.ocrCache,
           let cachedPage = try? storage.loadOCRResult(at: cache, sessionDirectory: sessionDirectory) {
            return (cachedPage, page)
        }

        if let staleCache = page.ocrCache {
            storage.deleteOCRResult(at: staleCache, sessionDirectory: sessionDirectory)
        }

        let imagePixelSize = Self.imagePixelSize(from: processedImageData)
        let fingerprint = ScanOCRFingerprint.value(for: page, configuration: configuration)

        do {
            let rawLines = try await recognizer.recognizeLines(
                in: processedImageData,
                configuration: configuration
            )
            let ocrPage = ScanOCRLayoutEngine.buildPage(
                pageID: page.id,
                imagePixelSize: imagePixelSize,
                rawLines: rawLines,
                status: .succeeded,
                errorMessage: nil
            )

            var updatedPage = page
            let cacheEntry = try storage.writeOCRResult(
                ocrPage,
                pageID: page.id,
                fingerprint: fingerprint,
                sessionDirectory: sessionDirectory
            )
            updatedPage.ocrCache = cacheEntry
            return (ocrPage, updatedPage)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let failedPage = ScanOCRLayoutEngine.buildPage(
                pageID: page.id,
                imagePixelSize: imagePixelSize,
                rawLines: [],
                status: .failed,
                errorMessage: error.localizedDescription
            )

            var updatedPage = page
            let cacheEntry = try storage.writeOCRResult(
                failedPage,
                pageID: page.id,
                fingerprint: fingerprint,
                sessionDirectory: sessionDirectory
            )
            updatedPage.ocrCache = cacheEntry
            return (failedPage, updatedPage)
        }
    }

    func loadCachedOCRPage(
        for page: ScanDraftPage,
        sessionDirectory: URL,
        configuration: ScanOCRConfiguration
    ) throws -> OCRPage? {
        guard ScanOCRFingerprint.isCacheValid(for: page, configuration: configuration),
              let cache = page.ocrCache else {
            return nil
        }
        return try storage.loadOCRResult(at: cache, sessionDirectory: sessionDirectory)
    }

    private static func imagePixelSize(from imageData: Data) -> CGSize {
        guard let image = UIImage(data: imageData),
              let cgImage = (ScanWorkingImageEncoder.orientationNormalizedImage(from: image) ?? image).cgImage else {
            return .zero
        }
        return CGSize(width: cgImage.width, height: cgImage.height)
    }
}
