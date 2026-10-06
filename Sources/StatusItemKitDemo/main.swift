// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import StatusItemKit

final class DemoApp: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController!
    private let notifier = Notifier()
    private var tick = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.requestAuthorization()
        controller = StatusItemController(
            pollInterval: 2,
            onPoll: { [weak self] in self?.poll() },
            onBuildMenu: { [weak self] menu in self?.buildMenu(menu) }
        )
        controller.start()
    }

    private func poll() {
        tick += 1
        let pct = (tick * 17) % 101                 // sweep 0..100
        let level = Severity.level(pct: pct, warnPct: 85)
        controller.setIcon(MeterIcon.arc(fraction: CGFloat(pct) / 100, color: level.color))
    }

    private func buildMenu(_ menu: NSMenu) {
        let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let labelItem = NSMenuItem()
        labelItem.view = MenuBuilder.textView("StatusItemKit demo  tick \(tick)", font: mono)
        menu.addItem(labelItem)

        menu.addItem(NSMenuItem.separator())

        let notifyItem = NSMenuItem(title: "Send test notification", action: #selector(notifyTest), keyEquivalent: "")
        notifyItem.target = self
        menu.addItem(notifyItem)

        SettingsMenu.addFooter(to: menu, appName: "StatusItemKit Demo")
    }

    @objc private func notifyTest() { notifier.post(title: "StatusItemKit", body: "Test notification.") }
}

let app = NSApplication.shared
let delegate = DemoApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
