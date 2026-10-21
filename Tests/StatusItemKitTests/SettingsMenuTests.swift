// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import AppKit
@testable import StatusItemKit

final class SettingsMenuTests: XCTestCase {
    private func appearanceMenu() -> AppearanceMenu {
        let defaults = UserDefaults(suiteName: "SettingsMenuTests-\(UUID().uuidString)")!
        return AppearanceMenu(appearance: MeterAppearance(defaults: defaults)) {}
    }

    // Icon sits in the main menu right below Settings, not inside it.
    func testFooterPutsIconBelowSettings() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Row", action: nil, keyEquivalent: ""))
        SettingsMenu.addFooter(to: menu, appName: "Demo", items: { sub in
            sub.addItem(NSMenuItem(title: "Mode", action: nil, keyEquivalent: ""))
        }, appearance: appearanceMenu())

        let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)
        XCTAssertEqual(titles, ["Row", "Settings", "Icon", "Quit Demo"])

        let settings = menu.items.first { $0.title == "Settings" }!.submenu!
        let inside = settings.items.map(\.title)
        XCTAssertFalse(inside.contains("Icon"))
        XCTAssertEqual(inside.first, "Mode")
        XCTAssertTrue(inside.contains("Start at Login"))
    }

    // An app's own pickers go in the same slot, after the shared Icon.
    func testBelowSettingsAddsTopLevelItemsBeforeQuit() {
        let menu = NSMenu()
        SettingsMenu.addFooter(to: menu, appName: "Demo", appearance: appearanceMenu(), belowSettings: { menu in
            menu.addItem(NSMenuItem(title: "Color", action: nil, keyEquivalent: ""))
        })
        XCTAssertEqual(menu.items.map(\.title), ["Settings", "Icon", "Color", "Quit Demo"])
    }

    func testFooterWithoutIcon() {
        let menu = NSMenu()
        SettingsMenu.addFooter(to: menu, appName: "Demo")
        XCTAssertEqual(menu.items.map(\.title), ["Settings", "Quit Demo"])
    }

    // `item(appearance:)` keeps its old placement for callers that use it.
    func testItemStillPlacesAppearanceInside() {
        let settings = SettingsMenu.item(appearance: appearanceMenu()).submenu!
        XCTAssertTrue(settings.items.contains { $0.title == "Icon" })
    }
}
