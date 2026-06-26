import Foundation

@Observable
final class ProGate {
    static let freePageExportLimit = 20

    var isProUnlocked: Bool = false

    func canExport(pageCount: Int) -> Bool {
        isProUnlocked || pageCount <= Self.freePageExportLimit
    }

    func requiresPaywall(pageCount: Int) -> Bool {
        !canExport(pageCount: pageCount)
    }

    /// Development bypass — allows export after dismissing the paywall placeholder.
    func unlockForDevelopment() {
        isProUnlocked = true
    }
}
