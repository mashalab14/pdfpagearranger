import Foundation
@testable import pdfpagearranger

final class MockScanPhotosAssetLoader: ScanPhotosAssetLoading, @unchecked Sendable {
    var payloadsByIdentifier: [String: Data] = [:]
    private(set) var loadedIdentifiers: [String] = []
    var loadDelayNanoseconds: UInt64 = 0
    var failingIdentifiers: Set<String> = []

    func loadImageData(for item: ScanOrderedPhotoImportItem) async throws -> Data {
        if Task.isCancelled {
            throw ScanDraftError.photosImportCancelled
        }
        if loadDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: loadDelayNanoseconds)
        }
        if Task.isCancelled {
            throw ScanDraftError.photosImportCancelled
        }
        loadedIdentifiers.append(item.itemIdentifier)
        if failingIdentifiers.contains(item.itemIdentifier) {
            throw ScanDraftError.photosAssetLoadFailure
        }
        guard let data = payloadsByIdentifier[item.itemIdentifier], !data.isEmpty else {
            throw ScanDraftError.photosAssetLoadFailure
        }
        return data
    }
}

enum ScanPhotosImportTestSupport {
    static func makeOrderedItems(count: Int) -> [ScanOrderedPhotoImportItem] {
        (0..<count).map { index in
            ScanOrderedPhotoImportItem(
                selectionIndex: index,
                itemIdentifier: "photo-\(index)"
            )
        }
    }

    static func makeLoader(
        count: Int,
        imageData: Data? = nil
    ) -> MockScanPhotosAssetLoader {
        let loader = MockScanPhotosAssetLoader()
        let data = imageData ?? ScanDraftTestFactory.makeTestImageData()
        for index in 0..<count {
            loader.payloadsByIdentifier["photo-\(index)"] = data
        }
        return loader
    }
}
