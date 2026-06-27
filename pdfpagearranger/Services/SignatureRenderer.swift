import PencilKit
import UIKit

enum SignatureRenderer {
    static func image(from drawing: PKDrawing, padding: CGFloat = 8) -> UIImage? {
        let bounds = drawing.bounds
        guard !bounds.isEmpty else { return nil }

        let paddedBounds = bounds.insetBy(dx: -padding, dy: -padding)
        return drawing.image(from: paddedBounds, scale: 2.0)
    }
}
