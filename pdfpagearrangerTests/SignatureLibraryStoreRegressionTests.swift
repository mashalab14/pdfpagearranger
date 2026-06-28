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
}
