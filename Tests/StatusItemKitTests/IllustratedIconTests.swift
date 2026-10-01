// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import AppKit
@testable import StatusItemKit

/// The compositor and the illustrated glyphs, on synthetic art (the real PNGs
/// live in the apps): a purple "hat" block over a brown "face", and a yellow keycap.
final class IllustratedIconTests: XCTestCase {
    /// A 1x + 2x image of `size` drawn by `draw` (in points).
    private func art(_ size: NSSize, _ draw: @escaping () -> Void) -> NSImage {
        let image = NSImage(size: size)
        for scale in [1, 2] as [CGFloat] {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            // rep.size is in points, so the context already maps points to pixels.
            draw()
            NSGraphicsContext.restoreGraphicsState()
            image.addRepresentation(rep)
        }
        return image
    }

    private let hatRect = NSRect(x: 4, y: 14, width: 16, height: 6)
    private lazy var macDaddyArt: MacDaddyArt = {
        let size = MacDaddyArt.canvas, hat = hatRect
        let picture = { (eyes: NSColor) in self.art(size) {
            NSColor.brown.set(); NSRect(x: 6, y: 2, width: 12, height: 12).fill()
            eyes.set(); NSRect(x: 9, y: 9, width: 6, height: 1).fill()
            NSColor(srgbRed: 0.45, green: 0.30, blue: 0.62, alpha: 1).set(); hat.fill()
        } }
        let mask = art(size) { NSColor.white.set(); hat.fill() }
        return MacDaddyArt(base: picture(.blue), asleep: picture(.black), hatTip: picture(.cyan), hatMask: mask, hatTipMask: mask)
    }()
    private lazy var keycap: NSImage = art(CharacterIcon.lumenCanvas) {
        NSColor(srgbRed: 1, green: 0.8, blue: 0.2, alpha: 1).set()
        NSBezierPath(roundedRect: NSRect(x: 5, y: 6, width: 12, height: 10.5), xRadius: 2, yRadius: 2).fill()
    }

    private func bitmap(_ img: NSImage, scale: Int = 2) -> NSBitmapImageRep {
        img.representations.compactMap { $0 as? NSBitmapImageRep }.first { $0.pixelsWide == Int(img.size.width) * scale }!
    }

    /// Colour at a point (y up) of the 2x rep.
    private func color(_ img: NSImage, _ x: CGFloat, _ y: CGFloat) -> NSColor {
        let rep = bitmap(img)
        return rep.colorAt(x: Int(x * 2), y: rep.pixelsHigh - 1 - Int(y * 2))!.usingColorSpace(.sRGB)!
    }

    private func saturation(_ c: NSColor) -> CGFloat {
        let mx = max(c.redComponent, c.greenComponent, c.blueComponent), mn = min(c.redComponent, c.greenComponent, c.blueComponent)
        return mx == 0 ? 0 : (mx - mn) / mx
    }

    // MARK: Compositor

    func testComposeMakesTwoNonTemplateReps() {
        let img = IllustratedIcon.compose(size: NSSize(width: 24, height: 22), base: macDaddyArt.base)
        XCTAssertFalse(img.isTemplate)
        XCTAssertEqual(img.size, NSSize(width: 24, height: 22))
        let sizes = img.representations.map { NSSize(width: $0.pixelsWide, height: $0.pixelsHigh) }.sorted { $0.width < $1.width }
        XCTAssertEqual(sizes, [NSSize(width: 24, height: 22), NSSize(width: 48, height: 44)])
    }

    func testRecolorKeepsShadingAndStaysInsideTheMask() {
        let img = IllustratedIcon.compose(size: MacDaddyArt.canvas, base: macDaddyArt.base,
                                          recolor: [.init(mask: macDaddyArt.hatMask, color: .red)])
        let hat = color(img, 12, 17)
        XCTAssertGreaterThan(hat.redComponent, hat.blueComponent + 0.3, "hat turned red")
        let face = color(img, 12, 5), plainFace = color(IllustratedIcon.compose(size: MacDaddyArt.canvas, base: macDaddyArt.base), 12, 5)
        XCTAssertEqual(face.redComponent, plainFace.redComponent, accuracy: 0.01, "outside the mask is untouched")
    }

    func testDesaturateGreys() {
        let img = IllustratedIcon.compose(size: MacDaddyArt.canvas, base: macDaddyArt.base, desaturate: 1)
        XCTAssertLessThan(saturation(color(img, 12, 17)), 0.03)
        XCTAssertLessThan(saturation(color(img, 12, 5)), 0.03)
    }

    func testOverlayDrawsInPoints() {
        var scales: [CGFloat] = []
        let img = IllustratedIcon.compose(size: NSSize(width: 10, height: 10), base: NSImage(size: NSSize(width: 10, height: 10))) { _, scale in
            scales.append(scale); NSColor.green.set(); NSRect(x: 5, y: 5, width: 5, height: 5).fill()
        }
        XCTAssertEqual(scales.sorted(), [1, 2])
        XCTAssertGreaterThan(color(img, 8, 8).greenComponent, 0.9)
        XCTAssertEqual(color(img, 2, 2).alphaComponent, 0, accuracy: 0.01)
    }

    // MARK: Mac Daddy

    func testMacDaddyEveryStateIsOneSizeAndDistinct() {
        var seen = Set<Data>()
        for level in [MacDaddyLevel.cool, .sweating, .redHot] {
            for asleep in [false, true] {
                for flourish in [nil, MacDaddyFlourish.hatTip, .chainGlint] {
                    let img = CharacterIcon.macDaddy(art: macDaddyArt, level: level, asleep: asleep, flourish: flourish)
                    XCTAssertEqual(img.size, NSSize(width: 24, height: 22))
                    XCTAssertFalse(img.isTemplate)
                    XCTAssertEqual(img.representations.count, 2)
                    seen.insert(img.tiffRepresentation ?? Data())
                }
            }
        }
        // Asleep ignores the hat tip (eyes shut), so asleep+hatTip == asleep: 18 - 3.
        XCTAssertEqual(seen.count, 15)
        XCTAssertTrue(CharacterIcon.macDaddy(art: macDaddyArt, level: .cool, asleep: false, flourish: nil)
                      === CharacterIcon.macDaddy(art: macDaddyArt, level: .cool, asleep: false, flourish: nil), "cached")
    }

    func testMacDaddyHatColourFollowsTheLoad() {
        func hat(_ l: MacDaddyLevel, asleep: Bool = false) -> NSColor {
            color(CharacterIcon.macDaddy(art: macDaddyArt, level: l, asleep: asleep, flourish: nil), 12, 17)
        }
        let cool = hat(.cool), sweating = hat(.sweating), redHot = hat(.redHot)
        XCTAssertGreaterThan(cool.blueComponent, cool.greenComponent, "cool hat stays purple")
        XCTAssertGreaterThan(sweating.redComponent, 0.6); XCTAssertGreaterThan(sweating.greenComponent, sweating.blueComponent + 0.2, "amber")
        XCTAssertGreaterThan(redHot.redComponent, redHot.greenComponent + 0.3, "red")
        XCTAssertGreaterThan(sweating.greenComponent, redHot.greenComponent + 0.15, "amber and red differ")
        // Asleep greys a cool hat but keeps the warning colour.
        XCTAssertLessThan(saturation(hat(.cool, asleep: true)), saturation(cool))
        XCTAssertGreaterThan(hat(.redHot, asleep: true).redComponent, hat(.redHot, asleep: true).blueComponent + 0.25)
    }

    // MARK: Lumen

    func testLumenSizeAndReps() {
        let img = CharacterIcon.lumen(keycap: keycap, level: 0.5)
        XCTAssertEqual(img.size, NSSize(width: 22, height: 22))
        XCTAssertFalse(img.isTemplate)
        XCTAssertEqual(img.representations.count, 2)
    }

    func testLumenRaysCountRisesWithLevel() {
        XCTAssertEqual(CharacterIcon.lumenRaysLit(level: 0), 0)
        XCTAssertEqual(CharacterIcon.lumenRaysLit(level: 0.01), 1, "any light lights a ray")
        XCTAssertEqual(CharacterIcon.lumenRaysLit(level: 1), 8)
        XCTAssertEqual(CharacterIcon.lumenRaysLit(level: 1, active: false), 0)
        var last = -1
        for l in stride(from: 0.0, through: 1.0, by: 0.05) {
            let n = CharacterIcon.lumenRaysLit(level: CGFloat(l))
            XCTAssertGreaterThanOrEqual(n, last); last = n
        }
        // And the drawing agrees: more opaque pixels outside the keycap as the level rises.
        func rayPixels(_ l: CGFloat) -> Int {
            let rep = bitmap(CharacterIcon.lumen(keycap: keycap, level: l))
            var n = 0
            for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh {
                let px = CGFloat(x) / 2, py = CGFloat(rep.pixelsHigh - 1 - y) / 2
                if NSRect(x: 4, y: 5, width: 14, height: 12.5).contains(NSPoint(x: px, y: py)) { continue }
                if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 { n += 1 }
            } }
            return n
        }
        XCTAssertEqual(rayPixels(0), 0)
        XCTAssertLessThan(rayPixels(0.01), rayPixels(0.5))
        XCTAssertLessThan(rayPixels(0.5), rayPixels(1))
    }

    func testLumenGreysWhenOffOrInactive() {
        let on = color(CharacterIcon.lumen(keycap: keycap, level: 0.6), 11, 11)
        XCTAssertGreaterThan(saturation(on), 0.5)
        XCTAssertLessThan(saturation(color(CharacterIcon.lumen(keycap: keycap, level: 0), 11, 11)), 0.03)
        XCTAssertLessThan(saturation(color(CharacterIcon.lumen(keycap: keycap, level: 0.6, active: false), 11, 11)), 0.03)
    }
}
