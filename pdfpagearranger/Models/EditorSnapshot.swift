import UIKit

struct EditorSnapshot {
    static let maxHistoryDepth = 50

    let pages: [PageItem]
    let pageObjectsByPage: [UUID: [PageObject]]
    let annotationsByPage: [UUID: [PageAnnotation]]
    let overlayRevisions: [UUID: Int]
    let imageAssets: [UUID: UIImage]
    let pageNumberSettings: PageNumberSettings
    let watermarkSettings: WatermarkSettings
}
