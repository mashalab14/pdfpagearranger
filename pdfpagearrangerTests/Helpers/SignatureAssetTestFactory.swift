import UIKit
@testable import pdfpagearranger

enum SignatureAssetTestFactory {
    static func makePNGData(
        color: UIColor = .black,
        size: CGSize = CGSize(width: 120, height: 48)
    ) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 8, y: size.height * 0.6))
            path.addCurve(
                to: CGPoint(x: size.width - 8, y: size.height * 0.45),
                controlPoint1: CGPoint(x: size.width * 0.35, y: size.height * 0.2),
                controlPoint2: CGPoint(x: size.width * 0.65, y: size.height * 0.85)
            )
            path.lineWidth = 3
            path.stroke()
        }
        return image.pngData() ?? Data()
    }

    static func makeTemporaryStoreDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SignatureLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
