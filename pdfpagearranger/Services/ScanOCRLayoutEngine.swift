import CoreGraphics
import Foundation

enum ScanOCRLayoutEngine {
    static func buildPage(
        pageID: UUID,
        imagePixelSize: CGSize,
        rawLines: [OCRLine],
        status: ScanOCRRecognitionStatus,
        errorMessage: String?,
        recognitionRevision: String = ScanOCRFingerprint.recognitionRevision
    ) -> OCRPage {
        let orderedLines = assignReadingOrder(rawLines)
        let paragraphs = groupIntoParagraphs(orderedLines)
        return OCRPage(
            pageID: pageID,
            imagePixelSize: imagePixelSize,
            recognitionRevision: recognitionRevision,
            status: status,
            errorMessage: errorMessage,
            paragraphs: paragraphs
        )
    }

    static func assignReadingOrder(_ lines: [OCRLine]) -> [OCRLine] {
        guard !lines.isEmpty else { return [] }

        let columns = detectColumns(lines)
        var ordered: [OCRLine] = []
        ordered.reserveCapacity(lines.count)

        for columnLines in columns {
            let sorted = columnLines.sorted { lhs, rhs in
                let lhsTop = lhs.normalizedBoundingBox.y + lhs.normalizedBoundingBox.height
                let rhsTop = rhs.normalizedBoundingBox.y + rhs.normalizedBoundingBox.height
                if abs(lhsTop - rhsTop) > 0.0001 {
                    return lhsTop > rhsTop
                }
                return lhs.normalizedBoundingBox.x < rhs.normalizedBoundingBox.x
            }
            ordered.append(contentsOf: sorted)
        }

        return ordered.enumerated().map { index, line in
            OCRLine(
                id: line.id,
                text: line.text,
                normalizedBoundingBox: line.normalizedBoundingBox,
                confidence: line.confidence,
                recognitionOrder: index
            )
        }
    }

    static func groupIntoParagraphs(_ lines: [OCRLine]) -> [OCRParagraph] {
        guard !lines.isEmpty else { return [] }

        var paragraphs: [OCRParagraph] = []
        var currentLines: [OCRLine] = [lines[0]]
        let medianHeight = medianLineHeight(lines)

        for index in 1..<lines.count {
            let previous = lines[index - 1]
            let current = lines[index]
            if shouldStartNewParagraph(between: previous, and: current, medianHeight: medianHeight) {
                paragraphs.append(OCRParagraph(lines: currentLines))
                currentLines = [current]
            } else {
                currentLines.append(current)
            }
        }

        paragraphs.append(OCRParagraph(lines: currentLines))
        return paragraphs
    }

    static func detectColumns(_ lines: [OCRLine]) -> [[OCRLine]] {
        guard lines.count > 1 else { return [lines] }

        let sortedByX = lines.sorted {
            $0.normalizedBoundingBox.x + ($0.normalizedBoundingBox.width / 2)
                < $1.normalizedBoundingBox.x + ($1.normalizedBoundingBox.width / 2)
        }

        var largestGap: CGFloat = 0
        var splitAfterIndex = -1
        for index in 0..<(sortedByX.count - 1) {
            let left = sortedByX[index]
            let right = sortedByX[index + 1]
            let leftMaxX = left.normalizedBoundingBox.x + left.normalizedBoundingBox.width
            let gap = right.normalizedBoundingBox.x - leftMaxX
            if gap > largestGap {
                largestGap = gap
                splitAfterIndex = index
            }
        }

        guard largestGap >= 0.12, splitAfterIndex >= 0 else {
            return [lines]
        }

        let leftColumnIDs = Set(sortedByX[...splitAfterIndex].map(\.id))
        let left = lines.filter { leftColumnIDs.contains($0.id) }
        let right = lines.filter { !leftColumnIDs.contains($0.id) }
        return [left, right]
    }

    private static func shouldStartNewParagraph(
        between previous: OCRLine,
        and current: OCRLine,
        medianHeight: CGFloat
    ) -> Bool {
        let previousBox = previous.normalizedBoundingBox.cgRect
        let currentBox = current.normalizedBoundingBox.cgRect

        let verticalGap = previousBox.minY - (currentBox.maxY)
        let verticalThreshold = max(medianHeight * 1.35, 0.012)
        if verticalGap > verticalThreshold {
            return true
        }

        let overlap = horizontalOverlap(previousBox, currentBox)
        if overlap < 0.25 {
            return true
        }

        let previousHeight = previousBox.height
        let currentHeight = currentBox.height
        let averageHeight = max((previousHeight + currentHeight) / 2, 0.001)
        if abs(previousHeight - currentHeight) / averageHeight > 0.65 {
            return true
        }

        return false
    }

    private static func horizontalOverlap(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let overlapLeft = max(lhs.minX, rhs.minX)
        let overlapRight = min(lhs.maxX, rhs.maxX)
        let overlapWidth = max(0, overlapRight - overlapLeft)
        guard overlapWidth > 0 else { return 0 }
        let minimumWidth = min(lhs.width, rhs.width)
        guard minimumWidth > 0 else { return 0 }
        return overlapWidth / minimumWidth
    }

    private static func medianLineHeight(_ lines: [OCRLine]) -> CGFloat {
        let heights = lines.map { CGFloat($0.normalizedBoundingBox.height) }.sorted()
        guard !heights.isEmpty else { return 0.02 }
        return heights[heights.count / 2]
    }
}
