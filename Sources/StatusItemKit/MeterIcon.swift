import AppKit

/// Custom-drawn, full-color (non-template) status-item glyphs. The pct-driven
/// meters (gauge/arc/pie/wedge) take a 0...1 fraction and a color; `dot` is a
/// plain filled circle for discrete-state apps. Ported from ProcessMonitor.
public enum MeterIcon {
    private static let side: CGFloat = 18

    private static func image(_ draw: @escaping (NSRect) -> Void) -> NSImage {
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            draw(rect); return true
        }
        img.isTemplate = false
        return img
    }

    private static func clamp(_ f: CGFloat) -> CGFloat { max(0, min(1, f)) }

    public static func dot(color: NSColor, diameter: CGFloat = 10) -> NSImage {
        let pad: CGFloat = 4
        let s = diameter + pad * 2
        let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
            color.set()
            NSBezierPath(ovalIn: NSRect(x: pad, y: pad, width: diameter, height: diameter)).fill()
            return true
        }
        img.isTemplate = false
        return img
    }

    /// Speedometer: needle angle proportional to fraction over a ~250° arc.
    public static func gauge(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY - 1.5)
            let radius: CGFloat = 6.5
            let startAngle: CGFloat = 215
            let endAngle: CGFloat = -35
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            track.lineWidth = 2.4
            track.lineCapStyle = .round
            color.withAlphaComponent(0.28).set()
            track.stroke()
            color.set()
            let needleAngle = (startAngle + (endAngle - startAngle) * frac) * .pi / 180
            let tip = NSPoint(x: center.x + cos(needleAngle) * (radius - 0.3),
                              y: center.y + sin(needleAngle) * (radius - 0.3))
            let needle = NSBezierPath()
            needle.move(to: center)
            needle.line(to: tip)
            needle.lineWidth = 2.8
            needle.lineCapStyle = .round
            needle.stroke()
            let hubR: CGFloat = 2.3
            NSBezierPath(ovalIn: NSRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)).fill()
        }
    }

    /// Radial arc: faint full track + bold arc filled to fraction.
    public static func arc(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY - 1.5)
            let radius: CGFloat = 6.5
            let startAngle: CGFloat = 215
            let endAngle: CGFloat = -35
            let lineWidth: CGFloat = 3.4
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            track.lineWidth = lineWidth
            track.lineCapStyle = .round
            color.withAlphaComponent(0.28).set()
            track.stroke()
            if frac > 0 {
                let fillEnd = startAngle + (endAngle - startAngle) * frac
                let fill = NSBezierPath()
                fill.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: fillEnd, clockwise: true)
                fill.lineWidth = lineWidth
                fill.lineCapStyle = .round
                color.set()
                fill.stroke()
            }
        }
    }

    /// Pie: full circle outline = cap; filled wedge = fraction in use.
    public static func pie(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7
            color.set()
            let circle = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            circle.lineWidth = 2.2
            circle.stroke()
            if frac > 0 {
                let wedgeRadius = radius - 1.4
                let wedge = NSBezierPath()
                wedge.move(to: center)
                wedge.appendArc(withCenter: center, radius: wedgeRadius, startAngle: 90, endAngle: 90 - 360 * frac, clockwise: true)
                wedge.close()
                wedge.fill()
            }
        }
    }

    /// Pie variant: solid wedge = fraction; faint full disk = remaining cap.
    public static func wedge(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7.5
            color.withAlphaComponent(0.28).set()
            NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
            if frac > 0 {
                let wedge = NSBezierPath()
                wedge.move(to: center)
                wedge.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * frac, clockwise: true)
                wedge.close()
                color.set()
                wedge.fill()
            }
        }
    }
}
