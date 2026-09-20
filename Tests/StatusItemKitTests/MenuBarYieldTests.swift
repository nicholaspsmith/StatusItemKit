// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
@testable import StatusItemKit

final class MenuBarYieldTests: XCTestCase {
    func testPayloadRoundTrips() {
        let p = MenuBarYield.Payload(state: .yield, token: "abc", ttl: 8)
        XCTAssertEqual(MenuBarYield.Payload(userInfo: p.userInfo), p)
    }

    func testMalformedUserInfoIsRejected() {
        // Distributed notifications arrive from outside this process; a garbled
        // one must be ignored rather than hide the host's icon forever.
        XCTAssertNil(MenuBarYield.Payload(userInfo: ["state": "sideways", "token": "a", "ttl": "8"]))
        XCTAssertNil(MenuBarYield.Payload(userInfo: [:]))
        XCTAssertNil(MenuBarYield.Payload(userInfo: nil))
    }

    func testPayloadCarriesOnlyPropertyListValues() {
        // Distributed notification userInfo must be plist-compatible, so every
        // value is a String on the wire.
        let p = MenuBarYield.Payload(state: .yield, token: "abc", ttl: 8)
        XCTAssertTrue(p.userInfo.values.allSatisfy { $0 is String })
    }

    func testRestorePayloadSurvivesTheRoundTrip() {
        let p = MenuBarYield.Payload(state: .restore, token: "abc", ttl: 0)
        XCTAssertEqual(MenuBarYield.Payload(userInfo: p.userInfo)?.state, .restore)
    }
}
