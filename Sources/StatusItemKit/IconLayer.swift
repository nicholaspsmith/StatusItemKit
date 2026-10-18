// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import QuartzCore

/// Shows a status button's icon on a CALayer of its own, so a new icon — an
/// animation frame — costs a layer swap instead of a redraw of the whole button
/// (measured 2026-10-15: 11% of a core at 24 fps through `button.image`, 0.35%
/// through the layer). The button keeps a transparent placeholder of the icon's
/// size, so the item's width and the menu's anchor are what they were. The layer
/// follows the button's bounds, its window's scale and its appearance (which
/// tints a template icon).
final class IconLayer {
    /// How often, and how many times, a refused icon is tried again while the
    /// button has no window yet.
    static let retryInterval: TimeInterval = 0.25
    static let retryLimit = 8

    private weak var button: NSButton?
    private let layer = CALayer()
    private let scaleOverride: (() -> CGFloat)?
    private var observers: [NSObjectProtocol] = []
    private var appearanceObservation: NSKeyValueObservation?
    private var placeholder: NSImage?
    private var image: NSImage?
    private var pending: NSImage?
    private var retries = 0
    /// The button's `wantsLayer` before the layer was attached, put back by `remove`.
    private var wantedLayer: Bool?

    init(button: NSButton, scale: (() -> CGFloat)? = nil) {
        self.button = button
        scaleOverride = scale
        layer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "hidden": NSNull()]
        layer.contentsGravity = .resize
        // Above anything AppKit adds to the button after us, such as its highlight.
        layer.zPosition = 1
    }

    deinit { remove() }

    /// Shows `image` on the layer and returns true. Returns false while the button
    /// has no window (the first icon, during launch): the caller then sets it the
    /// old way, and it is tried again every `retryInterval`, up to `retryLimit`.
    @discardableResult
    func show(_ image: NSImage) -> Bool {
        guard let button, button.window != nil else {
            pending = image
            scheduleRetry()
            return false
        }
        pending = nil
        retries = 0
        attach(to: button)
        if placeholder?.size != image.size || placeholder?.accessibilityDescription != image.accessibilityDescription
            || button.image !== placeholder {
            let fresh = IconBitmaps.placeholder(size: image.size, description: image.accessibilityDescription)
            placeholder = fresh
            button.image = fresh
        }
        self.image = image
        render()
        return true
    }

    /// Takes the layer off the button, clears the placeholder and leaves the button
    /// as layer-backed as it found it (the item shows text instead). `show` puts
    /// it back.
    func remove() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        appearanceObservation = nil
        layer.removeFromSuperlayer()
        layer.contents = nil
        if let button, let wantedLayer { button.wantsLayer = wantedLayer }
        wantedLayer = nil
        if let button, button.image === placeholder { button.image = nil }
        placeholder = nil
        image = nil
        pending = nil
    }

    // MARK: For tests

    var shownBitmap: CGImage? { layer.contents.map { $0 as! CGImage } }
    var shownScale: CGFloat { layer.contentsScale }
    var shownFrame: CGRect { layer.frame }
    var isShowing: Bool { layer.superlayer != nil && !layer.isHidden && layer.contents != nil }
    var zPosition: CGFloat { layer.zPosition }

    // MARK: Drawing

    /// The scale to draw for: the button's window's, else 2.
    private var scale: CGFloat { scaleOverride?() ?? button?.window?.backingScaleFactor ?? 2 }

    private func scheduleRetry() {
        guard retries < Self.retryLimit else { return }
        retries += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) { [weak self] in
            guard let self, let pending = self.pending else { return }
            self.show(pending)
        }
    }

    private func attach(to button: NSButton) {
        guard layer.superlayer == nil else { return }
        if wantedLayer == nil { wantedLayer = button.wantsLayer }
        button.wantsLayer = true
        button.layer?.addSublayer(layer)
        button.postsFrameChangedNotifications = true
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSView.frameDidChangeNotification, object: button,
                                            queue: nil) { [weak self] _ in self?.place() })
        if let window = button.window {
            for name in [NSWindow.didChangeBackingPropertiesNotification, NSWindow.didChangeScreenNotification] {
                observers.append(center.addObserver(forName: name, object: window, queue: nil) { [weak self] _ in
                    self?.render()
                })
            }
        }
        appearanceObservation = button.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.render() }
        }
    }

    /// Puts the icon's bitmap for the current scale and the bar's appearance on
    /// the layer, and places it.
    private func render() {
        guard let button, let image else { return }
        var tint: NSColor?
        if image.isTemplate {
            button.effectiveAppearance.performAsCurrentDrawingAppearance {
                tint = NSColor.labelColor.usingColorSpace(.sRGB)
            }
        }
        let scale = self.scale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contentsScale = scale
        layer.contents = IconBitmaps.bitmap(for: image, scale: scale, tint: tint, appearance: button.effectiveAppearance)
        place()
        CATransaction.commit()
    }

    /// Centres the layer in the button, on whole pixels; hides it when the item
    /// has no width (yielded to a menu-bar manager).
    private func place() {
        guard let button, let image else { return }
        let bounds = button.bounds, size = image.size, pixel = 1 / scale
        func snap(_ v: CGFloat) -> CGFloat { (v / pixel).rounded() * pixel }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = CGRect(x: snap((bounds.width - size.width) / 2), y: snap((bounds.height - size.height) / 2),
                             width: size.width, height: size.height)
        layer.isHidden = bounds.width < 1
        CATransaction.commit()
    }
}
