import Foundation
import PhotosUI
import SwiftUI

protocol ScanPhotosAssetLoading: Sendable {
    func loadImageData(for item: ScanOrderedPhotoImportItem) async throws -> Data
}

enum ScanPhotosOrderedItemsBuilder {
    static func orderedItems(from pickerItems: [PhotosPickerItem]) -> [ScanOrderedPhotoImportItem] {
        pickerItems.enumerated().map { index, item in
            ScanOrderedPhotoImportItem(
                selectionIndex: index,
                itemIdentifier: itemIdentifier(for: item, selectionIndex: index)
            )
        }
    }

    static func itemIdentifier(for item: PhotosPickerItem, selectionIndex: Int) -> String {
        item.itemIdentifier ?? "selection-\(selectionIndex)"
    }
}

struct PhotosPickerItemAssetLoader: ScanPhotosAssetLoading {
    private let itemsByIdentifier: [String: PhotosPickerItem]

    init(items: [PhotosPickerItem]) {
        var lookup: [String: PhotosPickerItem] = [:]
        lookup.reserveCapacity(items.count)
        for (index, item) in items.enumerated() {
            let identifier = ScanPhotosOrderedItemsBuilder.itemIdentifier(for: item, selectionIndex: index)
            lookup[identifier] = item
        }
        self.itemsByIdentifier = lookup
    }

    func loadImageData(for item: ScanOrderedPhotoImportItem) async throws -> Data {
        guard let pickerItem = itemsByIdentifier[item.itemIdentifier] else {
            throw ScanDraftError.photosAssetLoadFailure
        }
        guard let data = try await pickerItem.loadTransferable(type: Data.self), !data.isEmpty else {
            throw ScanDraftError.photosAssetLoadFailure
        }
        return data
    }
}
