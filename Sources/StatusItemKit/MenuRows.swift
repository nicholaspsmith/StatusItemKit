// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

// The menu rows every Menumon app shares (from Panes's MenuRows):
//
// - Clicking an option leaves the menu open (`KeepOpenMenu`), except Quit and
//   items whose title ends in "…" (they open a window or a dialog, and an
//   alert cannot run while a menu tracks).
// - A heading folds a section away (`FoldingSection`, `FoldHeadingRow`): its
//   chevron points down while folded, up while open.
// - A row you cannot click looks like one (`InfoMenuItem`): disabled, grey,
//   whether it is there when the menu opens or inserted later.

// MARK: - Read-only rows

/// A read-only menu row: stats, status lines, notes. Disabled by hand, not
/// left to AppKit's validation, which only runs as the menu opens: a row
/// inserted while it tracks (a section unfolding) would otherwise draw in full
/// label colour and look clickable.
public enum InfoMenuItem {
    public static func make(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// Disables every item in `items` that does nothing when clicked (no
    /// action, no submenu, no view), as AppKit's validation would.
    static func disableInert(_ items: [NSMenuItem]) {
        for item in items where !item.isSeparatorItem && item.action == nil && item.submenu == nil && item.view == nil {
            item.isEnabled = false
        }
    }
}

// MARK: - Base row

/// A view-based menu row: clicking it does not close the menu. AppKit draws
/// nothing for a view item, so this paints the native look itself (the
/// `.selection` material `ToggleMenuItem` uses, at the native inset and
/// radius) and takes the click, Return, Enter or Space.
open class MenuItemRow: NSView {
    public static let metrics = ToggleMenuMetrics.current
    /// Where a native key equivalent or submenu arrow ends, from the menu's
    /// right edge (Panes 1.1.1 menu, macOS 27).
    public static let trailingInset: CGFloat = 19
    /// Where native key-equivalent text ends: half a point further out than
    /// the arrow (Quit's ⌘Q, same capture).
    public static let keyTrailingInset: CGFloat = 18.5

    private let selection = NSVisualEffectView()

    public init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.metrics.height))
        // The menu widens its item views to its own width.
        autoresizingMask = [.width]
        selection.material = .selection
        selection.state = .active
        selection.isEmphasized = true
        selection.blendingMode = .behindWindow
        selection.maskImage = Self.roundedMask(radius: Self.metrics.highlightRadius)
        selection.frame = Self.metrics.highlightRect(in: bounds)
        selection.autoresizingMask = [.width]
        selection.isHidden = true
        addSubview(selection)
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// What a click (or Return) does. The row is disabled with its item.
    open func press() {}

    public var isRowEnabled: Bool { enclosingMenuItem?.isEnabled ?? true }
    public var isRowHighlighted: Bool { isRowEnabled && enclosingMenuItem?.isHighlighted == true }
    public var textColor: NSColor {
        !isRowEnabled ? .disabledControlTextColor : isRowHighlighted ? .selectedMenuItemTextColor : .labelColor
    }
    public var secondaryColor: NSColor {
        !isRowEnabled ? .disabledControlTextColor : isRowHighlighted ? .selectedMenuItemTextColor : .secondaryLabelColor
    }

    /// Recolour the row's own content for the highlight; called before each draw.
    open func updateColors() {}

    // The menu marks the row for display when its highlight changes.
    open override func viewWillDraw() {
        selection.isHidden = !isRowHighlighted
        updateColors()
        super.viewWillDraw()
    }

    // MARK: Mouse

    // Take the first click though the menu window is not key, and take the
    // release: a view item that handles the mouse itself keeps the menu up.
    open override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    // The whole row takes the mouse, not the labels in it.
    open override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    open override func mouseDown(with event: NSEvent) {}
    open override func mouseUp(with event: NSEvent) {
        guard isRowEnabled, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        press()
    }

    // MARK: Keyboard (as ToggleMenuItemView)

    // Arrow keys moving the highlight onto a view item ask whether it takes
    // first responder; say yes only then (not while the menu is opening).
    open override var acceptsFirstResponder: Bool {
        NSApp.currentEvent?.type == .keyDown && window?.isVisible == true
    }

    open override func keyDown(with event: NSEvent) {
        if isRowEnabled, enclosingMenuItem?.isHighlighted == true,
           ToggleMenuKeys.toggles(keyCode: event.keyCode, modifiers: event.modifierFlags) {
            press()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: Accessibility

    open override func isAccessibilityElement() -> Bool { true }
    open override func isAccessibilityEnabled() -> Bool { isRowEnabled }
    open override func accessibilityPerformPress() -> Bool {
        guard isRowEnabled else { return false }
        press()
        return true
    }

    public static func roundedMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

// MARK: - Fold heading

/// A section heading that folds the rows below it away: its title, an
/// optional small tag (a display's "HDMI"), and a chevron that points down
/// while folded and up while open.
public final class FoldHeadingRow: MenuItemRow {
    public var onClick: (() -> Void)?

    public var expanded: Bool {
        didSet { if expanded != oldValue { updateChevron(animated: true) } }
    }

    private let label = NSTextField(labelWithString: "")
    private let tagLabel = NSTextField(labelWithString: "")
    private let chevron = NSImageView()
    private let title: String

    /// `width` only seeds the frame: the row stretches to the menu's width.
    public init(title: String, tag: String? = nil, expanded: Bool, width: CGFloat = 240) {
        self.title = title
        self.expanded = expanded
        super.init(width: width)
        label.font = .menuFont(ofSize: 0)
        label.lineBreakMode = .byTruncatingTail
        label.stringValue = title
        tagLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        tagLabel.stringValue = tag ?? ""
        tagLabel.isHidden = tag == nil
        chevron.symbolConfiguration = .init(pointSize: 12, weight: .semibold)
        updateChevron(animated: false)

        for view in [label, tagLabel, chevron] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.metrics.titleX),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            tagLabel.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            tagLabel.firstBaselineAnchor.constraint(equalTo: label.firstBaselineAnchor),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.trailingInset),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.leadingAnchor.constraint(greaterThanOrEqualTo: tagLabel.trailingAnchor, constant: 8),
        ])
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func press() { onClick?() }

    public override func updateColors() {
        label.textColor = textColor
        tagLabel.textColor = isRowHighlighted ? .selectedMenuItemTextColor : .tertiaryLabelColor
        chevron.contentTintColor = secondaryColor
    }

    /// The SF Symbol the chevron shows: down while folded, up while open.
    public static func chevronSymbol(expanded: Bool) -> String { expanded ? "chevron.up" : "chevron.down" }

    private func updateChevron(animated: Bool) {
        guard let image = NSImage(systemSymbolName: Self.chevronSymbol(expanded: expanded),
                                  accessibilityDescription: nil) else { return }
        if animated, #available(macOS 14.0, *) {
            chevron.setSymbolImage(image, contentTransition: .replace.downUp)
        } else {
            chevron.image = image
        }
        needsDisplay = true
    }

    public override func accessibilityRole() -> NSAccessibility.Role? { .disclosureTriangle }
    public override func accessibilityLabel() -> String? { title }
    public override func accessibilityValue() -> Any? { NSNumber(value: expanded ? 1 : 0) }
}

/// A folding section of a menu: a `FoldHeadingRow` with its rows below it
/// while open. `key` remembers the state between openings (under
/// `menuSection.<key>.expanded`); without one the section starts as
/// `defaultExpanded` every time.
public enum FoldingSection {
    public static func defaultsKey(_ key: String) -> String { "menuSection.\(key).expanded" }

    @discardableResult
    public static func add(title: String, tag: String? = nil, key: String? = nil, defaultExpanded: Bool = false,
                           defaults: UserDefaults = .standard,
                           items: [NSMenuItem], to menu: NSMenu) -> FoldHeadingRow {
        KeepOpenMenu.apply(to: items)
        InfoMenuItem.disableInert(items)
        let storeKey = key.map(defaultsKey)
        let expanded = storeKey.map { defaults.object(forKey: $0) as? Bool ?? defaultExpanded } ?? defaultExpanded
        let header = NSMenuItem()
        let row = FoldHeadingRow(title: title, tag: tag, expanded: expanded)
        row.onClick = { [weak menu, weak header, weak row] in
            guard let menu, let header, let row else { return }
            row.expanded.toggle()
            if let storeKey { defaults.set(row.expanded, forKey: storeKey) }
            if row.expanded {
                let at = menu.index(of: header) + 1
                for (i, item) in items.enumerated() { menu.insertItem(item, at: at + i) }
            } else {
                for item in items where item.menu === menu { menu.removeItem(item) }
            }
        }
        header.view = row
        // AppKit lays the menu out around whether any item has a state: with
        // none it drops the checkmark column and the native titles move left
        // of this row's. Saying `.on` keeps the column, as ToggleMenuItem
        // does; AppKit draws nothing for a view item's state.
        header.state = .on
        menu.addItem(header)
        if expanded { items.forEach(menu.addItem) }
        return row
    }
}

// MARK: - Keep-open action rows

/// An ordinary action item drawn as a view so it keeps the menu open: its
/// tick, title and key equivalent where AppKit would draw them. Clicking it
/// sends the item's action to its target, with the item as sender, as AppKit
/// would; then `KeepOpenMenu.didPerform` brings the open menu up to date.
public final class KeepOpenMenuRow: MenuItemRow {
    private let content = ContentView()
    private var font: NSFont { .menuFont(ofSize: 0) }

    public init(item: NSMenuItem) {
        let font = NSFont.menuFont(ofSize: 0)
        let titleWidth = (item.title as NSString).size(withAttributes: [.font: font]).width
        let keyWidth = Self.keyText(of: item).map { ($0 as NSString).size(withAttributes: [.font: font]).width + 24 } ?? 0
        super.init(width: Self.width(titleWidth: titleWidth, imageWidth: item.image?.size.width, keyWidth: keyWidth))
        content.owner = self
        content.frame = bounds
        content.autoresizingMask = [.width]
        addSubview(content)
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The row's width: the title, the item's image in front of it (drawn
    /// with a 6 pt gap) and the key equivalent, between the native insets.
    static func width(titleWidth: CGFloat, imageWidth: CGFloat?, keyWidth: CGFloat) -> CGFloat {
        ceil(metrics.titleX + (imageWidth.map { $0 + 6 } ?? 0) + titleWidth + keyWidth + trailingInset)
    }

    public override func press() {
        guard let item = enclosingMenuItem, let action = item.action else { return }
        NSApp.sendAction(action, to: item.target, from: item)
        KeepOpenMenu.didPerform(item)
    }

    public override func updateColors() { content.needsDisplay = true }

    public static func keyText(of item: NSMenuItem) -> String? {
        guard !item.keyEquivalent.isEmpty else { return nil }
        let m = item.keyEquivalentModifierMask
        return MenuShortcutText.text(key: item.keyEquivalent, control: m.contains(.control), option: m.contains(.option),
                                     shift: m.contains(.shift), command: m.contains(.command))
    }

    fileprivate func drawContent(in bounds: NSRect) {
        guard let item = enclosingMenuItem else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let height = (item.title as NSString).size(withAttributes: attrs).height
        let y = floor((bounds.height - height) / 2)
        var x = Self.metrics.titleX
        if let image = item.image {
            let size = image.size
            image.draw(in: NSRect(x: x, y: round((bounds.height - size.height) / 2), width: size.width, height: size.height))
            x += size.width + 6
        }
        (item.title as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

        if let key = Self.keyText(of: item) {
            let keyAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: secondaryColor]
            let w = (key as NSString).size(withAttributes: keyAttrs).width
            (key as NSString).draw(at: NSPoint(x: bounds.maxX - Self.keyTrailingInset - w, y: y), withAttributes: keyAttrs)
        }
        if item.state == .on, let check = Self.checkmark(font: font, color: textColor) {
            let cy = round((bounds.height - check.size.height) / 2)
            check.draw(in: NSRect(x: round(Self.metrics.checkCenterX - check.size.width / 2), y: cy,
                                  width: check.size.width, height: check.size.height))
        }
    }

    /// The checkmark macOS draws in the state column, as ToggleMenuItemView
    /// draws it: `checkmark`, bold, filled with the text colour.
    public static func checkmark(font: NSFont, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: ToggleMenuMetrics.checkmarkPointSize(menuFontSize: font.pointSize),
                                                 weight: .bold)
        guard let symbol = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        return NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            color.set()
            rect.fill(using: .sourceIn)
            return true
        }
    }

    private final class ContentView: NSView {
        weak var owner: KeepOpenMenuRow?
        override func draw(_ dirtyRect: NSRect) { owner?.drawContent(in: bounds) }
    }

    public override func accessibilityRole() -> NSAccessibility.Role? { .menuItem }
    public override func accessibilityLabel() -> String? { enclosingMenuItem?.title }
}

/// Turns a menu's action items into `KeepOpenMenuRow`s, so clicking one
/// leaves the menu up: every item but Quit and the "…" ones.
public enum KeepOpenMenu {
    /// Whether clicking an item titled `title` leaves the menu open.
    public static func keepsMenuOpen(title: String, isQuit: Bool) -> Bool {
        !isQuit && !title.hasSuffix("…") && !title.hasSuffix("...")
    }

    /// Every eligible item in `items` and in their submenus.
    public static func apply(to items: [NSMenuItem]) {
        for item in items {
            if let sub = item.submenu { apply(to: sub.items); continue }
            guard item.view == nil, !item.isSeparatorItem, let action = item.action,
                  keepsMenuOpen(title: item.title, isQuit: action == #selector(NSApplication.terminate(_:)))
            else { continue }
            item.view = KeepOpenMenuRow(item: item)
        }
    }

    /// Marks `items` as a pick-one set (a mode, an icon, a colour): clicking
    /// one moves the tick to it while the menu stays open, as reopening the
    /// menu would. Items not in a set keep whatever state their action gives
    /// them, so a toggle's action sets `sender.state` itself.
    public static func pickOne(_ items: [NSMenuItem]) {
        let group = PickOneGroup(items)
        for item in items { groups.setObject(group, forKey: item) }
    }

    /// Brings the open menu up to date after `item` was clicked: moves a
    /// pick-one set's tick, then redraws the rows.
    public static func didPerform(_ item: NSMenuItem) {
        if let group = groups.object(forKey: item) {
            for other in group.items { other.state = other === item ? .on : .off }
        }
        for row in (item.menu?.items ?? []).compactMap({ $0.view as? KeepOpenMenuRow }) { row.updateColors() }
    }

    private final class PickOneGroup {
        private let refs: [Weak]
        var items: [NSMenuItem] { refs.compactMap(\.item) }
        init(_ items: [NSMenuItem]) { refs = items.map(Weak.init) }
        private final class Weak { weak var item: NSMenuItem?; init(_ i: NSMenuItem) { item = i } }
    }
    private static let groups = NSMapTable<NSMenuItem, PickOneGroup>.weakToStrongObjects()
}

/// A menu item's key equivalent as the menu shows it: the modifiers in
/// macOS's order (⌃⌥⇧⌘), then the key, with arrows, function and editing
/// keys as their glyphs and letters in capitals.
public enum MenuShortcutText {
    public static func text(key: String, control: Bool = false, option: Bool = false,
                            shift: Bool = false, command: Bool = false) -> String? {
        guard let scalar = key.unicodeScalars.first, key.unicodeScalars.count == 1 else { return nil }
        let name = glyphs[scalar.value] ?? key.uppercased()
        return (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + name
    }

    private static let glyphs: [UInt32: String] = {
        var g: [UInt32: String] = [
            0xF700: "↑", 0xF701: "↓", 0xF702: "←", 0xF703: "→",
            0xF728: "⌦", 0xF729: "↖", 0xF72B: "↘", 0xF72C: "⇞", 0xF72D: "⇟",
            0x08: "⌫", 0x7F: "⌫", 0x0D: "↩", 0x03: "⌤", 0x09: "⇥", 0x1B: "⎋", 0x20: "Space",
        ]
        for n in 1...12 { g[0xF703 + UInt32(n)] = "F\(n)" }
        return g
    }()
}
