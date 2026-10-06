// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// A checkbox menu item that keeps the menu open when it is ticked.
///
/// A standard `NSMenuItem` always closes its menu when clicked. That is right
/// for an action ("Open…", "Quit") and wrong for a checkbox: you tick one, the
/// menu vanishes, and you reopen it to tick the next. This item is view based,
/// so a click toggles the tick and calls `onToggle(newValue)` while the menu
/// stays up.
///
/// It is drawn to match a native checkbox item: the menu font, the native
/// checkmark in the native state column, the title at the same inset as the
/// ordinary items above and below, and the rounded selection highlight with
/// white text while the pointer is over it.
///
///     menu.addItem(ToggleMenuItem.make(title: "Show Sessions", isOn: shows) { on in
///         shows = on
///     })
///
/// Keyboard: with the item highlighted by the arrow keys, Return, Enter or
/// Space toggles it and the menu stays open.
public enum ToggleMenuItem {
    /// A keep-open checkbox item. Its `view` is a `ToggleMenuItemView`.
    ///
    /// - Parameters:
    ///   - isOn: the tick it starts with.
    ///   - enabled: a disabled item is greyed and ignores clicks.
    ///   - onToggle: called with the new value after every click, on the main
    ///     thread, while the menu is still open.
    public static func make(title: String,
                            isOn: Bool,
                            enabled: Bool = true,
                            toolTip: String? = nil,
                            onToggle: @escaping (Bool) -> Void) -> NSMenuItem {
        let view = ToggleMenuItemView(title: title, isOn: isOn, enabled: enabled, onToggle: onToggle)
        let item = NSMenuItem(title: title, action: #selector(ToggleMenuItemView.menuItemAction(_:)), keyEquivalent: "")
        // The item needs a target and an action: an autoenabling menu disables
        // (and so never highlights) an item without one. It is only reached if
        // AppKit itself performs the item, e.g. VoiceOver pressing the row.
        item.target = view
        item.view = view
        item.state = isOn ? .on : .off
        item.isEnabled = enabled
        item.toolTip = toolTip
        view.toolTip = toolTip
        return item
    }

    /// The toggle view behind an item made by `make`, if it is one.
    public static func view(of item: NSMenuItem) -> ToggleMenuItemView? {
        item.view as? ToggleMenuItemView
    }
}

/// Geometry of a native menu row, so a view item can line up with the
/// ordinary items around it. Pure values, unit-tested.
public struct ToggleMenuMetrics: Equatable {
    /// Row height.
    public var height: CGFloat
    /// Gap between the menu's edge and the selection highlight, each side.
    public var highlightInset: CGFloat
    /// Corner radius of the selection highlight.
    public var highlightRadius: CGFloat
    /// Centre of the checkmark glyph.
    public var checkCenterX: CGFloat
    /// Left edge of the title.
    public var titleX: CGFloat
    /// Room kept to the right of the title.
    public var trailing: CGFloat

    /// The metrics for the running macOS.
    public static var current: ToggleMenuMetrics {
        forMajorVersion(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    /// macOS 26 and later: measured from screenshots of native checkbox rows
    /// on macOS 27 (24 pt rows, highlight inset 5 pt with a 7 pt radius, tick
    /// centred at 18 pt, title at 30 pt). Earlier systems use the classic
    /// 22 pt row; those values are not measured on hardware.
    public static func forMajorVersion(_ major: Int) -> ToggleMenuMetrics {
        if major >= 26 {
            return ToggleMenuMetrics(height: 24, highlightInset: 5, highlightRadius: 7,
                                     checkCenterX: 18, titleX: 30, trailing: 20)
        }
        return ToggleMenuMetrics(height: 22, highlightInset: 5, highlightRadius: 4,
                                 checkCenterX: 14, titleX: 22, trailing: 20)
    }

    /// The selection highlight inside a row of `bounds`.
    public func highlightRect(in bounds: NSRect) -> NSRect {
        NSRect(x: bounds.minX + highlightInset, y: bounds.minY,
               width: max(0, bounds.width - highlightInset * 2), height: bounds.height)
    }

    /// The checkmark's point size beside menu text of `menuFontSize`
    /// (10.5 pt beside the standard 13 pt).
    public static func checkmarkPointSize(menuFontSize: CGFloat) -> CGFloat {
        (menuFontSize * 10.5 / 13 * 2).rounded() / 2
    }

    /// The width a row needs to show `titleWidth` of text without clipping.
    public func width(forTitleWidth titleWidth: CGFloat) -> CGFloat {
        ceil(titleX + titleWidth + trailing)
    }
}

/// The view behind `ToggleMenuItem`. Public so an app can change its tick or
/// title in place while the menu is open (`isOn`, `title`).
public final class ToggleMenuItemView: NSView, NSMenuItemValidation {
    public var title: String { didSet { needsDisplay = true; enclosingMenuItem?.title = title } }
    public var isOn: Bool { didSet { needsDisplay = true; enclosingMenuItem?.state = isOn ? .on : .off } }
    public var isEnabled: Bool { didSet { needsDisplay = true; enclosingMenuItem?.isEnabled = isEnabled } }
    private let onToggle: (Bool) -> Void
    private let metrics = ToggleMenuMetrics.current
    /// The selection highlight: the same vibrant `.selection` material a native
    /// row uses, so it blends with the menu exactly as theirs does (a flat
    /// accent fill reads a shade darker over a translucent menu).
    private let selection = NSVisualEffectView()
    /// Tick and title, drawn above the highlight.
    private let content = ContentView()

    private var font: NSFont { NSFont.menuFont(ofSize: 0) }

    init(title: String, isOn: Bool, enabled: Bool, onToggle: @escaping (Bool) -> Void) {
        self.title = title
        self.isOn = isOn
        self.isEnabled = enabled
        self.onToggle = onToggle
        let titleWidth = (title as NSString).size(withAttributes: [.font: NSFont.menuFont(ofSize: 0)]).width
        super.init(frame: NSRect(x: 0, y: 0, width: metrics.width(forTitleWidth: titleWidth), height: metrics.height))
        autoresizingMask = .width

        selection.material = .selection
        selection.state = .active
        selection.isEmphasized = true
        selection.blendingMode = .behindWindow
        selection.maskImage = Self.roundedMask(radius: metrics.highlightRadius)
        selection.frame = metrics.highlightRect(in: bounds)
        selection.autoresizingMask = .width
        selection.isHidden = true
        addSubview(selection)

        content.owner = self
        content.frame = bounds
        content.autoresizingMask = .width
        addSubview(content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Toggling

    /// Flip the tick and report it, as a click does.
    public func toggle() {
        guard isEnabled else { return }
        isOn.toggle()
        onToggle(isOn)
    }

    @objc func menuItemAction(_ sender: Any?) { toggle() }

    // An autoenabling menu asks the target; answer with our own enabled flag.
    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool { isEnabled }

    // Accept the first click even though the menu window is not key, and take
    // the release: a view item that handles the mouse itself keeps the menu up.
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    // The whole row takes the mouse, not the highlight or text layers in it.
    public override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    public override func mouseDown(with event: NSEvent) {}
    public override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        toggle()
    }

    // Keyboard. Return on a highlighted view item does nothing by default:
    // the menu neither performs the item nor closes. But when the arrow keys
    // move the highlight onto a view item, menu tracking asks the view whether
    // it accepts first responder and, if it does, routes the keys to it. So
    // accept only then (a key press, menu already on screen — not while the
    // menu is being opened, which would highlight the first toggle at once),
    // take Return, Enter and Space, and pass everything else on so the arrows
    // still move the highlight and Escape still closes the menu.
    public override var acceptsFirstResponder: Bool {
        NSApp.currentEvent?.type == .keyDown && window?.isVisible == true
    }

    public override func keyDown(with event: NSEvent) {
        if enclosingMenuItem?.isHighlighted == true,
           ToggleMenuKeys.toggles(keyCode: event.keyCode, modifiers: event.modifierFlags) {
            toggle()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: Drawing

    private var isHighlighted: Bool { isEnabled && enclosingMenuItem?.isHighlighted == true }

    // The menu marks the row for display when its highlight changes.
    public override func viewWillDraw() {
        selection.isHidden = !isHighlighted
        content.needsDisplay = true
        super.viewWillDraw()
    }

    fileprivate func drawContent(in bounds: NSRect) {
        let highlighted = isHighlighted
        let color: NSColor = !isEnabled ? .disabledControlTextColor
            : highlighted ? .selectedMenuItemTextColor : .labelColor

        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let textHeight = (title as NSString).size(withAttributes: attrs).height
        let textY = floor((bounds.height - textHeight) / 2)
        (title as NSString).draw(at: NSPoint(x: metrics.titleX, y: textY), withAttributes: attrs)

        if isOn, let check = Self.checkmark(font: font, color: color) {
            let y = round((bounds.height - check.size.height) / 2)
            check.draw(in: NSRect(x: round(metrics.checkCenterX - check.size.width / 2), y: y,
                                  width: check.size.width, height: check.size.height))
        }
    }

    private final class ContentView: NSView {
        weak var owner: ToggleMenuItemView?
        override func draw(_ dirtyRect: NSRect) { owner?.drawContent(in: bounds) }
    }

    /// A stretchable rounded-rectangle mask for the highlight.
    static func roundedMask(radius: CGFloat) -> NSImage {
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

    public override var isFlipped: Bool { false }

    /// The checkmark macOS draws in a menu's state column: the `checkmark`
    /// symbol, bold, at 10.5 pt beside 13 pt menu text. Filled with the text
    /// colour rather than palette-tinted, which drew it a shade too light.
    static func checkmark(font: NSFont, color: NSColor) -> NSImage? {
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

    // MARK: Accessibility

    public override func isAccessibilityElement() -> Bool { true }
    public override func accessibilityRole() -> NSAccessibility.Role? { .checkBox }
    public override func accessibilityLabel() -> String? { title }
    public override func accessibilityTitle() -> String? { title }
    public override func accessibilityValue() -> Any? { NSNumber(value: isOn ? 1 : 0) }
    public override func isAccessibilityEnabled() -> Bool { isEnabled }
    public override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        toggle()
        return true
    }
}

/// Which keys toggle a highlighted `ToggleMenuItem`. Pure, unit-tested.
public enum ToggleMenuKeys {
    public static let returnKey: UInt16 = 36
    public static let keypadEnter: UInt16 = 76
    public static let space: UInt16 = 49

    /// Return, keypad Enter or Space, with no command, option or control.
    public static func toggles(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let held = modifiers.intersection([.command, .option, .control])
        guard held.isEmpty else { return false }
        return keyCode == returnKey || keyCode == keypadEnter || keyCode == space
    }
}
