import Foundation

enum TextOverlayFormattingEngine {
    static func localizedTodayString(date: Date = Date(), locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func displayText(
        _ text: String,
        listMode: TextOverlayListMode
    ) -> String {
        switch listMode {
        case .plain:
            return text
        case .bulleted:
            return applyBulletedList(to: text)
        case .numbered:
            return applyNumberedList(to: text)
        }
    }

    static func applyBulletedList(to text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return "" }
            if trimmed.hasPrefix("• ") {
                return trimmed
            }
            return "• \(trimmed)"
        }.joined(separator: "\n")
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
        }
    }

    static func plainText(from text: String, listMode: TextOverlayListMode) -> String {
        switch listMode {
        case .plain:
            return text
        case .bulleted:
            return text
                .components(separatedBy: .newlines)
                .map { line in
                    var trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("• ") {
                        trimmed.removeFirst(2)
                    }
                    return trimmed
                }
                .joined(separator: "\n")
        case .numbered:
            return text
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
    }
}
