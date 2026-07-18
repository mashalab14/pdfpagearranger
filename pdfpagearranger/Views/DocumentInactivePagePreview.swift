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
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(
                        isActiveChrome ? Color.accentColor.opacity(0.85) : Color.clear,
                        lineWidth: isActiveChrome ? 2 : 0
                    )
            }
            .accessibilityIdentifier("documentInactivePagePreview")
    }
}
