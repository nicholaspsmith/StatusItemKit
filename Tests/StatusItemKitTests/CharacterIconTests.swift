import XCTest
import AppKit
@testable import StatusItemKit

final class CharacterIconTests: XCTestCase {
    func testCharactersAreNonTemplate18pt() {
        for img in [
            CharacterIcon.owl(session: 0.5, weekly: 0.3, sessionColor: .systemOrange, weeklyColor: .systemPurple),
            CharacterIcon.chameleon(color: .systemGreen),
            CharacterIcon.octopus(fraction: 0.6, color: .systemOrange),
        ] {
            XCTAssertFalse(img.isTemplate)
            XCTAssertEqual(img.size.width, 18, accuracy: 0.001)
            XCTAssertEqual(img.size.height, 18, accuracy: 0.001)
        }
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
        let low = inked(CharacterIcon.octopus(fraction: 0.2, color: .systemGreen), color: .systemGreen)
        let high = inked(CharacterIcon.octopus(fraction: 0.9, color: .systemGreen), color: .systemGreen)
        XCTAssertGreaterThan(high, low)
    }

    func testFractionExtremesDoNotCrash() {
        _ = CharacterIcon.owl(session: -1, weekly: 2, sessionColor: .red, weeklyColor: .blue)
        _ = CharacterIcon.octopus(fraction: 5, color: .red)
    }
}
