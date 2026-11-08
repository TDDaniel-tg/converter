import Foundation
import ServiceManagement

// MARK: - Preferences
final class Preferences {

    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let debounceDelay = "zestify_debounce_delay"
        static let onlyInFinder = "zestify_only_in_finder"
        static let saveMode = "zestify_save_mode"
        static let customSavePath = "zestify_custom_save_path"
        static let playSound = "zestify_play_sound"
        static let showNotifications = "zestify_show_notifications"
        static let revealInFinder = "zestify_reveal_in_finder"
    }

    private init() {}

    // MARK: - False Positive Protection
    var onlyInFinder: Bool {
        get {
            if defaults.object(forKey: Keys.onlyInFinder) == nil { return true }
            return defaults.bool(forKey: Keys.onlyInFinder)
        }
        set {
            defaults.set(newValue, forKey: Keys.onlyInFinder)
        }
    }

    var debounceDelay: TimeInterval {
        get {
            let val = defaults.double(forKey: Keys.debounceDelay)
            return val > 0 ? val : 0.30
        }
        set {
            defaults.set(newValue, forKey: Keys.debounceDelay)
        }
    }

    // MARK: - Save Mode
    var saveNextToOriginal: Bool {
        get {
            if defaults.object(forKey: Keys.saveMode) == nil { return true }
            return defaults.integer(forKey: Keys.saveMode) == 0
        }
        set {
            defaults.set(newValue ? 0 : 1, forKey: Keys.saveMode)
        }
    }

    var customSaveDirectory: URL {
        get {
            if let path = defaults.string(forKey: Keys.customSavePath), !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        }
        set {
            defaults.set(newValue.path, forKey: Keys.customSavePath)
        }
    }

    // MARK: - Notifications & Sounds
    var playSound: Bool {
        get {
            if defaults.object(forKey: Keys.playSound) == nil { return true }
            return defaults.bool(forKey: Keys.playSound)
        }
        set {
            defaults.set(newValue, forKey: Keys.playSound)
        }
    }

    var showNotifications: Bool {
        get {
            if defaults.object(forKey: Keys.showNotifications) == nil { return true }
            return defaults.bool(forKey: Keys.showNotifications)
        }
        set {
            defaults.set(newValue, forKey: Keys.showNotifications)
        }
    }

    var revealInFinder: Bool {
        get {
            return defaults.bool(forKey: Keys.revealInFinder)
        }
        set {
            defaults.set(newValue, forKey: Keys.revealInFinder)
        }
    }

    // MARK: - Launch At Login
    var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return false
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Zestify LaunchAtLogin error: \(error)")
                }
            }
        }
    }
}
