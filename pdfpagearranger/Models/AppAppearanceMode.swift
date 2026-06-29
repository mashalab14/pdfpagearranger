import SwiftUI

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case device
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .device:
            return "Device"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .device:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    static let defaultMode: AppAppearanceMode = .device
}

enum AppAppearanceSettings {
    static let storageKey = "appAppearanceMode"

    static func storedMode(in defaults: UserDefaults = .standard) -> AppAppearanceMode {
        guard let rawValue = defaults.string(forKey: storageKey),
              let mode = AppAppearanceMode(rawValue: rawValue) else {
            return .defaultMode
        }
        return mode
    }

    static func setStoredMode(_ mode: AppAppearanceMode, in defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: storageKey)
    }

    static func clearStoredMode(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
