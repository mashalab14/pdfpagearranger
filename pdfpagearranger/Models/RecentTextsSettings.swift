import Foundation

enum RecentTextsSettings {
    static let storageKey = "pdfEditorRecentTexts"
    static let maxEntryCount = 10

    static func storedEntries(in defaults: UserDefaults = .standard) -> [String] {
        guard let rawEntries = defaults.array(forKey: storageKey) as? [String] else {
            return []
        }
        return rawEntries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func setStoredEntries(_ entries: [String], in defaults: UserDefaults = .standard) {
        defaults.set(entries, forKey: storageKey)
    }

    static func recordCommittedText(_ text: String, in defaults: UserDefaults = .standard) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var entries = storedEntries(in: defaults).filter { $0 != trimmed }
        entries.insert(trimmed, at: 0)
        if entries.count > maxEntryCount {
            entries = Array(entries.prefix(maxEntryCount))
        }
        setStoredEntries(entries, in: defaults)
    }

    static func removeEntry(_ text: String, in defaults: UserDefaults = .standard) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entries = storedEntries(in: defaults).filter { $0 != trimmed }
        setStoredEntries(entries, in: defaults)
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
