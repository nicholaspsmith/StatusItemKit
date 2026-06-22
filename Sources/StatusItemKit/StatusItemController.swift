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

    public init(
        pollInterval: TimeInterval,
        onPoll: @escaping () -> Void,
        onBuildMenu: @escaping (NSMenu) -> Void
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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

    // MARK: Lazy menu rebuild

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        onBuildMenu(menu)
    }
}
