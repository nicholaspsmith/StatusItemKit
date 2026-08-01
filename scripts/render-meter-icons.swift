import AppKit

/// Renders every `MeterIcon` style across the 0...1 range, in both menu-bar
/// appearances, to a PNG for the README. Run via `scripts/render-meter-icons.sh`.
@main
struct RenderMeterIcons {
    static let fractions: [CGFloat] = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
    static let styles: [(String, (CGFloat, NSColor) -> NSImage)] = [
        ("gauge", { MeterIcon.gauge(fraction: $0, color: $1) }),
        ("arc", { MeterIcon.arc(fraction: $0, color: $1) }),
        ("pie", { MeterIcon.pie(fraction: $0, color: $1) }),
        ("wedge", { MeterIcon.wedge(fraction: $0, color: $1) }),
    ]

    static let pad: CGFloat = 22
    static let labelWidth: CGFloat = 74
    static let cell: CGFloat = 62
    static let header: CGFloat = 26
    static let glyph: CGFloat = 44

    static func main() {
        _ = NSApplication.shared

        let gridWidth = labelWidth + cell * CGFloat(fractions.count)
        let bandHeight = header + cell * CGFloat(styles.count)
        let width = pad * 2 + gridWidth
        let height = pad * 2 + 44 + (bandHeight + 40) * 2 + 96

        let sheet = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            NSGraphicsContext.current?.imageInterpolation = .high

            draw("MeterIcon styles", at: NSPoint(x: pad, y: pad - 4), size: 15,
                 color: .black, bold: true)
            draw("real 18pt menu-bar geometry, enlarged · fraction is the 0...1 value you pass",
                 at: NSPoint(x: pad, y: pad + 17), size: 11, color: .secondaryLabelColor)

            var y = pad + 44
            for band in [
                ("Light menu bar", NSColor(calibratedWhite: 0.93, alpha: 1), NSColor.black),
                ("Dark menu bar", NSColor(calibratedWhite: 0.16, alpha: 1), NSColor.white),
            ] {
                draw(band.0, at: NSPoint(x: pad, y: y), size: 12,
                     color: .secondaryLabelColor, bold: true)
                y += 20

                let rect = NSRect(x: pad, y: y, width: gridWidth, height: bandHeight)
                band.1.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()

                for (column, fraction) in fractions.enumerated() {
                    draw("\(Int(fraction * 100))%",
                         at: NSPoint(x: pad + labelWidth + cell * CGFloat(column), y: y + 7),
                         size: 10, color: band.2.withAlphaComponent(0.55), centeredIn: cell)
                }
                for (row, style) in styles.enumerated() {
                    let rowY = y + header + cell * CGFloat(row)
                    draw(style.0, at: NSPoint(x: pad + 12, y: rowY + cell / 2 - 7),
                         size: 12, color: band.2.withAlphaComponent(0.8))

                    for (column, fraction) in fractions.enumerated() {
                        let box = NSRect(
                            x: pad + labelWidth + cell * CGFloat(column) + (cell - glyph) / 2,
                            y: rowY + (cell - glyph) / 2,
                            width: glyph, height: glyph
                        )
                        drawUpright(style.1(fraction, band.2), in: box)
                    }
                }
                y += bandHeight + 20
            }

            draw("dot — a plain filled circle, no level (for discrete states)",
                 at: NSPoint(x: pad, y: y), size: 12, color: .secondaryLabelColor, bold: true)
            y += 20
            NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: pad, y: y, width: gridWidth, height: 56),
                xRadius: 10, yRadius: 10
            ).fill()
            for (i, color) in [NSColor.systemGreen, .systemOrange, .systemRed, .black].enumerated() {
                drawUpright(
                    MeterIcon.dot(color: color),
                    in: NSRect(x: pad + 20 + CGFloat(i) * 70, y: y + 12, width: 32, height: 32)
                )
            }
            return true
        }

        let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "meter-icons.png"
        guard
            let tiff = sheet.tiffRepresentation,
            let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("could not encode PNG\n".utf8))
            exit(1)
        }
        try! png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path) (\(Int(width))×\(Int(height)))")
    }

    /// The sheet is drawn flipped so text lays out top-down, but the icons are
    /// drawn in AppKit's usual bottom-up space. Without `respectFlipped` every
    /// glyph comes out mirrored vertically.
    static func drawUpright(_ image: NSImage, in box: NSRect) {
        image.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: nil)
    }

    static func draw(
        _ string: String, at point: NSPoint, size: CGFloat,
        color: NSColor, bold: Bool = false, centeredIn width: CGFloat? = nil
    ) {
        let font = bold
            ? NSFont.systemFont(ofSize: size, weight: .semibold)
            : NSFont.systemFont(ofSize: size)
        let text = NSAttributedString(
            string: string, attributes: [.font: font, .foregroundColor: color]
        )
        var origin = point
        if let width { origin.x += (width - text.size().width) / 2 }
        text.draw(at: origin)
    }
}
