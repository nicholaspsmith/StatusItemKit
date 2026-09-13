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

    func testMonitorLizardScreenFillsBottomUpAndTintsAmber() throws {
        // The screen rect in the implementation is x: 3.4...15.6, y: 6.9...14.1
        // on the 24x20 canvas. Sample near its top and bottom, a little in from
        // each edge so antialiasing at the boundary can't flip the result.
        let midX: CGFloat = 9.5, topY: CGFloat = 13.8, bottomY: CGFloat = 7.2

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

        // Without Night Shift the fill is KeyLight's yellow (systemYellow), not grey.
        let yellowTop = sample(bright, midX, topY)
        XCTAssertGreaterThan(yellowTop.redComponent, 0.9)
        XCTAssertGreaterThan(yellowTop.greenComponent, 0.7)
        XCTAssertLessThan(yellowTop.blueComponent, 0.25)

        // The lizard is tan, a different colour from the grey monitor: sample the head
        // (x 10...19.6, y 15...19) away from its spots and eye, and the bezel below it.
        let head = sample(bright, 14.8, 18.4)
        XCTAssertGreaterThan(head.alphaComponent, 0.9)
        XCTAssertGreaterThan(head.redComponent - head.blueComponent, 0.3, "head is tan, not grey")
        let bezel = sample(bright, 2.7, 10)
        XCTAssertLessThan(abs(bezel.redComponent - bezel.blueComponent), 0.05, "bezel stays grey")
    }
}
