import Foundation

/// Loads ordered Photos picker selections and persists them into the active draft session.
struct ScanPhotosSelectionImporter: Sendable {
    let storage: ScanDraftSessionStorage
    let scanImporter: ScanCameraScanImporter

    init(
        storage: ScanDraftSessionStorage = ScanDraftSessionStorage(),
        scanImporter: ScanCameraScanImporter? = nil
    ) {
        self.storage = storage
        self.scanImporter = scanImporter ?? ScanCameraScanImporter(storage: storage)
    }

    func importPhotos(
        orderedItems: [ScanOrderedPhotoImportItem],
        assetLoader: any ScanPhotosAssetLoading,
        sessionDirectory: URL,
        sessionDefaults: ScanVisualAdjustments,
        progressHandler: @Sendable (ScanPhotosImportProgress) -> Void = { _ in },
        isCancelled: @Sendable () -> Bool = { false }
    ) async throws -> [ScanDraftPage] {
        let sortedItems = orderedItems.sorted { $0.selectionIndex < $1.selectionIndex }
        guard !sortedItems.isEmpty else {
            throw ScanDraftError.emptyDraft
        }

        try ScanImportStorageValidator.validateCapacity(for: sortedItems.count)

        return try await scanImporter.importPages(
            pageCount: sortedItems.count,
            sourceType: .photos,
            sessionDirectory: sessionDirectory,
            sessionDefaults: sessionDefaults,
            progressHandler: { completed, total in
                progressHandler(ScanPhotosImportProgress(total: total, completed: completed))
            },
            isCancelled: isCancelled
        ) { index in
            let item = sortedItems[index]
            let rawData = try await assetLoader.loadImageData(for: item)
            let prepared = try ScanWorkingImageEncoder.preparedImportPayload(from: rawData)
            return ScanImportPagePayload(data: prepared.data, fileExtension: prepared.fileExtension)
        }
    }
}
