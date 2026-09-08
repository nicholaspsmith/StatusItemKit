import AppKit

/// Status-item glyphs that look like an app's mascot and still carry its data.
///
/// Same 18pt non-template canvas as `MeterIcon`, so an app can offer a
/// character alongside the geometric meters and switching moves nothing. Each
/// silhouette is hand-drawn as a path — at this size a mascot has to become a
/// pictogram — and the number lives in something the character *does*: the
/// owl's eyes are pie meters, the chameleon changes colour, the octopus fills
/// from the bottom.
public enum CharacterIcon {
    private static let side: CGFloat = 18
    /// A mid grey that survives both light and dark menu bars.
    private static let body = NSColor(white: 0.62, alpha: 1)

    private static func canvas(_ draw: @escaping (NSGraphicsContext) -> Void) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current else { return false }
            draw(ctx)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func clamp(_ f: CGFloat) -> CGFloat { max(0, min(1, f)) }

    /// An owl whose two eyes are pie meters — left for `session`, right for
    /// `weekly` (Claude Usage's two windows). Each eye takes its own colour so
    /// the usual severity escalation still shows.
    public static func owl(session: CGFloat, weekly: CGFloat, sessionColor: NSColor, weeklyColor: NSColor) -> NSImage {
        canvas { ctx in
            body.set()
            let head = NSBezierPath(ovalIn: NSRect(x: 2.5, y: 1.5, width: 13, height: 13))
            let tufts = NSBezierPath()
            tufts.move(to: NSPoint(x: 3.2, y: 11)); tufts.line(to: NSPoint(x: 2.2, y: 16.5)); tufts.line(to: NSPoint(x: 7.5, y: 14)); tufts.close()
            tufts.move(to: NSPoint(x: 14.8, y: 11)); tufts.line(to: NSPoint(x: 15.8, y: 16.5)); tufts.line(to: NSPoint(x: 10.5, y: 14)); tufts.close()
            head.append(tufts); head.windingRule = .nonZero
            head.fill()
            let beak = NSBezierPath()
            beak.move(to: NSPoint(x: 7.8, y: 6.2)); beak.line(to: NSPoint(x: 10.2, y: 6.2)); beak.line(to: NSPoint(x: 9, y: 3.8)); beak.close()
            ctx.compositingOperation = .destinationOut; beak.fill(); ctx.compositingOperation = .sourceOver
            for (cx, frac, color) in [(CGFloat(6), session, sessionColor), (CGFloat(12), weekly, weeklyColor)] {
                let c = NSPoint(x: cx, y: 8.6); let r: CGFloat = 2.7
                ctx.compositingOperation = .destinationOut
                NSBezierPath(ovalIn: NSRect(x: c.x - r - 0.6, y: c.y - r - 0.6, width: (r + 0.6) * 2, height: (r + 0.6) * 2)).fill()
                ctx.compositingOperation = .sourceOver
                NSColor(white: 1, alpha: 0.25).set()
                NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).fill()
                let pie = NSBezierPath(); pie.move(to: c)
                pie.appendArc(withCenter: c, radius: r, startAngle: 90, endAngle: 90 - 360 * max(0.02, clamp(frac)), clockwise: true)
                pie.close(); color.set(); pie.fill()
            }
        }
    }

    /// A chameleon in profile, painted the state colour. The metaphor is the
    /// data: it changes colour with the VPN.
    public static func chameleon(color: NSColor) -> NSImage {
        canvas { ctx in
            color.set()
            let p = NSBezierPath()
            p.move(to: NSPoint(x: 2, y: 7))
            p.curve(to: NSPoint(x: 8, y: 12.5), controlPoint1: NSPoint(x: 3, y: 10.5), controlPoint2: NSPoint(x: 5.5, y: 12.8))
            p.curve(to: NSPoint(x: 13.5, y: 10), controlPoint1: NSPoint(x: 10.5, y: 12.2), controlPoint2: NSPoint(x: 12.5, y: 11.5))
            p.curve(to: NSPoint(x: 15.5, y: 6.5), controlPoint1: NSPoint(x: 15, y: 9), controlPoint2: NSPoint(x: 15.8, y: 7.8))
            p.curve(to: NSPoint(x: 9, y: 4.2), controlPoint1: NSPoint(x: 14.5, y: 4.5), controlPoint2: NSPoint(x: 11.5, y: 4))
            p.curve(to: NSPoint(x: 2, y: 7), controlPoint1: NSPoint(x: 6.5, y: 4.2), controlPoint2: NSPoint(x: 3.5, y: 5))
            p.close(); p.fill()
            NSBezierPath(rect: NSRect(x: 6.2, y: 2.2, width: 1.8, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 11.2, y: 2.2, width: 1.8, height: 3)).fill()
            let tail = NSBezierPath()
            tail.appendArc(withCenter: NSPoint(x: 15.2, y: 3.8), radius: 2.2, startAngle: 100, endAngle: 400, clockwise: false)
            tail.lineWidth = 1.5; tail.lineCapStyle = .round; tail.stroke()
            ctx.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: NSRect(x: 4.6, y: 8.3, width: 2.2, height: 2.2)).fill()
            ctx.compositingOperation = .sourceOver
            color.set(); NSBezierPath(ovalIn: NSRect(x: 5.3, y: 9, width: 0.9, height: 0.9)).fill()
        }
    }

    /// An octopus that fills from the bottom with `fraction`, in `color`.
    public static func octopus(fraction: CGFloat, color: NSColor) -> NSImage {
        canvas { ctx in
            let shape = NSBezierPath(); shape.windingRule = .nonZero
            shape.appendOval(in: NSRect(x: 3.5, y: 7, width: 11, height: 10))
            shape.appendRect(NSRect(x: 4.5, y: 6.5, width: 9, height: 3.5))   // skirt the arms hang from
            for (x, dx) in [(CGFloat(4.0), CGFloat(-1.0)), (7.0, -0.3), (9.7, 0.3), (12.5, 1.0)] {
                let t = NSBezierPath()
                t.move(to: NSPoint(x: x, y: 9)); t.line(to: NSPoint(x: x + 2.2, y: 9))
                t.curve(to: NSPoint(x: x + 2.2 + dx, y: 2.5), controlPoint1: NSPoint(x: x + 2.2, y: 6), controlPoint2: NSPoint(x: x + 2.2 + dx, y: 4))
                t.curve(to: NSPoint(x: x + dx, y: 2.5), controlPoint1: NSPoint(x: x + 2.2 + dx, y: 1.6), controlPoint2: NSPoint(x: x + dx, y: 1.6))
                t.curve(to: NSPoint(x: x, y: 9), controlPoint1: NSPoint(x: x + dx, y: 4), controlPoint2: NSPoint(x: x, y: 6))
                t.close(); shape.append(t)
            }
            body.set(); shape.fill()
            ctx.saveGraphicsState(); shape.addClip()
            color.set(); NSRect(x: 0, y: 0, width: side, height: side * clamp(fraction)).fill()
            ctx.restoreGraphicsState()
            ctx.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: NSRect(x: 5.8, y: 10.5, width: 2.4, height: 2.4)).fill()
            NSBezierPath(ovalIn: NSRect(x: 9.8, y: 10.5, width: 2.4, height: 2.4)).fill()
            ctx.compositingOperation = .sourceOver
        }
    }
}
