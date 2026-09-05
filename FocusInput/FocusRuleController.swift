import Foundation

final class FocusRuleController {
    private let settings: FocusRuleSettings
    private let rules: AppRuleProviding
    private let inputSources: InputSourceSelecting
    var onError: ((AppRule, Error) -> Void)?
    var onSuccess: (() -> Void)?

    init(
        settings: FocusRuleSettings,
        rules: AppRuleProviding,
        inputSources: InputSourceSelecting
    ) {
        self.settings = settings
        self.rules = rules
        self.inputSources = inputSources
    }

    func applicationDidActivate(bundleIdentifier: String?) {
        guard settings.isEnabled,
              let bundleIdentifier,
              let rule = rules.rule(for: bundleIdentifier)
        else {
            return
        }

        guard inputSources.currentInputSourceID != rule.inputSourceID else {
            onSuccess?()
            return
        }

        do {
            try inputSources.selectInputSource(withID: rule.inputSourceID)
            onSuccess?()
        } catch {
            onError?(rule, error)
        }
    }
}
