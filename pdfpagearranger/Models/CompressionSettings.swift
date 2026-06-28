import Foundation

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
            return "Best visual fidelity with modest size savings."
        case .balanced:
            return "Recommended balance of quality and file size."
        case .smallestFile:
            return "Smallest size; image-heavy pages may lose sharpness."
        }
    }

    var jpegQuality: CGFloat {
        switch self {
        case .highestQuality:
            return 0.88
        case .balanced:
            return 0.62
        case .smallestFile:
            return 0.42
        }
    }

    var maxImageDimension: CGFloat {
        switch self {
        case .highestQuality:
            return 2_400
        case .balanced:
            return 1_600
        case .smallestFile:
            return 1_050
        }
    }

    var usesImageDownsampling: Bool {
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
            ratio = 0.88
        case .balanced:
            ratio = 0.58
        case .smallestFile:
            ratio = 0.38
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
