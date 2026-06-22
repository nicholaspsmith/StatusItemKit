import XCTest
@testable import StatusItemKit

final class SeverityTests: XCTestCase {
    func testNormalBelowHalf() {
        XCTAssertEqual(Severity.level(pct: 0, warnPct: 85), .normal)
        XCTAssertEqual(Severity.level(pct: 49, warnPct: 85), .normal)
    }
    func testElevatedFromHalfToWarn() {
        XCTAssertEqual(Severity.level(pct: 50, warnPct: 85), .elevated)
        XCTAssertEqual(Severity.level(pct: 84, warnPct: 85), .elevated)
    }
    func testHighAtOrAboveWarn() {
        XCTAssertEqual(Severity.level(pct: 85, warnPct: 85), .high)
        XCTAssertEqual(Severity.level(pct: 200, warnPct: 85), .high)
    }
}
