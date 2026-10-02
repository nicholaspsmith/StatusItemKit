# StatusItemKit

<p align="center"><img src="docs/mascot.png" width="160" alt="StatusItemKit mascot, from Menumon"></p>

<p align="center">Part of <strong><a href="https://menumon.nicksmith.software">Menumon</a></strong>.</p>

A small, reusable framework for building **standalone macOS menu-bar apps** in
Swift — no third-party host (like SwiftBar) required. It factors out the
mechanics every such app repeats: the status-item lifecycle, a polling loop, a
lazily-rebuilt menu, a text/icon render funnel, Start-at-Login, notifications,
data-driven meter icons, and a build/sign script that produces a proper `.app`
bundle.

It's the extracted common core of several personal menu-bar apps (process
monitor, battery time, VPN/DNS status).

## Why not SwiftBar?

[SwiftBar](https://github.com/swiftbar/SwiftBar) is a fine way to get a script
into the menu bar, and several of these apps started life as SwiftBar plugins.
They were rewritten as standalone apps because the plugin model kept getting in
the way:

- **No host process.** Each widget is its own `.app` with its own icon, its own
  process, and its own Start-at-Login toggle (`SMAppService`). Nothing to install
  first, no shared plugin directory where a stray file becomes a phantom icon, and
  one widget hanging cannot take the others down with it.
- **Real AppKit menus, not rendered stdout.** A plugin's dropdown is whatever its
  text protocol can express. Here it is a native `NSMenu`: sliders, checkmarks,
  submenus, custom views, images, keyboard shortcuts, the system colour picker.
- **Event-driven, not re-run on a timer.** A plugin is a script executed again
  every N seconds. An app can sit on IOKit power-source notifications (Battery
  Time), a `CGEventTap` (KeyLight, Apollo Monitor), `mullvad status listen`
  (VPN & DNS), or ScreenCaptureKit (MacRecorder) — things a shell script cannot
  do at all — and react the instant something changes.
- **The icon stays put.** A native status item keeps its position in the bar. A
  plugin's refresh re-creates its item, which is what bounces it around under
  menu-bar managers. Signing with a stable identity (`make-app.sh`) also keeps
  the cdhash stable, so TCC grants such as Accessibility survive rebuilds instead
  of having to be re-granted.
- **Testable.** The logic lives in Swift libraries with unit tests (for example
  `BatteryTimeCore`), not in a shell script whose only test is eyeballing the menu.
- **Data-driven icons.** `MeterIcon` draws proportional gauges, arcs, pies and
  wedges in colour from a single 0…1 value. A plugin is limited to text and
  pre-rendered images.

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
| `CharacterIcon` | The Menumon mascots as status glyphs that still carry the data: an owl whose eyelids droop with the session and whose pupils and whites redden with the week, a chameleon that changes colour and grows a tail or tongue per connection, an octopus that grows arms and heats up with load, a keycap whose rays light with the backlight, an Apollo interface face whose tick ring is the level, a caterpillar in headphones that lights a segment per running effect, a raccoon, a bin, a camcorder, and Menu Pimp, the Mac Daddy of the menu bar, whose suit and sweat follow process load. The owl blinks, Menu Pimp flashes a gold-gleaming grin, Carol runs, Caveepyan licks and Armonitor laps his monitor, each once a minute (`MinuteCue`). Each app pairs one with `MeterStyle.character` in the shared Icon picker. |
| `MinuteCue` / `IconAnimation` | Once a minute, each animated mascot takes its turn: every app wakes on the wall-clock minute and waits one second for each animated app ahead of it in `MinuteCue.order` that is running (Archimedes, Menu Pimp, Carol, Caveepyan, Armonitor), so they never move at once. Skipped under Reduce Motion. `IconAnimation` drives the frames at 60 fps, menus open or not. |
| `MonitorLizardLap` | Armonitor's big lap: a click-through overlay where he leaves his menu-bar slot and slithers counterclockwise round the whole screen and home in 8 s. Monitor Lizard plays it when a display setting other than brightness changes; his once-a-minute lap stays in the icon (`monitorLizard(…, lap:)`). |
| `IllustratedIcon` | Menu-bar images from mascot art instead of shapes drawn in code: `compose` lays out a 1× + 2× non-template image from a base PNG, greys it, recolours a masked region keeping its shading, and draws live overlays on top; `load(named:in:)` reads a `name.png` + `name@2x.png` pair from a bundle. `CharacterIcon.macDaddy(art:level:asleep:flourish:)` (with `MacDaddyArt.load(from:)`) and `CharacterIcon.lumen(keycap:level:active:)` are built on it; the art lives in each app's `Resources/bundle/` and the code-drawn glyphs remain as fallbacks. |
| `Severity` | `level(pct:warnPct:)` → `.normal` / `.elevated` / `.high`, with a `.color`. |
| `MeterStyle` | The meter shapes as a value: `.arc` / `.gauge` / `.pie` / `.wedge` / `.dot`, plus `MeterIcon.image(style:fraction:color:)`. |
| `MeterColor` | Named presets and the `#RRGGBB` round-trip used to persist a colour, plus `swatch(_:)` for menu-item images. |
| `MeterAppearance` | The user's chosen shape and colour, persisted in the app's own defaults (`MeterStyle`, `MeterColorHex`). |
| `AppearanceMenu` | The shared **Icon** submenu: shapes, colour presets, and the system colour picker — or, via `colorItems:`, an app's own colour block in their place. |
| `LoginItem` | `SMAppService.mainApp` register/unregister + the "must live in /Applications" alert. |
| `LoginRequest` | Parses `--login [on\|off\|status]` off a command line. Pure and unit-tested; a bare flag or `status` reports rather than registers, so an incomplete or mistyped command can never silently change Start at Login. |
| `LoginCLI` | `runIfRequested()` — acts on that flag and exits, or returns when it is absent. One line at the top of `main` gives an app a scriptable Start at Login, which is the only way an installer can turn it on: `SMAppService` registers the calling process's own bundle and nothing else. |
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

## Status-item icons

`MeterIcon` draws the glyph itself rather than shipping assets, so a status item
can show a live value without a single image file. Every style is drawn at 18pt,
the menu-bar glyph size.

![MeterIcon styles](docs/meter-icons.png)

| Style | Call | Reads as |
|---|---|---|
| `gauge` | `MeterIcon.gauge(fraction: 0.4, color: .black)` | Speedometer needle over a faint track. Distinctive, but the needle is thin — small changes are hard to see at 18pt. |
| `arc` | `MeterIcon.arc(fraction: 0.4, color: .black)` | Ring filling clockwise. The most legible at menu-bar size: the filled length reads instantly. |
| `pie` | `MeterIcon.pie(fraction: 0.4, color: .black)` | Outlined circle with a wedge filling in. Clear as a fraction, though 100% is a solid disc. |
| `wedge` | `MeterIcon.wedge(fraction: 0.4, color: .black)` | Solid disc with a wedge. Highest contrast — but note 0% is still a filled circle, so "empty" and "full" can be confused at a glance. |
| `dot` | `MeterIcon.dot(color: .systemGreen)` | No level at all — a plain filled circle for discrete states. Takes an optional `diameter` (default 10). |

`fraction` is clamped to `0...1`, so callers need not range-check.

Setting one is a single call on the controller:

```swift
controller.setIcon(MeterIcon.arc(fraction: 0.4, color: .black))
```

### Colour vs. template

These are **full-colour, non-template** images by default, which is what you want
when the colour carries meaning:

```swift
let pct = currentPercentage()
controller.setIcon(MeterIcon.arc(fraction: CGFloat(pct) / 100,
                                 color: Severity.level(pct: pct, warnPct: 85).color))
```

To instead match the standard menu-bar glyph — black in light mode, white in dark,
inverted while the menu is open — draw in black and mark it a template:

```swift
let icon = MeterIcon.arc(fraction: 0.4, color: .black)
icon.isTemplate = true
controller.setIcon(icon)
```

Template tinting uses only the drawn *alpha*, so the colour you pass is discarded;
black is simply the conventional ink. That also means the faint 28%-alpha track the
meters draw survives templating and still reads as a track. A useful pattern is to
template while the app can act, and fall back to a muted `.systemGray` full-colour
icon when it cannot — the greyed icon then reads as unavailable in both appearances.

Regenerate the image above after changing `MeterIcon`:

```sh
scripts/render-meter-icons.sh    # writes docs/meter-icons.png
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

### Versioning

The version comes from git, not `Info.plist`: `make-app.sh` stamps the
consuming repo's nearest `vMAJOR.MINOR.PATCH[-prerelease]` tag into the bundle
and **refuses to build without one**. In a Menumon app you don't tag by hand —
see [Releases](#releases-every-push-is-one) below.

| Key | Tagged, clean build | 3 commits past the tag, uncommitted edits |
|---|---|---|
| `CFBundleShortVersionString` | `1.2.0` | `1.2.0` |
| `CFBundleVersion` | `abc1234` | `abc1234.dirty` |
| `StatusItemKitVersion` | `1.2.0` | `1.2.0+3.gabc1234.dirty` |

`menu.addItem(AppVersion.menuItem())` adds a disabled "Version …" row showing
`StatusItemKitVersion`, so any two builds can be told apart from the menu.
Bump MAJOR for a breaking change in behaviour or settings, MINOR for a
feature, PATCH for a fix.

> **The `codesign` step is mandatory, not cosmetic.**
> `UNUserNotificationCenter` silently drops notification requests from unsigned
> bundles — threshold/alert notifications will appear to "not fire" if the
> signature is missing.

### Stable signing (so TCC grants survive rebuilds)

By default the bundle is **ad-hoc** signed. Ad-hoc signatures have no stable
identity, so every rebuild produces a new code hash (CDHash). macOS keys TCC
permissions — Accessibility, Screen Recording, etc. — on that hash, so an
ad-hoc app **loses its grant on every rebuild** and the user must re-approve it.
(That bites any app needing such a permission, e.g. a key-intercepting app.)

Run once to install a self-signed code-signing identity in your login keychain:

```sh
scripts/setup-signing.sh   # idempotent; creates "StatusItemKit Local Signing"
```

`make-app.sh` then signs with it automatically (precedence:
`$STATUSITEMKIT_SIGN_ID` → the `StatusItemKit Local Signing` identity → ad-hoc).
A real identity gives the bundle a stable Designated Requirement (the cert's
leaf hash, not the CDHash), so TCC honors the grant across rebuilds: approve
once, and it sticks.

Your app provides its own `Resources/Info.plist` with `LSUIElement=true` (no
Dock icon) and a real bundle identifier; use this repo's
[`Resources/Info.plist`](Resources/Info.plist) as the template.

## Releases: every push is one

Every Menumon app (and StatusItemKit and HotkeyKit) follows one rule: **every push is
a release, and every release has a changelog entry.** Before pushing, add a
section to the top of the repo's `CHANGELOG.md`:

```markdown
## [1.3.0] - 2026-09-26
### Changed
- What changed, for someone who uses the app.
```

When it reaches `main`, GitHub tags `v1.3.0` on that commit and publishes a
GitHub Release with the section as its notes. Two guards enforce the rule, both
running [`scripts/release/check-release.sh`](scripts/release/check-release.sh)
(the section must be new, dated, non-empty and above every existing tag):

- **`.github/workflows/release.yml`** in each app calls the reusable
  [`menumon-release.yml`](.github/workflows/menumon-release.yml). (Its old name,
  `menubarn-release.yml`, still works and warns on every run.) It runs on
  every push to `main` — merged PR or direct push, from any machine — and does
  the tagging. A push without a new version fails the run, so nothing slips by.
- **A `pre-push` hook** refuses the push locally, before GitHub sees it.
- **Pull requests** run the same check, and branch protection on `main`
  makes it required: a PR whose `CHANGELOG.md` has no new, correctly formatted
  version **cannot be merged** — unless its tip commit says `[no release]`,
  which passes the check without a version bump (so no new tag).

**One naming convention.** Versions are `vX.Y.Z` tags, changelog sections are
`## [X.Y.Z] - YYYY-MM-DD`, and a GitHub Release is titled with its tag,
`vX.Y.Z` — never "AppName X.Y.Z". Releases are only ever made by the workflow;
if one is created by hand, the workflow retitles it to its tag and fails the
run so it is noticed.

Set a repo up with `scripts/release/adopt.sh` (no arguments: every Menumon
app in `~/Code`, StatusItemKit and HotkeyKit; or pass repo paths). It
backfills `CHANGELOG.md` from the existing tags, writes the workflow, points
the repo's `core.hooksPath` at `scripts/release/hooks`, and sets the branch
protection that requires `release / check` to merge (needs `gh`).

### Things to know

- **Not a release?** Put `[no release]` in the tip commit's message — for
  setup, CI or tooling that changes nothing a user runs. Every guard skips it,
  and a PR marked that way can merge without a version.
- **Never `gh pr merge --admin`.** Branch protection doesn't bind admins
  (so a direct push to `main` still works, guarded by the hook and the push
  job), which means `--admin` would force a blocked PR through. Fix the PR.
  `git push --no-verify` skips only the local hook; GitHub still checks.
- **`## [Unreleased]`** — some changelogs were backfilled with commits made
  since the last tag. The next push turns that section into its version
  (rename the heading, add the date, reword the entries for a user).
- **Don't tag by hand.** The workflow tags; a hand-made tag for the same
  version makes the run fail. After a merge, `git pull` to fetch the tag, then
  rebuild so the menu shows a clean version instead of `+N.gSHA`.
- **The hook is per repo, per machine.** It lives in each repo's local git
  config, not a global `core.hooksPath`, which would silently disable every
  other repo's own hooks. So a fresh clone has no hook until it is re-armed —
  every app's `install.sh` and the macOS setup suite do that by running
  `scripts/release/adopt.sh --hooks-only`, which you can also run by hand. The
  GitHub check applies regardless.
- **Push over SSH.** Pushing a change to `.github/workflows/` over HTTPS needs
  a token with the `workflow` scope; the SSH remotes (`git@github.com:…`) need
  nothing extra.

## Development

```sh
swift test                          # unit tests (Severity, Shell, MenuBuilder, MeterIcon)
./scripts/make-app.sh StatusItemKitDemo && open build/StatusItemKitDemo.app
```

AppKit/system glue (`StatusItemController`, `LoginItem`, `Notifier`) isn't
unit-tested — it's verified by running the demo.

## License

Copyright (c) 2026 Nicholas Smith. Licensed under the
[Mozilla Public License 2.0](LICENSE). You may use, modify, sell and
redistribute this software, including inside proprietary products, provided
the copyright notice and license stay on these files and any modified
versions of them are made available under the same license.

## The Icon menu

Any app with a meter icon can offer the same picker — shape, seven colour
presets, and the macOS colour panel — in three lines:

```swift
let appearance = MeterAppearance(defaultStyle: .arc)
lazy var appearanceMenu = AppearanceMenu(appearance: appearance) { [weak self] in
    self?.redraw()          // called whenever a choice changes
}

// ...while building the menu:
menu.addItem(appearanceMenu.menuItem())     // an "Icon" item with the picker under it
```

Then draw with what the user chose:

```swift
controller.setIcon(appearance.image(fraction: fraction))
// or, when the app has its own severity ramp:
controller.setIcon(MeterIcon.image(style: appearance.style, fraction: fraction, color: myColor))
```

Notes:

- **`styles:` defaults to `MeterStyle.proportional`**, which omits `.dot` — it
  ignores the fraction, so it cannot do a percentage icon's job. Pass
  `MeterStyle.allCases` for an app whose icon shows state rather than a level.
- **Treat `appearance.color` as the resting colour.** If your app escalates
  (`Severity`), keep your warning colours for the upper bands: a meter that
  looks identical at 5% and 95% has stopped saying the thing it exists to say.
- **An app whose colour is not one number can supply its own colour block.**
  Pass `colorItems: { submenu in ... }` and it is called after the shapes and
  their separator instead of the presets and the panel; the app owns those
  items' persistence and redraw.
- **An app whose colours are all data can offer none.** Pass
  `offersColour: false` and the submenu is shapes only. Claude Usage does this:
  its owl's pupils and its bars are `MeterColor.usage(fraction)`, cyan at 0
  and red at 1, so a colour preference would only contradict them.
- **The default colour is the Green preset, not `NSColor.systemGreen`.** The
  system colour is dynamic and resolves to a different hex in dark mode, so it
  would never match a preset and a fresh install would show "Custom Colour…"
  ticked with nothing customised.
- **Colours persist as hex**, not archived `NSColor`: readable in
  `defaults read`, stable across OS versions, and fixable by hand.
- `AppearanceMenu` must be **retained by the app** — it is the menu items'
  target, and `NSMenuItem` does not retain its target. It drops its hold on the
  shared colour panel when the panel closes, so one app's picker cannot end up
  writing into another's preference.

## The menu-bar suite

One of the two frameworks behind a suite of macOS menu-bar apps. They share
one build-and-sign script and one installer, and are designed to sit in the
same bar together.

| App | What it does |
|---|---|
| [Claude Usage](https://github.com/nicholaspsmith/claude-usage-menubar) | Claude Code plan limits, resets, and live agent sessions |
| [Apollo Monitor](https://github.com/nicholaspsmith/apollo-monitor-menubar) | Apollo audio-interface monitor level, plus a mixer-process watchdog |
| [Battery Time](https://github.com/nicholaspsmith/battery-time-menubar) | Time remaining, power mode, and 24h usage |
| [VPN & DNS](https://github.com/nicholaspsmith/vpn-dns-menubar) | A chameleon for Mullvad + Tailscale state, with a DNS watcher |
| [Mac Daddy](https://github.com/nicholaspsmith/mac-daddy-menubar) | Kills media trackers, trashes stale downloads, reaps hung processes, and sweats as your process count climbs |
| [KeyLight](https://github.com/nicholaspsmith/keylight-menubar) | Ctrl+brightness keys remapped to keyboard backlight |
| [MacRecorder](https://github.com/nicholaspsmith/MacRecorder) | Screen recording with system audio |
| [Barn](https://github.com/nicholaspsmith/menubar-barn) | Sunset: macOS 26 and earlier only. Hid a block of status icons by width; on macOS 27 use System Settings ▸ Menu Bar |

| Framework | |
|---|---|
| **StatusItemKit** | Status-item lifecycle, polling, menus, meter icons, the shared Icon picker |
| [HotkeyKit](https://github.com/nicholaspsmith/HotkeyKit) | CGEventTap engine for intercepting and remapping global keys |

Install the whole suite on a fresh Mac with
[macOS Dev Environment Setup](https://github.com/nicholaspsmith/MacOS-Dev-Environment-Setup):

```bash
git clone https://github.com/nicholaspsmith/MacOS-Dev-Environment-Setup.git
cd MacOS-Dev-Environment-Setup && ./bootstrap.sh --all
```
