import Foundation
import PDFKit

enum CompressionPreset: String, CaseIterable, Identifiable, Codable {
    case highestQuality
    case balanced
    case smallestFile

    var id: String { rawValue }

    static let `default`: CompressionPreset = .balanced

    var title: String {
        switch self {
        case .highestQuality:
            return "Highest Quality"
        case .balanced:
            return "Balanced"
        case .smallestFile:
            return "Smallest File"
        }
    }

    var detail: String {
        switch self {
        case .highestQuality:
            return "Preserves all vector content; removes only redundant producer metadata."
        case .balanced:
            return "Recommended balance that keeps text and links while trimming document metadata."
        case .smallestFile:
            return "Most aggressive metadata cleanup while keeping pages fully vector."
        }
    }

    var metadataKeysToRemove: [String] {
        switch self {
        case .highestQuality:
            return [PDFDocumentAttribute.producerAttribute.rawValue]
        case .balanced:
            return [
                PDFDocumentAttribute.producerAttribute.rawValue,
                PDFDocumentAttribute.creatorAttribute.rawValue,
                PDFDocumentAttribute.keywordsAttribute.rawValue,
            ]
        case .smallestFile:
            return [
                PDFDocumentAttribute.producerAttribute.rawValue,
                PDFDocumentAttribute.creatorAttribute.rawValue,
                PDFDocumentAttribute.keywordsAttribute.rawValue,
                PDFDocumentAttribute.authorAttribute.rawValue,
                PDFDocumentAttribute.subjectAttribute.rawValue,
                PDFDocumentAttribute.titleAttribute.rawValue,
            ]
        }
    }

    var stripsLargeCustomMetadata: Bool {
        switch self {
        case .highestQuality:
            return false
        case .balanced, .smallestFile:
            return true
        }
    }

    func estimatedCompressedBytes(from originalBytes: Int64) -> Int64? {
        guard originalBytes > 0 else { return nil }
        let ratio: Double
        switch self {
        case .highestQuality:
            ratio = 0.92
        case .balanced:
            ratio = 0.82
        case .smallestFile:
            ratio = 0.72
        }
        return Int64((Double(originalBytes) * ratio).rounded(.down))
    }
}

struct CompressionSettings: Equatable {
    let preset: CompressionPreset
}

struct CompressionResult: Equatable {
    let outputURL: URL
    let originalByteCount: Int64
    let compressedByteCount: Int64

    var bytesSaved: Int64 {
        max(originalByteCount - compressedByteCount, 0)
    }

    var percentSaved: Double {
        guard originalByteCount > 0 else { return 0 }
        return (Double(bytesSaved) / Double(originalByteCount)) * 100
    }

    var meaningfulCompression: Bool {
        compressedByteCount < Int64(Double(originalByteCount) * 0.98)
    }
}

struct CompressionPreparedInput: Equatable {
    let exportURL: URL
    let byteCount: Int64
}
