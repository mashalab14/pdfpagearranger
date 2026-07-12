import UIKit
@testable import pdfpagearranger

enum ScanDraftTestFactory {
    static func makeTestImageData(
        size: CGSize = CGSize(width: 200, height: 280),
        color: UIColor = .white
    ) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }

    static func makeIsolatedStorage() -> ScanDraftSessionStorage {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanDraftTests-\(UUID().uuidString)", isDirectory: true)
        return ScanDraftSessionStorage(sessionsRoot: root)
    }

    static func makeDraftWithPages(
        count: Int,
        storage: ScanDraftSessionStorage? = nil
    ) throws -> (ScanDraftDocument, ScanDraftSessionStorage, URL) {
        let storage = storage ?? makeIsolatedStorage()
        var document = ScanDraftDocument()
        let sessionDirectory = try storage.createSessionDirectory(for: document.id)

        for index in 0..<count {
            let page = try storage.importOriginalImage(
                data: makeTestImageData(),
                pageID: UUID(),
                sourceType: index.isMultiple(of: 2) ? .camera : .photos,
                sessionDirectory: sessionDirectory
            )
            document.addPage(page)
        }

        return (document, storage, sessionDirectory)
    }
}
