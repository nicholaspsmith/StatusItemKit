// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import AppKit
@testable import StatusItemKit

final class MeterStyleTests: XCTestCase {

    // `dot` ignores the fraction, so it must not appear in a picker for a
    // percentage icon.
    func testProportionalExcludesDot() {
        XCTAssertFalse(MeterStyle.proportional.contains(.dot))
        XCTAssertEqual(Set(MeterStyle.proportional), [.arc, .gauge, .pie, .wedge])
        XCTAssertTrue(MeterStyle.allCases.contains(.dot))
    }

    // A preference outlives the build that wrote it.
    func testUnknownRawFallsBack() {
        XCTAssertEqual(MeterStyle.from("sparkline"), .arc)
        XCTAssertEqual(MeterStyle.from(nil, default: .pie), .pie)
        XCTAssertEqual(MeterStyle.from("wedge"), .wedge)
    }
}

final class MeterColorTests: XCTestCase {

    func testHexRoundTrip() {
        for preset in MeterColor.presets {
            XCTAssertEqual(MeterColor.hex(from: preset.color).uppercased(),
                           preset.hex.uppercased(), preset.name)
        }
    }

    func testParsesWithAndWithoutHash() {
        XCTAssertEqual(MeterColor.color(fromHex: "#0A84FF"), MeterColor.color(fromHex: "0A84FF"))
        XCTAssertNotNil(MeterColor.color(fromHex: " #34C759 "))
    }

    func testRejectsMalformed() {
        XCTAssertNil(MeterColor.color(fromHex: "#12345"))
        XCTAssertNil(MeterColor.color(fromHex: "not-a-colour"))
        XCTAssertNil(MeterColor.color(fromHex: ""))
    }

    // The panel returns colours in whatever space the user picked in; a
    // catalog or greyscale colour must still round-trip rather than crash.
    func testNonRGBColorConverts() {
        XCTAssertEqual(MeterColor.hex(from: .white).uppercased(), "#FFFFFF")
        XCTAssertFalse(MeterColor.hex(from: .systemRed).isEmpty)
    }

    // Green heads the list so an app adopting the picker keeps the appearance
    // it already had.
    func testGreenIsFirstPreset() {
        XCTAssertEqual(MeterColor.presets.first?.name, "Green")
    }

    private func rgb(_ c: NSColor) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let s = c.usingColorSpace(.sRGB)!
        return (s.redComponent, s.greenComponent, s.blueComponent)
    }

    // The usage ramp: cyan when nothing is used, red when everything is, and
    // the hue swings through blue and magenta on the way rather than fading
    // through grey.
    func testUsageRampRunsCyanThroughBlueToRed() {
        let start = rgb(MeterColor.usage(0))
        XCTAssertLessThan(start.r, 0.3); XCTAssertGreaterThan(start.g, 0.6); XCTAssertGreaterThan(start.b, 0.7)
        let end = rgb(MeterColor.usage(1))
        XCTAssertGreaterThan(end.r, 0.8); XCTAssertLessThan(end.g, 0.3); XCTAssertLessThan(end.b, 0.3)
        let mid = rgb(MeterColor.usage(0.5))
        XCTAssertGreaterThan(mid.b, mid.g, "half way is on the blue side, not green or grey")
        XCTAssertGreaterThan(max(mid.r, mid.g, mid.b) - min(mid.r, mid.g, mid.b), 0.5, "still saturated half way")
    }

    func testUsageRampClampsOutOfRangeFractions() {
        XCTAssertEqual(MeterColor.hex(from: MeterColor.usage(-1)), MeterColor.hex(from: MeterColor.usage(0)))
        XCTAssertEqual(MeterColor.hex(from: MeterColor.usage(2)), MeterColor.hex(from: MeterColor.usage(1)))
    }
}

final class MeterAppearanceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "MeterAppearanceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testDefaultsWhenNothingStored() {
        let appearance = MeterAppearance(defaults: defaults, defaultStyle: .pie)
        XCTAssertEqual(appearance.style, .pie)
        XCTAssertEqual(MeterColor.hex(from: appearance.color).uppercased(), "#34C759")
    }

    // The default must be a preset, or a fresh install ticks "Custom Colour…"
    // with nothing having been customised. NSColor.systemGreen is dynamic and
    // resolves to a different hex in dark mode, so it cannot serve.
    func testDefaultColorMatchesAPreset() {
        let appearance = MeterAppearance(defaults: defaults)
        XCTAssertTrue(MeterColor.presets.contains { $0.hex.uppercased() == appearance.colorHex.uppercased() })
    }

    func testRoundTripsThroughDefaults() {
        let appearance = MeterAppearance(defaults: defaults)
        appearance.style = .wedge
        appearance.color = MeterColor.color(fromHex: "#B18EEE")!
        let reloaded = MeterAppearance(defaults: defaults)
        XCTAssertEqual(reloaded.style, .wedge)
        XCTAssertEqual(reloaded.colorHex.uppercased(), "#B18EEE")
    }

    // A hand-edited or corrupted value must not leave the app unable to draw.
    func testGarbageStoredValuesFallBack() {
        defaults.set("banana", forKey: MeterAppearance.styleKey)
        defaults.set("#ZZZZZZ", forKey: MeterAppearance.colorKey)
        let appearance = MeterAppearance(defaults: defaults, defaultStyle: .gauge, defaultColor: .systemBlue)
        XCTAssertEqual(appearance.style, .gauge)
        XCTAssertEqual(MeterColor.hex(from: appearance.color),
                       MeterColor.hex(from: NSColor.systemBlue))
    }

    func testImageHonoursChosenStyle() {
        let appearance = MeterAppearance(defaults: defaults)
        appearance.style = .pie
        XCTAssertFalse(appearance.image(fraction: 0.5).size.width.isZero)
    }

    // The health ramp runs green, yellow, orange, red and clamps outside that.
    func testHealthRampRunsGreenThroughYellowAndOrangeToRed() {
        func hue(_ f: CGFloat) -> CGFloat { MeterColor.health(f).usingColorSpace(.sRGB)!.hueComponent * 360 }
        XCTAssertEqual(hue(0), 120, accuracy: 2, "green")
        XCTAssertEqual(hue(0.5), 60, accuracy: 2, "yellow")
        XCTAssertEqual(hue(0.75), 30, accuracy: 2, "orange")
        let end = MeterColor.health(1).usingColorSpace(.sRGB)!
        XCTAssertGreaterThan(end.redComponent, 0.85)
        XCTAssertLessThan(end.greenComponent, 0.15); XCTAssertLessThan(end.blueComponent, 0.15)
        XCTAssertEqual(MeterColor.hex(from: MeterColor.health(-1)), MeterColor.hex(from: MeterColor.health(0)))
        XCTAssertEqual(MeterColor.hex(from: MeterColor.health(2)), MeterColor.hex(from: MeterColor.health(1)))
    }
}
