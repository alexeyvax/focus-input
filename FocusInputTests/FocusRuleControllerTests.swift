import XCTest
@testable import FocusInput

final class FocusRuleControllerTests: XCTestCase {
    private var settings: TestSettings!
    private var rules: TestRuleStore!
    private var inputSources: TestInputSourceController!
    private var controller: FocusRuleController!

    override func setUp() {
        super.setUp()
        settings = TestSettings()
        rules = TestRuleStore()
        rules.save(
            AppRule(
                bundleIdentifier: "com.apple.Terminal",
                displayName: "Terminal",
                inputSourceID: "english"
            )
        )
        inputSources = TestInputSourceController()
        inputSources.currentInputSourceID = "other"
        controller = FocusRuleController(
            settings: settings,
            rules: rules,
            inputSources: inputSources
        )
    }

    func testConfiguredApplicationSelectsItsSourceWhenDifferent() {
        controller.applicationDidActivate(bundleIdentifier: "com.apple.Terminal")

        XCTAssertEqual(inputSources.selectedIDs, ["english"])
    }

    func testRepeatedActivationDoesNotReselectAnAlreadyCurrentSource() {
        controller.applicationDidActivate(bundleIdentifier: "com.apple.Terminal")
        controller.applicationDidActivate(bundleIdentifier: "com.apple.Terminal")

        XCTAssertEqual(inputSources.selectedIDs, ["english"])
    }

    func testCommonApplicationsUseOrdinaryRules() {
        let configuredApplications = [
            "com.apple.Terminal",
            "com.microsoft.VSCode",
            "com.apple.dt.Xcode",
            "com.tinyspeck.slackmacgap",
            "ru.keepcoder.Telegram"
        ]

        for bundleIdentifier in configuredApplications {
            rules.save(
                AppRule(
                    bundleIdentifier: bundleIdentifier,
                    displayName: bundleIdentifier,
                    inputSourceID: "source-\(bundleIdentifier)"
                )
            )
            inputSources.currentInputSourceID = "other"
            controller.applicationDidActivate(bundleIdentifier: bundleIdentifier)
        }

        XCTAssertEqual(
            inputSources.selectedIDs,
            configuredApplications.map { "source-\($0)" }
        )
    }

    func testAlreadyCurrentSourceIsNotSelectedAgain() {
        inputSources.currentInputSourceID = "english"

        controller.applicationDidActivate(bundleIdentifier: "com.apple.Terminal")

        XCTAssertTrue(inputSources.selectedIDs.isEmpty)
    }

    func testUnconfiguredApplicationDoesNothing() {
        controller.applicationDidActivate(bundleIdentifier: "com.apple.Safari")

        XCTAssertTrue(inputSources.selectedIDs.isEmpty)
    }

    func testDisabledAgentDoesNothing() {
        settings.isEnabled = false

        controller.applicationDidActivate(bundleIdentifier: "com.apple.Terminal")

        XCTAssertTrue(inputSources.selectedIDs.isEmpty)
    }

    func testMissingBundleIdentifierDoesNothing() {
        controller.applicationDidActivate(bundleIdentifier: nil)

        XCTAssertTrue(inputSources.selectedIDs.isEmpty)
    }

    func testMissingConfiguredSourceReportsErrorWithoutCrashing() {
        inputSources.selectionError = TestInputSourceError.missing
        var reportedRule: AppRule?
        var reportedError: Error?
        controller.onError = { rule, error in
            reportedRule = rule
            reportedError = error
        }

        controller.applicationDidActivate(bundleIdentifier: "com.apple.Terminal")

        XCTAssertEqual(reportedRule?.bundleIdentifier, "com.apple.Terminal")
        XCTAssertNotNil(reportedError)
    }

    func testSelectionFailureReportsErrorWithoutCrashing() {
        inputSources.selectionError = TestInputSourceError.selectionFailed
        var errorCount = 0
        controller.onError = { _, _ in errorCount += 1 }

        controller.applicationDidActivate(bundleIdentifier: "com.apple.Terminal")

        XCTAssertEqual(errorCount, 1)
    }

    func testRemovingRuleStopsFutureSwitching() {
        rules.removeRule(for: "com.apple.Terminal")

        controller.applicationDidActivate(bundleIdentifier: "com.apple.Terminal")

        XCTAssertTrue(inputSources.selectedIDs.isEmpty)
    }
}

final class ApplicationMonitorTests: XCTestCase {
    func testOwnApplicationCannotBeTrackedAsExternal() {
        XCTAssertFalse(
            ApplicationMonitor.isExternalApplication(
                bundleIdentifier: "com.app.focusinput",
                ownBundleIdentifier: "com.app.focusinput"
            )
        )
        XCTAssertTrue(
            ApplicationMonitor.isExternalApplication(
                bundleIdentifier: "com.apple.Terminal",
                ownBundleIdentifier: "com.app.focusinput"
            )
        )
        XCTAssertFalse(
            ApplicationMonitor.isExternalApplication(
                bundleIdentifier: nil,
                ownBundleIdentifier: "com.app.focusinput"
            )
        )
    }
}
