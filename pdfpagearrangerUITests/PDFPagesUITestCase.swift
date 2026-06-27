import XCTest

class PDFPagesUITestCase: XCTestCase {
    var app: XCUIApplication!
    private var tempPDFURLs: [URL] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = []
    }

    override func tearDownWithError() throws {
        for url in tempPDFURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempPDFURLs.removeAll()
        app = nil
    }

    @discardableResult
    func launchWithImportedPDF(pageCount: Int = 4, seedOverlay: Bool = false) throws -> URL {
        app.launchArguments = ["-uiTestAutoImportPages", String(pageCount)]
        if seedOverlay {
            app.launchArguments.append("-uiTestSeedOverlay")
        }
        app.launch()

        let documentReady = app.descendants(matching: .any)["documentModeReady"]
        XCTAssertTrue(documentReady.waitForExistence(timeout: 20), "Document Mode should open after import")

        let firstThumbnail = app.descendants(matching: .any)["pageThumbnail_1"]
        XCTAssertTrue(firstThumbnail.waitForExistence(timeout: 20), "First page thumbnail should render after import")
        return URL(fileURLWithPath: "/UITest/AutoImport-\(pageCount).pdf")
    }

    func waitForThumbnail(pageNumber: Int, timeout: TimeInterval = 15) -> XCUIElement {
        let thumbnail = app.descendants(matching: .any)["pageThumbnail_\(pageNumber)"]
        XCTAssertTrue(thumbnail.waitForExistence(timeout: timeout), "Thumbnail \(pageNumber) should appear")
        return thumbnail
    }
}
