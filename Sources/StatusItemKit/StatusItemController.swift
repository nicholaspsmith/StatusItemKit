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
    private var timer: Timer?

    public var button: NSStatusBarButton? { statusItem.button }

    /// - Parameter autosaveName: names the slot macOS remembers the item's
    ///   position under (`NSStatusItem Preferred Position <name>` in the app's
    ///   defaults). Supply one when the position matters and you want it stable
    ///   and inspectable; leave nil for the system default, `Item-0`.
    public init(
        pollInterval: TimeInterval,
        onPoll: @escaping () -> Void,
        onBuildMenu: @escaping (NSMenu) -> Void,
        autosaveName: String? = nil
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let autosaveName { statusItem.autosaveName = autosaveName }
        self.pollInterval = pollInterval
        self.onPoll = onPoll
        self.onBuildMenu = onBuildMenu
        super.init()
        statusItem.button?.attributedTitle = NSAttributedString(string: "…")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
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

    /// Show or hide the item itself. Used by `YieldClient` so a menu-bar manager
    /// can borrow this app's slot during a peek without moving anything.
    public func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
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
