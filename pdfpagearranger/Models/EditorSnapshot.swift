import UIKit

struct EditorSnapshot {
    let pages: [PageItem]
    let pageObjectsByPage: [UUID: [PageObject]]
    let overlayRevisions: [UUID: Int]
    let imageAssets: [UUID: UIImage]
    let pageNumberSettings: PageNumberSettings
}
