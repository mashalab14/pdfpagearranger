import CoreGraphics
import Foundation

enum PageNumberPosition: String, CaseIterable, Codable, Identifiable {
    case bottomCenter
    case bottomRight
    case bottomLeft
    case topCenter
    case topRight
    case topLeft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottomCenter: return "Bottom center"
        case .bottomRight: return "Bottom right"
        case .bottomLeft: return "Bottom left"
        case .topCenter: return "Top center"
        case .topRight: return "Top right"
        case .topLeft: return "Top left"
        }
    }

    /// Normalized position in rotated display space (origin top-left, 0–1).
    func normalizedDisplayPoint(marginFraction: CGFloat = 0.04) -> CGPoint {
        let inset = marginFraction
        switch self {
        case .bottomCenter:
            return CGPoint(x: 0.5, y: 1 - inset)
        case .bottomRight:
            return CGPoint(x: 1 - inset, y: 1 - inset)
        case .bottomLeft:
            return CGPoint(x: inset, y: 1 - inset)
        case .topCenter:
            return CGPoint(x: 0.5, y: inset)
        case .topRight:
            return CGPoint(x: 1 - inset, y: inset)
        case .topLeft:
            return CGPoint(x: inset, y: inset)
        }
    }
}

enum PageNumberFormat: String, CaseIterable, Codable, Identifiable {
    case numberOnly
    case pageNumber
    case pageNumberOfTotal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .numberOnly: return "1"
        case .pageNumber: return "Page 1"
        case .pageNumberOfTotal: return "Page 1 of 10"
        }
    }

    func formattedText(number: Int, totalPages: Int) -> String {
        switch self {
        case .numberOnly:
            return "\(number)"
        case .pageNumber:
            return "Page \(number)"
        case .pageNumberOfTotal:
            return "Page \(number) of \(totalPages)"
        }
    }
}

struct PageNumberSettings: Equatable, Codable {
    var isEnabled: Bool
    var position: PageNumberPosition
    var format: PageNumberFormat
    var startNumber: Int
    var appliesToAllPages: Bool
    var rangeStart: Int
    var rangeEnd: Int
    var fontSize: CGFloat
    var opacity: CGFloat

    static let `default` = PageNumberSettings(
        isEnabled: false,
        position: .bottomCenter,
        format: .numberOnly,
        startNumber: 1,
        appliesToAllPages: true,
        rangeStart: 1,
        rangeEnd: 1,
        fontSize: 12,
        opacity: 1
    )

    var thumbnailCacheKeySuffix: String {
        guard isEnabled else { return "pageNumbers-off" }
        return "pageNumbers-\(position.rawValue)-\(format.rawValue)-\(startNumber)-\(appliesToAllPages)-\(rangeStart)-\(rangeEnd)-\(fontSize)-\(opacity)"
    }

    func shouldApply(toExportIndex exportIndex: Int) -> Bool {
        guard isEnabled else { return false }
        let pagePosition = exportIndex + 1
        if appliesToAllPages {
            return true
        }
        return pagePosition >= rangeStart && pagePosition <= rangeEnd
    }

    func displayNumber(forExportIndex exportIndex: Int) -> Int {
        if appliesToAllPages {
            return startNumber + exportIndex
        }
        return startNumber + (exportIndex - (rangeStart - 1))
    }

    func normalizedRange(totalPages: Int) -> ClosedRange<Int> {
        let lower = max(1, min(rangeStart, rangeEnd))
        let upper = min(totalPages, max(rangeStart, rangeEnd))
        return lower...upper
    }
}
