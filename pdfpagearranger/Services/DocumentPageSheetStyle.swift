import SwiftUI

/// Visual constants for the unified document’s continuous paper-stack presentation.
enum DocumentPageSheetStyle {
    /// Horizontal inset around the vertical page stack (workspace, not per-page card padding).
    static let stackHorizontalMargin: CGFloat = 12

    /// Soft base shadow shared by every page sheet (active and inactive).
    static let baseShadowOpacity: Double = 0.08
    static let baseShadowRadius: CGFloat = 3
    static let baseShadowY: CGFloat = 1.5

    /// Restrained blue-tinted halo for the active page only (not a border).
    static let activeHaloOpacity: Double = 0.32
    static let activeHaloRadius: CGFloat = 14
    static let activeHaloY: CGFloat = 0

    static func pageSpacing(forContainerWidth width: CGFloat) -> CGFloat {
        max(2, min(6, width * 0.01))
    }
}

extension View {
    /// Applies identical layout footprint for active and inactive sheets; activation only adds a soft halo.
    func documentPageSheetChrome(isActive: Bool) -> some View {
        self
            .compositingGroup()
            .shadow(
                color: .black.opacity(DocumentPageSheetStyle.baseShadowOpacity),
                radius: DocumentPageSheetStyle.baseShadowRadius,
                y: DocumentPageSheetStyle.baseShadowY
            )
            .shadow(
                color: Color.accentColor.opacity(isActive ? DocumentPageSheetStyle.activeHaloOpacity : 0),
                radius: DocumentPageSheetStyle.activeHaloRadius,
                y: DocumentPageSheetStyle.activeHaloY
            )
    }
}
