import Foundation

enum ScanImportStorageValidator {
    /// Conservative per-image estimate used before import begins.
    static let bytesPerImageEstimate: Int64 = 8_000_000
    static let safetyMarginBytes: Int64 = 50_000_000

    static func validateCapacity(for itemCount: Int) throws {
        guard itemCount > 0 else { return }
        let required = Int64(itemCount) * bytesPerImageEstimate + safetyMarginBytes
        let available = try availableCapacity()
        guard available >= required else {
            throw ScanDraftError.insufficientStorage
        }
    }

    private static func availableCapacity() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }
}
