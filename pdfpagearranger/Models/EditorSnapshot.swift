import Foundation

struct EditorSnapshot: Equatable {
    let pages: [PageItem]
    let pageObjectsByPage: [UUID: [PageObject]]
    let overlayRevisions: [UUID: Int]
}
