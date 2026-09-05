import XCTest
@testable import FocusInput

final class AppRuleStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "FocusInputTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSavingExistingBundleIdentifierUpdatesInsteadOfDuplicating() {
        let store = AppRuleStore(defaults: defaults)
        store.save(AppRule(bundleIdentifier: "app.one", displayName: "One", inputSourceID: "abc"))
        store.save(AppRule(bundleIdentifier: "app.one", displayName: "One Renamed", inputSourceID: "ru"))

        XCTAssertEqual(store.rules.count, 1)
        XCTAssertEqual(store.rule(for: "app.one")?.displayName, "One Renamed")
        XCTAssertEqual(store.rule(for: "app.one")?.inputSourceID, "ru")
    }

    func testPersistenceRoundTrips() {
        let firstStore = AppRuleStore(defaults: defaults)
        let rule = AppRule(bundleIdentifier: "app.one", displayName: "One", inputSourceID: "abc")
        firstStore.save(rule)

        let restoredStore = AppRuleStore(defaults: defaults)

        XCTAssertEqual(restoredStore.rules, [rule])
    }

    func testRulesAreSortedByDisplayName() {
        let store = AppRuleStore(defaults: defaults)
        store.save(AppRule(bundleIdentifier: "app.z", displayName: "Zulu", inputSourceID: "abc"))
        store.save(AppRule(bundleIdentifier: "app.a", displayName: "alpha", inputSourceID: "abc"))
        store.save(AppRule(bundleIdentifier: "app.b", displayName: "Beta", inputSourceID: "abc"))

        XCTAssertEqual(store.rules.map(\.displayName), ["alpha", "Beta", "Zulu"])
    }

    func testRemovingRulePersists() {
        let store = AppRuleStore(defaults: defaults)
        store.save(AppRule(bundleIdentifier: "app.one", displayName: "One", inputSourceID: "abc"))
        store.removeRule(for: "app.one")

        XCTAssertNil(AppRuleStore(defaults: defaults).rule(for: "app.one"))
    }
}

final class ApplicationCatalogTests: XCTestCase {
    func testBuiltInApplicationsAppearWithoutConfiguredRules() {
        let applications = ApplicationCatalog.menuApplications(
            for: [],
            isInstalled: { _ in true }
        )

        XCTAssertEqual(
            applications.map(\.bundleIdentifier),
            [
                "com.jetbrains.intellij",
                "com.jetbrains.intellij.ce",
                "com.googlecode.iterm2",
                "com.apple.Notes",
                "com.tinyspeck.slackmacgap",
                "ru.keepcoder.Telegram",
                "com.apple.Terminal",
                "com.apple.TextEdit",
                "com.microsoft.VSCode",
                "com.apple.dt.Xcode"
            ]
        )
        XCTAssertEqual(
            applications.map(\.displayName),
            [
                "IntelliJ IDEA",
                "IntelliJ IDEA Community Edition",
                "iTerm2",
                "Notes",
                "Slack",
                "Telegram",
                "Terminal",
                "TextEdit",
                "Visual Studio Code",
                "Xcode"
            ]
        )
    }

    func testConfiguredBuiltInApplicationsAreNotDuplicated() {
        let rules = ApplicationCatalog.builtInApplications.map {
            AppRule(
                bundleIdentifier: $0.bundleIdentifier,
                displayName: $0.displayName,
                inputSourceID: "english"
            )
        }
        let applications = ApplicationCatalog.menuApplications(
            for: rules,
            isInstalled: { _ in true }
        )

        XCTAssertEqual(applications.count, ApplicationCatalog.builtInApplications.count)
        XCTAssertEqual(
            Set(applications.map(\.bundleIdentifier)).count,
            ApplicationCatalog.builtInApplications.count
        )
    }

    func testBuiltInApplicationsAreSortedWithConfiguredApplications() {
        let applications = ApplicationCatalog.menuApplications(
            for: [
                AppRule(bundleIdentifier: "app.z", displayName: "Zulu", inputSourceID: "z"),
                AppRule(bundleIdentifier: "app.a", displayName: "Alpha", inputSourceID: "a")
            ],
            isInstalled: { _ in true }
        )

        XCTAssertEqual(
            applications.map(\.displayName),
            [
                "Alpha",
                "IntelliJ IDEA",
                "IntelliJ IDEA Community Edition",
                "iTerm2",
                "Notes",
                "Slack",
                "Telegram",
                "Terminal",
                "TextEdit",
                "Visual Studio Code",
                "Xcode",
                "Zulu"
            ]
        )
    }

    func testUninstalledBuiltInApplicationIsHidden() {
        let applications = ApplicationCatalog.menuApplications(
            for: [],
            isInstalled: { $0 == "com.apple.Terminal" }
        )

        XCTAssertEqual(applications.map(\.displayName), ["Terminal"])
    }

    func testUninstalledBuiltInApplicationWithRuleIsHidden() {
        let applications = ApplicationCatalog.menuApplications(
            for: [
                AppRule(
                    bundleIdentifier: "com.apple.dt.Xcode",
                    displayName: "Xcode",
                    inputSourceID: "english"
                ),
                AppRule(
                    bundleIdentifier: "com.example.Editor",
                    displayName: "Editor",
                    inputSourceID: "english"
                )
            ],
            isInstalled: { $0 == "com.apple.Terminal" }
        )

        XCTAssertEqual(applications.map(\.displayName), ["Editor", "Terminal"])
    }
}
