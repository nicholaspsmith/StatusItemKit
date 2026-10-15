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
