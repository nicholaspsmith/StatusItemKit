// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import AppKit
@testable import StatusItemKit

final class MenuRowsTests: XCTestCase {
    private final class Target: NSObject {
        var fired: [String] = []
        @objc func pick(_ sender: NSMenuItem) { fired.append(sender.title) }
    }

    func testInfoItemIsDisabled() {
        XCTAssertFalse(InfoMenuItem.make("Health: 99%").isEnabled)
    }

    func testOnlyQuitAndEllipsisItemsCloseTheMenu() {
        XCTAssertTrue(KeepOpenMenu.keepsMenuOpen(title: "Low Power", isQuit: false))
        XCTAssertFalse(KeepOpenMenu.keepsMenuOpen(title: "Quit Demo", isQuit: true))
        XCTAssertFalse(KeepOpenMenu.keepsMenuOpen(title: "Preferences…", isQuit: false))
        XCTAssertFalse(KeepOpenMenu.keepsMenuOpen(title: "Open...", isQuit: false))
    }

    func testApplyMakesActionItemsKeepOpenRows() {
        let t = Target()
        let pick = NSMenuItem(title: "Low Power", action: #selector(Target.pick(_:)), keyEquivalent: "")
        pick.target = t
        let prefs = NSMenuItem(title: "Preferences…", action: #selector(Target.pick(_:)), keyEquivalent: ",")
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let info = InfoMenuItem.make("62%")
        KeepOpenMenu.apply(to: [pick, prefs, quit, info])
        XCTAssertTrue(pick.view is KeepOpenMenuRow)
        XCTAssertNil(prefs.view)
        XCTAssertNil(quit.view)
        XCTAssertNil(info.view)
    }

    func testPressSendsTheActionAndMovesAPickOneTick() {
        let t = Target()
        let menu = NSMenu()
        let items = ["Automatic", "Low Power", "High Power"].map { title -> NSMenuItem in
            let item = NSMenuItem(title: title, action: #selector(Target.pick(_:)), keyEquivalent: "")
            item.target = t
            menu.addItem(item)
            return item
        }
        items[0].state = .on
        KeepOpenMenu.pickOne(items)
        KeepOpenMenu.apply(to: items)
        (items[2].view as! KeepOpenMenuRow).press()
        XCTAssertEqual(t.fired, ["High Power"])
        XCTAssertEqual(items.map(\.state), [.off, .off, .on])
    }

    func testTogglesOutsideAPickOneSetKeepTheirOwnState() {
        let t = Target()
        let menu = NSMenu()
        let a = NSMenuItem(title: "A", action: #selector(Target.pick(_:)), keyEquivalent: "")
        let b = NSMenuItem(title: "B", action: #selector(Target.pick(_:)), keyEquivalent: "")
        for i in [a, b] { i.target = t; i.state = .on; menu.addItem(i) }
        KeepOpenMenu.apply(to: [a, b])
        (a.view as! KeepOpenMenuRow).press()
        XCTAssertEqual([a.state, b.state], [.on, .on])
    }

    func testFoldingSectionStartsFoldedAndUnfoldsDisabledInfoRows() {
        let defaults = scratchDefaults("FoldingSection")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Top", action: nil, keyEquivalent: ""))
        let plain = NSMenuItem(title: "Plain stat", action: nil, keyEquivalent: "")
        let rows = [InfoMenuItem.make("Battery: 62%"), plain]
        let heading = FoldingSection.add(title: "Battery Stats", key: "stats", defaults: defaults, items: rows, to: menu)
        XCTAssertEqual(menu.numberOfItems, 2)
        XCTAssertFalse(heading.expanded)
        XCTAssertFalse(plain.isEnabled, "an inert row is disabled, so it draws grey when inserted later")

        heading.press()
        XCTAssertTrue(heading.expanded)
        XCTAssertEqual(menu.items.map(\.title).suffix(2), ["Battery: 62%", "Plain stat"])
        XCTAssertEqual(defaults.object(forKey: FoldingSection.defaultsKey("stats")) as? Bool, true)

        heading.press()
        XCTAssertEqual(menu.numberOfItems, 2)
        XCTAssertEqual(defaults.object(forKey: FoldingSection.defaultsKey("stats")) as? Bool, false)
    }

    func testFoldingSectionRemembersItsState() {
        let defaults = scratchDefaults("FoldingSection")
        defaults.set(true, forKey: FoldingSection.defaultsKey("stats"))
        let menu = NSMenu()
        let heading = FoldingSection.add(title: "S", key: "stats", defaults: defaults,
                                         items: [InfoMenuItem.make("x")], to: menu)
        XCTAssertTrue(heading.expanded)
        XCTAssertEqual(menu.numberOfItems, 2)
    }

    func testChevronPointsDownFoldedAndUpOpen() {
        XCTAssertEqual(FoldHeadingRow.chevronSymbol(expanded: false), "chevron.down")
        XCTAssertEqual(FoldHeadingRow.chevronSymbol(expanded: true), "chevron.up")
    }

    func testAnUntickedRowsImageSitsInTheCheckColumnSoItsTitleAligns() {
        let item = NSMenuItem(title: "Mullvad · Connected", action: #selector(Target.pick(_:)), keyEquivalent: "")
        let plain = KeepOpenMenuRow(item: item).frame.width
        item.image = NSImage(size: NSSize(width: 10, height: 10))
        XCTAssertTrue(KeepOpenMenuRow.imageInColumn(item))
        XCTAssertEqual(KeepOpenMenuRow(item: item).frame.width, plain, accuracy: 1)
    }

    func testATickedRowKeepsItsImageBeforeTheTitle() {
        let item = NSMenuItem(title: "Zurich", action: #selector(Target.pick(_:)), keyEquivalent: "")
        item.state = .on
        let plain = KeepOpenMenuRow(item: item).frame.width
        item.image = NSImage(size: NSSize(width: 10, height: 10))
        XCTAssertFalse(KeepOpenMenuRow.imageInColumn(item))
        XCTAssertEqual(KeepOpenMenuRow(item: item).frame.width, plain + 16, accuracy: 1)
    }

    func testShortcutText() {
        XCTAssertEqual(MenuShortcutText.text(key: ",", command: true), "⌘,")
        XCTAssertEqual(MenuShortcutText.text(key: "q", command: true), "⌘Q")
        XCTAssertEqual(MenuShortcutText.text(key: "\u{F702}", option: true, command: true), "⌥⌘←")
    }

    // MARK: Preferences

    func testPreferencesFooterIsPreferencesThenQuit() {
        let menu = NSMenu()
        menu.addItem(InfoMenuItem.make("Row"))
        var opened = 0
        PreferencesMenu.addFooter(to: menu, appName: "Demo") { opened += 1 }
        let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)
        XCTAssertEqual(titles, ["Row", "Preferences…", "Quit Demo"])
        let prefs = menu.items.first { $0.title == "Preferences…" }!
        XCTAssertEqual(prefs.keyEquivalent, ",")
        XCTAssertEqual(prefs.keyEquivalentModifierMask, .command)
        NSApp.sendAction(prefs.action!, to: prefs.target, from: prefs)
        XCTAssertEqual(opened, 1)
    }

    func testPreferencesWindowIsTitledAndNotResizable() {
        _ = NSApplication.shared
        let pane = PreferencesPane(appName: "Demo") { PreferencesForm { StartAtLoginToggle() } }
        let window = pane.makeWindow()
        XCTAssertEqual(window.title, "Demo Preferences")
        XCTAssertFalse(window.styleMask.contains(.resizable))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertTrue(pane.makeWindow() === window, "one window per app")
    }
}
