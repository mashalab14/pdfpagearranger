import XCTest
@testable import pdfpagearranger

final class SignatureLibraryStoreRegressionTests: XCTestCase {
    private var tempDirectories: [URL] = []
    private var store: SignatureLibraryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let directory = try SignatureAssetTestFactory.makeTemporaryStoreDirectory()
        tempDirectories.append(directory)
        store = SignatureLibraryStore(rootDirectory: directory)
    }

    override func tearDownWithError() throws {
        for directory in tempDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectories.removeAll()
        store = nil
        try super.tearDownWithError()
    }

    func testSavingSignatureCreatesMetadataAndImageFile() throws {
        let imageData = SignatureAssetTestFactory.makePNGData()

        let asset = try store.saveSignature(
            imageData: imageData,
            sourceType: .drawn,
            displayName: "My Signature"
        )

        XCTAssertEqual(asset.displayName, "My Signature")
        XCTAssertEqual(asset.sourceType, .drawn)
        XCTAssertTrue(store.hasImageFile(for: asset))
        XCTAssertEqual(store.loadImageData(for: asset), imageData)
        XCTAssertNotNil(store.getSignature(id: asset.id))
    }

    func testListingSignaturesReturnsSavedSignatures() throws {
        let first = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .black),
            sourceType: .drawn,
            displayName: "First"
        )
        let second = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .blue),
            sourceType: .photo,
            displayName: "Second"
        )

        let listed = store.listSignatures()
        XCTAssertEqual(Set(listed.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(listed.count, 2)
        XCTAssertGreaterThanOrEqual(listed[0].createdAt, listed[1].createdAt)
    }

    func testGettingSignatureByIDReturnsCorrectMetadata() throws {
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .importedImage,
            displayName: "Imported"
        )

        let fetched = try XCTUnwrap(store.getSignature(id: asset.id))
        XCTAssertEqual(fetched.id, asset.id)
        XCTAssertEqual(fetched.displayName, "Imported")
        XCTAssertEqual(fetched.sourceType, .importedImage)
        XCTAssertEqual(fetched.imageFileName, asset.imageFileName)
        XCTAssertEqual(fetched.thumbnailFileName, asset.thumbnailFileName)
    }

    func testDeletingSignatureRemovesMetadataAndImageFile() throws {
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn
        )

        XCTAssertTrue(store.hasImageFile(for: asset))
        store.deleteSignature(id: asset.id)

        XCTAssertNil(store.getSignature(id: asset.id))
        XCTAssertFalse(store.hasImageFile(for: asset))
        XCTAssertTrue(store.listSignatures().isEmpty)
    }

    func testDeletingMissingSignatureDoesNotCrash() {
        store.deleteSignature(id: UUID())
        XCTAssertTrue(store.listSignatures().isEmpty)
    }

    func testMissingImageFileIsHandledGracefully() throws {
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn
        )

        try FileManager.default.removeItem(at: store.imageURL(for: asset))

        XCTAssertNotNil(store.getSignature(id: asset.id))
        XCTAssertNil(store.loadImageData(for: asset))
        XCTAssertFalse(store.hasImageFile(for: asset))
    }

    func testMultipleSignaturesAreListedNewestFirst() throws {
        let oldest = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .black),
            sourceType: .drawn,
            displayName: "Oldest"
        )
        let middle = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .blue),
            sourceType: .photo,
            displayName: "Middle"
        )
        let newest = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .red),
            sourceType: .importedImage,
            displayName: "Newest"
        )

        let listed = store.listSignatures()
        XCTAssertEqual(Set(listed.map(\.id)), Set([oldest.id, middle.id, newest.id]))
        XCTAssertEqual(listed.count, 3)

        for index in 0..<(listed.count - 1) {
            XCTAssertGreaterThanOrEqual(
                listed[index].createdAt,
                listed[index + 1].createdAt,
                "Signatures should be listed newest first by createdAt"
            )
        }
    }

    func testCorruptMetadataFileReturnsEmptyListWithoutCrashing() throws {
        let metadataURL = tempDirectories[0].appendingPathComponent(SignatureLibraryStore.metadataFileName)
        try Data("not-json".utf8).write(to: metadataURL)

        XCTAssertTrue(store.listSignatures().isEmpty)
        XCTAssertNil(store.getSignature(id: UUID()))
    }

    func testSaveSignatureRejectsEmptyImageData() {
        XCTAssertThrowsError(
            try store.saveSignature(imageData: Data(), sourceType: .drawn)
        ) { error in
            XCTAssertEqual(error as? SignatureLibraryStoreError, .emptyImageData)
        }
    }

    func testRenamingUpdatesDisplayName() throws {
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn,
            displayName: "Original"
        )

        let renamed = try store.renameSignature(id: asset.id, newDisplayName: "Updated Name")

        XCTAssertEqual(renamed.displayName, "Updated Name")
        XCTAssertEqual(store.getSignature(id: asset.id)?.displayName, "Updated Name")
    }

    func testRenamingTrimsWhitespaceFromDisplayName() throws {
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn,
            displayName: "Original"
        )

        let renamed = try store.renameSignature(id: asset.id, newDisplayName: "  Trimmed Name  ")

        XCTAssertEqual(renamed.displayName, "Trimmed Name")
    }

    func testRenamingUpdatesUpdatedAt() throws {
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn,
            displayName: "Original"
        )

        _ = try store.renameSignature(id: asset.id, newDisplayName: "First Rename")
        let afterFirstRename = try XCTUnwrap(store.getSignature(id: asset.id))

        Thread.sleep(forTimeInterval: 1.1)
        _ = try store.renameSignature(id: asset.id, newDisplayName: "Second Rename")
        let afterSecondRename = try XCTUnwrap(store.getSignature(id: asset.id))

        XCTAssertGreaterThan(afterSecondRename.updatedAt, afterFirstRename.updatedAt)
    }

    func testRenamingPersistsAfterReloadingStore() throws {
        let directory = tempDirectories[0]
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn,
            displayName: "Before Reload"
        )

        _ = try store.renameSignature(id: asset.id, newDisplayName: "After Reload")

        let reloadedStore = SignatureLibraryStore(rootDirectory: directory)
        let fetched = try XCTUnwrap(reloadedStore.getSignature(id: asset.id))
        XCTAssertEqual(fetched.displayName, "After Reload")
    }

    func testRenamingOneSignatureDoesNotAffectOthers() throws {
        let first = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .black),
            sourceType: .drawn,
            displayName: "First"
        )
        let second = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .blue),
            sourceType: .drawn,
            displayName: "Second"
        )

        _ = try store.renameSignature(id: first.id, newDisplayName: "First Renamed")

        XCTAssertEqual(store.getSignature(id: first.id)?.displayName, "First Renamed")
        XCTAssertEqual(store.getSignature(id: second.id)?.displayName, "Second")
    }

    func testRenamingNonExistentSignatureFailsGracefully() {
        XCTAssertThrowsError(
            try store.renameSignature(id: UUID(), newDisplayName: "Missing")
        ) { error in
            XCTAssertEqual(error as? SignatureLibraryStoreError, .signatureNotFound)
        }
    }

    func testRenamingRejectsEmptyOrWhitespaceOnlyNames() throws {
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn,
            displayName: "Original"
        )

        XCTAssertThrowsError(
            try store.renameSignature(id: asset.id, newDisplayName: "")
        ) { error in
            XCTAssertEqual(error as? SignatureLibraryStoreError, .emptyDisplayName)
        }

        XCTAssertThrowsError(
            try store.renameSignature(id: asset.id, newDisplayName: "   ")
        ) { error in
            XCTAssertEqual(error as? SignatureLibraryStoreError, .emptyDisplayName)
        }

        XCTAssertEqual(store.getSignature(id: asset.id)?.displayName, "Original")
    }

    func testImageFilesRemainUnchangedAfterRename() throws {
        let imageData = SignatureAssetTestFactory.makePNGData()
        let asset = try store.saveSignature(
            imageData: imageData,
            sourceType: .drawn,
            displayName: "Original"
        )
        let imageURL = store.imageURL(for: asset)
        let imageDataBeforeRename = try Data(contentsOf: imageURL)
        let imageFileNameBeforeRename = asset.imageFileName
        let thumbnailFileNameBeforeRename = asset.thumbnailFileName

        let renamed = try store.renameSignature(id: asset.id, newDisplayName: "Renamed")

        XCTAssertEqual(renamed.imageFileName, imageFileNameBeforeRename)
        XCTAssertEqual(renamed.thumbnailFileName, thumbnailFileNameBeforeRename)
        XCTAssertEqual(renamed.id, asset.id)
        XCTAssertEqual(try Data(contentsOf: imageURL), imageDataBeforeRename)
        XCTAssertTrue(store.hasImageFile(for: renamed))
    }
}
