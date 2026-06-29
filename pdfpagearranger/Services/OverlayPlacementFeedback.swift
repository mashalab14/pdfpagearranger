import UIKit

enum OverlayPlacementAnimation {
    static let duration: TimeInterval = 0.15
    static let initialScale: CGFloat = 0.95

    static func scale(for reveal: CGFloat) -> CGFloat {
        initialScale + (1 - initialScale) * reveal
    }
}

enum OverlayPlacementFeedback {
    static func playPlacementHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}
