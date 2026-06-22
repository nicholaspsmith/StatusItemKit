# StatusItemKit + menu-bar app conversions — design

**Date:** 2026-06-22
**Status:** Approved (design); implementation plan to follow.

## Problem

Two menu-bar tools currently run as [SwiftBar](https://github.com/swiftbar/SwiftBar)
plugins and therefore depend on a third-party host app being installed and running:

- `~/Code/vpn-dns-menubar` — one status dot consolidating Mullvad VPN + Tailscale,
  with a click-through dropdown and a live `accept-dns` indicator.
- `~/Code/battery-time-menubar` — battery time-remaining (the estimate Apple removed
  in 2016) with a rich stats/settings dropdown.

The goal is to convert both into **standalone Swift menu-bar apps** — like the existing
`~/Code/MacOS_Process_Monitor` (ProcessMonitor) — so they no longer rely on SwiftBar,
and to factor everything those apps share into a reusable, open-source base framework.

## Goals

- Standalone `.app` bundles for both tools; no SwiftBar dependency.
- A reusable base framework, **StatusItemKit**, in its own open-source (MIT) git repo.
- Parsing implemented as **pure, testable functions** with SwiftPM test targets.
- Keep each existing SwiftBar plugin in place until its Swift app reaches parity, then
  it can be deleted — no flag day.

## Non-goals (this round)

- Retrofitting ProcessMonitor onto StatusItemKit. It stays untouched; it's a later
  candidate and the proof-by-third-consumer can happen then.
- Converting the companion launchd agents. The vpn-dns DNS-sync agent
  (`com.nicholassmith.mullvad-tailscale-dns`) is independent of SwiftBar and keeps
  running. The battery `power-watch` agent **is** replaced — but by in-app IOKit
  notifications, not by a separate agent (see Battery app below).

## Decisions (locked)

| Decision | Choice |
|----------|--------|
| Repo topology | Separate repos. Apps depend on StatusItemKit via a **local SwiftPM path** (`.package(path: "../StatusItemKit")`) during dev, switched to a git URL + version tag for release. |
| Base v1 scope | **Core mechanics + meter icons.** |
| ProcessMonitor | Left untouched this round. |
| Framework name | **StatusItemKit.** |

## Architecture

```
~/Code/StatusItemKit/          NEW open-source repo (the base framework)
~/Code/vpn-dns-menubar/        existing repo; Swift app added alongside the plugin
~/Code/battery-time-menubar/   existing repo; Swift app added alongside the plugin
~/Code/MacOS_Process_Monitor/  untouched this round
```

### The testability split (applies to every app)

Each app is **two source targets + one test target**:

- `Sources/<App>Core/` — **pure Swift, no AppKit.** All parsing and logic. Takes raw
  command output (`String`) in, returns typed models / formatted strings out. No
  `Process`, no I/O, no system calls. This is the unit-tested surface.
- `Sources/<App>/` — **executable, AppKit.** Imports `StatusItemKit` + `<App>Core`.
  Runs the commands, feeds their output to Core, drives the status item and menu.
- `Tests/<App>CoreTests/` — **XCTest against Core** using recorded fixture strings.

"Pure and testable" means Core never touches the system: a test hands it a recorded
`pmset`/`ioreg`/`mullvad` dump and asserts on the parsed result. The battery plugin
already ships shell fixtures (`PMSET_FIXTURE`, `IOREG_FIXTURE`, `PMSET_LOG_FIXTURE`,
`POWERMODE_FIXTURE`); those captured texts are reused as Swift test fixtures.

## StatusItemKit — the shared framework

One SwiftPM library, `platforms: [.macOS(.v13)]`, MIT-licensed. Public surface:

- **`Shell.run(_ path: String, _ args: [String]) -> String?`** — `Process` → stdout
  helper, extracted from ProcessMonitor's `readAllProcs` plumbing. The one I/O
  primitive every app needs.
- **`StatusItemController`** — owns the `NSStatusItem`, the poll `Timer` (configurable
  interval), `.accessory` activation policy, and lazy menu rebuild via
  `NSMenuDelegate.menuNeedsUpdate`. Constructed with a `poll` closure (returns app
  state) and a `buildMenu` closure (called on menu open). Replaces the AppDelegate
  boilerplate.
- **Render funnel** — `setTitle(_:warn:)` (attributed, monospaced-digit, red-on-warn)
  and `setIcon(_:)` (imageOnly, clears `contentTintColor`). The mutually-exclusive
  `imagePosition` discipline (`.noImage` for text, `.imageOnly` for icons) is baked in
  so callers can't leave stray title spacing.
- **`MenuBuilder` helpers** — the view-based `NSMenuItem` that escapes the
  keyboard-shortcut column reservation, and the `NSString.size(withAttributes:)`
  label-measurement (`ceil` + small buffer, not `intrinsicContentSize`). Generic, not
  sparkline-specific.
- **`LoginItem`** — `SMAppService.mainApp` register/unregister + the "must live in
  /Applications or ~/Applications" error alert.
- **`Notifier`** — `UNUserNotificationCenter` authorization request + `post(title:body:)`.
- **`MeterIcon`** (the "+ icons" module) — `gauge` / `arc` / `pie` / `wedge`
  proportional-fill drawers + `dot(color:)`, each parameterized by `fraction` (0...1)
  and `color`, lifted from ProcessMonitor's `make…Image`. Non-template (color carries
  information). ProcessMonitor's `meterColor` severity ramp becomes a reusable
  `Severity` helper (green < 50%, orange < warn, red ≥ warn).
- **Tooling** — `scripts/make-app.sh <ProductName> [<BundleDisplayName>]`: the
  parameterized `build-app.sh` (swift build -c release → assemble `.app` bundle →
  **ad-hoc codesign**, kept because `UNUserNotificationCenter` silently drops requests
  from unsigned bundles). The SwiftPM executable product name and the user-visible
  bundle name can differ (e.g. product `BatteryTime` → "Battery Time.app"); the second
  arg defaults to the first. An `Info.plist` template with `LSUIElement=true` and a
  bundle-ID placeholder. Each app vendors a one-line `scripts/build-app.sh` that calls
  the shared script from the local path, e.g.
  `exec ../StatusItemKit/scripts/make-app.sh BatteryTime "Battery Time"`.

StatusItemKit's own tests cover the pure bits (severity ramp boundaries, label-width
math, meter-geometry sanity). The AppKit glue is verified manually.

### Repo skeleton

```
StatusItemKit/
  Package.swift                 library product "StatusItemKit"
  Sources/StatusItemKit/        Shell, StatusItemController, render funnel,
                                MenuBuilder, LoginItem, Notifier, MeterIcon, Severity
  Tests/StatusItemKitTests/     pure-bit tests
  scripts/make-app.sh           parameterized build + ad-hoc sign
  Resources/Info.plist.template LSUIElement + bundle-ID placeholder
  README.md  LICENSE (MIT)  .gitignore  docs/
```

## App: vpn-dns-menubar → `VPNDNSMenuBar` (bundle "VPN & DNS.app")

- **`VPNDNSCore`** — `parseMullvadStatus`, `parseTailscaleStatus` / `parseCorpDNS` →
  a `VPNState` model plus row labels and severity colors. Ports the awk/grep from the
  95-line plugin.
- **App** — dot via `MeterIcon.dot(color:)`; 3-row menu: `accept-dns` status
  (non-clickable), Mullvad row → shells out to the existing
  `assets/open-native-menu.sh` AX helper (kept), Tailscale row → `open -a Tailscale`.
  5s poll, matching today.
- **Out of scope** — the `com.nicholassmith.mullvad-tailscale-dns` DNS-sync launchd
  agent is independent of SwiftBar and keeps running unchanged.

## App: battery-time-menubar → `BatteryTime` (bundle "Battery Time.app")

- **`BatteryTimeCore`** — `parsePmsetBatt`, `parseIORegBattery` (~8 fields: health,
  cycles, voltage, instant amperage, temperature, adapter name/watts, raw capacity),
  the post-unplug ETA-stopgap math (measured-draw projection capped by a nominal ~12 W),
  the 24h on-battery-vs-AC parse, humanize/format helpers, and the tips triggers. This
  is the bulk of the port and where the fixture tests pay off.
- **App** — folds the existing **`render-title.swift`** in as the battery-glyph drawer
  (already Swift — the hardest visual piece is done). Dropdown: energy mode via
  `sudo pmset … powermode` (existing passwordless-sudoers rule reused), stats, °C/°F
  toggle, 24h usage (computed via the existing perl one-liner, cached in-memory and
  recomputed on a 10-min timer), tips dialog, and icon/percentage/time display toggles
  via `UserDefaults`. **Instant plug/unplug** via native IOKit power-source
  notifications (`IOPSNotificationCreateRunLoopSource`), retiring the `power-watch`
  launchd agent.

## Testing strategy

- Pure parsing in `*Core` targets; SwiftPM `*CoreTests` assert against recorded
  fixtures (reuse the battery plugin's existing fixtures; capture vpn-dns fixtures from
  live `mullvad`/`tailscale` output).
- StatusItemKit unit-tests its pure helpers.
- AppKit/menu behavior verified manually with a per-app checklist (the ProcessMonitor
  model — build, launch, click, observe), since there is no way to unit-test the
  status item itself.

## Execution strategy

The dependency graph: **StatusItemKit is the keystone — its public API gates both
apps**, so it cannot be parallelized with them.

1. **Build StatusItemKit first, single-threaded** (main session). Validate the public
   API by sketching both apps' call sites before freezing it. Repo init + atomic
   commits + push (create the GitHub remote here).
2. **Fan out two parallel subagents**, one per app repo. They are separate repos
   consuming StatusItemKit read-only, so they are naturally isolated — no git worktrees
   needed, no write conflicts. Each agent: Core + exec + tests + build + manual-verify
   checklist + atomic commits in its own repo.
3. **Integrate** (main session): review both, run builds/tests, do the manual menu-bar
   verification, absorb any StatusItemKit API gaps centrally (re-tag, bump both apps).

This beats three fully-independent agents, which would each guess at an unstable shared
API and diverge. Step 2 uses the dispatching-parallel-agents skill.

## Risks / notes

- **API churn:** app work may reveal StatusItemKit API gaps. Mitigated by sketching
  call sites before freezing (step 1) and absorbing changes centrally (step 3).
- **Lost shell test coverage:** the battery plugin's shell test harness does not carry
  over; the `*Core` fixture tests are the replacement and must cover the same states.
- **Energy-mode sudo:** depends on the existing `/etc/sudoers.d` rule; the app shells
  out exactly as the plugin does.
- **Native-menu AX trick (vpn-dns):** kept as a shell-out to the existing AppleScript
  helper rather than reimplemented; still needs Accessibility/Automation permission,
  now granted to the new app instead of SwiftBar.
