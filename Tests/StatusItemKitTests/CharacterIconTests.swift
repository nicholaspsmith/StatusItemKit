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

    // The whites go pinker as the lid comes down: pure white while the eye is
    // at least three-quarters open, a clear light pink when nearly shut.
    func testOwlWhitesRedden() throws {
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
        let open = whitest(CharacterIcon.owl(session: 0.2, weekly: 0.2))
        XCTAssertGreaterThan(open.greenComponent, 0.99)
        // Three-quarters shut: enough white still showing to sample cleanly.
        // The read-back is not colour-managed like the screen (a 0.80 fill
        // samples as ~0.84), so the bounds are loose: clearly pinker than the
        // old faint ramp (~0.90 here), clearly not red.
        let tired = whitest(CharacterIcon.owl(session: 0.75, weekly: 0.75))
        XCTAssertGreaterThan(tired.redComponent, 0.95)
        XCTAssertLessThan(tired.greenComponent, 0.87)
        XCTAssertGreaterThan(tired.greenComponent, 0.7)
        XCTAssertEqual(tired.greenComponent, tired.blueComponent, accuracy: 0.02)
    }
}
