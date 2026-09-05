import AppKit

struct ApplicationInfo {
    let bundleIdentifier: String
    let displayName: String
}

enum ApplicationCatalog {
    static let builtInApplications = [
        ApplicationInfo(
            bundleIdentifier: "com.jetbrains.intellij",
            displayName: "IntelliJ IDEA"
        ),
        ApplicationInfo(
            bundleIdentifier: "com.jetbrains.intellij.ce",
            displayName: "IntelliJ IDEA Community Edition"
        ),
        ApplicationInfo(
            bundleIdentifier: "com.googlecode.iterm2",
            displayName: "iTerm2"
        ),
        ApplicationInfo(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes"
        ),
        ApplicationInfo(
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            displayName: "Slack"
        ),
        ApplicationInfo(
            bundleIdentifier: "ru.keepcoder.Telegram",
            displayName: "Telegram"
        ),
        ApplicationInfo(
            bundleIdentifier: "com.apple.Terminal",
            displayName: "Terminal"
        ),
        ApplicationInfo(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit"
        ),
        ApplicationInfo(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "Visual Studio Code"
        ),
        ApplicationInfo(
            bundleIdentifier: "com.apple.dt.Xcode",
            displayName: "Xcode"
        )
    ]

    static func menuApplications(
        for rules: [AppRule],
        isInstalled: (String) -> Bool = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
        }
    ) -> [ApplicationInfo] {
        let builtInBundleIdentifiers = Set(builtInApplications.map(\.bundleIdentifier))
        let installedBuiltInApplications = builtInApplications.filter {
            isInstalled($0.bundleIdentifier)
        }
        let installedBuiltInBundleIdentifiers = Set(
            installedBuiltInApplications.map(\.bundleIdentifier)
        )

        var applications = rules.filter {
            !builtInBundleIdentifiers.contains($0.bundleIdentifier)
                || installedBuiltInBundleIdentifiers.contains($0.bundleIdentifier)
        }.map {
            ApplicationInfo(
                bundleIdentifier: $0.bundleIdentifier,
                displayName: $0.displayName
            )
        }

        for builtInApplication in installedBuiltInApplications
        where !applications.contains(where: {
            $0.bundleIdentifier == builtInApplication.bundleIdentifier
        }) {
            applications.append(builtInApplication)
        }

        return applications.sorted { lhs, rhs in
            let comparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if comparison == .orderedSame {
                return lhs.bundleIdentifier < rhs.bundleIdentifier
            }
            return comparison == .orderedAscending
        }
    }
}

final class ApplicationMonitor {
    private var observer: NSObjectProtocol?

    var frontmostApplicationBundleIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func start(activationHandler: @escaping (String?) -> Void) {
        guard observer == nil else { return }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            activationHandler(application?.bundleIdentifier)
        }
    }

    static func isExternalApplication(
        bundleIdentifier: String?,
        ownBundleIdentifier: String?
    ) -> Bool {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return false }
        return bundleIdentifier != ownBundleIdentifier
    }

    func stop() {
        guard let observer else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(observer)
        self.observer = nil
    }

    deinit {
        stop()
    }
}
