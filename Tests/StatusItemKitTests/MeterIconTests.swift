import XCTest
import AppKit
@testable import StatusItemKit

final class MeterIconTests: XCTestCase {
    func testDotIsNonTemplateWithExpectedSize() {
        let img = MeterIcon.dot(color: .systemGreen, diameter: 10)
        XCTAssertFalse(img.isTemplate)
        XCTAssertEqual(img.size.width, 18, accuracy: 0.001)   // 10 + 4*2 padding
        XCTAssertEqual(img.size.height, 18, accuracy: 0.001)
    }

    func testMetersAreNonTemplate18pt() {
        for img in [
            MeterIcon.gauge(fraction: 0.5, color: .systemOrange),
            MeterIcon.arc(fraction: 0.5, color: .systemOrange),
            MeterIcon.pie(fraction: 0.5, color: .systemOrange),
            MeterIcon.wedge(fraction: 0.5, color: .systemOrange),
        ] {
            XCTAssertFalse(img.isTemplate)
            XCTAssertEqual(img.size.width, 18, accuracy: 0.001)
            XCTAssertEqual(img.size.height, 18, accuracy: 0.001)
        }
    }

    func testFractionExtremesDoNotCrash() {
        // out-of-range fractions are clamped, not fatal
        _ = MeterIcon.arc(fraction: -1, color: .systemGreen)
        _ = MeterIcon.wedge(fraction: 2, color: .systemRed)
    }
}
