import XCTest
@testable import StatusItemKit

final class ShellTests: XCTestCase {
    func testEchoReturnsStdout() {
        XCTAssertEqual(Shell.run("/bin/echo", ["hello"]), "hello\n")
    }
    func testNonexistentBinaryReturnsNil() {
        XCTAssertNil(Shell.run("/nonexistent/binary", []))
    }
    func testNonzeroExitReturnsNil() {
        // `false` exits 1 with no output.
        XCTAssertNil(Shell.run("/usr/bin/false", []))
    }
}
