import Foundation
import UIKit

/// Maps between plain body text (stored in drafts/spans) and display text that includes list markers.
enum TextOverlayListEditingEngine {
    struct LineMapping: Equatable {
        let plainStart: Int
        let plainLength: Int
        let prefixUTF16Length: Int
        let displayStart: Int

        var plainEnd: Int { plainStart + plainLength }
        var displayBodyStart: Int { displayStart + prefixUTF16Length }
        var displayEnd: Int { displayBodyStart + plainLength }
    }

    static func lineMappings(
        plainText: String,
        listMode: TextOverlayListMode,
        listIndent: Int
    ) -> [LineMapping] {
        let lines = plainText.components(separatedBy: "\n")
        var mappings: [LineMapping] = []
        var plainCursor = 0
        var displayCursor = 0
        var number = 1

        for (index, line) in lines.enumerated() {
            let plainLength = (line as NSString).length
            let prefix = prefixString(
                listMode: listMode,
                listIndent: listIndent,
                number: number
            )
            if listMode == .numbered {
                number += 1
            }

            mappings.append(
                LineMapping(
                    plainStart: plainCursor,
                    plainLength: plainLength,
                    prefixUTF16Length: (prefix as NSString).length,
                    displayStart: displayCursor
                )
            )

            plainCursor += plainLength + (index < lines.count - 1 ? 1 : 0)
            displayCursor += (prefix as NSString).length + plainLength + (index < lines.count - 1 ? 1 : 0)
        }
        return mappings
    }

    static func prefixString(
        listMode: TextOverlayListMode,
        listIndent: Int,
        number: Int
    ) -> String {
        let indent = String(repeating: "    ", count: min(max(listIndent, 0), TextOverlayDraft.maxListIndent))
        let marker: String
        switch listMode {
        case .plain:
            marker = ""
        case .bulleted:
            marker = "• "
        case .dashed:
            marker = "– "
        case .numbered:
            marker = "\(max(number, 1)). "
        }
        return indent + marker
    }

    static func displayUTF16Location(
        plainLocation: Int,
        plainText: String,
        listMode: TextOverlayListMode,
        listIndent: Int
    ) -> Int {
        let mappings = lineMappings(plainText: plainText, listMode: listMode, listIndent: listIndent)
        guard !mappings.isEmpty else { return 0 }
        let clamped = min(max(plainLocation, 0), (plainText as NSString).length)
        for mapping in mappings {
            if clamped <= mapping.plainEnd {
                let offset = max(0, clamped - mapping.plainStart)
                return mapping.displayBodyStart + offset
            }
        }
        return mappings.last?.displayEnd ?? 0
    }

    static func plainUTF16Location(
        displayLocation: Int,
        plainText: String,
        listMode: TextOverlayListMode,
        listIndent: Int
    ) -> Int {
        let mappings = lineMappings(plainText: plainText, listMode: listMode, listIndent: listIndent)
        guard !mappings.isEmpty else { return 0 }
        let displayLength = mappings.last.map { $0.displayEnd + (plainText.hasSuffix("\n") ? 0 : 0) } ?? 0
        // Compute full display length including newlines between lines.
        let fullDisplay = TextOverlayFormattingEngine.displayText(plainText, listMode: listMode, listIndent: listIndent)
        _ = displayLength
        let clamped = min(max(displayLocation, 0), (fullDisplay as NSString).length)

        for (index, mapping) in mappings.enumerated() {
            if clamped < mapping.displayBodyStart {
                return mapping.plainStart
            }
            if clamped <= mapping.displayEnd {
                return mapping.plainStart + (clamped - mapping.displayBodyStart)
            }
            // Between this line's end and next line start sits a newline.
            let nextStart = index + 1 < mappings.count ? mappings[index + 1].displayStart : Int.max
            if clamped < nextStart {
                return mapping.plainEnd
            }
        }
        return (plainText as NSString).length
    }

    static func displayRange(
        plainRange: NSRange,
        plainText: String,
        listMode: TextOverlayListMode,
        listIndent: Int
    ) -> NSRange {
        let start = displayUTF16Location(
            plainLocation: plainRange.location,
            plainText: plainText,
            listMode: listMode,
            listIndent: listIndent
        )
        let end = displayUTF16Location(
            plainLocation: plainRange.location + plainRange.length,
            plainText: plainText,
            listMode: listMode,
            listIndent: listIndent
        )
        return NSRange(location: start, length: max(0, end - start))
    }

    static func plainRange(
        displayRange: NSRange,
        plainText: String,
        listMode: TextOverlayListMode,
        listIndent: Int
    ) -> NSRange {
        let start = plainUTF16Location(
            displayLocation: displayRange.location,
            plainText: plainText,
            listMode: listMode,
            listIndent: listIndent
        )
        let end = plainUTF16Location(
            displayLocation: displayRange.location + displayRange.length,
            plainText: plainText,
            listMode: listMode,
            listIndent: listIndent
        )
        return NSRange(location: start, length: max(0, end - start))
    }

    /// Returns body-only attributed text with list markers/indent prefixes removed.
    static func attributedBodyStrippingMarkers(
        from attributed: NSAttributedString,
        listMode: TextOverlayListMode,
        listIndent: Int
    ) -> NSAttributedString {
        guard listMode != .plain || listIndent > 0 else { return attributed }

        let display = attributed.string
        let plain = TextOverlayFormattingEngine.plainText(from: display, listMode: listMode)
        // Rebuild by slicing body ranges from the display attributed string using mappings
        // derived from the stripped plain text (stable against partially edited markers).
        let mappings = lineMappings(plainText: plain, listMode: listMode, listIndent: listIndent)
        let result = NSMutableAttributedString()
        let displayLines = display.components(separatedBy: "\n")
        var displayCursor = 0

        for (index, line) in displayLines.enumerated() {
            let lineLength = (line as NSString).length
            let prefix: String
            if index < mappings.count {
                prefix = prefixString(
                    listMode: listMode,
                    listIndent: listIndent,
                    number: index + 1
                )
            } else {
                prefix = ""
            }
            var bodyStart = 0
            let nsLine = line as NSString
            // Prefer exact prefix; fall back to stripping known markers for resilience.
            if !prefix.isEmpty, nsLine.length >= (prefix as NSString).length,
               nsLine.substring(to: (prefix as NSString).length) == prefix {
                bodyStart = (prefix as NSString).length
            } else {
                let strippedLine = TextOverlayFormattingEngine.plainText(from: line, listMode: listMode)
                bodyStart = max(0, nsLine.length - (strippedLine as NSString).length)
            }

            let bodyLength = max(0, lineLength - bodyStart)
            if bodyLength > 0 {
                let range = NSRange(location: displayCursor + bodyStart, length: bodyLength)
                if NSMaxRange(range) <= attributed.length {
                    result.append(attributed.attributedSubstring(from: range))
                }
            }
            if index < displayLines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
            displayCursor += lineLength + (index < displayLines.count - 1 ? 1 : 0)
        }

        // If stripping produced a mismatch, fall back to plain-string reconstruction.
        if result.string != plain {
            return NSAttributedString(string: plain, attributes: attributed.length > 0
                ? attributed.attributes(at: 0, effectiveRange: nil)
                : [:])
        }
        return result
    }

    /// Protected UTF-16 ranges covering list markers (not body text).
    static func markerRanges(
        plainText: String,
        listMode: TextOverlayListMode,
        listIndent: Int
    ) -> [NSRange] {
        lineMappings(plainText: plainText, listMode: listMode, listIndent: listIndent)
            .filter { $0.prefixUTF16Length > 0 }
            .map { NSRange(location: $0.displayStart, length: $0.prefixUTF16Length) }
    }

    static func rangesIntersect(_ a: NSRange, _ b: NSRange) -> Bool {
        let aEnd = a.location + a.length
        let bEnd = b.location + b.length
        return a.location < bEnd && b.location < aEnd
    }

}
