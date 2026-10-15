// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

// Template icons drawn two ways in the real menu bar, in pairs: AppKit's own
// `button.image` (old) and IconLayer (new). Each item's menu says which it is.
// Compare them on light and dark bars, with Reduce Transparency on and off, on
// each display. Quit from any item's menu.
import AppKit

final class Compare: NSObject, NSApplicationDelegate {
    var items: [NSStatusItem] = []
    var layers: [IconLayer] = []

    func applicationDidFinishLaunching(_ n: Notification) {
        func meter(_ make: (CGFloat, NSColor) -> NSImage) -> NSImage {
            let image = make(0.6, .black)
            image.isTemplate = true
            return image
        }
        let samples: [(String, NSImage)] = [
            ("gauge", meter(MeterIcon.gauge)), ("arc", meter(MeterIcon.arc)),
            ("pie", meter(MeterIcon.pie)), ("wedge", meter(MeterIcon.wedge)),
            ("battery symbol", NSImage(systemSymbolName: "battery.75percent", accessibilityDescription: nil)!),
        ]
        // Status items are added right to left, so add each pair new-then-old to read old, new.
        for (name, image) in samples.reversed() {
            for old in [false, true] {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                let button = item.button!
                button.imagePosition = .imageOnly
                if old {
                    button.image = image
                } else {
                    let icons = IconLayer(button: button)
                    if !icons.show(image) { button.image = image }
                    layers.append(icons)
                }
                let menu = NSMenu()
                menu.addItem(withTitle: "\(name): \(old ? "OLD — AppKit draws it" : "NEW — IconLayer")", action: nil, keyEquivalent: "")
                menu.addItem(.separator())
                menu.addItem(withTitle: "Quit icon-compare", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
                item.menu = menu
                items.append(item)
            }
        }
    }
}

let app = NSApplication.shared
let delegate = Compare()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
