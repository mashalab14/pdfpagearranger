import Foundation

enum ScanVisualBatchApplyScope: String, CaseIterable, Identifiable, Sendable {
    case thisPage
    case selectedPages
    case allPages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisPage: return "This Page"
        case .selectedPages: return "Selected Pages"
        case .allPages: return "All Pages"
        }
    }

    var requiresConfirmation: Bool {
        switch self {
        case .thisPage: return false
        case .selectedPages, .allPages: return true
        }
    }
}

struct ScanDraftVisualBatchProgress: Equatable, Sendable {
    var completed: Int
    var total: Int
    var currentPageID: UUID?
    var currentPageNumber: Int?
    var isCancelling: Bool

    static let idle = ScanDraftVisualBatchProgress(
        completed: 0,
        total: 0,
        currentPageID: nil,
        currentPageNumber: nil,
        isCancelling: false
    )
}
