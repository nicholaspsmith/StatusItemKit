// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import SwiftUI

// The Preferences window every Menumon app shares, after Mac Daddy's:
//
//     menu:    …
//              ─────────
//              Preferences…        ⌘,
//              Quit <App>          ⌘Q
//
//     window:  "<App> Preferences", not resizable, Esc / ⌘W close it.
//              A grouped SwiftUI form: the app's sections (General first,
//              with StartAtLoginToggle), then the version, centred and grey.
//
// An app supplies only its sections:
//
//     let prefs = PreferencesPane(appName: "Battery Time") {
//         PreferencesForm {
//             Section("General") { StartAtLoginToggle() }
//         }
//     }
//     PreferencesMenu.addFooter(to: menu, appName: "Battery Time") { prefs.show() }

/// The window. One per app; `show()` brings it to the front, creating it the
/// first time.
public final class PreferencesPane: NSObject, NSWindowDelegate {
    public let appName: String
    private let makeContent: () -> AnyView
    private(set) public var window: NSWindow?
    /// Called each time the window is shown, before it appears: re-read state
    /// something else may have changed.
    public var onShow: (() -> Void)?
    /// Called when the window closes.
    public var onClose: (() -> Void)?

    public init<Content: View>(appName: String, @ViewBuilder content: @escaping () -> Content) {
        self.appName = appName
        self.makeContent = { AnyView(content()) }
    }

    public static func title(appName: String) -> String { "\(appName) Preferences" }

    /// The window, created on first use (not shown).
    @discardableResult
    public func makeWindow() -> NSWindow {
        if let window { return window }
        let hosting = NSHostingController(rootView: makeContent())
        // NSWindow(contentViewController:) doesn't size itself to a hosted
        // SwiftUI view on its own; without this it opens as a title bar.
        hosting.sizingOptions = [.preferredContentSize]
        let w = PreferencesWindow(contentViewController: hosting)
        w.title = Self.title(appName: appName)
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        window = w
        return w
    }

    public func show() {
        onShow?()
        let w = makeWindow()
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    public func windowWillClose(_ notification: Notification) { onClose?() }
}

/// Esc and ⌘W close it: an accessory app has no main menu to supply ⌘W.
final class PreferencesWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        makeFirstResponder(nil)   // end editing first, so a field's save-on-blur runs
        performClose(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods == .command, event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// The grouped form every Preferences window uses: the app's sections, then
/// the version, centred and grey. `width` is Mac Daddy's 460 by default; keep
/// it unless the content needs more.
public struct PreferencesForm<Content: View>: View {
    private let width: CGFloat
    private let showsVersion: Bool
    private let content: Content

    public init(width: CGFloat = 460, showsVersion: Bool = true, @ViewBuilder content: () -> Content) {
        self.width = width
        self.showsVersion = showsVersion
        self.content = content()
    }

    public var body: some View {
        Form {
            content
            if showsVersion { PreferencesVersionSection() }
        }
        .formStyle(.grouped)
        .frame(width: width)
        .padding(.vertical, 8)
    }
}

/// The last section: "Version X.Y.Z", centred, grey. `PreferencesForm` adds
/// it; a tabbed window puts it at the foot of its General tab.
public struct PreferencesVersionSection: View {
    public init() {}
    public var body: some View {
        Section {
            Text("Version \(AppVersion.string)").font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// A section footer in the house style: grey callout text, left aligned.
public struct PreferencesNote: View {
    private let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text).font(.callout).foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Start at Login (SMAppService), re-read whenever the window comes to the
/// front, since System Settings can change it behind the app's back. When
/// macOS refuses, the switch snaps back and `LoginItem.set` explains why.
public struct StartAtLoginToggle: View {
    @State private var on = LoginItem.isEnabled
    public init() {}
    public var body: some View {
        Toggle("Start at Login", isOn: Binding(get: { on }, set: { LoginItem.set($0); on = LoginItem.isEnabled }))
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                on = LoginItem.isEnabled
            }
    }
}

/// A row of icon choices drawn as they look in the bar, the chosen one
/// outlined in the accent colour (Panes's and KeyLight's icon pickers).
///
/// By default the tiles pack to the left, each as wide as its tile or its
/// name, so a long name pushes its neighbours apart. With a `columnWidth`
/// every tile sits centred in a column that wide instead: the tiles are evenly
/// spaced whatever they are called, and a name wider than its column shrinks
/// a little to fit instead of being cut off (Claude Usage's colour pairs).
/// `columnWidth(for:)` gives the width that spreads a number of tiles across
/// a `PreferencesForm` row. A fixed width, not a stretchy one: a grouped form
/// measures a row of greedy columns short and squeezes its padding.
public struct IconTilePicker<ID: Hashable>: View {
    public struct Choice {
        public let id: ID
        public let title: String
        public let image: NSImage
        public init(id: ID, title: String, image: NSImage) {
            self.id = id
            self.title = title
            self.image = image
        }
    }

    private let choices: [Choice]
    private let columnWidth: CGFloat?
    @Binding private var selection: ID

    public init(_ choices: [Choice], selection: Binding<ID>, columnWidth: CGFloat? = nil) {
        self.choices = choices
        self.columnWidth = columnWidth
        _selection = selection
    }

    /// The column width that spreads `count` tiles evenly across a row of a
    /// `PreferencesForm` of `formWidth` (a grouped form insets its rows 30
    /// a side), never narrower than a tile.
    public static func columnWidth(for count: Int, formWidth: CGFloat = 460) -> CGFloat {
        let row = formWidth - 60, n = CGFloat(max(1, count))
        return max(56, ((row - columnSpacing * (n - 1)) / n).rounded(.down))
    }

    private static var columnSpacing: CGFloat { 5 }

    public var body: some View {
        HStack(alignment: .top, spacing: columnWidth == nil ? 10 : Self.columnSpacing) {
            ForEach(choices, id: \.id) { choice in
                Button { selection = choice.id } label: {
                    VStack(spacing: 4) {
                        Image(nsImage: choice.image)
                            .frame(width: 56, height: 34)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.85)))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(choice.id == selection ? Color.accentColor : Color.clear, lineWidth: 2))
                        Text(choice.title).font(.caption)
                            .foregroundStyle(choice.id == selection ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(columnWidth == nil ? 1 : 0.75)
                    }
                    .frame(width: columnWidth)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.title)
                .accessibilityAddTraits(choice.id == selection ? .isSelected : [])
            }
        }
    }
}

/// The foot of every Menumon menu: Preferences… (⌘,), then Quit (⌘Q).
/// Replaces `SettingsMenu.addFooter`.
public enum PreferencesMenu {
    public static let title = "Preferences…"

    public static func addFooter(to menu: NSMenu, appName: String, open: @escaping () -> Void) {
        if menu.numberOfItems > 0, menu.items.last?.isSeparatorItem == false { menu.addItem(.separator()) }
        menu.addItem(item(open: open))
        let quit = NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    /// Preferences… on its own, for a menu that builds its own foot.
    public static func item(open: @escaping () -> Void) -> NSMenuItem {
        let target = ClosureTarget(open)
        let item = NSMenuItem(title: title, action: #selector(ClosureTarget.fire), keyEquivalent: ",")
        item.target = target
        item.representedObject = target   // NSMenuItem.target is weak; this keeps it alive
        return item
    }

    private final class ClosureTarget: NSObject {
        private let action: () -> Void
        init(_ action: @escaping () -> Void) { self.action = action }
        @objc func fire() { action() }
    }
}
