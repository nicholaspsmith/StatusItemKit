// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// The one Settings submenu every Menumon app ends its menu with, just above
/// Quit. Same shape everywhere:
///
///     Settings ▸  <the app's own settings: modes, keys, bypass…>
///                 ─────────
///                 Icon ▸
///                 Start at Login
///                 ─────────
///                 Version 1.2.0      (grey)
///
/// An app passes its own items in `items`; anything it leaves out (no Icon
/// picker, no Start at Login) is simply skipped.
public enum SettingsMenu {
    /// - Parameters:
    ///   - items: the app's own settings, top of the submenu, in order. Called
    ///     each time the menu is built, so states are current.
    ///   - appearance: the app's Icon picker, if it has one.
    ///   - startAtLogin: whether to offer Start at Login (SMAppService).
    public static func item(title: String = "Settings",
                            items: (NSMenu) -> Void = { _ in },
                            appearance: AppearanceMenu? = nil,
                            startAtLogin: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        items(submenu)

        var shared: [NSMenuItem] = []
        if let appearance { shared.append(appearance.menuItem()) }
        if startAtLogin {
            shared.append(loginItem())
        }
        if !shared.isEmpty {
            if submenu.numberOfItems > 0 { submenu.addItem(.separator()) }
            shared.forEach(submenu.addItem)
        }
        if submenu.numberOfItems > 0 { submenu.addItem(.separator()) }
        submenu.addItem(AppVersion.menuItem())

        item.submenu = submenu
        return item
    }

    /// Settings, then Quit: the foot of every Menumon menu.
    public static func addFooter(to menu: NSMenu,
                                 appName: String,
                                 items: (NSMenu) -> Void = { _ in },
                                 appearance: AppearanceMenu? = nil,
                                 startAtLogin: Bool = true) {
        if menu.numberOfItems > 0, menu.items.last?.isSeparatorItem == false { menu.addItem(.separator()) }
        menu.addItem(item(items: items, appearance: appearance, startAtLogin: startAtLogin))
        let quit = NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    /// Start at Login as a keep-open checkbox. When macOS refuses (the app is
    /// not in an Applications folder) the tick snaps back to the real state,
    /// the menu closes, and the usual alert explains why.
    static func loginItem() -> NSMenuItem {
        weak var row: ToggleMenuItemView?
        let item = ToggleMenuItem.make(title: "Start at Login", isOn: LoginItem.isEnabled) { on in
            do {
                try LoginItem.setEnabled(on)
            } catch {
                row?.isOn = LoginItem.isEnabled
                row?.enclosingMenuItem?.menu?.cancelTracking()
                // An alert cannot run inside menu tracking; show it once the
                // menu has gone.
                DispatchQueue.main.async { LoginItem.set(on) }
            }
        }
        row = ToggleMenuItem.view(of: item)
        return item
    }
}
