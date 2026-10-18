// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import XCTest
@testable import StatusItemKit

final class StatusItemControllerIconTests: XCTestCase {
    func testSetIconDrawsOnTheLayerAndSetTitleTakesItOff() {
        _ = NSApplication.shared
        let controller = StatusItemController(pollInterval: 3600, onPoll: {}, onBuildMenu: { _ in })
        let image = IconBitmapsTests.icon()
        controller.setIcon(image)
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + IconLayer.retryInterval * 2) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        let button = controller.button!
        XCTAssertFalse(button.image === image, "the button holds a placeholder; the icon is on the layer")
        XCTAssertEqual(button.image?.size, image.size)
        XCTAssertTrue(button.layer?.sublayers?.contains { $0.zPosition == 1 && $0.contents != nil } == true)

        controller.setTitle("42%", warn: false)
        XCTAssertNil(button.image)
        XCTAssertFalse(button.layer?.sublayers?.contains { $0.zPosition == 1 && $0.contents != nil } == true)
        XCTAssertEqual(button.attributedTitle.string, "42%")
    }
}
