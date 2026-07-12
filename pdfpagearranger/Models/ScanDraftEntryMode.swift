import Foundation

/// Direct entry mode when launching the scan draft flow from the home screen.
enum ScanDraftEntryMode: Identifiable, Equatable {
    case camera
    case photos

    var id: Self { self }
}
