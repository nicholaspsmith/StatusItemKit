// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import AppKit
@testable import StatusItemKit

final class CharacterIconTests: XCTestCase {
    func testWideCharactersUseTheRoomTheBarGives() {
        let owl = CharacterIcon.owl(session: 0.5, weekly: 0.3)
        XCTAssertEqual(owl.size, NSSize(width: 32, height: 22))
        XCTAssertEqual(CharacterIcon.chameleon(color: .systemGreen, tail: true, tongue: true).size, NSSize(width: 30, height: 22))
        XCTAssertEqual(CharacterIcon.key(level: 0.5).size, NSSize(width: 22, height: 22))
        XCTAssertEqual(CharacterIcon.apollo(level: 0.5, online: true).size, NSSize(width: 22, height: 22))
        XCTAssertEqual(CharacterIcon.camcorder(recording: true).size, NSSize(width: 24, height: 22))
        XCTAssertFalse(owl.isTemplate)
    }

    func testCharactersAreNonTemplate18pt() {
        for img in [
            CharacterIcon.battery(charge: 0.7, color: .systemGreen),
            CharacterIcon.raccoon(active: false), CharacterIcon.bin(active: true),
        ] {
            XCTAssertFalse(img.isTemplate)
            XCTAssertEqual(img.size.width, 18, accuracy: 0.001)
            XCTAssertEqual(img.size.height, 18, accuracy: 0.001)
        }
    }

    func testSeaStagesByQuarter() {
        XCTAssertEqual(CharacterIcon.seaStage(0), .greenFour)
        XCTAssertEqual(CharacterIcon.seaStage(0.24), .greenFour)
        XCTAssertEqual(CharacterIcon.seaStage(0.25), .yellowFour)
        XCTAssertEqual(CharacterIcon.seaStage(0.5), .orangeEight)
        XCTAssertEqual(CharacterIcon.seaStage(0.75), .redEight)
        XCTAssertEqual(CharacterIcon.seaStage(1), .redEight)
    }

    func testSeaStagesHeatUp() {
        XCTAssertEqual(CharacterIcon.SeaStage.greenFour.color, .systemGreen)
        XCTAssertEqual(CharacterIcon.SeaStage.yellowFour.color, .systemYellow)
        XCTAssertEqual(CharacterIcon.SeaStage.orangeEight.color, .systemOrange)
        XCTAssertEqual(CharacterIcon.SeaStage.redEight.color, .systemRed)
    }

    func testSeaStagesShareOneCanvas() {
        for stage in CharacterIcon.SeaStage.allCases {
            XCTAssertEqual(CharacterIcon.octopus(stage: stage).size, NSSize(width: 28, height: 22))
        }
        XCTAssertEqual(CharacterIcon.octopus(fraction: 0.3).size, NSSize(width: 28, height: 22))
    }

    func testFractionExtremesDoNotCrash() {
        _ = CharacterIcon.owl(session: -1, weekly: 2)
        _ = CharacterIcon.octopus(fraction: 5)
        _ = CharacterIcon.chameleon(color: .red, tail: false, tongue: false)
        _ = CharacterIcon.key(level: 3)
    }

    func testKeyLightsAtOnePercent() throws {
        // At 1% the key must already be yellow: sample the key body's colour.
        func isYellowish(_ img: NSImage) -> Bool {
            let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
            for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.9,
                   c.redComponent > 0.8, c.greenComponent > 0.6, c.blueComponent < 0.4 { return true }
            } }
            return false
        }
        XCTAssertTrue(isYellowish(CharacterIcon.key(level: 0.01)))
        XCTAssertFalse(isYellowish(CharacterIcon.key(level: 0)))
    }

    private func sample(_ img: NSImage, _ x: CGFloat, _ y: CGFloat) -> NSColor {
        let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
        let scale = CGFloat(rep.pixelsWide) / img.size.width
        // Bitmap rows run top-down; the canvas is drawn bottom-up.
        return rep.colorAt(x: Int(x * scale), y: Int((img.size.height - y) * scale))!.usingColorSpace(.sRGB)!
    }

    // Both pupils are one colour: dark green (#005401) with the weekly window
    // untouched, orange-red (#FF5401) when it is spent, and the eyes always match.
    func testOwlPupilsRunGreenToRedWithTheWeeklyWindow() {
        let fresh = CharacterIcon.owl(session: 0, weekly: 0)
        for x in [CGFloat(8.6), 23.4] {
            let c = sample(fresh, x, 11)
            XCTAssertLessThan(c.redComponent, 0.05, "fresh pupil has no red")
            XCTAssertGreaterThan(c.greenComponent, c.blueComponent + 0.2, "fresh pupil is green")
        }
        let spent = CharacterIcon.owl(session: 0, weekly: 1)
        for x in [CGFloat(8.6), 23.4] {
            let c = sample(spent, x, 11)
            XCTAssertGreaterThan(c.redComponent, 0.95, "spent pupil is red")
            XCTAssertLessThan(c.greenComponent, 0.5); XCTAssertLessThan(c.blueComponent, 0.05)
        }
        // The session window does not touch the pupil.
        let busy = sample(CharacterIcon.owl(session: 0.4, weekly: 0), 8.6, 11)
        let idle = sample(fresh, 8.6, 11)
        XCTAssertEqual(busy.redComponent, idle.redComponent, accuracy: 0.02)
        XCTAssertEqual(busy.blueComponent, idle.blueComponent, accuracy: 0.02)
    }

    // The veins appear in the last quarter of the week: none below 75%, 1%
    // opaque at 75%, rising straight to solid at 100%.
    func testOwlVeinOpacityTracksTheWeeklyWindow() {
        // The reddest pixel in the eye white, outside the pupil, relative to the
        // palest (the white itself, pink or not): how far green has dropped below
        // red on the veins beyond the white's own tint.
        func vein(_ weekly: CGFloat) -> CGFloat {
            // At 8x, so the half-point veins cover whole pixels.
            let img = CharacterIcon.owl(session: 0, weekly: weekly), scale: CGFloat = 8
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(img.size.width * scale),
                                       pixelsHigh: Int(img.size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                                       hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            img.draw(in: NSRect(x: 0, y: 0, width: CGFloat(rep.pixelsWide), height: CGFloat(rep.pixelsHigh)))
            NSGraphicsContext.restoreGraphicsState()
            var best: CGFloat = 0, palest: CGFloat = 1
            for px in 0..<rep.pixelsWide { for py in 0..<rep.pixelsHigh {
                let x = CGFloat(px) / scale, y = img.size.height - CGFloat(py) / scale
                let d = hypot(x - 8.6, y - 11)
                // Skip the right eye's rim, which overlaps this eye's edge.
                guard d > 3.8, d < 6.6, hypot(x - 23.4, y - 11) > 8.6, let c = rep.colorAt(x: px, y: py)?.usingColorSpace(.sRGB) else { continue }
                best = max(best, c.redComponent - c.greenComponent)
                palest = min(palest, c.redComponent - c.greenComponent)
            } }
            return best - palest
        }
        XCTAssertLessThan(vein(0), 0.01, "no veins at 0%")
        XCTAssertLessThan(vein(0.74), 0.01, "no veins before 75%")
        XCTAssertGreaterThan(vein(0.8), 0.05, "veins showing past 75%")
        XCTAssertLessThan(vein(0.8), vein(0.9))
        XCTAssertLessThan(vein(0.9), vein(1))
        // Solid red (red - green ≈ 0.83) over the fully pink white (≈ 0.3).
        XCTAssertGreaterThan(vein(1), 0.45, "veins solid red at 100%")
    }

    // Both lids droop together with the session window, whatever the weekly is.
    func testOwlLidsFollowTheSessionWindowInBothEyes() {
        // A point in the upper half of each eye: white when open, brown once
        // the lid has come half way down. Sampled at 80° (mirrored in the right
        // eye), in a gap between veins.
        let open = CharacterIcon.owl(session: 0, weekly: 1)
        let half = CharacterIcon.owl(session: 0.5, weekly: 0)
        for x: CGFloat in [8.6 + 0.87, 23.4 - 0.87] {
            let o = sample(open, x, 15.9)
            XCTAssertGreaterThan(o.greenComponent, 0.7, "eye open at 0 session")
            let h = sample(half, x, 15.9)
            XCTAssertLessThan(h.greenComponent, 0.4, "lid covers the upper half at 0.5 session")
            XCTAssertGreaterThan(h.redComponent, h.blueComponent, "the lid is brown")
        }
    }

    func testMonitorLizardIsWideNonTemplateAndVariesWithState() {
        let dim = CharacterIcon.monitorLizard(brightness: 0.1, nightShift: false)
        XCTAssertEqual(dim.size, NSSize(width: 25, height: 22))
        XCTAssertFalse(dim.isTemplate)
        let bright = CharacterIcon.monitorLizard(brightness: 1.0, nightShift: false)
        let amber = CharacterIcon.monitorLizard(brightness: 1.0, nightShift: true)
        XCTAssertNotEqual(dim.tiffRepresentation, bright.tiffRepresentation, "the screen fill tracks brightness")
        XCTAssertNotEqual(bright.tiffRepresentation, amber.tiffRepresentation, "Night Shift tints the screen")
        XCTAssertNotEqual(bright.tiffRepresentation, CharacterIcon.monitorLizard(brightness: 1.0, nightShift: false, tongue: true).tiffRepresentation)
    }

    func testMonitorLizardScreenFillsBottomUpAndTintsAmber() throws {
        // The screen rect in the implementation is x: 2.6...17.4, y: 6.1...14.5
        // on the 25x22 canvas. Sample near its top and bottom, a little in from
        // each edge so antialiasing at the boundary can't flip the result, and
        // below the paws (y 13.4 up) that grip the top bezel.
        let midX: CGFloat = 9.5, topY: CGFloat = 12.8, bottomY: CGFloat = 6.7

        func sample(_ img: NSImage, _ x: CGFloat, _ y: CGFloat) -> NSColor {
            let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
            let scale = CGFloat(rep.pixelsWide) / img.size.width
            // Bitmap rows run top-down; the canvas is drawn bottom-up.
            return rep.colorAt(x: Int(x * scale), y: Int((img.size.height - y) * scale))!.usingColorSpace(.sRGB)!
        }

        let dim = CharacterIcon.monitorLizard(brightness: 0.25, nightShift: false)
        let bright = CharacterIcon.monitorLizard(brightness: 1.0, nightShift: false)
        let amber = CharacterIcon.monitorLizard(brightness: 1.0, nightShift: true)

        // The fill grows bottom-up: at low brightness the bottom of the screen
        // is already lit but the top is still empty (transparent, since the
        // screen was cut out of the bezel); at full brightness both are lit.
        XCTAssertLessThan(sample(dim, midX, topY).alphaComponent, 0.1, "dim: top of screen still unlit")
        XCTAssertGreaterThan(sample(dim, midX, bottomY).alphaComponent, 0.5, "dim: bottom of screen already lit")
        XCTAssertGreaterThan(sample(bright, midX, topY).alphaComponent, 0.5, "bright: top of screen lit")
        XCTAssertGreaterThan(sample(bright, midX, bottomY).alphaComponent, 0.5, "bright: bottom of screen lit")

        // Night Shift tints the fill amber; without it the fill is the same
        // neutral grey as the rest of the body.
        let amberTop = sample(amber, midX, topY)
        XCTAssertGreaterThan(amberTop.redComponent, 0.9)
        XCTAssertGreaterThan(amberTop.greenComponent, 0.5); XCTAssertLessThan(amberTop.greenComponent, 0.75)
        XCTAssertLessThan(amberTop.blueComponent, 0.35)

        // Without Night Shift the fill is the mascot's sky blue, not grey and not the
        // lizard's yellow.
        let blueTop = sample(bright, midX, topY)
        XCTAssertLessThan(blueTop.redComponent, 0.5)
        XCTAssertGreaterThan(blueTop.blueComponent, 0.9)

        // The lizard is a sandy leopard gecko, a different colour from the grey monitor
        // and the blue screen: sample the head (x 11.4...22.6, y 13.6...21.3) away from
        // its spots and eye, and the bezel.
        let head = sample(bright, 15.2, 18.6)
        XCTAssertGreaterThan(head.alphaComponent, 0.9)
        XCTAssertGreaterThan(head.redComponent - head.blueComponent, 0.4, "head is sandy yellow, not grey")
        XCTAssertGreaterThan(head.greenComponent - head.blueComponent, 0.25)
        let bezel = sample(bright, 9.5, 5.5)   // the bottom bezel strip, y 5...6.1
        XCTAssertLessThan(abs(bezel.redComponent - bezel.blueComponent), 0.05, "bezel stays grey")
    }

    // The whites go pinker as the weekly window fills: pure white below a
    // quarter used, a clear light pink when it is nearly spent.
    func testOwlWhitesReddenWithTheWeeklyWindow() throws {
        // The brightest white-ish pixel is the eye white itself: the lid is
        // brown, the pupil black and the veins red, and anti-aliasing only
        // ever blends towards those.
        func whitest(_ img: NSImage) -> NSColor {
            let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
            var best = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
            for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.99,
                      c.redComponent > 0.95 else { continue }
                if c.greenComponent > best.greenComponent { best = c }
            } }
            return best
        }
        let open = whitest(CharacterIcon.owl(session: 0, weekly: 0.2))
        XCTAssertGreaterThan(open.greenComponent, 0.99)
        // Three-quarters of the week spent, lids open so the white is easy to sample.
        // The read-back is not colour-managed like the screen (a 0.80 fill
        // samples as ~0.84), so the bounds are loose: clearly pinker than the
        // old faint ramp (~0.90 here), clearly not red.
        let tired = whitest(CharacterIcon.owl(session: 0, weekly: 0.75))
        XCTAssertGreaterThan(tired.redComponent, 0.95)
        XCTAssertLessThan(tired.greenComponent, 0.87)
        XCTAssertGreaterThan(tired.greenComponent, 0.7)
        XCTAssertEqual(tired.greenComponent, tired.blueComponent, accuracy: 0.02)
        // A heavy session with a fresh week keeps the whites white.
        let session = whitest(CharacterIcon.owl(session: 0.6, weekly: 0))
        XCTAssertGreaterThan(session.greenComponent, 0.99)
    }

    func testMenuCraneIs22ptFullColourAndEveryStateDiffers() {
        let states: [CharacterIcon.CraneState] = [.idle, .searching, .grabbed, .miss]
        let images = states.map { CharacterIcon.menuCrane(state: $0) }
        for img in images {
            XCTAssertEqual(img.size, NSSize(width: 22, height: 22))
            XCTAssertFalse(img.isTemplate)
        }
        let pngs = images.map { NSBitmapImageRep(data: $0.tiffRepresentation!)!.representation(using: .png, properties: [:])! }
        XCTAssertEqual(Set(pngs).count, states.count)
    }

    func testCaterpillarKeepsOneWideCanvasForEveryState() {
        for (effects, state) in [(0, CaterpillarState.processing), (3, .processing), (5, .processing),
                                 (9, .processing), (2, .bypassed), (2, .error)] {
            let img = CharacterIcon.caterpillar(effects: effects, state: state)
            XCTAssertEqual(img.size, NSSize(width: 36, height: 22))
            XCTAssertFalse(img.isTemplate)
        }
    }

    func testCaterpillarIsSupersampledInto2xAnd1xBitmaps() {
        let img = CharacterIcon.caterpillar(effects: 3, state: .processing)
        let widths = Set(img.representations.map(\.pixelsWide))
        XCTAssertEqual(widths, [72, 36])
    }

    func testCaterpillarSegmentsLightWithEffectsAndCapAtFive() {
        func pixels(_ effects: Int) -> Data? {
            CharacterIcon.caterpillar(effects: effects, state: .processing)
                .representations.compactMap { $0 as? NSBitmapImageRep }.first { $0.pixelsWide == 72 }?
                .representation(using: .png, properties: [:])
        }
        XCTAssertNotEqual(pixels(0), pixels(3))
        XCTAssertEqual(pixels(5), pixels(9))
    }

    func testMacDaddyIsOneWidthInEveryState() {
        var seen = Set<Data>()
        for level in [MacDaddyLevel.cool, .sweating, .redHot] {
            for asleep in [false, true] {
                for flourish in [nil, MacDaddyFlourish.hatTip, .chainGlint] {
                    let img = CharacterIcon.macDaddy(level: level, asleep: asleep, flourish: flourish)
                    XCTAssertEqual(img.size, NSSize(width: 24, height: 22))
                    XCTAssertFalse(img.isTemplate)
                    let sizes = img.representations.map { NSSize(width: $0.pixelsWide, height: $0.pixelsHigh) }.sorted { $0.width < $1.width }
                    XCTAssertEqual(sizes, [NSSize(width: 24, height: 22), NSSize(width: 48, height: 44)])
                    seen.insert(img.tiffRepresentation ?? Data())
                }
            }
        }
        XCTAssertEqual(seen.count, 18, "every state should draw differently")
        XCTAssertTrue(CharacterIcon.macDaddy(level: .cool, asleep: false, flourish: nil)
                      === CharacterIcon.macDaddy(level: .cool, asleep: false, flourish: nil), "cached")
    }

    func testMacDaddyHotCuesSurviveSleep() {
        let imgs = [MacDaddyLevel.cool, .sweating, .redHot].map {
            CharacterIcon.macDaddy(level: $0, asleep: true, flourish: nil).tiffRepresentation ?? Data()
        }
        XCTAssertEqual(Set(imgs).count, 3, "asleep cool, sweating and red-hot must still differ")
    }

    func testMacDaddyDrawingStaysInsideTheCanvas() {
        for level in [MacDaddyLevel.cool, .sweating, .redHot] { for asleep in [false, true] {
            for flourish in [nil, MacDaddyFlourish.hatTip, .chainGlint] {
                let img = CharacterIcon.macDaddy(level: level, asleep: asleep, flourish: flourish)
                guard let rep = img.representations.max(by: { $0.pixelsWide < $1.pixelsWide }) as? NSBitmapImageRep else {
                    return XCTFail("no bitmap rep")
                }
                // The outermost pixel ring (0.5pt at 2x) on top, left and right stays empty, so nothing is cropped.
                var touched = 0
                for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: 0)?.alphaComponent ?? 0) > 0.02 { touched += 1 }
                for y in 0..<rep.pixelsHigh {
                    if (rep.colorAt(x: 0, y: y)?.alphaComponent ?? 0) > 0.02 { touched += 1 }
                    if (rep.colorAt(x: rep.pixelsWide - 1, y: y)?.alphaComponent ?? 0) > 0.02 { touched += 1 }
                }
                XCTAssertEqual(touched, 0, "\(level) asleep=\(asleep) \(String(describing: flourish)) touches the canvas edge")
            }
        } }
    }
}
