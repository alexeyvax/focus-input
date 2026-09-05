import Foundation

struct AppRule: Codable, Equatable {
    let bundleIdentifier: String
    var displayName: String
    var inputSourceID: String
}

protocol AppRuleProviding {
    func rule(for bundleIdentifier: String) -> AppRule?
}
