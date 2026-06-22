# StatusItemKit

A small, reusable framework for building **standalone macOS menu-bar apps** in
Swift — no third-party host (like SwiftBar) required. It factors out the
mechanics every such app repeats: the status-item lifecycle, a polling loop, a
lazily-rebuilt menu, a text/icon render funnel, Start-at-Login, notifications,
data-driven meter icons, and a build/sign script that produces a proper `.app`
bundle.

It's the extracted common core of several personal menu-bar apps (process
monitor, battery time, VPN/DNS status).

## Requirements

- macOS **13+** (required by `SMAppService` for Start-at-Login)
- Swift 5.9 / Xcode 15+

## What's in it

| Type | Purpose |
|------|---------|
| `Shell.run(_:_:)` | Run a CLI tool, get stdout as `String?` (nil on launch failure / non-zero exit). The one I/O primitive. |
| `StatusItemController` | Owns the `NSStatusItem`, a polling `Timer`, `.accessory` activation, and lazy menu rebuild. Constructed with `onPoll` + `onBuildMenu` closures. |
| `setTitle(_:warn:)` / `setIcon(_:)` | The render funnel — mutually-exclusive text vs. image paths, so you never get stray title spacing. |
| `MenuBuilder` | `labelWidth(...)` and a view-based `textView(...)` that escapes NSMenu's keyboard-shortcut column reservation (uses explicit frames, not auto-layout). |
| `MeterIcon` | Custom-drawn, full-color status glyphs: `dot`, and the proportional `gauge` / `arc` / `pie` / `wedge` meters (take a `0...1` fraction + color). |
| `Severity` | `level(pct:warnPct:)` → `.normal` / `.elevated` / `.high`, with a `.color`. |
| `LoginItem` | `SMAppService.mainApp` register/unregister + the "must live in /Applications" alert. |
| `Notifier` | `UNUserNotificationCenter` authorization + `post(title:body:)`. |

## Using it

Add the package. During local development against a sibling checkout:

```swift
// Package.swift
.package(path: "../StatusItemKit")
```

For a release, pin a tagged version:

```swift
.package(url: "https://github.com/nicholaspsmith/StatusItemKit.git", from: "1.0.0")
```

Then depend on the `StatusItemKit` product from your executable target.

## Minimal example

A complete, runnable example lives in
[`Sources/StatusItemKitDemo/main.swift`](Sources/StatusItemKitDemo/main.swift):
it shows a status item whose `MeterIcon.arc` sweeps green→orange→red, with a
menu that sends a test notification and toggles Start-at-Login. The essence:

```swift
import AppKit
import StatusItemKit

final class App: NSObject, NSApplicationDelegate {
    var controller: StatusItemController!

    func applicationDidFinishLaunching(_ n: Notification) {
        controller = StatusItemController(
            pollInterval: 5,
            onPoll: { [weak self] in self?.poll() },
            onBuildMenu: { [weak self] menu in self?.build(menu) }
        )
        controller.start()
    }

    func poll() {
        let pct = currentPercentage()  // your data
        controller.setIcon(MeterIcon.arc(fraction: CGFloat(pct) / 100,
                                         color: Severity.level(pct: pct, warnPct: 85).color))
    }

    func build(_ menu: NSMenu) {
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}
```

## Building a `.app` bundle

`scripts/make-app.sh` wraps a SwiftPM executable product into an ad-hoc-signed
`.app`. Run it from your package root (it reads `./Resources/Info.plist` and
writes `./build/<DisplayName>.app`):

```sh
scripts/make-app.sh <ProductName> [<BundleDisplayName>]
# e.g.
scripts/make-app.sh StatusItemKitDemo
scripts/make-app.sh BatteryTime "Battery Time"
```

> **The ad-hoc `codesign` step is mandatory, not cosmetic.**
> `UNUserNotificationCenter` silently drops notification requests from unsigned
> bundles — threshold/alert notifications will appear to "not fire" if the
> signature is missing.

Your app provides its own `Resources/Info.plist` with `LSUIElement=true` (no
Dock icon) and a real bundle identifier; use this repo's
[`Resources/Info.plist`](Resources/Info.plist) as the template.

## Development

```sh
swift test                          # unit tests (Severity, Shell, MenuBuilder, MeterIcon)
./scripts/make-app.sh StatusItemKitDemo && open build/StatusItemKitDemo.app
```

AppKit/system glue (`StatusItemController`, `LoginItem`, `Notifier`) isn't
unit-tested — it's verified by running the demo.

## License

[MIT](LICENSE)
