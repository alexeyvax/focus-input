# Changelog

All notable changes to this project are documented in this file.

## 2.0.0 - Unreleased

- Rename the product, app, executable, Xcode project, scheme, target, and module to Focus Input.
- Change the application bundle identifier to `com.app.focusinput`.
- Add user-configurable per-application input-source rules identified by bundle ID and TIS source ID.
- Add a **Choose Application…** rule creation flow.
- Show common installed editors, messaging apps, terminals, and macOS utilities before they have configured input sources, while hiding any that are not installed.
- Support enabled select-capable keyboard input sources, including non-ASCII sources such as Russian.
- Use the bundled template artwork for the menu bar icon.
- Show the Focus Input application icon in the Dock while the app is running.
- Preserve event-driven activation handling, manual overrides, local-only storage, and near-zero idle work.

## 1.0.0 - 2026-09-05

- Select a chosen ASCII-capable keyboard layout when Apple Terminal, Visual Studio Code, or Xcode becomes active.
- Choose the preferred layout from a native menu bar menu.
- Enable or disable automatic switching without quitting the app.
- Optionally launch at login using the native macOS service.
- Run locally without polling, networking, telemetry, or third-party dependencies.
