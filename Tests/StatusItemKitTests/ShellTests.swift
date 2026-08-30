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

    func testEnvOverlayReachesChild() {
        // Overlay vars are visible in the child. The Tailscale CLI silently
        // misbehaves without TERM (prints an error to stdout, exit 0), so
        // callers must be able to inject it.
        let out = Shell.run("/bin/sh", ["-c", "printf %s \"$SIK_TEST_VAR\""],
                            env: ["SIK_TEST_VAR": "dumb"])
        XCTAssertEqual(out, "dumb")
    }

    func testEnvOverlayStillInheritsParentEnvironment() {
        // The overlay merges over the inherited environment, not replaces it:
        // HOME must survive when only an unrelated var is injected.
        let out = Shell.run("/bin/sh", ["-c", "printf %s \"$HOME\""],
                            env: ["SIK_TEST_VAR": "x"])
        XCTAssertEqual(out, ProcessInfo.processInfo.environment["HOME"])
    }
}
