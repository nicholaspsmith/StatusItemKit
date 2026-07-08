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

    func testTimesOutAndKillsHangingProcess() {
        // A child that never exits must not wedge the caller: the un-timed
        // version blocked here forever (the bug that froze the menu-bar icon).
        let start = Date()
        let result = Shell.run("/bin/sleep", ["30"], timeout: 1)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertNil(result)                        // hung command yields nil
        XCTAssertLessThan(elapsed, 10)              // returned promptly, didn't wait 30s
    }

    func testFastCommandWithinTimeoutSucceeds() {
        // The timeout is a backstop; well-behaved commands are unaffected.
        XCTAssertEqual(Shell.run("/bin/echo", ["hi"], timeout: 5), "hi\n")
    }
}
