import AppKit

/// Owns an NSStatusItem, a polling timer, and lazy menu rebuilding. The host
/// supplies `onPoll` (gather state + call setTitle/setIcon) and `onBuildMenu`
/// (populate the menu when it opens). Rendering is funnelled through setTitle/
/// setIcon so the text and image paths stay mutually exclusive.
public final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let pollInterval: TimeInterval
    private let onPoll: () -> Void
    private let onBuildMenu: (NSMenu) -> Void
    private let onPrimaryClick: (() -> Void)?
    private let menu = NSMenu()
    private var timer: Timer?

    public var button: NSStatusBarButton? { statusItem.button }

    /// - Parameter autosaveName: names the slot macOS remembers the item's
    ///   position under (`NSStatusItem Preferred Position <name>` in the app's
    ///   defaults). Supply one when the position matters and you want it stable
    ///   and inspectable; leave nil for the system default, `Item-0`.
    /// - Parameter onPrimaryClick: when supplied, a left click runs this instead
    ///   of opening the menu, and the menu moves to right-click (and
    ///   control-click). Leave nil for the usual behaviour, where any click opens
    ///   the menu.
    public init(
        pollInterval: TimeInterval,
        onPoll: @escaping () -> Void,
        onBuildMenu: @escaping (NSMenu) -> Void,
        autosaveName: String? = nil,
        onPrimaryClick: (() -> Void)? = nil
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let autosaveName { statusItem.autosaveName = autosaveName }
        self.pollInterval = pollInterval
        self.onPoll = onPoll
        self.onBuildMenu = onBuildMenu
        self.onPrimaryClick = onPrimaryClick
        super.init()
        statusItem.button?.attributedTitle = NSAttributedString(string: "…")
        menu.delegate = self

        if onPrimaryClick == nil {
            statusItem.menu = menu
        } else {
            // Leaving `statusItem.menu` unset is what frees the left click: with
            // a menu attached, AppKit swallows the click to open it and the
            // button's action never runs.
            statusItem.button?.target = self
            statusItem.button?.action = #selector(handleClick)
            statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    // MARK: Click handling

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isSecondary {
            showMenu()
        } else {
            onPrimaryClick?()
        }
    }

    /// Attach the menu just long enough to pop it, then detach so the next left
    /// click still reaches the button's action.
    private func showMenu() {
        popUp(menu)
    }

    /// Drop an arbitrary menu under the item, anchored and highlighted the way a
    /// status menu should be. Useful when a left click should present something
    /// other than the item's own menu.
    public func popUp(_ menu: NSMenu) {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    public func start() {
        onPoll()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.onPoll()
        }
    }

    // MARK: Render funnel

    /// Text render path: clears any image, monospaced-digit font, red on warn.
    public func setTitle(_ text: String, warn: Bool) {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.imagePosition = .noImage
        button.contentTintColor = nil
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: warn ? NSColor.systemRed : NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            ]
        )
    }

    /// Icon render path: clears title + tint (icons are full-color non-template).
    public func setIcon(_ image: NSImage) {
        guard let button = statusItem.button else { return }
        button.attributedTitle = NSAttributedString(string: "")
        button.imagePosition = .imageOnly
        button.contentTintColor = nil
        button.image = image
    }

    /// Give up this item's width, or take it back. Used by `YieldClient` so a
    /// menu-bar manager can borrow the slot during a peek without moving
    /// anything.
    ///
    /// Deliberately *not* `isVisible = false`. Hiding an item makes macOS discard
    /// its remembered position outright — measured: four apps lost their
    /// `Preferred Position` keys across a single peek and came back at x≈-1200,
    /// inside the very block that was supposed to be hidden. Writing the saved
    /// value back before un-hiding does not help; it is cleared again. Shrinking
    /// to zero width frees essentially the same space while the item stays
    /// present, so its placement survives untouched.
    public func setVisible(_ visible: Bool) {
        statusItem.length = visible ? NSStatusItem.variableLength : 0
    }

    /// The item's width. A status item grows leftward — its right edge stays put
    /// — which is what lets a wide item push its left-hand neighbours off the
    /// display without disturbing anything to its right.
    public var length: CGFloat {
        get { statusItem.length }
        set { statusItem.length = newValue }
    }

    // MARK: Lazy menu rebuild

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        onBuildMenu(menu)
    }
}
