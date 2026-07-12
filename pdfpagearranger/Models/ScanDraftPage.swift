import CoreGraphics
import Foundation

/// One page in a scan-to-PDF draft session.
/// Camera and Photos sources converge into this unified model immediately after acquisition.
struct ScanDraftPage: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let sourceType: ScanPageSource
    /// App-controlled working copy; never mutates the Photos library original.
    var originalImage: ScanDraftImageReference
    var processedImage: ScanDraftImageReference?
    var thumbnailImage: ScanDraftImageReference?
    var originalPixelSize: CGSize
    var geometry: ScanPageGeometry
    var visualAdjustments: ScanVisualAdjustments
    var processingState: ScanPageProcessingState
    var processingError: String?
    var thumbnailState: ScanThumbnailState
    /// Fingerprint of inputs when `processedImage` was last produced.
    var processingFingerprint: String?
    /// Cached OCR output for the final processed image.
    var ocrCache: ScanDraftOCRCacheEntry?

    init(
        id: UUID = UUID(),
        sourceType: ScanPageSource,
        originalImage: ScanDraftImageReference,
        processedImage: ScanDraftImageReference? = nil,
        thumbnailImage: ScanDraftImageReference? = nil,
        originalPixelSize: CGSize,
        geometry: ScanPageGeometry = .default,
        visualAdjustments: ScanVisualAdjustments = .neutral,
        processingState: ScanPageProcessingState = .pending,
        processingError: String? = nil,
        thumbnailState: ScanThumbnailState = .notGenerated,
        processingFingerprint: String? = nil,
        ocrCache: ScanDraftOCRCacheEntry? = nil
    ) {
        self.id = id
        self.sourceType = sourceType
        self.originalImage = originalImage
        self.processedImage = processedImage
        self.thumbnailImage = thumbnailImage
        self.originalPixelSize = originalPixelSize
        self.geometry = geometry
        self.visualAdjustments = visualAdjustments
        self.processingState = processingState
        self.processingError = processingError
        self.thumbnailState = thumbnailState
        self.processingFingerprint = processingFingerprint
        self.ocrCache = ocrCache
    }

    var needsProcessing: Bool {
        !ScanProcessingFingerprint.isProcessedOutputValid(for: self)
    }
}
