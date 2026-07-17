import Foundation

enum TextOverlayFormattingEngine {
    static func localizedTodayString(date: Date = Date(), locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func appendToday(to text: String, date: Date = Date(), locale: Locale = .current) -> String {
        let today = localizedTodayString(date: date, locale: locale)
        if text.isEmpty {
            return today
        }
        if text.hasSuffix("\n") {
            return text + today
        }
        return text + " " + today
    }

    static func displayText(
        _ text: String,
        listMode: TextOverlayListMode,
        listIndent: Int = 0
    ) -> String {
        let indented = applyIndent(to: text, indent: listIndent)
        switch listMode {
        case .plain:
            return indented
        case .bulleted:
            return applyBulletedList(to: indented)
        case .numbered:
            return applyNumberedList(to: indented)
        case .dashed:
            return applyDashedList(to: indented)
        }
    }

    static func applyIndent(to text: String, indent: Int) -> String {
        let level = min(max(indent, 0), TextOverlayDraft.maxListIndent)
        guard level > 0 else { return text }
        let prefix = String(repeating: "    ", count: level)
        return text
            .components(separatedBy: .newlines)
            .map { line in
                let trimmedLeading = line.trimmingCharacters(in: .whitespaces)
                guard !trimmedLeading.isEmpty else { return "" }
                return prefix + trimmedLeading
            }
            .joined(separator: "\n")
    }

    static func applyBulletedList(to text: String) -> String {
        applyMarkerList(to: text, marker: "• ")
    }

    static func applyDashedList(to text: String) -> String {
        applyMarkerList(to: text, marker: "– ")
    }

    static func applyNumberedList(to text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var number = 1
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return "" }
            if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                _ = match
                return trimmed
            }
            defer { number += 1 }
            return "\(number). \(trimmed)"
        }.joined(separator: "\n")
    }

    static func switchingListMode(
        from current: TextOverlayListMode,
        to newMode: TextOverlayListMode,
        text: String
    ) -> String {
        guard current != newMode else { return text }
        let plain = plainText(from: text, listMode: current)
        switch newMode {
        case .plain:
            return plain
        case .bulleted:
            return applyBulletedList(to: plain)
        case .numbered:
            return applyNumberedList(to: plain)
        case .dashed:
            return applyDashedList(to: plain)
        }
    }

    static func plainText(from text: String, listMode: TextOverlayListMode) -> String {
        let withoutMarkers: String
        switch listMode {
        case .plain:
            withoutMarkers = text
        case .bulleted:
            withoutMarkers = stripMarker(from: text, marker: "• ")
        case .dashed:
            withoutMarkers = stripMarker(from: text, marker: "– ")
        case .numbered:
            withoutMarkers = text
                .components(separatedBy: .newlines)
                .map { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if let dotIndex = trimmed.firstIndex(of: "."),
                       trimmed[..<dotIndex].allSatisfy(\.isNumber),
                       trimmed.index(after: dotIndex) < trimmed.endIndex,
                       trimmed[trimmed.index(after: dotIndex)] == " " {
                        return String(trimmed[trimmed.index(dotIndex, offsetBy: 2)...])
                    }
                    return trimmed
                }
                .joined(separator: "\n")
        }
        return stripLeadingIndent(from: withoutMarkers)
    }

    private static func applyMarkerList(to text: String, marker: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return "" }
            if trimmed.hasPrefix(marker) {
                return trimmed
            }
            return marker + trimmed
        }.joined(separator: "\n")
    }

    private static func stripMarker(from text: String, marker: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { line in
                var trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(marker) {
                    trimmed.removeFirst(marker.count)
                }
                return trimmed
            }
            .joined(separator: "\n")
    }

    private static func stripLeadingIndent(from text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { line in
                var result = line
                while result.hasPrefix("    ") {
                    result.removeFirst(4)
                }
                return result
            }
            .joined(separator: "\n")
    }
}
