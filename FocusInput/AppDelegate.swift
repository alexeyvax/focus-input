import AppKit
import ServiceManagement
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private let ruleStore = AppRuleStore()
    private let inputSources = InputSourceController()
    private let applicationMonitor = ApplicationMonitor()
    private lazy var focusRule = FocusRuleController(
        settings: settings,
        rules: ruleStore,
        inputSources: inputSources
    )

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var ruleWarningMessage: String?
    private var launchAtLoginWarningMessage: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        configureRuleCallbacks()
        configureStatusItem()

        applicationMonitor.start { [weak self] bundleIdentifier in
            self?.focusRule.applicationDidActivate(bundleIdentifier: bundleIdentifier)
        }
        focusRule.applicationDidActivate(
            bundleIdentifier: applicationMonitor.frontmostApplicationBundleIdentifier
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        applicationMonitor.stop()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(
                systemSymbolName: "keyboard.badge.ellipsis",
                accessibilityDescription: "Focus Input"
            )
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Focus Input"
        statusItem.button?.setAccessibilityLabel("Focus Input")
        menu.delegate = self
        statusItem.menu = menu
        self.statusItem = statusItem
        rebuildMenu()
    }

    private func configureRuleCallbacks() {
        focusRule.onError = { [weak self] rule, error in
            self?.ruleWarningMessage = "\(rule.displayName): \(error.localizedDescription)"
        }
        focusRule.onSuccess = { [weak self] in
            self?.ruleWarningMessage = nil
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let titleItem = NSMenuItem(title: "Focus Input", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let enabledItem = menuItem(title: "Enabled", action: #selector(toggleEnabled))
        enabledItem.state = settings.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let applicationsItem = NSMenuItem(title: "Applications", action: nil, keyEquivalent: "")
        applicationsItem.submenu = makeApplicationsMenu()
        menu.addItem(applicationsItem)

        let launchItem = menuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin))
        switch SMAppService.mainApp.status {
        case .enabled:
            launchItem.state = .on
        case .requiresApproval:
            launchItem.state = .mixed
        default:
            launchItem.state = .off
        }
        menu.addItem(launchItem)

        if let warning = currentWarning() {
            let warningItem = NSMenuItem(title: "⚠ \(warning)", action: nil, keyEquivalent: "")
            warningItem.isEnabled = false
            menu.addItem(warningItem)
        }

        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit Focus Input", action: #selector(quit), keyEquivalent: "q"))
    }

    private func makeApplicationsMenu() -> NSMenu {
        let submenu = NSMenu(title: "Applications")
        let sources = inputSources.selectableInputSources

        for application in ApplicationCatalog.menuApplications(for: ruleStore.rules) {
            let applicationItem = NSMenuItem(
                title: application.displayName,
                action: nil,
                keyEquivalent: ""
            )
            applicationItem.submenu = makeRuleMenu(
                for: application,
                rule: ruleStore.rule(for: application.bundleIdentifier),
                sources: sources
            )
            submenu.addItem(applicationItem)
        }

        submenu.addItem(.separator())
        submenu.addItem(menuItem(title: "Choose Application…", action: #selector(chooseApplication)))
        return submenu
    }

    private func makeRuleMenu(
        for application: ApplicationInfo,
        rule: AppRule?,
        sources: [InputSource]
    ) -> NSMenu {
        let submenu = NSMenu(title: application.displayName)

        if let rule, !sources.contains(where: { $0.id == rule.inputSourceID }) {
            let warning = NSMenuItem(
                title: "⚠ Configured input source is unavailable",
                action: nil,
                keyEquivalent: ""
            )
            warning.isEnabled = false
            submenu.addItem(warning)
            submenu.addItem(.separator())
        }

        if rule == nil {
            let unconfiguredItem = NSMenuItem(
                title: "Not configured",
                action: nil,
                keyEquivalent: ""
            )
            unconfiguredItem.isEnabled = false
            submenu.addItem(unconfiguredItem)
            submenu.addItem(.separator())
        }

        if sources.isEmpty {
            let emptyItem = NSMenuItem(title: "No input sources available", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for source in sources {
                let item = menuItem(title: source.name, action: #selector(selectRuleInputSource))
                item.representedObject = RuleSourceSelection(
                    bundleIdentifier: application.bundleIdentifier,
                    displayName: application.displayName,
                    inputSourceID: source.id
                )
                item.state = source.id == rule?.inputSourceID ? .on : .off
                submenu.addItem(item)
            }
        }

        if let rule {
            submenu.addItem(.separator())
            let removeItem = menuItem(title: "Do Not Manage", action: #selector(removeRule))
            removeItem.representedObject = rule.bundleIdentifier
            submenu.addItem(removeItem)
        }
        return submenu
    }

    private func currentWarning() -> String? {
        if SMAppService.mainApp.status == .requiresApproval {
            return "Allow Launch at Login in System Settings."
        }
        return launchAtLoginWarningMessage ?? ruleWarningMessage
    }

    private func menuItem(
        title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func configureRule(for application: ApplicationInfo) {
        guard ApplicationMonitor.isExternalApplication(
            bundleIdentifier: application.bundleIdentifier,
            ownBundleIdentifier: Bundle.main.bundleIdentifier
        ) else {
            showError(title: "Cannot Add Application", message: "Focus Input cannot manage itself.")
            return
        }

        let sources = inputSources.selectableInputSources
        guard !sources.isEmpty else {
            showError(
                title: "No Input Sources",
                message: "Enable at least one keyboard input source in System Settings and try again."
            )
            return
        }

        let existingRule = ruleStore.rule(for: application.bundleIdentifier)
        let preferredSourceID = existingRule?.inputSourceID
            ?? inputSources.currentInputSourceID
            ?? sources[0].id
        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26))
        for source in sources {
            popUp.addItem(withTitle: source.name)
            popUp.lastItem?.representedObject = source.id
        }
        if let index = sources.firstIndex(where: { $0.id == preferredSourceID }) {
            popUp.selectItem(at: index)
        }

        let alert = NSAlert()
        alert.messageText = existingRule == nil
            ? "Manage \(application.displayName)"
            : "Edit \(application.displayName)"
        alert.informativeText = "Choose the input source to select when this application becomes active."
        alert.accessoryView = popUp
        alert.addButton(withTitle: existingRule == nil ? "Add Rule" : "Save")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn,
              let inputSourceID = popUp.selectedItem?.representedObject as? String
        else {
            return
        }

        ruleStore.save(
            AppRule(
                bundleIdentifier: application.bundleIdentifier,
                displayName: application.displayName,
                inputSourceID: inputSourceID
            )
        )
        ruleWarningMessage = nil
        applyRuleIfFrontmost(bundleIdentifier: application.bundleIdentifier)
        rebuildMenu()
    }

    private func applicationInfo(at url: URL) -> ApplicationInfo? {
        guard url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier,
              !bundleIdentifier.isEmpty
        else {
            return nil
        }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return ApplicationInfo(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName
        )
    }

    private func applyRuleIfFrontmost(bundleIdentifier: String) {
        guard applicationMonitor.frontmostApplicationBundleIdentifier == bundleIdentifier else { return }
        focusRule.applicationDidActivate(bundleIdentifier: bundleIdentifier)
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        ruleWarningMessage = nil
        rebuildMenu()
    }

    @objc private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK else {
            return
        }

        guard let url = panel.url,
              let application = applicationInfo(at: url)
        else {
            showError(
                title: "Invalid Application",
                message: "Choose a valid macOS application bundle with a bundle identifier."
            )
            return
        }
        configureRule(for: application)
    }

    @objc private func selectRuleInputSource(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? RuleSourceSelection else {
            return
        }

        let rule = AppRule(
            bundleIdentifier: selection.bundleIdentifier,
            displayName: ruleStore.rule(for: selection.bundleIdentifier)?.displayName
                ?? selection.displayName,
            inputSourceID: selection.inputSourceID
        )
        ruleStore.save(rule)
        ruleWarningMessage = nil
        applyRuleIfFrontmost(bundleIdentifier: rule.bundleIdentifier)
        rebuildMenu()
    }

    @objc private func removeRule(_ sender: NSMenuItem) {
        guard let bundleIdentifier = sender.representedObject as? String else { return }
        ruleStore.removeRule(for: bundleIdentifier)
        ruleWarningMessage = nil
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        let shouldEnable = service.status != .enabled

        do {
            if shouldEnable {
                try service.register()
            } else {
                try service.unregister()
            }
            launchAtLoginWarningMessage = nil
        } catch {
            launchAtLoginWarningMessage = "Launch at Login: \(error.localizedDescription)"
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private struct RuleSourceSelection {
    let bundleIdentifier: String
    let displayName: String
    let inputSourceID: String
}
