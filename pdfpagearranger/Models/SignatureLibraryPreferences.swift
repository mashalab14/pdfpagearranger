import Foundation

struct SignatureLibraryPreferences: Equatable, Codable {
    var defaultSignatureID: UUID?

    static let empty = SignatureLibraryPreferences(defaultSignatureID: nil)
}
