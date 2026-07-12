import XCTest
@testable import pdfpagearranger

final class RecentTextsSettingsRegressionTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "RecentTextsSettingsTests-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testCommittedTextIsStoredMostRecentFirst() {
        RecentTextsSettings.recordCommittedText("Alpha", in: defaults)
        RecentTextsSettings.recordCommittedText("Beta", in: defaults)

        XCTAssertEqual(RecentTextsSettings.storedEntries(in: defaults), ["Beta", "Alpha"])
    }

    func testCancelledTextIsNotStoredAutomatically() {
        RecentTextsSettings.recordCommittedText("   ", in: defaults)
        XCTAssertTrue(RecentTextsSettings.storedEntries(in: defaults).isEmpty)
    }

    func testEmptyTextIsNotStored() {
        RecentTextsSettings.recordCommittedText("", in: defaults)
        XCTAssertTrue(RecentTextsSettings.storedEntries(in: defaults).isEmpty)
    }

    func testDuplicateHandlingMovesEntryToFront() {
        RecentTextsSettings.recordCommittedText("Alpha", in: defaults)
        RecentTextsSettings.recordCommittedText("Beta", in: defaults)
        RecentTextsSettings.recordCommittedText("Alpha", in: defaults)

        XCTAssertEqual(RecentTextsSettings.storedEntries(in: defaults), ["Alpha", "Beta"])
    }

    func testMaximumHistorySizeIsBounded() {
        for index in 0..<12 {
            RecentTextsSettings.recordCommittedText("Entry \(index)", in: defaults)
        }

        let entries = RecentTextsSettings.storedEntries(in: defaults)
        XCTAssertEqual(entries.count, RecentTextsSettings.maxEntryCount)
        XCTAssertEqual(entries.first, "Entry 11")
    }

    func testRemovalDeletesEntry() {
        RecentTextsSettings.recordCommittedText("Keep", in: defaults)
        RecentTextsSettings.recordCommittedText("Remove", in: defaults)
        RecentTextsSettings.removeEntry("Remove", in: defaults)

        XCTAssertEqual(RecentTextsSettings.storedEntries(in: defaults), ["Keep"])
    }

    func testLocalPersistenceRoundTrip() {
        RecentTextsSettings.recordCommittedText("Line one\nLine two", in: defaults)
        XCTAssertEqual(RecentTextsSettings.storedEntries(in: defaults).first, "Line one\nLine two")
    }
}
