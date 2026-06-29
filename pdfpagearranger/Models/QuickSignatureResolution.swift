import Foundation

enum QuickSignatureResolution: Equatable {
    case placeImmediately(SignatureAsset)
    case openLibrary(showDefaultGuidanceBanner: Bool)
}
