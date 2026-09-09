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
        XCTAssertFalse(owl.isTemplate)
    }

    func testCharactersAreNonTemplate18pt() {
        for img in [
            CharacterIcon.battery(charge: 0.7, color: .systemGreen),
            CharacterIcon.camcorder(recording: true),
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
}
