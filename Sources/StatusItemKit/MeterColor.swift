import AppKit

/// A named colour offered in the icon picker, and the hex round-trip used to
/// persist whatever the user lands on.
public struct MeterColor: Equatable, Sendable {
    public let name: String
    public let hex: String

    public init(name: String, hex: String) {
        self.name = name
        self.hex = hex
    }

    public var color: NSColor { MeterColor.color(fromHex: hex) ?? .systemGreen }

    /// The presets every app offers. Green heads the list because it is what
    /// the suite drew before any of this was configurable, so an app adopting
    /// the picker keeps the appearance it already had.
    public static let presets: [MeterColor] = [
        MeterColor(name: "Green",  hex: "#34C759"),
        MeterColor(name: "Purple", hex: "#B18EEE"),
        MeterColor(name: "Blue",   hex: "#0A84FF"),
        MeterColor(name: "Teal",   hex: "#40C8E0"),
        MeterColor(name: "Orange", hex: "#FF9F0A"),
        MeterColor(name: "Pink",   hex: "#FF6FB5"),
        MeterColor(name: "Grey",   hex: "#98989D"),
    ]

    // MARK: - Hex

    /// Parses `#RRGGBB` and `RRGGBB`. Colours are persisted as hex rather than
    /// archived NSColor: it survives across OS versions, is readable in
    /// `defaults read`, and is editable by hand when something goes wrong.
    public static func color(fromHex hex: String) -> NSColor? {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                       green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255,
                       alpha: 1)
    }

    public static func hex(from color: NSColor) -> String {
        // The panel hands back colours in whatever space the user picked in;
        // converting first keeps the round-trip stable instead of failing on a
        // catalog or greyscale colour.
        guard let rgb = color.usingColorSpace(.sRGB) else { return "#34C759" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// A filled circle for a menu item's image, so the swatch is visible next
    /// to its name rather than the name having to carry the whole meaning.
    public static func swatch(_ color: NSColor, diameter: CGFloat = 12) -> NSImage {
        let size = NSSize(width: diameter, height: diameter)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            ring.lineWidth = 1
            ring.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }
}
