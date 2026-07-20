import SwiftUI
import UIKit

/// Full-width inactive page preview used in the unified vertical document scroller.
/// Sheet chrome (shared base shadow + active halo) is applied by the parent slot so
/// active and inactive pages keep an identical layout footprint.
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
            .accessibilityIdentifier("documentInactivePagePreview")
    }
}
