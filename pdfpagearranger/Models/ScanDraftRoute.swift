import Foundation

/// Navigation destinations for the unified scan-to-PDF feature flow.
enum ScanDraftRoute: Hashable, Identifiable {
    case cameraAcquisition
    case photosAcquisition
    case draftReview
    case pageAdjustment(pageID: UUID)
    case pdfGenerationProgress

    var id: String {
        switch self {
        case .cameraAcquisition: return "cameraAcquisition"
        case .photosAcquisition: return "photosAcquisition"
        case .draftReview: return "draftReview"
        case .pageAdjustment(let pageID): return "pageAdjustment-\(pageID.uuidString)"
        case .pdfGenerationProgress: return "pdfGenerationProgress"
        }
    }
}
