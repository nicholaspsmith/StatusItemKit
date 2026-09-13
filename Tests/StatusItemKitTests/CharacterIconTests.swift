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

    func testOwlPupilsTakeTheirWindowsColours() throws {
        // Left eye is the session window, right the weekly: each pupil takes
        // the colour of its bar so the two can be told apart at a glance.
        let blue = NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
        let red = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        let owl = CharacterIcon.owl(session: 0, weekly: 0, sessionPupil: blue, weeklyPupil: red)
        let rep = NSBitmapImageRep(data: owl.tiffRepresentation!)!
        let scale = CGFloat(rep.pixelsWide) / owl.size.width
        func sample(_ x: CGFloat, _ y: CGFloat) -> NSColor {
            // Bitmap rows run top-down; the canvas is drawn bottom-up.
            rep.colorAt(x: Int(x * scale), y: Int((owl.size.height - y) * scale))!.usingColorSpace(.sRGB)!
        }
        let left = sample(8.6, 11), right = sample(23.4, 11)
        XCTAssertGreaterThan(left.blueComponent, 0.9); XCTAssertLessThan(left.redComponent, 0.1)
        XCTAssertGreaterThan(right.redComponent, 0.9); XCTAssertLessThan(right.blueComponent, 0.1)
    }

    func testOwlPupilsDefaultToBlack() throws {
        let owl = CharacterIcon.owl(session: 0, weekly: 0)
        let rep = NSBitmapImageRep(data: owl.tiffRepresentation!)!
        let scale = CGFloat(rep.pixelsWide) / owl.size.width
        let c = rep.colorAt(x: Int(8.6 * scale), y: Int((owl.size.height - 11) * scale))!.usingColorSpace(.sRGB)!
        XCTAssertLessThan(c.redComponent + c.greenComponent + c.blueComponent, 0.1)
    }

    func testMonitorLizardIsWideNonTemplateAndVariesWithState() {
        let dim = CharacterIcon.monitorLizard(brightness: 0.1, nightShift: false)
        XCTAssertEqual(dim.size, NSSize(width: 24, height: 20))
        XCTAssertFalse(dim.isTemplate)
        let bright = CharacterIcon.monitorLizard(brightness: 1.0, nightShift: false)
        let amber = CharacterIcon.monitorLizard(brightness: 1.0, nightShift: true)
        XCTAssertNotEqual(dim.tiffRepresentation, bright.tiffRepresentation, "the screen fill tracks brightness")
        XCTAssertNotEqual(bright.tiffRepresentation, amber.tiffRepresentation, "Night Shift tints the screen")
        XCTAssertNotEqual(bright.tiffRepresentation, CharacterIcon.monitorLizard(brightness: 1.0, nightShift: false, tongue: true).tiffRepresentation)
    }
}
