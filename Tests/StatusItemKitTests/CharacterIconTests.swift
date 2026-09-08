import XCTest
import AppKit
@testable import StatusItemKit

final class CharacterIconTests: XCTestCase {
    func testCharactersAreNonTemplate18pt() {
        for img in [
            CharacterIcon.owl(session: 0.5, weekly: 0.3, sessionColor: .systemOrange, weeklyColor: .systemPurple),
            CharacterIcon.chameleon(color: .systemGreen, tails: 2),
            CharacterIcon.octopus(fraction: 0.6),
            CharacterIcon.key(level: 0.5), CharacterIcon.battery(charge: 0.7, color: .systemGreen),
            CharacterIcon.camcorder(recording: true), CharacterIcon.rocket(level: 0.4, online: true),
            CharacterIcon.raccoon(active: false), CharacterIcon.bin(active: true),
        ] {
            XCTAssertFalse(img.isTemplate)
            XCTAssertEqual(img.size.width, 18, accuracy: 0.001)
            XCTAssertEqual(img.size.height, 18, accuracy: 0.001)
        }
    }

    func testOctopusColourSteps() {
        XCTAssertEqual(CharacterIcon.octopusColor(0.2), .systemGreen)
        XCTAssertEqual(CharacterIcon.octopusColor(0.3), .systemYellow)
        XCTAssertEqual(CharacterIcon.octopusColor(0.6), .systemOrange)
        XCTAssertEqual(CharacterIcon.octopusColor(0.8), .systemRed)
    }

    func testOctopusFillGrowsWithTheFraction() throws {
        func inked(_ img: NSImage, color: NSColor) -> Int {
            let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
            var n = 0
            for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.5, c.greenComponent > 0.6, c.redComponent < 0.5 { n += 1 }
            } }
            return n
        }
        // one lit tentacle at 20%, four (in red) at 100%: count red ink instead
        func red(_ img: NSImage) -> Int {
            let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
            var n = 0
            for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.5, c.redComponent > 0.7, c.greenComponent < 0.5 { n += 1 }
            } }
            return n
        }
        XCTAssertGreaterThan(red(CharacterIcon.octopus(fraction: 1.0)), red(CharacterIcon.octopus(fraction: 0.8)))
        XCTAssertGreaterThan(inked(CharacterIcon.octopus(fraction: 0.2), color: .systemGreen), 0)
    }

    func testFractionExtremesDoNotCrash() {
        _ = CharacterIcon.owl(session: -1, weekly: 2, sessionColor: .red, weeklyColor: .blue)
        _ = CharacterIcon.octopus(fraction: 5)
        _ = CharacterIcon.chameleon(color: .red, tails: 9)
        _ = CharacterIcon.key(level: 3)
    }
}
