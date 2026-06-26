import Foundation

struct PageItem: Identifiable, Equatable, Codable, Hashable {
    let id: UUID
    let originalPageIndex: Int
    var rotation: Int
    /// When this page was created via duplicate, references the source page item's id.
    var duplicateSourceID: UUID?

    init(
        originalPageIndex: Int,
        rotation: Int = 0,
        duplicateSourceID: UUID? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.originalPageIndex = originalPageIndex
        self.rotation = rotation
        self.duplicateSourceID = duplicateSourceID
    }

    func rotated() -> PageItem {
        var copy = self
        copy.rotation = (rotation + 90) % 360
        return copy
    }

    func duplicated() -> PageItem {
        PageItem(
            originalPageIndex: originalPageIndex,
            rotation: rotation,
            duplicateSourceID: id
        )
    }
}
