@testable import FocusInput

final class TestSettings: FocusRuleSettings {
    var isEnabled = true
}

final class TestRuleStore: AppRuleProviding {
    private var rulesByBundleIdentifier: [String: AppRule] = [:]

    var rules: [AppRule] {
        Array(rulesByBundleIdentifier.values)
    }

    func rule(for bundleIdentifier: String) -> AppRule? {
        rulesByBundleIdentifier[bundleIdentifier]
    }

    func save(_ rule: AppRule) {
        rulesByBundleIdentifier[rule.bundleIdentifier] = rule
    }

    func removeRule(for bundleIdentifier: String) {
        rulesByBundleIdentifier.removeValue(forKey: bundleIdentifier)
    }
}

enum TestInputSourceError: Error {
    case missing
    case selectionFailed
}

final class TestInputSourceController: InputSourceSelecting {
    var currentInputSourceID: String?
    var selectionError: Error?
    private(set) var selectedIDs: [String] = []

    func selectInputSource(withID id: String) throws {
        selectedIDs.append(id)
        if let selectionError {
            throw selectionError
        }
        currentInputSourceID = id
    }
}
