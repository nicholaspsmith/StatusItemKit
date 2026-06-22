# StatusItemKit Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build StatusItemKit — a reusable, open-source SwiftPM library that provides the shared mechanics for standalone macOS menu-bar apps (status-item lifecycle, polling, lazy menu, render funnel, login-item, notifications, meter icons, and a parameterized build/sign script) — validated by a small demo app.

**Architecture:** One SwiftPM library target `StatusItemKit` plus an example executable `StatusItemKitDemo` in the same package. Pure helpers (severity ramp, label-width math) are unit-tested with XCTest; AppKit/system glue (controller, login item, notifier, icon drawing) is verified by building and running the demo app. A `scripts/make-app.sh` wraps any SwiftPM executable into an ad-hoc-signed `.app` bundle.

**Tech Stack:** Swift 5.9, SwiftPM, AppKit, ServiceManagement (`SMAppService`), UserNotifications, macOS 13+.

## Global Constraints

- Platform floor: **macOS 13** (`platforms: [.macOS(.v13)]`) — required by `SMAppService.mainApp`. Copy verbatim into `Package.swift`.
- License: **MIT**.
- Repo is **public** on GitHub from the first push.
- The build script's **ad-hoc `codesign` step is mandatory** — `UNUserNotificationCenter` silently drops notification requests from unsigned bundles. Never remove it.
- Meter icons are **non-template** (`isTemplate = false`) — color carries severity information.
- Status-item rendering is **mutually exclusive** text vs. image: text path sets `imagePosition = .noImage` and clears `image`; icon path sets `imagePosition = .imageOnly` and clears `contentTintColor`. Every render path sets `imagePosition` explicitly.
- Use **explicit frames, not auto-layout constraints**, for any `NSView` placed in an `NSMenuItem` — NSMenu reads the frame at insertion time before any layout pass runs.
- Git: atomic commits per task. Commit messages end with the `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer.

---

### Task 1: Package skeleton + Severity ramp (pure, TDD)

**Files:**
- Create: `Package.swift`
- Create: `Sources/StatusItemKit/Severity.swift`
- Create: `.gitignore`
- Test: `Tests/StatusItemKitTests/SeverityTests.swift`

**Interfaces:**
- Produces: `enum Severity: Equatable { case normal, elevated, high }`, `static func Severity.level(pct: Int, warnPct: Int) -> Severity`, `var Severity.color: NSColor`.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StatusItemKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "StatusItemKit", targets: ["StatusItemKit"]),
        .executable(name: "StatusItemKitDemo", targets: ["StatusItemKitDemo"]),
    ],
    targets: [
        .target(name: "StatusItemKit"),
        .executableTarget(name: "StatusItemKitDemo", dependencies: ["StatusItemKit"]),
        .testTarget(name: "StatusItemKitTests", dependencies: ["StatusItemKit"]),
    ]
)
```

- [ ] **Step 2: Write `.gitignore`**

```
.build/
build/
*.app
.DS_Store
.swiftpm/
```

- [ ] **Step 3: Write the failing test** in `Tests/StatusItemKitTests/SeverityTests.swift`

```swift
import XCTest
@testable import StatusItemKit

final class SeverityTests: XCTestCase {
    func testNormalBelowHalf() {
        XCTAssertEqual(Severity.level(pct: 0, warnPct: 85), .normal)
        XCTAssertEqual(Severity.level(pct: 49, warnPct: 85), .normal)
    }
    func testElevatedFromHalfToWarn() {
        XCTAssertEqual(Severity.level(pct: 50, warnPct: 85), .elevated)
        XCTAssertEqual(Severity.level(pct: 84, warnPct: 85), .elevated)
    }
    func testHighAtOrAboveWarn() {
        XCTAssertEqual(Severity.level(pct: 85, warnPct: 85), .high)
        XCTAssertEqual(Severity.level(pct: 200, warnPct: 85), .high)
    }
}
```

- [ ] **Step 4: Run the test, verify it fails**

Run: `swift test --filter SeverityTests`
Expected: FAIL — `Severity` is not defined (compile error).

- [ ] **Step 5: Implement `Sources/StatusItemKit/Severity.swift`**

```swift
import AppKit

/// Three-level severity derived from a percentage against a warn threshold.
/// The `level` function is pure (Int -> case); `color` is the AppKit mapping.
public enum Severity: Equatable {
    case normal, elevated, high

    /// green below 50%, orange from 50% up to the warn threshold, red at/above it.
    public static func level(pct: Int, warnPct: Int) -> Severity {
        if pct >= warnPct { return .high }
        if pct >= 50 { return .elevated }
        return .normal
    }

    public var color: NSColor {
        switch self {
        case .normal: return .systemGreen
        case .elevated: return .systemOrange
        case .high: return .systemRed
        }
    }
}
```

- [ ] **Step 6: Run the test, verify it passes**

Run: `swift test --filter SeverityTests`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add Package.swift .gitignore Sources/StatusItemKit/Severity.swift Tests/StatusItemKitTests/SeverityTests.swift
git commit -m "feat: package skeleton + Severity ramp

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Shell command runner

**Files:**
- Create: `Sources/StatusItemKit/Shell.swift`
- Test: `Tests/StatusItemKitTests/ShellTests.swift`

**Interfaces:**
- Produces: `enum Shell { static func run(_ path: String, _ args: [String]) -> String? }` — returns stdout as UTF-8, or `nil` on launch failure / non-zero exit / non-UTF-8 output.

- [ ] **Step 1: Write the failing test** in `Tests/StatusItemKitTests/ShellTests.swift`

```swift
import XCTest
@testable import StatusItemKit

final class ShellTests: XCTestCase {
    func testEchoReturnsStdout() {
        XCTAssertEqual(Shell.run("/bin/echo", ["hello"]), "hello\n")
    }
    func testNonexistentBinaryReturnsNil() {
        XCTAssertNil(Shell.run("/nonexistent/binary", []))
    }
    func testNonzeroExitReturnsNil() {
        // `false` exits 1 with no output.
        XCTAssertNil(Shell.run("/usr/bin/false", []))
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --filter ShellTests`
Expected: FAIL — `Shell` is not defined.

- [ ] **Step 3: Implement `Sources/StatusItemKit/Shell.swift`**

```swift
import Foundation

/// Minimal synchronous command runner. Returns stdout as UTF-8 text on a
/// clean (exit 0) run, or nil if the process can't launch, exits non-zero,
/// or its output isn't UTF-8. stderr is discarded.
public enum Shell {
    public static func run(_ path: String, _ args: [String]) -> String? {
        let task = Process()
        task.launchPath = path
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `swift test --filter ShellTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/StatusItemKit/Shell.swift Tests/StatusItemKitTests/ShellTests.swift
git commit -m "feat: Shell command runner

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: MenuBuilder label-width math + view-based item

**Files:**
- Create: `Sources/StatusItemKit/MenuBuilder.swift`
- Test: `Tests/StatusItemKitTests/MenuBuilderTests.swift`

**Interfaces:**
- Produces: `enum MenuBuilder` with:
  - `static func labelWidth(_ text: String, font: NSFont, buffer: CGFloat = 4) -> CGFloat` — `ceil(NSString.size) + buffer`.
  - `static func textView(_ text: String, font: NSFont, color: NSColor = .secondaryLabelColor, leftPad: CGFloat = 20, rightPad: CGFloat = 6, vPad: CGFloat = 3) -> NSView` — explicit-frame NSView wrapping an NSTextField, for use as `NSMenuItem.view`.

- [ ] **Step 1: Write the failing test** in `Tests/StatusItemKitTests/MenuBuilderTests.swift`

```swift
import XCTest
import AppKit
@testable import StatusItemKit

final class MenuBuilderTests: XCTestCase {
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    func testLabelWidthIsCeiledPlusBuffer() {
        let text = "▁▂▃▄▅▆▇█  100→200"
        let raw = (text as NSString).size(withAttributes: [.font: font]).width
        XCTAssertEqual(MenuBuilder.labelWidth(text, font: font, buffer: 4), ceil(raw) + 4, accuracy: 0.001)
    }

    func testLongerTextIsWider() {
        XCTAssertGreaterThan(
            MenuBuilder.labelWidth("longer string here", font: font),
            MenuBuilder.labelWidth("short", font: font)
        )
    }

    func testTextViewHasNonZeroExplicitFrame() {
        let v = MenuBuilder.textView("hello", font: font)
        XCTAssertGreaterThan(v.frame.width, 0)
        XCTAssertGreaterThan(v.frame.height, 0)
        XCTAssertEqual(v.subviews.count, 1)  // the label
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --filter MenuBuilderTests`
Expected: FAIL — `MenuBuilder` is not defined.

- [ ] **Step 3: Implement `Sources/StatusItemKit/MenuBuilder.swift`**

```swift
import AppKit

/// Helpers for menu items that must escape NSMenu's standard layout (which
/// reserves trailing space for the keyboard-shortcut column on every row).
public enum MenuBuilder {
    /// Width a label needs in a menu-item view. Uses NSString.size (not
    /// NSTextField.intrinsicContentSize, which rounds down sub-pixel and clips
    /// the trailing glyph), ceils, and adds a small safety buffer.
    public static func labelWidth(_ text: String, font: NSFont, buffer: CGFloat = 4) -> CGFloat {
        let measured = (text as NSString).size(withAttributes: [.font: font])
        return ceil(measured.width) + buffer
    }

    /// An NSView (for NSMenuItem.view) wrapping a left-padded label. Uses
    /// explicit frames: NSMenu reads the frame at insertion time, before any
    /// auto-layout pass, so a constraint-only view would be zero-sized.
    public static func textView(
        _ text: String,
        font: NSFont,
        color: NSColor = .secondaryLabelColor,
        leftPad: CGFloat = 20,
        rightPad: CGFloat = 6,
        vPad: CGFloat = 3
    ) -> NSView {
        let w = labelWidth(text, font: font)
        let h = ceil((text as NSString).size(withAttributes: [.font: font]).height)

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.frame = NSRect(x: leftPad, y: vPad, width: w, height: h)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w + leftPad + rightPad, height: h + vPad * 2))
        container.addSubview(label)
        return container
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `swift test --filter MenuBuilderTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/StatusItemKit/MenuBuilder.swift Tests/StatusItemKitTests/MenuBuilderTests.swift
git commit -m "feat: MenuBuilder label-width math + view-based item

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: MeterIcon drawing (dot + gauge/arc/pie/wedge)

**Files:**
- Create: `Sources/StatusItemKit/MeterIcon.swift`
- Test: `Tests/StatusItemKitTests/MeterIconTests.swift`

**Interfaces:**
- Produces: `enum MeterIcon` with static functions, each returning a non-template `NSImage`:
  - `dot(color: NSColor, diameter: CGFloat = 10) -> NSImage`
  - `gauge(fraction: CGFloat, color: NSColor) -> NSImage`
  - `arc(fraction: CGFloat, color: NSColor) -> NSImage`
  - `pie(fraction: CGFloat, color: NSColor) -> NSImage`
  - `wedge(fraction: CGFloat, color: NSColor) -> NSImage`
  - `fraction` is clamped to `0...1` internally.

These render via Core Graphics so they produce a valid bitmap in headless `swift test` (no live status bar). Drawing correctness is verified visually in the demo (Task 8); the unit tests assert structural invariants only.

- [ ] **Step 1: Write the failing test** in `Tests/StatusItemKitTests/MeterIconTests.swift`

```swift
import XCTest
import AppKit
@testable import StatusItemKit

final class MeterIconTests: XCTestCase {
    func testDotIsNonTemplateWithExpectedSize() {
        let img = MeterIcon.dot(color: .systemGreen, diameter: 10)
        XCTAssertFalse(img.isTemplate)
        XCTAssertEqual(img.size.width, 18, accuracy: 0.001)   // 10 + 4*2 padding
        XCTAssertEqual(img.size.height, 18, accuracy: 0.001)
    }

    func testMetersAreNonTemplate18pt() {
        for img in [
            MeterIcon.gauge(fraction: 0.5, color: .systemOrange),
            MeterIcon.arc(fraction: 0.5, color: .systemOrange),
            MeterIcon.pie(fraction: 0.5, color: .systemOrange),
            MeterIcon.wedge(fraction: 0.5, color: .systemOrange),
        ] {
            XCTAssertFalse(img.isTemplate)
            XCTAssertEqual(img.size.width, 18, accuracy: 0.001)
            XCTAssertEqual(img.size.height, 18, accuracy: 0.001)
        }
    }

    func testFractionExtremesDoNotCrash() {
        // out-of-range fractions are clamped, not fatal
        _ = MeterIcon.arc(fraction: -1, color: .systemGreen)
        _ = MeterIcon.wedge(fraction: 2, color: .systemRed)
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --filter MeterIconTests`
Expected: FAIL — `MeterIcon` is not defined.

- [ ] **Step 3: Implement `Sources/StatusItemKit/MeterIcon.swift`**

```swift
import AppKit

/// Custom-drawn, full-color (non-template) status-item glyphs. The pct-driven
/// meters (gauge/arc/pie/wedge) take a 0...1 fraction and a color; `dot` is a
/// plain filled circle for discrete-state apps. Ported from ProcessMonitor.
public enum MeterIcon {
    private static let side: CGFloat = 18

    private static func image(_ draw: @escaping (NSRect) -> Void) -> NSImage {
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            draw(rect); return true
        }
        img.isTemplate = false
        return img
    }

    private static func clamp(_ f: CGFloat) -> CGFloat { max(0, min(1, f)) }

    public static func dot(color: NSColor, diameter: CGFloat = 10) -> NSImage {
        let pad: CGFloat = 4
        let s = diameter + pad * 2
        let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
            color.set()
            NSBezierPath(ovalIn: NSRect(x: pad, y: pad, width: diameter, height: diameter)).fill()
            return true
        }
        img.isTemplate = false
        return img
    }

    /// Speedometer: needle angle proportional to fraction over a ~250° arc.
    public static func gauge(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY - 1.5)
            let radius: CGFloat = 6.5
            let startAngle: CGFloat = 215
            let endAngle: CGFloat = -35
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            track.lineWidth = 2.4
            track.lineCapStyle = .round
            color.withAlphaComponent(0.28).set()
            track.stroke()
            color.set()
            let needleAngle = (startAngle + (endAngle - startAngle) * frac) * .pi / 180
            let tip = NSPoint(x: center.x + cos(needleAngle) * (radius - 0.3),
                              y: center.y + sin(needleAngle) * (radius - 0.3))
            let needle = NSBezierPath()
            needle.move(to: center)
            needle.line(to: tip)
            needle.lineWidth = 2.8
            needle.lineCapStyle = .round
            needle.stroke()
            let hubR: CGFloat = 2.3
            NSBezierPath(ovalIn: NSRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)).fill()
        }
    }

    /// Radial arc: faint full track + bold arc filled to fraction.
    public static func arc(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY - 1.5)
            let radius: CGFloat = 6.5
            let startAngle: CGFloat = 215
            let endAngle: CGFloat = -35
            let lineWidth: CGFloat = 3.4
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            track.lineWidth = lineWidth
            track.lineCapStyle = .round
            color.withAlphaComponent(0.28).set()
            track.stroke()
            if frac > 0 {
                let fillEnd = startAngle + (endAngle - startAngle) * frac
                let fill = NSBezierPath()
                fill.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: fillEnd, clockwise: true)
                fill.lineWidth = lineWidth
                fill.lineCapStyle = .round
                color.set()
                fill.stroke()
            }
        }
    }

    /// Pie: full circle outline = cap; filled wedge = fraction in use.
    public static func pie(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7
            color.set()
            let circle = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            circle.lineWidth = 2.2
            circle.stroke()
            if frac > 0 {
                let wedgeRadius = radius - 1.4
                let wedge = NSBezierPath()
                wedge.move(to: center)
                wedge.appendArc(withCenter: center, radius: wedgeRadius, startAngle: 90, endAngle: 90 - 360 * frac, clockwise: true)
                wedge.close()
                wedge.fill()
            }
        }
    }

    /// Pie variant: solid wedge = fraction; faint full disk = remaining cap.
    public static func wedge(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7.5
            color.withAlphaComponent(0.28).set()
            NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
            if frac > 0 {
                let wedge = NSBezierPath()
                wedge.move(to: center)
                wedge.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * frac, clockwise: true)
                wedge.close()
                color.set()
                wedge.fill()
            }
        }
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `swift test --filter MeterIconTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/StatusItemKit/MeterIcon.swift Tests/StatusItemKitTests/MeterIconTests.swift
git commit -m "feat: MeterIcon drawing (dot + gauge/arc/pie/wedge)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: LoginItem + Notifier (system glue, build-verified)

**Files:**
- Create: `Sources/StatusItemKit/LoginItem.swift`
- Create: `Sources/StatusItemKit/Notifier.swift`

**Interfaces:**
- Produces:
  - `enum LoginItem { static var isEnabled: Bool { get }; static func toggle() }` — wraps `SMAppService.mainApp`; on failure shows an NSAlert explaining the /Applications requirement.
  - `final class Notifier { init(); func requestAuthorization(); func post(title: String, body: String) }` — wraps `UNUserNotificationCenter`.

These touch system frameworks and a live `NSApplication`/bundle, so they are **not unit-tested**; they compile here and are exercised by the demo (Task 8). No test file.

- [ ] **Step 1: Implement `Sources/StatusItemKit/LoginItem.swift`**

```swift
import AppKit
import ServiceManagement

/// Start-at-Login via SMAppService.mainApp (registration is bundle-ID based and
/// requires the app to live in /Applications or ~/Applications).
public enum LoginItem {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Toggle registration. On failure (most often: app not in /Applications),
    /// shows a warning alert.
    public static func toggle() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled {
                try svc.unregister()
            } else {
                try svc.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't toggle Start at Login"
            alert.informativeText = """
            \(error.localizedDescription)

            macOS requires the app to live in /Applications or ~/Applications for this to work. Move the app there and try again.
            """
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
```

- [ ] **Step 2: Implement `Sources/StatusItemKit/Notifier.swift`**

```swift
import UserNotifications

/// Thin wrapper over UNUserNotificationCenter. Requires the host to be a signed
/// bundle with a bundle identifier, or requests are silently dropped.
public final class Notifier {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "statusitemkit.\(title).\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `swift build`
Expected: Builds with no errors (library target compiles `LoginItem` + `Notifier`).

- [ ] **Step 4: Commit**

```bash
git add Sources/StatusItemKit/LoginItem.swift Sources/StatusItemKit/Notifier.swift
git commit -m "feat: LoginItem + Notifier system wrappers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: StatusItemController + render funnel (AppKit glue, build-verified)

**Files:**
- Create: `Sources/StatusItemKit/StatusItemController.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks (standalone AppKit).
- Produces: `final class StatusItemController: NSObject, NSMenuDelegate` with:
  - `init(pollInterval: TimeInterval, onPoll: @escaping () -> Void, onBuildMenu: @escaping (NSMenu) -> Void)`
  - `func start()` — runs `onPoll` once immediately, then on a repeating timer.
  - `func setTitle(_ text: String, warn: Bool)` — text render path.
  - `func setIcon(_ image: NSImage)` — icon render path.
  - `var button: NSStatusBarButton? { get }` — for callers that need direct access.

- [ ] **Step 1: Implement `Sources/StatusItemKit/StatusItemController.swift`**

```swift
import AppKit

/// Owns an NSStatusItem, a polling timer, and lazy menu rebuilding. The host
/// supplies `onPoll` (gather state + call setTitle/setIcon) and `onBuildMenu`
/// (populate the menu when it opens). Rendering is funnelled through setTitle/
/// setIcon so the text and image paths stay mutually exclusive.
public final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let pollInterval: TimeInterval
    private let onPoll: () -> Void
    private let onBuildMenu: (NSMenu) -> Void
    private var timer: Timer?

    public var button: NSStatusBarButton? { statusItem.button }

    public init(
        pollInterval: TimeInterval,
        onPoll: @escaping () -> Void,
        onBuildMenu: @escaping (NSMenu) -> Void
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.pollInterval = pollInterval
        self.onPoll = onPoll
        self.onBuildMenu = onBuildMenu
        super.init()
        statusItem.button?.attributedTitle = NSAttributedString(string: "…")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    public func start() {
        onPoll()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.onPoll()
        }
    }

    // MARK: Render funnel

    /// Text render path: clears any image, monospaced-digit font, red on warn.
    public func setTitle(_ text: String, warn: Bool) {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.imagePosition = .noImage
        button.contentTintColor = nil
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: warn ? NSColor.systemRed : NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            ]
        )
    }

    /// Icon render path: clears title + tint (icons are full-color non-template).
    public func setIcon(_ image: NSImage) {
        guard let button = statusItem.button else { return }
        button.attributedTitle = NSAttributedString(string: "")
        button.imagePosition = .imageOnly
        button.contentTintColor = nil
        button.image = image
    }

    // MARK: Lazy menu rebuild

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        onBuildMenu(menu)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: Builds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/StatusItemKit/StatusItemController.swift
git commit -m "feat: StatusItemController + render funnel

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Build/sign tooling (make-app.sh + Info.plist template)

**Files:**
- Create: `scripts/make-app.sh`
- Create: `Resources/Info.plist` (the demo's plist, doubles as the template)

**Interfaces:**
- Produces: `scripts/make-app.sh <ProductName> [<BundleDisplayName>]` run from a SwiftPM package root; builds release, assembles `build/<DisplayName>.app`, copies `Resources/Info.plist`, ad-hoc signs. Defaults `<BundleDisplayName>` to `<ProductName>`.

- [ ] **Step 1: Write `Resources/Info.plist`** (used by the demo; template for apps — change `CFBundleExecutable`/`CFBundleName`/`CFBundleIdentifier` per app)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>StatusItemKitDemo</string>
    <key>CFBundleIdentifier</key>
    <string>com.nicholaspsmith.StatusItemKitDemo</string>
    <key>CFBundleName</key>
    <string>StatusItemKitDemo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Write `scripts/make-app.sh`**

```bash
#!/bin/bash
# Wrap a SwiftPM executable product into an ad-hoc-signed .app bundle.
# Run from the consuming package's root (it reads ./Resources/Info.plist and
# writes ./build/<DisplayName>.app). The ad-hoc codesign is REQUIRED:
# UNUserNotificationCenter silently drops requests from unsigned bundles.
#
# Usage: scripts/make-app.sh <ProductName> [<BundleDisplayName>]
set -euo pipefail

PRODUCT="${1:?usage: make-app.sh <ProductName> [<BundleDisplayName>]}"
DISPLAY="${2:-$PRODUCT}"
APP_BUNDLE="build/${DISPLAY}.app"

echo "==> swift build -c release"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/${PRODUCT}"
if [ ! -x "$BIN" ]; then
    echo "Build did not produce executable at $BIN" >&2
    exit 1
fi

echo "==> Assembling ${APP_BUNDLE}"
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "$BIN" "${APP_BUNDLE}/Contents/MacOS/${PRODUCT}"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
# Optional extra bundle resources (icons, helper scripts) live in Resources/bundle/.
if [ -d Resources/bundle ]; then
    cp -R Resources/bundle/. "${APP_BUNDLE}/Contents/Resources/"
fi

# Ad-hoc sign so notifications/launch services treat this as a stable identity.
codesign --force --sign - "${APP_BUNDLE}" >/dev/null

echo "==> Built ${APP_BUNDLE}"
echo "Launch with: open ${APP_BUNDLE}"
```

- [ ] **Step 3: Make it executable**

Run: `chmod +x scripts/make-app.sh`

- [ ] **Step 4: Commit**

```bash
git add scripts/make-app.sh Resources/Info.plist
git commit -m "feat: parameterized build/sign script + Info.plist template

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Demo app — dogfood the whole framework

**Files:**
- Create: `Sources/StatusItemKitDemo/main.swift`

**Interfaces:**
- Consumes: `StatusItemController`, `MeterIcon`, `Severity`, `LoginItem`, `Notifier`, `MenuBuilder` from the library.

This is the end-to-end manual validation: a real status item driven by the controller, cycling a meter color/fraction each poll, with a menu exercising MenuBuilder, LoginItem, and Notifier.

- [ ] **Step 1: Implement `Sources/StatusItemKitDemo/main.swift`**

```swift
import AppKit
import StatusItemKit

final class DemoApp: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController!
    private let notifier = Notifier()
    private var tick = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.requestAuthorization()
        controller = StatusItemController(
            pollInterval: 2,
            onPoll: { [weak self] in self?.poll() },
            onBuildMenu: { [weak self] menu in self?.buildMenu(menu) }
        )
        controller.start()
    }

    private func poll() {
        tick += 1
        let pct = (tick * 17) % 101                 // sweep 0..100
        let level = Severity.level(pct: pct, warnPct: 85)
        controller.setIcon(MeterIcon.arc(fraction: CGFloat(pct) / 100, color: level.color))
    }

    private func buildMenu(_ menu: NSMenu) {
        let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let labelItem = NSMenuItem()
        labelItem.view = MenuBuilder.textView("StatusItemKit demo  tick \(tick)", font: mono)
        menu.addItem(labelItem)

        menu.addItem(NSMenuItem.separator())

        let notifyItem = NSMenuItem(title: "Send test notification", action: #selector(notifyTest), keyEquivalent: "")
        notifyItem.target = self
        menu.addItem(notifyItem)

        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(NSMenuItem.separator())
        // No target: terminate(_:) travels the responder chain to NSApp.
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func notifyTest() { notifier.post(title: "StatusItemKit", body: "Test notification.") }
    @objc private func toggleLogin() { LoginItem.toggle() }
}

let app = NSApplication.shared
let delegate = DemoApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 2: Build the demo app bundle**

Run: `./scripts/make-app.sh StatusItemKitDemo`
Expected: prints `Built build/StatusItemKitDemo.app` with no errors.

- [ ] **Step 3: Run the full test suite**

Run: `swift test`
Expected: all tests PASS (Severity, Shell, MenuBuilder, MeterIcon).

- [ ] **Step 4: Manual verification** (the AppKit glue has no unit tests)

Run: `open build/StatusItemKitDemo.app`
Verify, then quit via the menu:
- A small colored arc icon appears in the menu bar and changes color/fill every ~2s (green → orange → red as it sweeps).
- Clicking it shows the menu: the padded "demo tick N" label row (no clipped trailing glyph), "Send test notification", "Start at Login" (with a checkmark state), "Quit".
- "Send test notification" produces a Notification Center banner (this confirms the ad-hoc signing works).
- "Quit" exits.

- [ ] **Step 5: Commit**

```bash
git add Sources/StatusItemKitDemo/main.swift
git commit -m "feat: demo app dogfooding the framework

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: README + LICENSE + publish

**Files:**
- Create: `README.md`
- Create: `LICENSE`

**Interfaces:** none (docs + publish).

- [ ] **Step 1: Write `LICENSE`** — standard MIT text, copyright `2026 Nicholas Smith`.

- [ ] **Step 2: Write `README.md`** covering: what StatusItemKit is, the public API (Shell, StatusItemController, render funnel, MenuBuilder, MeterIcon, Severity, LoginItem, Notifier), how to depend on it (`.package(path:)` for local dev, `.package(url:from:)` for release), the `make-app.sh` workflow, and a "minimal example" pointing at `Sources/StatusItemKitDemo`. Note the macOS 13 floor and the mandatory ad-hoc signing for notifications.

- [ ] **Step 3: Verify a clean build + tests from scratch**

Run: `rm -rf .build build && swift test && ./scripts/make-app.sh StatusItemKitDemo`
Expected: tests PASS, bundle builds.

- [ ] **Step 4: Commit**

```bash
git add README.md LICENSE
git commit -m "docs: README + MIT LICENSE

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: Create the public GitHub repo and push**

```bash
gh repo create StatusItemKit --public --source=. --remote=origin --description "Reusable framework for standalone macOS menu-bar apps" --push
```
Expected: repo created, `main` pushed. Confirm with `gh repo view --web` URL printed.

---

## Notes for the app plans (written after this plan executes)

Once StatusItemKit's API is frozen (this plan complete), author two separate plans, then run them as parallel agents (one per repo — naturally isolated, no worktrees):

- `vpn-dns-menubar`: `VPNDNSCore` (pure parsing) + `VPNDNSMenuBar` executable (depends on StatusItemKit via `.package(path: "../StatusItemKit")`), tests against captured `mullvad`/`tailscale` fixtures, dot via `MeterIcon.dot`, 3-row menu, AX helper shell-out. Bundle "VPN & DNS.app".
- `battery-time-menubar`: `BatteryTimeCore` (pure parsing of `pmset`/`ioreg`/24h-log) + `BatteryTime` executable, tests against the existing shell fixtures, folded-in `render-title.swift` glyph, IOKit power-source notifications, energy-mode sudo. Bundle "Battery Time.app".
