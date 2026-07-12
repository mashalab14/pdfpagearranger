import Foundation

enum ScanDraftError: LocalizedError, Equatable {
    case imageCannotBeLoaded
    case unsupportedImageData
    case processingFailure(stage: ScanProcessingStage)
    case temporaryFileWriteFailure
    case insufficientStorage
    case pdfGenerationFailure
    case editorHandoffFailure
    case sessionNotFound
    case emptyDraft
    case acquisitionCancelled
    case scannerUnsupported
    case cameraPermissionDenied
    case cameraPermissionRestricted
    case visionKitScannerFailure
    case imageExtractionFailure
    case imageEncodingFailure
    case draftModelUpdateFailure
    case photosAssetLoadFailure
    case corruptedImageData
    case photosImportCancelled
    case draftCleanupFailure

    var errorDescription: String? {
        switch self {
        case .imageCannotBeLoaded:
            return "The image could not be loaded."
        case .unsupportedImageData:
            return "This image format is not supported."
        case .processingFailure(let stage):
            return "Image processing failed during \(stage.displayName)."
        case .temporaryFileWriteFailure:
            return "Could not save a working copy of the image."
        case .insufficientStorage:
            return "There is not enough storage available."
        case .pdfGenerationFailure:
            return "Could not generate the PDF."
        case .editorHandoffFailure:
            return "The generated PDF could not be opened in the editor."
        case .sessionNotFound:
            return "The scan session could not be found."
        case .emptyDraft:
            return "Add at least one page before continuing."
        case .acquisitionCancelled:
            return nil
        case .scannerUnsupported:
            return "Document scanning is not available on this device."
        case .cameraPermissionDenied:
            return "Camera access is required to scan documents. You can enable it in Settings."
        case .cameraPermissionRestricted:
            return "Camera access is restricted on this device."
        case .visionKitScannerFailure:
            return "The document scanner could not complete the scan."
        case .imageExtractionFailure:
            return "A scanned page could not be read."
        case .imageEncodingFailure:
            return "A scanned page could not be saved."
        case .draftModelUpdateFailure:
            return "The scanned pages could not be added to the draft."
        case .photosAssetLoadFailure:
            return "One or more selected photos could not be imported. Try again."
        case .corruptedImageData:
            return "One or more selected images could not be read."
        case .photosImportCancelled:
            return nil
        case .draftCleanupFailure:
            return "The draft could not be removed from this device."
        }
    }
}

enum ScanProcessingStage: String, Codable, CaseIterable, Sendable {
    case normalizeOrientation
    case detectBoundaries
    case applyCrop
    case applyPerspectiveCorrection
    case applyRotation
    case applyVisualAdjustments
    case generateThumbnail
    case generateProcessedImage

    var displayName: String {
        switch self {
        case .normalizeOrientation: return "orientation normalization"
        case .detectBoundaries: return "boundary detection"
        case .applyCrop: return "cropping"
        case .applyPerspectiveCorrection: return "perspective correction"
        case .applyRotation: return "rotation"
        case .applyVisualAdjustments: return "visual adjustments"
        case .generateThumbnail: return "thumbnail generation"
        case .generateProcessedImage: return "processed image generation"
        }
    }
}
