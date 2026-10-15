// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import XCTest
@testable import StatusItemKit

final class IconLayerTests: XCTestCase {
    private var window: NSWindow!
    private var button: NSButton!
    private var scale: CGFloat = 2

    override func setUp() {
        _ = NSApplication.shared
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 22), styleMask: .borderless,
                          backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        button = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 22))
        window.contentView?.addSubview(button)
        scale = 2
    }

    override func tearDown() {
        window.close()
        window = nil
        button = nil
    }

    private func makeLayer() -> IconLayer { IconLayer(button: button, scale: { [unowned self] in self.scale }) }

    /// Lets queued main-thread work (the appearance and retry hops) run.
    private func settle(_ seconds: TimeInterval = 0) {
        let done = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { DispatchQueue.main.async { done.fulfill() } }
        wait(for: [done], timeout: seconds + 2)
    }

    func testShowsTheIconOnALayerAndAPlaceholderOnTheButton() {
        let icons = makeLayer(), image = IconBitmapsTests.icon()
        XCTAssertTrue(icons.show(image))
        XCTAssertFalse(button.image === image)
        XCTAssertEqual(button.image?.size, image.size)
        XCTAssertEqual(icons.shownBitmap?.width, 72)
        XCTAssertEqual(icons.shownScale, 2)
        XCTAssertTrue(icons.isShowing)
        XCTAssertEqual(icons.shownFrame, CGRect(x: 0, y: 0, width: 36, height: 22))
    }

    // Review focus 1: the bar moves to a display with another scale.
    func testAScaleChangeRepicksTheBitmap() {
        let icons = makeLayer()
        icons.show(IconBitmapsTests.icon())
        scale = 1
        NotificationCenter.default.post(name: NSWindow.didChangeBackingPropertiesNotification, object: window)
        XCTAssertEqual(icons.shownBitmap?.width, 36)
        XCTAssertEqual(icons.shownScale, 1)
    }

    // Review focus 5: a template follows the bar's light or dark appearance.
    func testATemplateIsTintedForTheAppearanceAndFollowsIt() {
        let icons = makeLayer()
        button.appearance = NSAppearance(named: .darkAqua)
        icons.show(IconBitmapsTests.template())
        XCTAssertGreaterThan(IconBitmapsTests.centre(icons.shownBitmap!).red, 0.9)
        button.appearance = NSAppearance(named: .aqua)
        settle()
        XCTAssertLessThan(IconBitmapsTests.centre(icons.shownBitmap!).red, 0.1)
    }

    // Review focus 3: an icon of another size (KeyLight's styles, a wider battery).
    func testAnotherSizeResizesThePlaceholderAndRecentres() {
        let icons = makeLayer()
        icons.show(IconBitmapsTests.icon(width: 36))
        icons.show(IconBitmapsTests.icon(width: 26))
        XCTAssertEqual(button.image?.size, NSSize(width: 26, height: 22))
        XCTAssertEqual(icons.shownFrame, CGRect(x: 5, y: 0, width: 26, height: 22))   // the test button stays 36 wide
    }

    // Review focus 2: the menu's highlight, added to the button later, stays under the icon.
    func testTheIconStaysAboveLayersAddedLater() {
        let icons = makeLayer()
        icons.show(IconBitmapsTests.icon())
        let highlight = CALayer()
        button.layer?.addSublayer(highlight)
        XCTAssertGreaterThan(icons.zPosition, highlight.zPosition)
    }

    // setVisible(false) shrinks the item to nothing: the icon must not show outside it.
    func testZeroWidthHidesTheIcon() {
        let icons = makeLayer()
        icons.show(IconBitmapsTests.icon())
        button.frame.size.width = 0
        XCTAssertFalse(icons.isShowing)
        button.frame.size.width = 36
        XCTAssertTrue(icons.isShowing)
    }

    func testRemoveTakesTheLayerOffAndClearsThePlaceholder() {
        let icons = makeLayer()
        icons.show(IconBitmapsTests.icon())
        icons.remove()
        XCTAssertFalse(icons.isShowing)
        XCTAssertNil(button.image)
        XCTAssertTrue(icons.show(IconBitmapsTests.icon()))
        XCTAssertTrue(icons.isShowing)
    }

    // Review focus 4: the first icon arrives before the button has a window (launch).
    func testBeforeAWindowItIsRefusedThenTakesOver() {
        let loose = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 22))
        let icons = IconLayer(button: loose, scale: { 2 })
        let image = IconBitmapsTests.icon()
        XCTAssertFalse(icons.show(image))
        loose.image = image                       // what StatusItemController does on a refusal
        window.contentView?.addSubview(loose)
        settle(IconLayer.retryInterval * 2)
        XCTAssertTrue(icons.isShowing)
        XCTAssertFalse(loose.image === image)
        XCTAssertEqual(loose.image?.size, image.size)
    }
}
