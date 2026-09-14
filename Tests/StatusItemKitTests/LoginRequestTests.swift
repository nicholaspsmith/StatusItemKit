import XCTest
@testable import StatusItemKit

final class LoginRequestTests: XCTestCase {
    // argv[0] is always the binary path; parsing starts after it.
    private func parse(_ tail: String...) -> LoginRequest {
        LoginRequest.parse(arguments: ["/path/to/Widget"] + tail)
    }

    func testNoFlagMeansRunTheApp() {
        XCTAssertEqual(parse(), .absent)
        XCTAssertEqual(parse("--verbose"), .absent)
    }

    /// A bare `--login` reports rather than registers: an incomplete command
    /// must not silently change whether the app starts at login.
    func testBareFlagReportsStatus() {
        XCTAssertEqual(parse("--login"), .command(.status))
        XCTAssertEqual(parse("--login", "status"), .command(.status))
    }

    func testOnAndOff() {
        XCTAssertEqual(parse("--login", "on"), .command(.enable))
        XCTAssertEqual(parse("--login", "off"), .command(.disable))
    }

    /// A typo is a usage error, not a silent default to on.
    func testUnrecognisedValueIsRejected() {
        XCTAssertEqual(parse("--login", "yes"), .unrecognized("yes"))
        XCTAssertEqual(parse("--login", "ON"), .unrecognized("ON"))
        XCTAssertEqual(parse("--login", "1"), .unrecognized("1"))
    }

    /// `--login --other` must not swallow the next flag as its value.
    func testDoesNotConsumeAFollowingFlag() {
        XCTAssertEqual(parse("--login", "--step"), .command(.status))
    }

    /// The flag is recognised wherever it appears, not only first.
    func testFlagAnywhereOnTheCommandLine() {
        XCTAssertEqual(parse("--step", "up", "--login", "on"), .command(.enable))
    }

    func testUsageNamesTheExecutable() {
        XCTAssertEqual(LoginRequest.usage(executable: "Barn"),
                       "usage: Barn --login [on|off|status]")
    }

    /// The default executable name comes from argv[0], so each app's usage line
    /// is right without it having to repeat its own name.
    func testExecutableNameDefaultsToArgv0Basename() {
        XCTAssertEqual(
            LoginRequest.executableName(arguments: ["/Applications/Barn.app/Contents/MacOS/Barn"]),
            "Barn"
        )
        XCTAssertEqual(LoginRequest.executableName(arguments: []), "app")
    }
}
