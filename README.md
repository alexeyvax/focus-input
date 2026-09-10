# Focus Input

Focus Input is a native macOS menu bar utility that associates a preferred keyboard input source with an application. When a configured application becomes active, Focus Input selects that source once. Applications without a rule are left unchanged, and manual source changes remain untouched until you leave and return to the configured application.

## Requirements

- macOS 13.0 or newer
- Xcode with the macOS SDK when building from source
- No third-party dependencies

## Install

When a Focus Input release is available, download its notarized ZIP from [GitHub Releases](https://github.com/alexeyvax/code-input-en/releases), unzip it, move `Focus Input.app` to `/Applications`, and launch it.

To build from source, open `FocusInput.xcodeproj` in Xcode and run the `FocusInput` scheme, or run:

```bash
xcodebuild \
  -project FocusInput.xcodeproj \
  -scheme FocusInput \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run the unit tests with:

```bash
xcodebuild \
  -project FocusInput.xcodeproj \
  -scheme FocusInput \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Use

Focus Input appears with its compact icon in the menu bar and shows its application icon in the Dock while running.

The menu provides:

- **Enabled** — enables or disables all rule application.
- **Applications** — shows installed built-in applications (IntelliJ IDEA, iTerm2, Notes, Slack, Telegram, Terminal, TextEdit, Visual Studio Code, and Xcode) and also lists configured applications. Both IntelliJ IDEA editions are supported. An unconfigured built-in entry has no selected input source; choosing one creates its rule. Built-in applications that are not installed are hidden. Each configured application submenu lets you choose any enabled, select-capable keyboard input source or choose **Do Not Manage**.
- **Choose Application…** — selects an `.app` bundle without scanning the Mac for applications.
- **Launch at Login** — registers or unregisters Focus Input with macOS using `SMAppService`. A mixed state means macOS requires approval in **System Settings → General → Login Items**.
- **Quit Focus Input** — stops the observer and exits.

Rules use stable application bundle identifiers and Text Input Source Services IDs. Display names are stored only for presentation. All rule data stays in `UserDefaults` on the Mac.

## Privacy

Focus Input has no networking, telemetry, analytics, crash reporting, or third-party runtime code. It observes foreground application changes locally and does not record an activity history. It does not use Accessibility, AppleScript, or simulated keystrokes. See the complete [privacy policy](PRIVACY.md).

## Troubleshooting

If a configured source is unavailable, enable it in **System Settings → Keyboard → Text Input → Edit**, then choose it again in the application's Focus Input submenu. A stale rule displays a warning and is otherwise ignored safely.

If Launch at Login shows an approval warning, allow Focus Input in **System Settings → General → Login Items**. Launch at Login works most reliably after moving `Focus Input.app` to `/Applications` and launching it from there.

## Removal

Turn off **Launch at Login**, choose **Quit Focus Input**, and delete `Focus Input.app`. To remove preferences and rules as well, run:

```bash
defaults delete com.app.focusinput
```

## Known limitations

Rules apply to an entire application, not an individual window, editor, terminal panel, document, or text field. Focus Input neither restores the previous source when leaving an application nor continuously enforces a rule. Different application variants may use different bundle identifiers and therefore require separate rules.

The previous `en` artwork is intentionally not used by the renamed product. Neutral branded application artwork is still required before the Focus Input release.
