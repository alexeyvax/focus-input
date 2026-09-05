import Foundation

protocol FocusRuleSettings {
    var isEnabled: Bool { get }
}

final class Settings: FocusRuleSettings {
    private enum Key {
        static let isEnabled = "isEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.isEnabled: true])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set { defaults.set(newValue, forKey: Key.isEnabled) }
    }
}
