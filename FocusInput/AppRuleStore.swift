import Foundation

final class AppRuleStore: AppRuleProviding {
    private static let storageKey = "appRules"

    private let defaults: UserDefaults
    private var rulesByBundleIdentifier: [String: AppRule]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.storageKey),
           let decodedRules = try? PropertyListDecoder().decode([AppRule].self, from: data) {
            rulesByBundleIdentifier = Dictionary(
                decodedRules.map { ($0.bundleIdentifier, $0) },
                uniquingKeysWith: { _, newest in newest }
            )
        } else {
            rulesByBundleIdentifier = [:]
        }
    }

    var rules: [AppRule] {
        rulesByBundleIdentifier.values.sorted { lhs, rhs in
            let comparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if comparison == .orderedSame {
                return lhs.bundleIdentifier < rhs.bundleIdentifier
            }
            return comparison == .orderedAscending
        }
    }

    func rule(for bundleIdentifier: String) -> AppRule? {
        rulesByBundleIdentifier[bundleIdentifier]
    }

    func save(_ rule: AppRule) {
        guard !rule.bundleIdentifier.isEmpty,
              !rule.displayName.isEmpty,
              !rule.inputSourceID.isEmpty
        else {
            return
        }

        rulesByBundleIdentifier[rule.bundleIdentifier] = rule
        persist()
    }

    func removeRule(for bundleIdentifier: String) {
        guard rulesByBundleIdentifier.removeValue(forKey: bundleIdentifier) != nil else { return }
        persist()
    }

    private func persist() {
        guard let data = try? PropertyListEncoder().encode(rules) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
