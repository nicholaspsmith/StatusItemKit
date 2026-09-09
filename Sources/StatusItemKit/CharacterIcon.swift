import AppKit

/// Status-item glyphs that look like an app's mascot and still carry its data.
///
/// Same 18pt non-template canvas as `MeterIcon`, so an app can offer a
/// character alongside the geometric meters and switching moves nothing. Each
/// silhouette is hand-drawn as a path — at this size a mascot has to become a
/// pictogram — and the number lives in something the character *does*: the
/// owl's eyes are pie meters, the chameleon changes colour and grows a tail per
/// connection, the octopus lights a tentacle per quarter, the key's rays light
/// with the backlight, the rocket's flame is the level, the raccoon's eyes
/// close when paused, the bin's lid lifts when active.
public enum CharacterIcon {
    /// A mid grey that survives both light and dark menu bars.
    static let body = NSColor(white: 0.62, alpha: 1)

    static func canvas(_ draw: @escaping (NSGraphicsContext) -> Void) -> NSImage {
        canvas(width: 18, height: 18, draw)
    }

    /// The menu bar gives an item 22pt of height and any width it asks for, so a
    /// character that needs the room (the owl's eyes, a wide battery) can take it.
    static func canvas(width: CGFloat, height: CGFloat, _ draw: @escaping (NSGraphicsContext) -> Void) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current else { return false }
            draw(ctx)
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Punch `path` out of what has been drawn so far.
    static func cut(_ ctx: NSGraphicsContext, _ path: NSBezierPath) {
        ctx.compositingOperation = .destinationOut
        path.fill()
        ctx.compositingOperation = .sourceOver
    }

    // OWL v2: squarer head using the full height, soft ear bumps, big eyes bulging past the sides.
    public static func owl(session: CGFloat, weekly: CGFloat, sessionColor: NSColor, weeklyColor: NSColor) -> NSImage {
        canvas(width: 32, height: 22) { ctx in
            body.set()
            // Head: a wide rounded block with soft ear tufts at the top corners.
            let head = NSBezierPath(roundedRect: NSRect(x: 3, y: 1, width: 26, height: 18), xRadius: 7, yRadius: 7)
            let ears = NSBezierPath()
            ears.move(to: NSPoint(x: 4, y: 13)); ears.curve(to: NSPoint(x: 5, y: 21.5), controlPoint1: NSPoint(x: 3.2, y: 17), controlPoint2: NSPoint(x: 3.6, y: 20.6)); ears.curve(to: NSPoint(x: 12, y: 17.5), controlPoint1: NSPoint(x: 7.4, y: 20.2), controlPoint2: NSPoint(x: 10, y: 18.6)); ears.close()
            ears.move(to: NSPoint(x: 28, y: 13)); ears.curve(to: NSPoint(x: 27, y: 21.5), controlPoint1: NSPoint(x: 28.8, y: 17), controlPoint2: NSPoint(x: 28.4, y: 20.6)); ears.curve(to: NSPoint(x: 20, y: 17.5), controlPoint1: NSPoint(x: 24.6, y: 20.2), controlPoint2: NSPoint(x: 22, y: 18.6)); ears.close()
            head.append(ears); head.windingRule = .nonZero
            head.fill()
            let beak = NSBezierPath()
            beak.move(to: NSPoint(x: 14.2, y: 6.8)); beak.line(to: NSPoint(x: 17.8, y: 6.8)); beak.line(to: NSPoint(x: 16, y: 3.4)); beak.close()
            cut(ctx, beak)
            // Eyes: two big pie meters on white, bulging past the sides of the head.
            for (cx, frac, color) in [(CGFloat(8.6), session, sessionColor), (CGFloat(23.4), weekly, weeklyColor)] {
                let c = NSPoint(x: cx, y: 11); let r: CGFloat = 7.4
                cut(ctx, NSBezierPath(ovalIn: NSRect(x: c.x - r - 1, y: c.y - r - 1, width: (r + 1) * 2, height: (r + 1) * 2)))
                body.set(); NSBezierPath(ovalIn: NSRect(x: c.x - r - 0.8, y: c.y - r - 0.8, width: (r + 0.8) * 2, height: (r + 0.8) * 2)).fill()
                NSColor.white.set(); NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).fill()
                let pie = NSBezierPath(); pie.move(to: c)
                pie.appendArc(withCenter: c, radius: r, startAngle: 90, endAngle: 90 - 360 * max(0.02, min(1, frac)), clockwise: true)
                pie.close(); color.set(); pie.fill()
            }
        }
    }

    /// A pale blue while nearly idle (below 15%), green from there, orange above
    /// 50%, red above 75%.
    public static func octopusColor(_ f: CGFloat) -> NSColor {
        if f > 0.75 { return .systemRed }
        if f > 0.5 { return .systemOrange }
        if f >= 0.15 { return .systemGreen }
        return NSColor(red: 0.62, green: 0.84, blue: 1.0, alpha: 1)
    }

    public static func octopus(fraction: CGFloat) -> NSImage {
        canvas { ctx in
            // One tentacle per quarter, but never none: the colour is part of the reading.
            let lit = max(1, Int((max(0, min(1, fraction)) * 4).rounded())); let col = Self.octopusColor(fraction)
            // tentacles first (behind the head): each a thick stroke from under the head, down, curling outward
            let arms: [(NSPoint, NSPoint, NSPoint, NSPoint)] = [   // start, c1, c2, end
                (NSPoint(x: 5.2, y: 8.5), NSPoint(x: 3.6, y: 5.5), NSPoint(x: 0.8, y: 2.6), NSPoint(x: 3.2, y: 2.4)),
                (NSPoint(x: 7.6, y: 8),   NSPoint(x: 7.2, y: 4.5), NSPoint(x: 4.6, y: 1.4), NSPoint(x: 6.6, y: 1.6)),
                (NSPoint(x: 10.4, y: 8),  NSPoint(x: 10.8, y: 4.5), NSPoint(x: 13.4, y: 1.4), NSPoint(x: 11.4, y: 1.6)),
                (NSPoint(x: 12.8, y: 8.5), NSPoint(x: 14.4, y: 5.5), NSPoint(x: 17.2, y: 2.6), NSPoint(x: 14.8, y: 2.4)),
            ]
            for (i, a) in arms.enumerated() {
                let t = NSBezierPath(); t.move(to: a.0); t.curve(to: a.3, controlPoint1: a.1, controlPoint2: a.2)
                t.lineWidth = 2.3; t.lineCapStyle = .round
                (i < lit ? col : body).set(); t.stroke()
            }
            // round head, wider than tall, sitting on the arms
            body.set(); NSBezierPath(ovalIn: NSRect(x: 2.8, y: 6.2, width: 12.4, height: 11.2)).fill()
            // eyes low on the head, like the emoji
            cut(ctx, NSBezierPath(ovalIn: NSRect(x: 5.7, y: 8.6, width: 2.6, height: 2.6)))
            cut(ctx, NSBezierPath(ovalIn: NSRect(x: 9.7, y: 8.6, width: 2.6, height: 2.6)))
        }
    }
    // CHAMELEON with 0/1/2 tails
    public static func chameleon(color: NSColor, tails: Int) -> NSImage {
        // 10% wider and a further 10% taller than the 18pt grid.
        canvas(width: 20, height: 22) { ctx in
            let scale = NSAffineTransform(); scale.scaleX(by: 20.0 / 18.0, yBy: 22.0 / 18.0); scale.concat()
            color.set()
            let p = NSBezierPath()
            p.move(to: NSPoint(x: 2, y: 7))
            p.curve(to: NSPoint(x: 8, y: 12.5), controlPoint1: NSPoint(x: 3, y: 10.5), controlPoint2: NSPoint(x: 5.5, y: 12.8))
            p.curve(to: NSPoint(x: 12.5, y: 10.2), controlPoint1: NSPoint(x: 10, y: 12.3), controlPoint2: NSPoint(x: 11.6, y: 11.5))
            p.curve(to: NSPoint(x: 13.2, y: 6.2), controlPoint1: NSPoint(x: 13.6, y: 9), controlPoint2: NSPoint(x: 13.8, y: 7.5))
            p.curve(to: NSPoint(x: 9, y: 4.2), controlPoint1: NSPoint(x: 12.4, y: 4.6), controlPoint2: NSPoint(x: 11.5, y: 4))
            p.curve(to: NSPoint(x: 2, y: 7), controlPoint1: NSPoint(x: 6.5, y: 4.2), controlPoint2: NSPoint(x: 3.5, y: 5))
            p.close(); p.fill()
            NSBezierPath(rect: NSRect(x: 6, y: 2.2, width: 1.8, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 10.4, y: 2.2, width: 1.8, height: 3)).fill()
            if tails >= 1 { let t = NSBezierPath(); t.appendArc(withCenter: NSPoint(x: 14.6, y: 4.2), radius: 2.0, startAngle: 110, endAngle: 410, clockwise: false); t.lineWidth = 1.5; t.lineCapStyle = .round; t.stroke() }
            if tails >= 2 { let t = NSBezierPath(); t.appendArc(withCenter: NSPoint(x: 15.6, y: 9.4), radius: 1.8, startAngle: 200, endAngle: 500, clockwise: false); t.lineWidth = 1.4; t.lineCapStyle = .round; t.stroke() }
            cut(ctx, NSBezierPath(ovalIn: NSRect(x: 4.6, y: 8.3, width: 2.2, height: 2.2)))
            color.set(); NSBezierPath(ovalIn: NSRect(x: 5.3, y: 9, width: 0.9, height: 0.9)).fill()
        }
    }
    // KEYLIGHT: a keycap with sunglasses; rays around it light up clockwise with the backlight level.
    public static func key(level: CGFloat, active: Bool = true) -> NSImage {
        // Drawn on the 18pt grid, shown 10% larger; the rays already reach the edges.
        canvas(width: 20, height: 20) { ctx in
            let scale = NSAffineTransform(); scale.scale(by: 20.0 / 18.0); scale.concat()
            let lit = active ? Int((max(0, min(1, level)) * 8).rounded()) : 0
            for i in 0..<8 {
                let a = CGFloat(90 - i * 45) * .pi / 180
                let r = NSBezierPath(); r.move(to: NSPoint(x: 9 + cos(a) * 6.3, y: 9 + sin(a) * 6.3)); r.line(to: NSPoint(x: 9 + cos(a) * 8.6, y: 9 + sin(a) * 8.6))
                r.lineWidth = 1.6; r.lineCapStyle = .round; (i < lit ? NSColor.systemYellow : NSColor(white: 0.62, alpha: 0.45)).set(); r.stroke()
            }
            (lit > 0 ? NSColor.systemYellow : body).set()
            NSBezierPath(roundedRect: NSRect(x: 4.2, y: 4.2, width: 9.6, height: 9.6), xRadius: 2, yRadius: 2).fill()
            // sunglasses
            let g = NSBezierPath(); g.appendOval(in: NSRect(x: 5.3, y: 8.2, width: 3.2, height: 2.4)); g.appendOval(in: NSRect(x: 9.5, y: 8.2, width: 3.2, height: 2.4)); g.appendRect(NSRect(x: 8.3, y: 9.1, width: 1.4, height: 0.7))
            cut(ctx, g)
            cut(ctx, NSBezierPath(rect: NSRect(x: 7, y: 6, width: 4, height: 0.9)))
        }
    }
    // BATTERY: a battery with a face; the body fills with the charge.
    public static func battery(charge: CGFloat, color: NSColor) -> NSImage {
        canvas { ctx in
            body.set()
            NSBezierPath(roundedRect: NSRect(x: 5, y: 1.5, width: 8, height: 14), xRadius: 1.6, yRadius: 1.6).fill()
            NSBezierPath(roundedRect: NSRect(x: 7.5, y: 15.3, width: 3, height: 1.6), xRadius: 0.6, yRadius: 0.6).fill()
            ctx.saveGraphicsState(); NSBezierPath(roundedRect: NSRect(x: 5, y: 1.5, width: 8, height: 14), xRadius: 1.6, yRadius: 1.6).addClip()
            color.set(); NSRect(x: 5, y: 1.5, width: 8, height: 14 * max(0, min(1, charge))).fill(); ctx.restoreGraphicsState()
            let face = NSBezierPath(); face.appendOval(in: NSRect(x: 6.6, y: 9.8, width: 1.7, height: 1.7)); face.appendOval(in: NSRect(x: 9.7, y: 9.8, width: 1.7, height: 1.7))
            let smile = NSBezierPath(); smile.appendArc(withCenter: NSPoint(x: 9, y: 8.2), radius: 1.9, startAngle: 200, endAngle: 340, clockwise: false); smile.lineWidth = 0.9; smile.lineCapStyle = .round
            cut(ctx, face); ctx.compositingOperation = .destinationOut; smile.stroke(); ctx.compositingOperation = .sourceOver
        }
    }
    // CAMCORDER: body + lens + viewfinder; a red light when recording.
    public static func camcorder(recording: Bool) -> NSImage {
        canvas { ctx in
            body.set()
            NSBezierPath(roundedRect: NSRect(x: 1.5, y: 4, width: 11, height: 8.5), xRadius: 2, yRadius: 2).fill()
            let lens = NSBezierPath(); lens.move(to: NSPoint(x: 12.5, y: 6.5)); lens.line(to: NSPoint(x: 17, y: 4.5)); lens.line(to: NSPoint(x: 17, y: 12)); lens.line(to: NSPoint(x: 12.5, y: 10)); lens.close(); lens.fill()
            NSBezierPath(roundedRect: NSRect(x: 3, y: 12.3, width: 6, height: 2.6), xRadius: 1, yRadius: 1).fill() // viewfinder/handle
            cut(ctx, NSBezierPath(ovalIn: NSRect(x: 4.2, y: 6.2, width: 4.2, height: 4.2)))
            body.set(); NSBezierPath(ovalIn: NSRect(x: 5.5, y: 7.5, width: 1.6, height: 1.6)).fill()
            if recording { NSColor.systemRed.set(); NSBezierPath(ovalIn: NSRect(x: 9.3, y: 9.6, width: 2.2, height: 2.2)).fill() }
        }
    }
    // ROCKET: the exhaust flame is the level bar; grey body when offline.
    public static func rocket(level: CGFloat, online: Bool) -> NSImage {
        canvas { ctx in
            (online ? body : NSColor(white: 0.45, alpha: 1)).set()
            let r = NSBezierPath(); r.move(to: NSPoint(x: 9, y: 17.5))
            r.curve(to: NSPoint(x: 12.2, y: 8), controlPoint1: NSPoint(x: 12, y: 15), controlPoint2: NSPoint(x: 12.2, y: 11))
            r.line(to: NSPoint(x: 12.2, y: 6.5)); r.line(to: NSPoint(x: 5.8, y: 6.5)); r.line(to: NSPoint(x: 5.8, y: 8))
            r.curve(to: NSPoint(x: 9, y: 17.5), controlPoint1: NSPoint(x: 5.8, y: 11), controlPoint2: NSPoint(x: 6, y: 15)); r.close(); r.fill()
            NSBezierPath(rect: NSRect(x: 3.2, y: 6.5, width: 3, height: 3.8)).fill(); NSBezierPath(rect: NSRect(x: 11.8, y: 6.5, width: 3, height: 3.8)).fill()
            cut(ctx, NSBezierPath(ovalIn: NSRect(x: 7.7, y: 10.6, width: 2.6, height: 2.6)))
            if online {
                let h = 1 + 5 * max(0, min(1, level))
                let f = NSBezierPath(); f.move(to: NSPoint(x: 6.6, y: 6.2)); f.line(to: NSPoint(x: 11.4, y: 6.2)); f.line(to: NSPoint(x: 9, y: 6.2 - h)); f.close()
                NSColor.systemOrange.set(); f.fill()
                let f2 = NSBezierPath(); f2.move(to: NSPoint(x: 7.8, y: 6.2)); f2.line(to: NSPoint(x: 10.2, y: 6.2)); f2.line(to: NSPoint(x: 9, y: 6.2 - h * 0.55)); f2.close()
                NSColor.systemYellow.set(); f2.fill()
            }
        }
    }
    // RACCOON head: mask band; eyes open when active, closed (lines) when paused.
    public static func raccoon(active: Bool) -> NSImage {
        canvas { ctx in
            body.set()
            let head = NSBezierPath(ovalIn: NSRect(x: 2.5, y: 2, width: 13, height: 12))
            head.appendOval(in: NSRect(x: 2, y: 10.5, width: 5, height: 6)); head.appendOval(in: NSRect(x: 11, y: 10.5, width: 5, height: 6)); head.windingRule = .nonZero; head.fill()
            // mask band across the eyes
            let mask = NSBezierPath(roundedRect: NSRect(x: 3.2, y: 6.8, width: 11.6, height: 4.2), xRadius: 2.1, yRadius: 2.1); cut(ctx, mask)
            NSColor(white: 0.3, alpha: 1).set(); mask.fill()
            if active {
                NSColor.systemRed.set()
                NSBezierPath(ovalIn: NSRect(x: 5, y: 7.7, width: 2.6, height: 2.6)).fill(); NSBezierPath(ovalIn: NSRect(x: 10.4, y: 7.7, width: 2.6, height: 2.6)).fill()
            } else {
                let z = NSBezierPath(); z.move(to: NSPoint(x: 5, y: 9)); z.line(to: NSPoint(x: 7.6, y: 9)); z.move(to: NSPoint(x: 10.4, y: 9)); z.line(to: NSPoint(x: 13, y: 9)); z.lineWidth = 1.2; z.lineCapStyle = .round; body.set(); z.stroke()
            }
            cut(ctx, NSBezierPath(ovalIn: NSRect(x: 8.1, y: 3.8, width: 1.8, height: 1.5)))
        }
    }
    // BIN: recycling bin; lid lifted when active (with a green recycle triangle), closed when paused.
    public static func bin(active: Bool) -> NSImage {
        canvas { ctx in
            (active ? NSColor.systemGreen : body).set()
            let b = NSBezierPath(); b.move(to: NSPoint(x: 4, y: 12)); b.line(to: NSPoint(x: 14, y: 12)); b.line(to: NSPoint(x: 13, y: 1.5)); b.line(to: NSPoint(x: 5, y: 1.5)); b.close(); b.fill()
            if active {
                // Lid flung back to the left; a little guy peeks out over the rim on the right.
                let lid = NSBezierPath(); lid.move(to: NSPoint(x: 2.2, y: 12.2)); lid.line(to: NSPoint(x: 8.6, y: 17.2)); lid.line(to: NSPoint(x: 9.4, y: 16)); lid.line(to: NSPoint(x: 3.2, y: 11.2)); lid.close(); lid.fill()
                body.set()
                NSBezierPath(ovalIn: NSRect(x: 8.6, y: 11.2, width: 5.6, height: 5.6)).fill()   // head
                NSBezierPath(rect: NSRect(x: 12.4, y: 10.6, width: 2.6, height: 2.2)).fill()      // an arm over the rim
                cut(ctx, NSBezierPath(ovalIn: NSRect(x: 9.8, y: 13.5, width: 1.3, height: 1.3)))
                cut(ctx, NSBezierPath(ovalIn: NSRect(x: 11.9, y: 13.5, width: 1.3, height: 1.3)))
            } else {
                NSBezierPath(roundedRect: NSRect(x: 3, y: 12.4, width: 12, height: 1.8), xRadius: 0.6, yRadius: 0.6).fill()
                NSBezierPath(roundedRect: NSRect(x: 7.5, y: 14, width: 3, height: 1.4), xRadius: 0.5, yRadius: 0.5).fill()
            }
            // ribs
            let ribs = NSBezierPath(); for x in [7.0, 9.0, 11.0] { ribs.move(to: NSPoint(x: x, y: 3.5)); ribs.line(to: NSPoint(x: x, y: 10)) }; ribs.lineWidth = 0.9
            ctx.compositingOperation = .destinationOut; ribs.stroke(); ctx.compositingOperation = .sourceOver
        }
    }}
