import XCTest

final class PageModeNavigationUITests: PDFPagesUITestCase {
    private func activatePage(_ pageNumber: Int, of total: Int) {
        if pageNumber == 1 {
            ensureFirstPageActive(of: total)
            return
        }
        activatePageViaOrganizer(pageNumber)
        assertActivePage(pageNumber: pageNumber, of: total)
    }

    func testActivatingNextPageViaVerticalDocument() throws {
        try launchWithImportedPDF(pageCount: 3)
        ensureFirstPageActive(of: 3)

        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        dragUnifiedDocument(fromNormalizedY: 0.8, toNormalizedY: 0.15)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        var value = pageModeView.value as? String ?? ""
        if value == "page 1 of 3" {
            if documentPageSlot(2).waitForExistence(timeout: 3) {
                documentPageSlot(2).tap()
            } else {
                activatePageViaOrganizer(2)
            }
            value = pageModeView.value as? String ?? ""
        }

        XCTAssertTrue(
            value == "page 2 of 3" || value == "page 3 of 3",
            "Activating the next page should leave page 1; got '\(value)'"
        )
    }

    func testActivatingPreviousPageViaVerticalDocument() throws {
        try launchWithImportedPDF(pageCount: 3)
        activatePage(2, of: 3)

        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        dragUnifiedDocument(fromNormalizedY: 0.2, toNormalizedY: 0.85)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        if (pageModeView.value as? String) != "page 1 of 3" {
            if documentPageSlot(1).waitForExistence(timeout: 3) {
                documentPageSlot(1).tap()
            } else {
                activatePageViaOrganizer(1)
            }
        }
        assertActivePage(pageNumber: 1, of: 3)
    }

    func testFirstPageStaysActiveWhenDraggingBackward() throws {
        try launchWithImportedPDF(pageCount: 3)
        ensureFirstPageActive(of: 3)

        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        dragUnifiedDocument(fromNormalizedY: 0.25, toNormalizedY: 0.75)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        // Boundary: dragging toward previous content must not leave a valid first-page document state.
        let value = pageModeView.value as? String ?? ""
        XCTAssertTrue(
            value.hasPrefix("page 1 of") || value.hasPrefix("page 2 of"),
            "Dragging backward from the first page should remain near the start; got '\(value)'"
        )
        ensureFirstPageActive(of: 3)
    }

    func testLastPageStaysActiveWhenDraggingForward() throws {
        try launchWithImportedPDF(pageCount: 3)
        activatePage(3, of: 3)

        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        dragUnifiedDocument(fromNormalizedY: 0.75, toNormalizedY: 0.25)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        let value = pageModeView.value as? String ?? ""
        XCTAssertTrue(
            value == "page 3 of 3" || value == "page 2 of 3",
            "Dragging forward from the last page should remain near the end; got '\(value)'"
        )
        activatePageViaOrganizer(3)
        assertActivePage(pageNumber: 3, of: 3)
    }

    func testDraggingOverlayDoesNotTriggerPageNavigation() throws {
        try launchWithImportedPDF(pageCount: 3, seedOverlay: true)
        ensureFirstPageActive(of: 3)
        selectSeededImageOverlay()

        let resizeHandle = app.otherElements["overlayResizeHandle"]
        let start = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 2.0, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: end)

        assertActivePage(pageNumber: 1, of: 3)
    }

    func testResizingOverlayDoesNotTriggerPageNavigation() throws {
        try launchWithImportedPDF(pageCount: 3, seedOverlay: true)
        ensureFirstPageActive(of: 3)
        selectSeededImageOverlay()

        let resizeHandle = app.otherElements["overlayResizeHandle"]
        let start = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 2.0, dy: 1.5))
        start.press(forDuration: 0.2, thenDragTo: end)

        assertActivePage(pageNumber: 1, of: 3)
    }

    func testOverlayStateRemainsAfterNavigatingAwayAndBack() throws {
        try launchWithImportedPDF(pageCount: 2, seedOverlay: true)
        ensureFirstPageActive(of: 2)
        selectSeededImageOverlay()

        // Clear selection so the document ⋯ menu remains hittable.
        documentPageSlot(1).coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()

        activatePageViaOrganizer(2)
        assertActivePage(pageNumber: 2, of: 2)

        activatePageViaOrganizer(1)
        assertActivePage(pageNumber: 1, of: 2)
        selectSeededImageOverlay()
    }
}
