import SwiftUI
import UIKit

/// Full-width inactive page preview used in the unified vertical document scroller.
struct DocumentInactivePagePreview: View {
    let pageImage: UIImage
    let objects: [PageObject]
    let overlayImages: [UUID: UIImage]
    let pageRotation: Int
    let isActiveChrome: Bool

    var body: some View {
        let composited = OverlayCompositor.composite(
            baseImage: pageImage,
            objects: objects,
            images: overlayImages,
            pageRotation: pageRotation
        )
        Image(uiImage: composited)
            .resizable()
            .scaledToFit()
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(
                        isActiveChrome ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.06),
                        lineWidth: isActiveChrome ? 1.5 : 0.5
                    )
            }
            .accessibilityIdentifier("documentInactivePagePreview")
    }
}
