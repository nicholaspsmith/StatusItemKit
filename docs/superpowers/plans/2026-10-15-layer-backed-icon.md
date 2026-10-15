# Layer-Backed Status Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace how `StatusItemController.setIcon(_:)` draws, for every StatusItemKit app, so an icon change (an animation frame) costs a `CALayer` contents swap instead of a status-button redraw, released only after three test stages show no regressions.

**Architecture:** Two new internal types. `IconBitmaps` turns an `NSImage` into the `CGImage` for a given scale (tinting templates) and caches it per image. `IconLayer` puts that bitmap on a sublayer of the status button, keeps a transparent same-size placeholder as the button's own image (so width and menu anchor are unchanged), and follows the button's bounds, its window's scale and its appearance. `StatusItemController.setIcon` hands every image to `IconLayer`, falling back to `button.image` only until the button has a window.

**Tech Stack:** Swift 5.9, AppKit, QuartzCore, XCTest; macOS 13+ (StatusItemKit's floor).

**Spec:** `docs/superpowers/specs/2026-10-15-layer-backed-icon-design.md`

## Global Constraints

- No public API change: `setIcon(_:)`, `setTitle(_:warn:)`, `setVisible(_:)` keep their signatures and meaning. `IconLayer` and `IconBitmaps` are `internal`.
- No flag: the new drawing replaces the old for every app (spec, "One path").
- `setTitle` stays exactly as it is, apart from removing the layer.
- Nothing reaches StatusItemKit `main` before stages 1 and 2 pass: every push to `main` is a release that parity rolls into all eleven apps.
- Release is StatusItemKit **0.33.0** (minor). CHANGELOG section `## [0.33.0] - YYYY-MM-DD`, written only in Task 8.
- Commits on `layer-icon` end with `[no release]` until Task 8, so the pre-push hook and `release / check` let the soak push through.
- Do not launch Apollo Monitor on this Mac (Nick's rule); it is covered by the soak.
- Pass bar for cost: SoundChain walking at 24 fps under 1% CPU; no app's idle CPU higher than before.
- Screen capture of the menu bar is blank on this display: visual checks are Nick's.

## Review Focus

1. The bar moves to a display with another scale (built-in 2x ↔ Dell) while an icon animates — expect the right bitmap at once, never blurry or doubled. Pinned in Task 2 (`testAScaleChangeRepicksTheBitmap`).
2. The menu opens over the icon — expect the highlight under the mascot, never over it. Pinned in Task 2 (`testTheIconStaysAboveLayersAddedLater`).
3. An icon changes size (KeyLight switching style, a wider battery) — expect the item to resize and the icon to stay centred. Pinned in Task 2 (`testAnotherSizeResizesThePlaceholderAndRecentres`).
4. The first icon is set during launch, before the status button has a window — expect it drawn the old way, then moved onto the layer. Pinned in Task 2 (`testBeforeAWindowItIsRefusedThenTakesOver`).
5. The menu bar flips light ↔ dark under a template icon — expect the tint to follow. Pinned in Task 2 (`testATemplateIsTintedForTheAppearanceAndFollowsIt`).

---

### Task 1: IconBitmaps — the bitmap for an icon at a scale

**Files:**
- Create: `Sources/StatusItemKit/IconBitmaps.swift`
- Test: `Tests/StatusItemKitTests/IconBitmapsTests.swift`

**Interfaces:**
- Produces: `enum IconBitmaps` with
  `static func bitmap(for image: NSImage, scale: CGFloat, tint: NSColor? = nil) -> CGImage?` and
  `static func placeholder(size: NSSize, description: String?) -> NSImage`;
  test helpers `IconBitmapsTests.icon(width:color:)`, `IconBitmapsTests.template()`, `IconBitmapsTests.centre(_:)`, `IconBitmapsTests.corner(_:)` (static, used by Tasks 2–3).

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/StatusItemKitTests/IconBitmapsTests.swift
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import XCTest
@testable import StatusItemKit

final class IconBitmapsTests: XCTestCase {
    /// A `width`x22 icon with a 1x and a 2x bitmap, as CharacterIcon makes them.
    static func icon(width: CGFloat = 36, color: NSColor = .systemGreen) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: 22))
        for scale in [1, 2] as [CGFloat] {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(22 * scale),
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = image.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            color.set()
            NSRect(x: 4, y: 4, width: width - 8, height: 14).fill()
            NSGraphicsContext.restoreGraphicsState()
            image.addRepresentation(rep)
        }
        return image
    }

    /// A black 22x22 template drawn in code (no bitmap of its own), as MeterIcon makes them.
    static func template() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { rect in
            NSColor.black.set()
            rect.insetBy(dx: 3, dy: 3).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    static func centre(_ cg: CGImage) -> (red: CGFloat, alpha: CGFloat) { pixel(cg, x: cg.width / 2, y: cg.height / 2) }
    static func corner(_ cg: CGImage) -> (red: CGFloat, alpha: CGFloat) { pixel(cg, x: 0, y: 0) }
    private static func pixel(_ cg: CGImage, x: Int, y: Int) -> (red: CGFloat, alpha: CGFloat) {
        let c = NSBitmapImageRep(cgImage: cg).colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
        return (c.redComponent, c.alphaComponent)
    }

    func testUsesTheIconsOwnBitmapForEachScale() {
        let image = Self.icon()
        XCTAssertEqual(IconBitmaps.bitmap(for: image, scale: 2)?.width, 72)
        XCTAssertEqual(IconBitmaps.bitmap(for: image, scale: 1)?.width, 36)
    }

    // An animation's frames are cached by CharacterIcon, so each converts once.
    func testConvertsEachImageAndScaleOnce() {
        let image = Self.icon()
        let a = IconBitmaps.bitmap(for: image, scale: 2)
        XCTAssertTrue(a === IconBitmaps.bitmap(for: image, scale: 2))
        XCTAssertFalse(a === IconBitmaps.bitmap(for: image, scale: 1))
    }

    func testDrawsAnImageThatHasNoBitmapOfThatSize() {
        let image = Self.template()
        image.isTemplate = false
        let cg = IconBitmaps.bitmap(for: image, scale: 3)
        XCTAssertEqual(cg?.width, 66)
        XCTAssertEqual(cg?.height, 66)
    }

    func testTintsATemplateAndKeepsEachTintApart() {
        let image = Self.template()
        let white = IconBitmaps.bitmap(for: image, scale: 2, tint: .white)!
        let black = IconBitmaps.bitmap(for: image, scale: 2, tint: .black)!
        XCTAssertEqual(Self.centre(white).red, 1, accuracy: 0.02)
        XCTAssertEqual(Self.centre(white).alpha, 1, accuracy: 0.02)
        XCTAssertEqual(Self.centre(black).red, 0, accuracy: 0.02)
        XCTAssertEqual(Self.corner(white).alpha, 0, accuracy: 0.02)   // outside the ink stays clear
    }

    func testPlaceholderKeepsTheSizeAndDescriptionAndDrawsNothing() {
        let p = IconBitmaps.placeholder(size: NSSize(width: 25, height: 22), description: "Carol")
        XCTAssertEqual(p.size, NSSize(width: 25, height: 22))
        XCTAssertEqual(p.accessibilityDescription, "Carol")
        XCTAssertTrue(p.representations.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --filter IconBitmapsTests`
Expected: build error, `cannot find 'IconBitmaps' in scope`.

- [ ] **Step 3: Implement**

```swift
// Sources/StatusItemKit/IconBitmaps.swift
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// The bitmaps `IconLayer` shows: an icon at the bar's scale, a template tinted
/// for the bar's appearance. Converting is the only real work a new frame costs,
/// so each image, scale and tint is converted once and kept while the image
/// lives; CharacterIcon caches its frames, so an animation converts each once.
enum IconBitmaps {
    private static let cache = NSMapTable<NSImage, NSMutableDictionary>.weakToStrongObjects()

    /// `image` as a bitmap of `scale` pixels per point: its own representation of
    /// exactly that size when it has one, else drawn at that scale. A template is
    /// filled with `tint`; for any other image `tint` is ignored.
    static func bitmap(for image: NSImage, scale: CGFloat, tint: NSColor? = nil) -> CGImage? {
        let tint = image.isTemplate ? tint : nil
        let key = "\(scale)|\(tint.map(colorKey) ?? "-")" as NSString
        if let hit = cache.object(forKey: image)?[key] { return (hit as! CGImage) }
        guard let made = make(image, scale: scale, tint: tint) else { return nil }
        let entry = cache.object(forKey: image) ?? {
            let fresh = NSMutableDictionary()
            cache.setObject(fresh, forKey: image)
            return fresh
        }()
        entry[key] = made
        return made
    }

    /// A transparent image of `size`, carrying `description` for accessibility:
    /// what the status button itself shows, so the item keeps the icon's width.
    static func placeholder(size: NSSize, description: String?) -> NSImage {
        let image = NSImage(size: size)
        image.accessibilityDescription = description
        return image
    }

    private static func make(_ image: NSImage, scale: CGFloat, tint: NSColor?) -> CGImage? {
        let w = Int((image.size.width * scale).rounded()), h = Int((image.size.height * scale).rounded())
        guard w > 0, h > 0 else { return nil }
        if tint == nil,
           let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep })
               .first(where: { $0.pixelsWide == w && $0.pixelsHigh == h }),
           let cg = rep.cgImage {
            return cg
        }
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let rect = NSRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        if let tint {
            tint.set()
            rect.fill(using: .sourceIn)
        }
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    private static func colorKey(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        return String(format: "%.3f,%.3f,%.3f,%.3f", c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
    }
}
```

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --filter IconBitmapsTests`
Expected: `Executed 5 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/StatusItemKit/IconBitmaps.swift Tests/StatusItemKitTests/IconBitmapsTests.swift
git commit -m "IconBitmaps: an icon's bitmap per scale, templates tinted, cached [no release]"
```

---

### Task 2: IconLayer — the icon on a layer of the status button

**Files:**
- Create: `Sources/StatusItemKit/IconLayer.swift`
- Test: `Tests/StatusItemKitTests/IconLayerTests.swift`

**Interfaces:**
- Consumes: `IconBitmaps.bitmap(for:scale:tint:)`, `IconBitmaps.placeholder(size:description:)`.
- Produces: `final class IconLayer` with `init(button: NSButton, scale: (() -> CGFloat)? = nil)`,
  `@discardableResult func show(_ image: NSImage) -> Bool`, `func remove()`,
  `static let retryInterval: TimeInterval` (0.25), and for tests `shownBitmap: CGImage?`, `shownScale: CGFloat`,
  `shownFrame: CGRect`, `isShowing: Bool`, `zPosition: CGFloat`.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/StatusItemKitTests/IconLayerTests.swift
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import XCTest
@testable import StatusItemKit

final class IconLayerTests: XCTestCase {
    private var window: NSWindow!
    private var button: NSButton!
    private var scale: CGFloat = 2

    override func setUp() {
        _ = NSApplication.shared
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 22), styleMask: .borderless,
                          backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        button = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 22))
        window.contentView?.addSubview(button)
        scale = 2
    }

    override func tearDown() {
        window.close()
        window = nil
        button = nil
    }

    private func makeLayer() -> IconLayer { IconLayer(button: button, scale: { [unowned self] in self.scale }) }

    /// Lets queued main-thread work (the appearance and retry hops) run.
    private func settle(_ seconds: TimeInterval = 0) {
        let done = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { DispatchQueue.main.async { done.fulfill() } }
        wait(for: [done], timeout: seconds + 2)
    }

    func testShowsTheIconOnALayerAndAPlaceholderOnTheButton() {
        let icons = makeLayer(), image = IconBitmapsTests.icon()
        XCTAssertTrue(icons.show(image))
        XCTAssertFalse(button.image === image)
        XCTAssertEqual(button.image?.size, image.size)
        XCTAssertEqual(icons.shownBitmap?.width, 72)
        XCTAssertEqual(icons.shownScale, 2)
        XCTAssertTrue(icons.isShowing)
        XCTAssertEqual(icons.shownFrame, CGRect(x: 0, y: 0, width: 36, height: 22))
    }

    // Review focus 1: the bar moves to a display with another scale.
    func testAScaleChangeRepicksTheBitmap() {
        let icons = makeLayer()
        icons.show(IconBitmapsTests.icon())
        scale = 1
        NotificationCenter.default.post(name: NSWindow.didChangeBackingPropertiesNotification, object: window)
        XCTAssertEqual(icons.shownBitmap?.width, 36)
        XCTAssertEqual(icons.shownScale, 1)
    }

    // Review focus 5: a template follows the bar's light or dark appearance.
    func testATemplateIsTintedForTheAppearanceAndFollowsIt() {
        let icons = makeLayer()
        button.appearance = NSAppearance(named: .darkAqua)
        icons.show(IconBitmapsTests.template())
        XCTAssertGreaterThan(IconBitmapsTests.centre(icons.shownBitmap!).red, 0.9)
        button.appearance = NSAppearance(named: .aqua)
        settle()
        XCTAssertLessThan(IconBitmapsTests.centre(icons.shownBitmap!).red, 0.1)
    }

    // Review focus 3: an icon of another size (KeyLight's styles, a wider battery).
    func testAnotherSizeResizesThePlaceholderAndRecentres() {
        let icons = makeLayer()
        icons.show(IconBitmapsTests.icon(width: 36))
        icons.show(IconBitmapsTests.icon(width: 26))
        XCTAssertEqual(button.image?.size, NSSize(width: 26, height: 22))
        XCTAssertEqual(icons.shownFrame, CGRect(x: 5, y: 0, width: 26, height: 22))   // the test button stays 36 wide
    }

    // Review focus 2: the menu's highlight, added to the button later, stays under the icon.
    func testTheIconStaysAboveLayersAddedLater() {
        let icons = makeLayer()
        icons.show(IconBitmapsTests.icon())
        let highlight = CALayer()
        button.layer?.addSublayer(highlight)
        XCTAssertGreaterThan(icons.zPosition, highlight.zPosition)
    }

    // setVisible(false) shrinks the item to nothing: the icon must not show outside it.
    func testZeroWidthHidesTheIcon() {
        let icons = makeLayer()
        icons.show(IconBitmapsTests.icon())
        button.frame.size.width = 0
        XCTAssertFalse(icons.isShowing)
        button.frame.size.width = 36
        XCTAssertTrue(icons.isShowing)
    }

    func testRemoveTakesTheLayerOffAndClearsThePlaceholder() {
        let icons = makeLayer()
        icons.show(IconBitmapsTests.icon())
        icons.remove()
        XCTAssertFalse(icons.isShowing)
        XCTAssertNil(button.image)
        XCTAssertTrue(icons.show(IconBitmapsTests.icon()))
        XCTAssertTrue(icons.isShowing)
    }

    // Review focus 4: the first icon arrives before the button has a window (launch).
    func testBeforeAWindowItIsRefusedThenTakesOver() {
        let loose = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 22))
        let icons = IconLayer(button: loose, scale: { 2 })
        let image = IconBitmapsTests.icon()
        XCTAssertFalse(icons.show(image))
        loose.image = image                       // what StatusItemController does on a refusal
        window.contentView?.addSubview(loose)
        settle(IconLayer.retryInterval * 2)
        XCTAssertTrue(icons.isShowing)
        XCTAssertFalse(loose.image === image)
        XCTAssertEqual(loose.image?.size, image.size)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --filter IconLayerTests`
Expected: build error, `cannot find 'IconLayer' in scope`.

- [ ] **Step 3: Implement**

```swift
// Sources/StatusItemKit/IconLayer.swift
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import QuartzCore

/// Shows a status button's icon on a CALayer of its own, so a new icon — an
/// animation frame — costs a layer swap instead of a redraw of the whole button
/// (measured 2026-10-15: 11% of a core at 24 fps through `button.image`, 0.35%
/// through the layer). The button keeps a transparent placeholder of the icon's
/// size, so the item's width and the menu's anchor are what they were. The layer
/// follows the button's bounds, its window's scale and its appearance (which
/// tints a template icon).
final class IconLayer {
    /// How often, and how many times, a refused icon is tried again while the
    /// button has no window yet.
    static let retryInterval: TimeInterval = 0.25
    static let retryLimit = 8

    private weak var button: NSButton?
    private let layer = CALayer()
    private let scaleOverride: (() -> CGFloat)?
    private var observers: [NSObjectProtocol] = []
    private var appearanceObservation: NSKeyValueObservation?
    private var placeholder: NSImage?
    private var image: NSImage?
    private var pending: NSImage?
    private var retries = 0

    init(button: NSButton, scale: (() -> CGFloat)? = nil) {
        self.button = button
        scaleOverride = scale
        layer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "hidden": NSNull()]
        layer.contentsGravity = .resize
        // Above anything AppKit adds to the button after us, such as its highlight.
        layer.zPosition = 1
    }

    deinit { remove() }

    /// Shows `image` on the layer and returns true. Returns false while the button
    /// has no window (the first icon, during launch): the caller then sets it the
    /// old way, and it is tried again every `retryInterval`, up to `retryLimit`.
    @discardableResult
    func show(_ image: NSImage) -> Bool {
        guard let button, button.window != nil else {
            pending = image
            scheduleRetry()
            return false
        }
        pending = nil
        retries = 0
        attach(to: button)
        if placeholder?.size != image.size || placeholder?.accessibilityDescription != image.accessibilityDescription
            || button.image !== placeholder {
            let fresh = IconBitmaps.placeholder(size: image.size, description: image.accessibilityDescription)
            placeholder = fresh
            button.image = fresh
        }
        self.image = image
        render()
        return true
    }

    /// Takes the layer off the button and clears the placeholder (the item shows
    /// text instead). `show` puts it back.
    func remove() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        appearanceObservation = nil
        layer.removeFromSuperlayer()
        layer.contents = nil
        if let button, button.image === placeholder { button.image = nil }
        placeholder = nil
        image = nil
        pending = nil
    }

    // MARK: For tests

    var shownBitmap: CGImage? { layer.contents.map { $0 as! CGImage } }
    var shownScale: CGFloat { layer.contentsScale }
    var shownFrame: CGRect { layer.frame }
    var isShowing: Bool { layer.superlayer != nil && !layer.isHidden && layer.contents != nil }
    var zPosition: CGFloat { layer.zPosition }

    // MARK: Drawing

    /// The scale to draw for: the button's window's, else 2.
    private var scale: CGFloat { scaleOverride?() ?? button?.window?.backingScaleFactor ?? 2 }

    private func scheduleRetry() {
        guard retries < Self.retryLimit else { return }
        retries += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) { [weak self] in
            guard let self, let pending = self.pending else { return }
            self.show(pending)
        }
    }

    private func attach(to button: NSButton) {
        guard layer.superlayer == nil else { return }
        button.wantsLayer = true
        button.layer?.addSublayer(layer)
        button.postsFrameChangedNotifications = true
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSView.frameDidChangeNotification, object: button,
                                            queue: nil) { [weak self] _ in self?.place() })
        if let window = button.window {
            for name in [NSWindow.didChangeBackingPropertiesNotification, NSWindow.didChangeScreenNotification] {
                observers.append(center.addObserver(forName: name, object: window, queue: nil) { [weak self] _ in
                    self?.render()
                })
            }
        }
        appearanceObservation = button.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.render() }
        }
    }

    /// Puts the icon's bitmap for the current scale (and appearance, for a
    /// template) on the layer, and places it.
    private func render() {
        guard let button, let image else { return }
        var tint: NSColor?
        if image.isTemplate {
            button.effectiveAppearance.performAsCurrentDrawingAppearance {
                tint = NSColor.labelColor.usingColorSpace(.sRGB)
            }
        }
        let scale = self.scale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contentsScale = scale
        layer.contents = IconBitmaps.bitmap(for: image, scale: scale, tint: tint)
        place()
        CATransaction.commit()
    }

    /// Centres the layer in the button, on whole pixels; hides it when the item
    /// has no width (yielded to a menu-bar manager).
    private func place() {
        guard let button, let image else { return }
        let bounds = button.bounds, size = image.size, pixel = 1 / scale
        func snap(_ v: CGFloat) -> CGFloat { (v / pixel).rounded() * pixel }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = CGRect(x: snap((bounds.width - size.width) / 2), y: snap((bounds.height - size.height) / 2),
                             width: size.width, height: size.height)
        layer.isHidden = bounds.width < 1
        CATransaction.commit()
    }
}
```

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --filter IconLayerTests`
Expected: `Executed 8 tests, with 0 failures`.
If `testATemplateIsTintedForTheAppearanceAndFollowsIt` fails on the second assertion, check the KVO on `effectiveAppearance` fired (set a breakpoint in the observation block); `NSView.effectiveAppearance` is KVO-compliant from macOS 10.14.

- [ ] **Step 5: Commit**

```bash
git add Sources/StatusItemKit/IconLayer.swift Tests/StatusItemKitTests/IconLayerTests.swift
git commit -m "IconLayer: a status button's icon on a layer of its own [no release]"
```

---

### Task 3: StatusItemController draws every icon through IconLayer

**Files:**
- Modify: `Sources/StatusItemKit/StatusItemController.swift` (the `setTitle` and `setIcon` render funnel, and a new stored property)
- Test: `Tests/StatusItemKitTests/StatusItemControllerIconTests.swift`

**Interfaces:**
- Consumes: `IconLayer(button:)`, `show(_:) -> Bool`, `remove()`, `IconLayer.retryInterval`, `IconBitmapsTests.icon()`.
- Produces: unchanged public API; `setIcon` now draws on the layer.

- [ ] **Step 1: Write the failing test**

This test creates a real status item for a moment (it appears in the bar while the test runs and goes when the controller is released).

```swift
// Tests/StatusItemKitTests/StatusItemControllerIconTests.swift
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import XCTest
@testable import StatusItemKit

final class StatusItemControllerIconTests: XCTestCase {
    func testSetIconDrawsOnTheLayerAndSetTitleTakesItOff() {
        _ = NSApplication.shared
        let controller = StatusItemController(pollInterval: 3600, onPoll: {}, onBuildMenu: { _ in })
        let image = IconBitmapsTests.icon()
        controller.setIcon(image)
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + IconLayer.retryInterval * 2) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        let button = controller.button!
        XCTAssertFalse(button.image === image, "the button holds a placeholder; the icon is on the layer")
        XCTAssertEqual(button.image?.size, image.size)
        XCTAssertTrue(button.layer?.sublayers?.contains { $0.zPosition == 1 && $0.contents != nil } == true)

        controller.setTitle("42%", warn: false)
        XCTAssertNil(button.image)
        XCTAssertFalse(button.layer?.sublayers?.contains { $0.zPosition == 1 && $0.contents != nil } == true)
        XCTAssertEqual(button.attributedTitle.string, "42%")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter StatusItemControllerIconTests`
Expected: FAIL at "the button holds a placeholder; the icon is on the layer" (today `button.image === image`).

- [ ] **Step 3: Implement**

In `Sources/StatusItemKit/StatusItemController.swift`, add a stored property after `private var timer: Timer?`:

```swift
    /// Draws the icon on a layer of its own (see `IconLayer`), so animation frames
    /// cost a layer swap instead of a redraw of the button.
    private lazy var iconLayer: IconLayer? = statusItem.button.map { IconLayer(button: $0) }
```

Replace `setTitle(_:warn:)`'s first line `guard let button = statusItem.button else { return }` with:

```swift
        guard let button = statusItem.button else { return }
        iconLayer?.remove()
```

Replace the body of `setIcon(_:)` with:

```swift
    /// Icon render path: clears title + tint (icons are full-color non-template).
    /// The icon is drawn on a layer of its own; until the button has a window (the
    /// first icon, during launch) it is set the old way and moved over shortly.
    public func setIcon(_ image: NSImage) {
        guard let button = statusItem.button else { return }
        // Touch only what changes: resetting the title or image position on a
        // status button forces the bar to re-lay out, which cancels a menu
        // that is tracking on the same item.
        if button.attributedTitle.length != 0 { button.attributedTitle = NSAttributedString(string: "") }
        if button.imagePosition != .imageOnly { button.imagePosition = .imageOnly }
        if button.contentTintColor != nil { button.contentTintColor = nil }
        if iconLayer?.show(image) != true { button.image = image }
    }
```

- [ ] **Step 4: Run the whole suite**

Run: `swift test`
Expected: all tests pass (130 existing + 14 new).

- [ ] **Step 5: Commit**

```bash
git add Sources/StatusItemKit/StatusItemController.swift Tests/StatusItemKitTests/StatusItemControllerIconTests.swift
git commit -m "setIcon draws every icon on a layer of its own [no release]"
```

---

### Task 4: icon-compare — old and new template rendering side by side

**Files:**
- Create: `scripts/icon-compare.swift`, `scripts/icon-compare.sh`

**Interfaces:**
- Consumes: `IconLayer`, `IconBitmaps`, `MeterIcon` (compiled straight from `Sources/`, so `internal` is visible).

- [ ] **Step 1: Write the tool**

```swift
// scripts/icon-compare.swift
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

// Template icons drawn two ways in the real menu bar, in pairs: AppKit's own
// `button.image` (old) and IconLayer (new). Each item's menu says which it is.
// Compare them on light and dark bars, with Reduce Transparency on and off, on
// each display. Quit from any item's menu.
import AppKit

final class Compare: NSObject, NSApplicationDelegate {
    var items: [NSStatusItem] = []
    var layers: [IconLayer] = []

    func applicationDidFinishLaunching(_ n: Notification) {
        func meter(_ make: (CGFloat, NSColor) -> NSImage) -> NSImage {
            let image = make(0.6, .black)
            image.isTemplate = true
            return image
        }
        let samples: [(String, NSImage)] = [
            ("gauge", meter(MeterIcon.gauge)), ("arc", meter(MeterIcon.arc)),
            ("pie", meter(MeterIcon.pie)), ("wedge", meter(MeterIcon.wedge)),
            ("battery symbol", NSImage(systemSymbolName: "battery.75percent", accessibilityDescription: nil)!),
        ]
        // Status items are added right to left, so add each pair new-then-old to read old, new.
        for (name, image) in samples.reversed() {
            for old in [false, true] {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                let button = item.button!
                button.imagePosition = .imageOnly
                if old {
                    button.image = image
                } else {
                    let icons = IconLayer(button: button)
                    if !icons.show(image) { button.image = image }
                    layers.append(icons)
                }
                let menu = NSMenu()
                menu.addItem(withTitle: "\(name): \(old ? "OLD — AppKit draws it" : "NEW — IconLayer")", action: nil, keyEquivalent: "")
                menu.addItem(.separator())
                menu.addItem(withTitle: "Quit icon-compare", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
                item.menu = menu
                items.append(item)
            }
        }
    }
}

let app = NSApplication.shared
let delegate = Compare()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

```bash
#!/bin/bash
# scripts/icon-compare.sh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Show template icons drawn the old way and by IconLayer, side by side in the bar.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
swiftc -O scripts/icon-compare.swift Sources/StatusItemKit/IconLayer.swift Sources/StatusItemKit/IconBitmaps.swift \
    Sources/StatusItemKit/MeterIcon.swift -o "$TMP/icon-compare"
"$TMP/icon-compare"
```

- [ ] **Step 2: Build and run it**

Run: `chmod +x scripts/icon-compare.sh && ./scripts/icon-compare.sh &`
Expected: ten new items in the bar, five old/new pairs; each item's menu names it. Nothing printed on stderr.

- [ ] **Step 3: Nick compares** (screen capture of the bar is blank on this display). For each pair, on a light and a dark menu bar (System Settings ▸ Appearance, or a light/dark wallpaper), with Reduce Transparency (Accessibility ▸ Display) off and on, on the built-in display and the Dell: does NEW look the same as OLD (colour, weight, translucency)? Record the answer in the spec's Design section (templates: same → layer; different → AppKit's path). Quit from any item's menu.

- [ ] **Step 4: Commit**

```bash
git add scripts/icon-compare.swift scripts/icon-compare.sh docs/superpowers/specs/2026-10-15-layer-backed-icon-design.md
git commit -m "icon-compare: old and new template rendering side by side [no release]"
```

---

### Task 5 (only if Task 4 found a difference): templates keep AppKit's path

**Files:**
- Modify: `Sources/StatusItemKit/StatusItemController.swift` (`setIcon`)
- Modify: `Tests/StatusItemKitTests/StatusItemControllerIconTests.swift`

- [ ] **Step 1: Add the failing test** to `StatusItemControllerIconTests`:

```swift
    // Templates are drawn by AppKit, with the bar's vibrancy (spec: the layer did not match it).
    func testATemplateIsDrawnByAppKit() {
        _ = NSApplication.shared
        let controller = StatusItemController(pollInterval: 3600, onPoll: {}, onBuildMenu: { _ in })
        controller.setIcon(IconBitmapsTests.icon())
        let template = IconBitmapsTests.template()
        controller.setIcon(template)
        XCTAssertTrue(controller.button?.image === template)
        XCTAssertFalse(controller.button?.layer?.sublayers?.contains { $0.zPosition == 1 && $0.contents != nil } == true)
    }
```

- [ ] **Step 2: Run:** `swift test --filter StatusItemControllerIconTests` — expect FAIL (`button.image` is a placeholder).

- [ ] **Step 3: Implement** — in `setIcon`, replace the last line with:

```swift
        // Templates are tinted by AppKit with the bar's vibrancy, which a layer does
        // not reproduce (compared by eye with scripts/icon-compare.sh): the old way.
        if image.isTemplate {
            iconLayer?.remove()
            button.image = image
        } else if iconLayer?.show(image) != true {
            button.image = image
        }
```

- [ ] **Step 4: Run:** `swift test` — expect all pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/StatusItemKit/StatusItemController.swift Tests/StatusItemKitTests/StatusItemControllerIconTests.swift
git commit -m "Template icons keep AppKit's vibrant drawing [no release]"
```

---

### Task 6: Stage 1 — every app, locally, against the branch

**Files:** none in the repo; work in the session scratchpad, `$S` = `/private/tmp/claude-501/-Users-nicholassmith-Code-soundchain-menubar/e5743e65-32e9-4e3c-98d1-3e97eb8a87ea/scratchpad`.

- [ ] **Step 1: Pause parity** so it installs nothing mid-test: `parity-ctl pause`. Expected: `~/Library/Logs/parity.log` ends with `paused`.

- [ ] **Step 2: Clean clones beside the branch.** The apps' `Package.swift` depend on `../StatusItemKit`, so a scratch `code/` with fresh clones and a symlink to this checkout builds them against `layer-icon` without touching `~/Code` (another session may be working in battery-time-menubar):

```bash
S=/private/tmp/claude-501/-Users-nicholassmith-Code-soundchain-menubar/e5743e65-32e9-4e3c-98d1-3e97eb8a87ea/scratchpad; mkdir -p $S/stage1 && cd $S/stage1
ln -sfn /Users/nicholassmith/Code/StatusItemKit StatusItemKit
APPS="mac-daddy-menubar vpn-dns-menubar battery-time-menubar keylight-menubar claude-usage-menubar home-assistant-menubar soundchain-menubar monitor-lizard-menubar menu-crane panes-menubar"
for r in $APPS; do git clone -q --depth 1 git@github.com:nicholaspsmith/$r.git $r; (cd $r && ./scripts/build-app.sh) 2>&1 | grep -E "error|Built"; done
```
Expected: ten `==> Built build/<App>.app` lines and no errors. (Apollo Monitor is left out: not launched on this Mac.)

- [ ] **Step 3: Measure the old builds** (installed, running), 20 s each:

```bash
for app in $(ls -d $S/stage1/*/build/*.app); do exe=$(plutil -extract CFBundleExecutable raw "$app/Contents/Info.plist"); p=$(pgrep -x "$exe"); [ -n "$p" ] && echo "$exe old $(top -l 6 -s 4 -pid $p -stats cpu | tail -1)"; done | tee $S/stage1/cpu-old.txt
```

- [ ] **Step 4: Swap in the new builds**, recording which apps were running (only those are swapped and later restored):

```bash
for app in $(ls -d $S/stage1/*/build/*.app); do id=$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist"); exe=$(plutil -extract CFBundleExecutable raw "$app/Contents/Info.plist")
  pgrep -x "$exe" >/dev/null || continue; echo "$id" >> $S/stage1/was-running.txt
  osascript -e "tell application id \"$id\" to quit"; for i in $(seq 1 20); do pgrep -x "$exe" >/dev/null || break; sleep 0.5; done
  open -g "$app"; sleep 3; done
```
(SoundChain: graceful quit only, never `pkill`. Use `perl -e 'select(undef,undef,undef,0.5)'` where foreground `sleep` is refused.)

- [ ] **Step 5: Measure the new builds** with Step 3's loop into `cpu-new.txt`. Pass: no app higher than in `cpu-old.txt` beyond noise (±0.5 points). SoundChain: if bypassed, compare its sleeping CPU (old 3.3%); then ask Nick to untick Bypass with music playing and measure the walk — pass under 1%.

- [ ] **Step 6: Nick's checklist**, app by app (tick in the plan as each passes):
  - Each app: icon right on the built-in display and the Dell; menu opened over it (highlight under the icon) and closed; light and dark menu bar; Reduce Transparency on; at :00/:30 its minute animation plays; Settings ▸, Start at Login, Quit work.
  - SoundChain: walking to music; asleep while bypassed; headphones on/off; the bar moved to the other display while she walks.
  - KeyLight: every icon style (key, gauge, arc, pie, wedge), including the template meters; muted grey when unavailable.
  - Battery Time: on battery, charging, full; the plain (template) battery style.
  - Menu Crane: idle, searching, copied; its alternate (template) icon.
  - Homestead: weather animating; hollow when unreachable.
  - Panes: Major Pane, and the grid icon with its tile slide.
  - Claude Usage, VPN & DNS, Mac Daddy, Monitor Lizard: their states as they come up.

- [ ] **Step 7: Restore** the installed apps: for each id in `was-running.txt`, quit the scratch build gracefully and `open -g ~/Applications/<App>.app`; then `parity-ctl resume`.

- [ ] **Step 8: Record** the CPU tables and checklist outcome in the spec's Verification section and commit:

```bash
git add docs/superpowers/specs/2026-10-15-layer-backed-icon-design.md
git commit -m "Spec: stage 1 results [no release]"
```

---

### Task 7: Stage 2 — soak on both Macs

- [ ] **Step 1: Push the branch while it is checked out** (parity merges a pushed, checked-out branch into its StatusItemKit build and installs every dependent app built with it on both Macs):

```bash
git push -u origin layer-icon
parity-ctl nudge
```
Expected within one cycle, in `~/Library/Logs/parity.log`: `StatusItemKit: built … from origin/main, origin/layer-icon`, then each app `installed … (relaunched)` on both Macs, and every launch check `passed`.

- [ ] **Step 2: Soak two days.** Nick uses both Macs as normal. Rollback if anything is wrong: `git checkout main && git push origin --delete layer-icon` (or `gh api -X DELETE repos/nicholaspsmith/StatusItemKit/git/refs/heads/layer-icon`); parity rebuilds without it.

- [ ] **Step 3: Check at the end**: no new crash reports for any Menumon app (`ls -t ~/Library/Logs/DiagnosticReports | head` on both Macs), parity's log shows no failed launch checks, and Nick has seen nothing off. Record in the spec's Verification section; commit with `[no release]`.

---

### Task 8: Stage 3 — release StatusItemKit 0.33.0

**Files:**
- Modify: `CHANGELOG.md`, `README.md`

- [ ] **Step 1: Changelog** — add at the top of the version sections, dated the day of the release:

```markdown
## [0.33.0] - YYYY-MM-DD

- `setIcon(_:)` draws the icon on a layer of its own, so an animation frame costs a layer swap instead of a redraw of the status button: about 0.35% of a core at 24 fps instead of 11% (measured 2026-10-15). Same API; every app gets it. The button keeps a transparent placeholder of the icon's size, so widths, menus and highlights are unchanged; the icon follows the display's scale and, for templates, the bar's light or dark appearance
```
(If Task 5 ran, add: `Template icons are still drawn by AppKit, keeping the bar's vibrancy`.)

- [ ] **Step 2: README** — replace the `setTitle(_:warn:)` / `setIcon(_:)` row with:

```markdown
| `setTitle(_:warn:)` / `setIcon(_:)` | The render funnel: mutually exclusive text and image paths, so there is never stray title spacing. `setIcon` draws on a layer of its own (`IconLayer`), so animation frames are cheap; the button keeps a same-size transparent placeholder. |
```

- [ ] **Step 3: Release** — commit (no `[no release]`), push, open the PR, merge when `release / check` passes:

```bash
git add CHANGELOG.md README.md
git commit -m "0.33.0: setIcon draws on a layer of its own"
git push
gh pr create --title "0.33.0: setIcon draws on a layer of its own" --body-file <(sed -n '/^## Verification/,/^## Risks/p' docs/superpowers/specs/2026-10-15-layer-backed-icon-design.md)
gh pr checks --watch && gh pr merge --merge
git checkout main && git pull --tags && git describe --tags      # v0.33.0
gh api -X DELETE repos/nicholaspsmith/StatusItemKit/git/refs/heads/layer-icon; git branch -d layer-icon
```
Expected: `v0.33.0`; parity then opens and merges a release PR in each app (`parity/StatusItemKit-0.33.0`), visible in `parity-ctl state`.
