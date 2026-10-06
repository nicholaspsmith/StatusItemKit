// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import AppKit
@testable import StatusItemKit

final class ToggleMenuItemTests: XCTestCase {
    // MARK: Metrics

    func testModernMetricsMatchMeasuredNativeRow() {
        let m = ToggleMenuMetrics.forMajorVersion(27)
        XCTAssertEqual(m.height, 24)
        XCTAssertEqual(m.highlightInset, 5)
        XCTAssertEqual(m.highlightRadius, 7)
        XCTAssertEqual(m.checkCenterX, 18)
        XCTAssertEqual(m.titleX, 30)
        XCTAssertEqual(ToggleMenuMetrics.forMajorVersion(26), m)
    }

    func testOlderSystemsUseTheClassicRow() {
        XCTAssertEqual(ToggleMenuMetrics.forMajorVersion(14).height, 22)
        XCTAssertNotEqual(ToggleMenuMetrics.forMajorVersion(15), ToggleMenuMetrics.forMajorVersion(26))
    }

    func testHighlightIsInsetEachSideAndFullHeight() {
        let m = ToggleMenuMetrics.forMajorVersion(27)
        let r = m.highlightRect(in: NSRect(x: 0, y: 0, width: 200, height: 24))
        XCTAssertEqual(r, NSRect(x: 5, y: 0, width: 190, height: 24))
        XCTAssertEqual(m.highlightRect(in: NSRect(x: 0, y: 0, width: 4, height: 24)).width, 0)
    }

    func testWidthFitsTitleBetweenInsets() {
        let m = ToggleMenuMetrics.forMajorVersion(27)
        XCTAssertEqual(m.width(forTitleWidth: 100.2), ceil(30 + 100.2 + 20))
    }

    func testCheckmarkSizeFollowsMenuFont() {
        XCTAssertEqual(ToggleMenuMetrics.checkmarkPointSize(menuFontSize: 13), 10.5)
        XCTAssertGreaterThan(ToggleMenuMetrics.checkmarkPointSize(menuFontSize: 16),
                             ToggleMenuMetrics.checkmarkPointSize(menuFontSize: 13))
    }

    // MARK: Keys

    func testReturnEnterAndSpaceToggle() {
        for key in [ToggleMenuKeys.returnKey, ToggleMenuKeys.keypadEnter, ToggleMenuKeys.space] {
            XCTAssertTrue(ToggleMenuKeys.toggles(keyCode: key, modifiers: []))
            XCTAssertTrue(ToggleMenuKeys.toggles(keyCode: key, modifiers: [.shift]))
        }
    }

    func testArrowsEscapeAndChordsDoNotToggle() {
        for key: UInt16 in [123, 124, 125, 126, 53, 0] {
            XCTAssertFalse(ToggleMenuKeys.toggles(keyCode: key, modifiers: []))
        }
        XCTAssertFalse(ToggleMenuKeys.toggles(keyCode: ToggleMenuKeys.returnKey, modifiers: [.command]))
        XCTAssertFalse(ToggleMenuKeys.toggles(keyCode: ToggleMenuKeys.space, modifiers: [.option]))
    }

    // MARK: Item

    func testMakeBuildsAViewItemWithState() {
        let item = ToggleMenuItem.make(title: "Show Sessions", isOn: true, toolTip: "tip") { _ in }
        let view = ToggleMenuItem.view(of: item)
        XCTAssertNotNil(view)
        XCTAssertEqual(item.title, "Show Sessions")
        XCTAssertEqual(item.state, .on)
        XCTAssertEqual(item.toolTip, "tip")
        XCTAssertTrue(view!.autoresizingMask.contains(.width))
        XCTAssertEqual(view!.frame.height, ToggleMenuMetrics.current.height)
        // A target and action keep an autoenabling menu from disabling it.
        XCTAssertNotNil(item.action)
        XCTAssertTrue(item.target === view)
    }

    func testToggleFlipsStateAndReportsNewValue() {
        var reported: [Bool] = []
        let item = ToggleMenuItem.make(title: "Bypass", isOn: false) { reported.append($0) }
        let view = ToggleMenuItem.view(of: item)!
        view.toggle()
        XCTAssertTrue(view.isOn)
        view.toggle()
        XCTAssertEqual(reported, [true, false])
    }

    func testDisabledItemIgnoresToggle() {
        var calls = 0
        let item = ToggleMenuItem.make(title: "Off", isOn: true, enabled: false) { _ in calls += 1 }
        let view = ToggleMenuItem.view(of: item)!
        view.toggle()
        XCTAssertTrue(view.isOn)
        XCTAssertEqual(calls, 0)
        XCTAssertFalse(view.validateMenuItem(item))
        XCTAssertFalse(view.accessibilityPerformPress())
    }

    func testAccessibilityIsACheckbox() {
        let item = ToggleMenuItem.make(title: "Mute", isOn: true) { _ in }
        let view = ToggleMenuItem.view(of: item)!
        XCTAssertEqual(view.accessibilityRole(), .checkBox)
        XCTAssertEqual(view.accessibilityTitle(), "Mute")
        XCTAssertEqual(view.accessibilityValue() as? NSNumber, 1)
        XCTAssertTrue(view.accessibilityPerformPress())
        XCTAssertEqual(view.accessibilityValue() as? NSNumber, 0)
    }

    func testSettingsStartAtLoginKeepsMenuOpen() {
        let settings = SettingsMenu.item()
        let login = settings.submenu?.items.first { $0.title == "Start at Login" }
        XCTAssertNotNil(login)
        XCTAssertNotNil(login.flatMap(ToggleMenuItem.view(of:)))
    }
}
