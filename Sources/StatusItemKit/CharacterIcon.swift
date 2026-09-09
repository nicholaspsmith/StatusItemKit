import AppKit

/// Status-item glyphs that look like an app's mascot and still carry its data.
///
/// Same 18pt non-template canvas as `MeterIcon`, so an app can offer a
/// character alongside the geometric meters and switching moves nothing. Each
/// silhouette is hand-drawn as a path — at this size a mascot has to become a
/// pictogram — and the number lives in something the character *does*: the
/// owl's eyes are pie meters, the chameleon changes colour and grows a tail per
/// connection, the octopus grows and heats from four green arms to eight red ones, the key's rays light
/// with the backlight, the Apollo's volume arc is the level, the raccoon's eyes
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

    static let eyelid = NSColor(red: 0.45, green: 0.28, blue: 0.14, alpha: 1)

    // OWL v2: squarer head using the full height, soft ear bumps, big eyes bulging past the sides.
    /// The owl is eyelid-brown all over. Each eye is a real eye: white, black pupil, and a brown eyelid that
    /// drops as usage rises — wide open at 0, half closed at 0.5, shut at 1.
    public static func owl(session: CGFloat, weekly: CGFloat) -> NSImage {
        canvas(width: 32, height: 22) { ctx in
            eyelid.set()
            // Head: a wide rounded block with soft ear tufts at the top corners.
            let head = NSBezierPath(roundedRect: NSRect(x: 3, y: 1, width: 26, height: 18), xRadius: 7, yRadius: 7)
            let ears = NSBezierPath()
            ears.move(to: NSPoint(x: 4, y: 13)); ears.curve(to: NSPoint(x: 5, y: 21.5), controlPoint1: NSPoint(x: 3.2, y: 17), controlPoint2: NSPoint(x: 3.6, y: 20.6)); ears.curve(to: NSPoint(x: 12, y: 17.5), controlPoint1: NSPoint(x: 7.4, y: 20.2), controlPoint2: NSPoint(x: 10, y: 18.6)); ears.close()
            ears.move(to: NSPoint(x: 28, y: 13)); ears.curve(to: NSPoint(x: 27, y: 21.5), controlPoint1: NSPoint(x: 28.8, y: 17), controlPoint2: NSPoint(x: 28.4, y: 20.6)); ears.curve(to: NSPoint(x: 20, y: 17.5), controlPoint1: NSPoint(x: 24.6, y: 20.2), controlPoint2: NSPoint(x: 22, y: 18.6)); ears.close()
            head.append(ears); head.windingRule = .nonZero
            head.fill()
            // Beak: a big black wedge, drawn before the eyes so they sit on top of it.
            let beak = NSBezierPath()
            beak.move(to: NSPoint(x: 12.6, y: 9.2)); beak.line(to: NSPoint(x: 19.4, y: 9.2)); beak.line(to: NSPoint(x: 16, y: 0.3)); beak.close()
            cut(ctx, beak); NSColor.black.set(); beak.fill()
            // Eyes: two big eyes bulging past the sides of the head.
            for (cx, frac) in [(CGFloat(8.6), session), (CGFloat(23.4), weekly)] {
                let c = NSPoint(x: cx, y: 11); let r: CGFloat = 7.4
                let closed = max(0, min(1, frac))
                cut(ctx, NSBezierPath(ovalIn: NSRect(x: c.x - r - 1, y: c.y - r - 1, width: (r + 1) * 2, height: (r + 1) * 2)))
                eyelid.set(); NSBezierPath(ovalIn: NSRect(x: c.x - r - 0.8, y: c.y - r - 0.8, width: (r + 0.8) * 2, height: (r + 0.8) * 2)).fill()
                let eye = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                // Tiredness: once the eye is less than three-quarters open the
                // white picks up a faint pink and short red veins appear, both
                // reddening as the lid comes down.
                let tired = max(0, min(1, (closed - 0.25) / 0.75))
                let pr: CGFloat = 3.1
                NSColor(red: 1, green: 1 - 0.18 * tired, blue: 1 - 0.18 * tired, alpha: 1).set(); eye.fill()
                if tired > 0 {
                    ctx.saveGraphicsState(); eye.addClip()
                    NSColor(red: 0.95, green: 0.12, blue: 0.12, alpha: 0.3 + 0.7 * tired).set()
                    // Veins run radially: one end near the pupil, the other near
                    // the rim, each with a slight bend, fanned across the lower
                    // half where the lid leaves them visible longest.
                    for (i, angle) in [CGFloat(200), 232, 262, 292, 322, 350].enumerated() {
                        let a = angle * .pi / 180, bend: CGFloat = i % 2 == 0 ? 0.9 : -0.9
                        let start = NSPoint(x: c.x + cos(a) * (pr + 0.6), y: c.y + sin(a) * (pr + 0.6))
                        let end = NSPoint(x: c.x + cos(a) * (r - 0.5), y: c.y + sin(a) * (r - 0.5))
                        let mid = NSPoint(x: (start.x + end.x) / 2 - sin(a) * bend, y: (start.y + end.y) / 2 + cos(a) * bend)
                        let v = NSBezierPath(); v.move(to: start)
                        v.curve(to: end, controlPoint1: mid, controlPoint2: mid)
                        v.lineWidth = 0.5; v.lineCapStyle = .round; v.stroke()
                    }
                    ctx.restoreGraphicsState()
                }
                // Pupil.
                NSColor.black.set(); NSBezierPath(ovalIn: NSRect(x: c.x - pr, y: c.y - pr, width: pr * 2, height: pr * 2)).fill()
                // Eyelid: brown, sliding down from the top by `closed` of the eye's height.
                ctx.saveGraphicsState()
                eye.addClip()
                let lidBottom = c.y + r - closed * r * 2
                eyelid.set()
                NSBezierPath(rect: NSRect(x: c.x - r - 1, y: lidBottom, width: r * 2 + 2, height: r * 2 + 1)).fill()
                if closed > 0.02 && closed < 0.98 {
                    let edge = NSBezierPath()
                    edge.move(to: NSPoint(x: c.x - r - 1, y: lidBottom)); edge.line(to: NSPoint(x: c.x + r + 1, y: lidBottom))
                    edge.lineWidth = 0.8; NSColor(red: 0.28, green: 0.16, blue: 0.07, alpha: 1).set(); edge.stroke()
                }
                ctx.restoreGraphicsState()
            }
        }
    }

    /// Which octopus stands for a load fraction: four green arms below a
    /// quarter, four yellow below half, eight orange below three quarters, and
    /// eight red above.
    public enum SeaStage: Int, CaseIterable, Sendable {
        case greenFour, yellowFour, orangeEight, redEight

        public var color: NSColor {
            switch self {
            case .greenFour: return .systemGreen
            case .yellowFour: return .systemYellow
            case .orangeEight: return .systemOrange
            case .redEight: return .systemRed
            }
        }
    }

    public static func seaStage(_ f: CGFloat) -> SeaStage {
        if f >= 0.75 { return .redEight }
        if f >= 0.5 { return .orangeEight }
        if f >= 0.25 { return .yellowFour }
        return .greenFour
    }

    // OCTOPUS: escalates by shape and colour. Every stage shares one 28x22
    // canvas so the bar never shifts as the load moves between stages.
    public static func octopus(fraction: CGFloat) -> NSImage {
        octopus(stage: seaStage(max(0, min(1, fraction))))
    }

    public static func octopus(stage: SeaStage) -> NSImage {
        canvas(width: 28, height: 22) { ctx in
            stage.color.set()
            switch stage {
            case .greenFour, .yellowFour:
                let t = NSAffineTransform(); t.translateX(by: 3, yBy: 0); t.scale(by: 22.0 / 18.0); t.concat()
                smallOctopus(ctx)
            case .orangeEight, .redEight:
                let t = NSAffineTransform(); t.translateX(by: 2, yBy: 0); t.scale(by: 22.0 / 18.0); t.concat()
                bigOctopus(ctx)
            }
        }
    }

    /// A thick, round-capped stroke through a cubic curve: one tentacle.
    private static func arm(_ a: NSPoint, _ c1: NSPoint, _ c2: NSPoint, _ b: NSPoint, width: CGFloat) {
        let t = NSBezierPath(); t.move(to: a); t.curve(to: b, controlPoint1: c1, controlPoint2: c2)
        t.lineWidth = width; t.lineCapStyle = .round; t.stroke()
    }

    private static func octopusHead(_ ctx: NSGraphicsContext) {
        // round head, wider than tall, sitting on the arms; eyes low like the emoji
        NSBezierPath(ovalIn: NSRect(x: 2.8, y: 6.2, width: 12.4, height: 11.2)).fill()
        cut(ctx, NSBezierPath(ovalIn: NSRect(x: 5.7, y: 8.6, width: 2.6, height: 2.6)))
        cut(ctx, NSBezierPath(ovalIn: NSRect(x: 9.7, y: 8.6, width: 2.6, height: 2.6)))
    }

    /// The original four-armed octopus.
    private static func smallOctopus(_ ctx: NSGraphicsContext) {
        arm(NSPoint(x: 5.2, y: 8.5), NSPoint(x: 3.6, y: 5.5), NSPoint(x: 0.8, y: 2.6), NSPoint(x: 3.2, y: 2.4), width: 2.3)
        arm(NSPoint(x: 7.6, y: 8), NSPoint(x: 7.2, y: 4.5), NSPoint(x: 4.6, y: 1.4), NSPoint(x: 6.6, y: 1.6), width: 2.3)
        arm(NSPoint(x: 10.4, y: 8), NSPoint(x: 10.8, y: 4.5), NSPoint(x: 13.4, y: 1.4), NSPoint(x: 11.4, y: 1.6), width: 2.3)
        arm(NSPoint(x: 12.8, y: 8.5), NSPoint(x: 14.4, y: 5.5), NSPoint(x: 17.2, y: 2.6), NSPoint(x: 14.8, y: 2.4), width: 2.3)
        octopusHead(ctx)
    }

    /// Eight arms fanned evenly under the head, the outer ones reaching wide.
    private static func bigOctopus(_ ctx: NSGraphicsContext) {
        let w: CGFloat = 1.6
        arm(NSPoint(x: 3.8, y: 9.5), NSPoint(x: 1.6, y: 8.6), NSPoint(x: -0.6, y: 6), NSPoint(x: 1, y: 4.4), width: w)
        arm(NSPoint(x: 5, y: 8.4), NSPoint(x: 3.4, y: 5.8), NSPoint(x: 1.2, y: 3), NSPoint(x: 3.2, y: 2.2), width: w)
        arm(NSPoint(x: 6.8, y: 7.8), NSPoint(x: 6, y: 5), NSPoint(x: 3.8, y: 1.6), NSPoint(x: 5.8, y: 1), width: w)
        arm(NSPoint(x: 8.4, y: 7.6), NSPoint(x: 8.2, y: 4.6), NSPoint(x: 6.8, y: 1.2), NSPoint(x: 8.2, y: 0.8), width: w)
        arm(NSPoint(x: 9.6, y: 7.6), NSPoint(x: 9.8, y: 4.6), NSPoint(x: 11.2, y: 1.2), NSPoint(x: 9.8, y: 0.8), width: w)
        arm(NSPoint(x: 11.2, y: 7.8), NSPoint(x: 12, y: 5), NSPoint(x: 14.2, y: 1.6), NSPoint(x: 12.2, y: 1), width: w)
        arm(NSPoint(x: 13, y: 8.4), NSPoint(x: 14.6, y: 5.8), NSPoint(x: 16.8, y: 3), NSPoint(x: 14.8, y: 2.2), width: w)
        arm(NSPoint(x: 14.2, y: 9.5), NSPoint(x: 16.4, y: 8.6), NSPoint(x: 18.6, y: 6), NSPoint(x: 17, y: 4.4), width: w)
        octopusHead(ctx)
    }

    // CHAMELEON
/// A chameleon climbing at an incline, painted the state colour. Its tail
    /// hangs down when Tailscale is connected; its tongue flicks out when
    /// Mullvad is.
    /// The chameleon's stick, and its colour when nothing is connected.
    static let stick = NSColor(red: 0.45, green: 0.28, blue: 0.14, alpha: 1)
    /// Its colour while Mullvad is up (#ddca01).
    static let mullvadYellow = NSColor(red: 0xdd / 255.0, green: 0xca / 255.0, blue: 0x01 / 255.0, alpha: 1)

    /// A chameleon hanging onto a brown stick. Brown like the stick when
    /// nothing is connected; green with its tail out for Tailscale; yellow
    /// with its tongue out for Mullvad; yellow with green splotches, tongue
    /// and tail when both are up. `alert` overrides the body colour for
    /// Mullvad's in-between states (connecting, blocked).
    public static func chameleon(tailscale: Bool, mullvad: Bool, alert: NSColor? = nil) -> NSImage {
        let color = alert ?? (mullvad ? mullvadYellow : tailscale ? NSColor.systemGreen : stick)
        return chameleon(color: color, tail: tailscale, tongue: mullvad, splotches: mullvad && tailscale)
    }

    public static func chameleon(color: NSColor, tail: Bool, tongue: Bool, splotches: Bool = false) -> NSImage {
            canvas(width: 30, height: 22) { ctx in
            // body on an 18-grid, tilted nose-up ~35° like it is climbing; room on the left for the tongue
            let t = NSAffineTransform(); t.translateX(by: 18, yBy: 13); t.rotate(byDegrees: -35); t.scale(by: 1.25); t.translateX(by: -9, yBy: -7.5); t.concat()
            // the stick it hangs from, under the feet, running the length of the body
            let branch = NSBezierPath(); branch.move(to: NSPoint(x: -0.5, y: 1.1)); branch.line(to: NSPoint(x: 15.5, y: 1.1))
            branch.lineWidth = 1.8; branch.lineCapStyle = .round; stick.set(); branch.stroke()
            if tongue {
                // a long thin tongue from the snout with a knob at the tip
                // (aimed slightly down in body space so it reads level once the body is tilted up)
                let tg = NSBezierPath(); tg.move(to: NSPoint(x: 2.2, y: 7.2)); tg.line(to: NSPoint(x: -3.8, y: 5.6)); tg.lineWidth = 1.1; tg.lineCapStyle = .round
                NSColor(red: 0.96, green: 0.42, blue: 0.56, alpha: 1).set(); tg.stroke()
                NSBezierPath(ovalIn: NSRect(x: -5.0, y: 4.4, width: 1.9, height: 1.9)).fill()
            }
            color.set()
            let p = NSBezierPath()
            p.move(to: NSPoint(x: 1.5, y: 7))
            p.curve(to: NSPoint(x: 7.5, y: 12.3), controlPoint1: NSPoint(x: 2.5, y: 10.5), controlPoint2: NSPoint(x: 5, y: 12.6))
            p.curve(to: NSPoint(x: 12.5, y: 10.2), controlPoint1: NSPoint(x: 9.8, y: 12.1), controlPoint2: NSPoint(x: 11.6, y: 11.5))
            p.curve(to: NSPoint(x: 13.2, y: 6.4), controlPoint1: NSPoint(x: 13.6, y: 9), controlPoint2: NSPoint(x: 13.8, y: 7.6))
            p.curve(to: NSPoint(x: 8.5, y: 4.3), controlPoint1: NSPoint(x: 12.4, y: 4.8), controlPoint2: NSPoint(x: 11, y: 4.1))
            p.curve(to: NSPoint(x: 1.5, y: 7), controlPoint1: NSPoint(x: 6, y: 4.3), controlPoint2: NSPoint(x: 3, y: 5))
            p.close(); p.fill()
            if splotches {
                ctx.saveGraphicsState(); p.addClip()
                NSColor.systemGreen.set()
                for (x, y, w, h) in [(CGFloat(5.6), CGFloat(9.8), CGFloat(2.4), CGFloat(1.9)), (8.6, 6.6, 2.2, 1.8), (10.4, 9.4, 1.9, 1.6), (7.2, 11.0, 1.7, 1.3), (11.8, 6.8, 1.3, 1.2), (3.2, 6.2, 1.5, 1.2)] {
                    NSBezierPath(ovalIn: NSRect(x: x - w / 2, y: y - h / 2, width: w, height: h)).fill()
                }
                ctx.restoreGraphicsState(); color.set()
            }
            // feet, gripping the stick
            NSBezierPath(rect: NSRect(x: 5.6, y: 1.6, width: 1.9, height: 3.6)).fill()
            NSBezierPath(rect: NSRect(x: 10, y: 1.6, width: 1.9, height: 3.6)).fill()
            if tail {
                // a long sweep down from the rump that ends in a smooth curl: the sweep
                // lands on the top of the curl circle, tangent to it
                // (trailing out behind the rump in body space, so it hangs down-right once tilted)
                let c = NSPoint(x: 17.6, y: 4.6); let r: CGFloat = 1.7
                let s = NSBezierPath()
                s.move(to: NSPoint(x: 12.9, y: 6.5))
                s.curve(to: NSPoint(x: c.x, y: c.y + r), controlPoint1: NSPoint(x: 15.2, y: 6.6), controlPoint2: NSPoint(x: 15.4, y: c.y + r))
                s.appendArc(withCenter: c, radius: r, startAngle: 90, endAngle: -200, clockwise: true)
                s.lineWidth = 1.6; s.lineCapStyle = .round; s.lineJoinStyle = .round; s.stroke()
            }
            cut(ctx, NSBezierPath(ovalIn: NSRect(x: 4.2, y: 8.2, width: 2.3, height: 2.3)))
            color.set(); NSBezierPath(ovalIn: NSRect(x: 4.95, y: 8.95, width: 0.9, height: 0.9)).fill()
            }
        }

    // KEYLIGHT: a keycap with sunglasses; rays around it light up clockwise with the backlight level.
    public static func key(level: CGFloat, active: Bool = true) -> NSImage {
        // Drawn on the 18pt grid, shown at the bar's full 22pt height; the rays already reach the edges.
        canvas(width: 22, height: 22) { ctx in
            let scale = NSAffineTransform(); scale.scale(by: 22.0 / 18.0); scale.concat()
            // Any backlight at all lights the first ray (1% must not read as off);
            // the rest follow the level in eighths.
            let f = max(0, min(1, level))
            let lit = active && f > 0 ? max(1, Int((f * 8).rounded())) : 0
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
    // CAMCORDER: a camcorder with a face — one big lens-eye on the body looking
    // towards its snout of a lens hood, a small smile, a viewfinder for a hat,
    // and the record light on top that comes on while recording.
    public static func camcorder(recording: Bool) -> NSImage {
        canvas(width: 24, height: 22) { ctx in
            body.set()
            // body and lens hood
            NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3, width: 14.5, height: 14), xRadius: 2.6, yRadius: 2.6).fill()
            let hood = NSBezierPath(); hood.move(to: NSPoint(x: 16, y: 7)); hood.line(to: NSPoint(x: 22.5, y: 4.4)); hood.line(to: NSPoint(x: 22.5, y: 15.6)); hood.line(to: NSPoint(x: 16, y: 13)); hood.close(); hood.fill()
            // viewfinder hat
            NSBezierPath(roundedRect: NSRect(x: 3.5, y: 16.6, width: 7, height: 3), xRadius: 1.1, yRadius: 1.1).fill()
            // the eye: a big lens looking towards the hood
            let ec = NSPoint(x: 8.6, y: 11), er: CGFloat = 3.9
            cut(ctx, NSBezierPath(ovalIn: NSRect(x: ec.x - er - 0.6, y: ec.y - er - 0.6, width: (er + 0.6) * 2, height: (er + 0.6) * 2)))
            NSColor.white.set(); NSBezierPath(ovalIn: NSRect(x: ec.x - er, y: ec.y - er, width: er * 2, height: er * 2)).fill()
            NSColor.black.set(); NSBezierPath(ovalIn: NSRect(x: ec.x - 1.1, y: ec.y - 2.1, width: 3.8, height: 3.8)).fill()
            // smile under the eye
            let smile = NSBezierPath()
            smile.appendArc(withCenter: NSPoint(x: 8.6, y: 6.2), radius: 1.9, startAngle: 215, endAngle: 325, clockwise: false)
            smile.lineWidth = 0.9; smile.lineCapStyle = .round
            ctx.compositingOperation = .destinationOut; smile.stroke(); ctx.compositingOperation = .sourceOver
            // record light on the hat: red while recording, a dark socket otherwise
            (recording ? NSColor.systemRed : NSColor(white: 0.35, alpha: 1)).set()
            NSBezierPath(ovalIn: NSRect(x: 11.4, y: 17.2, width: 2.6, height: 2.6)).fill()
        }
    }
    // APOLLO: an Apollo Twin's face — the monitor knob with its tick arc is
    // the mouth, and two squircle buttons above it are the eyes. The arc runs
    // from bottom-left over the top to bottom-right, ticks lighting green with
    // the level. Everything dims when the level cannot be changed.
    public static func apollo(level: CGFloat, online: Bool) -> NSImage {
        canvas(width: 22, height: 22) { ctx in
            let grey = online ? body : NSColor(white: 0.45, alpha: 1)
            let dim = NSColor(white: 0.62, alpha: 0.35)
            let lit = online ? NSColor.systemGreen : NSColor(white: 0.55, alpha: 1)
            let c = NSPoint(x: 11, y: 8)
            // volume ticks: 13 of them across 270°, starting bottom-left
            let ticks = 13
            let litCount = online ? Int((max(0, min(1, level)) * CGFloat(ticks)).rounded()) : 0
            for i in 0..<ticks {
                let a = (225 - CGFloat(i) * 270 / CGFloat(ticks - 1)) * .pi / 180
                let t = NSBezierPath()
                t.move(to: NSPoint(x: c.x + cos(a) * 5.6, y: c.y + sin(a) * 5.6))
                t.line(to: NSPoint(x: c.x + cos(a) * 7.6, y: c.y + sin(a) * 7.6))
                t.lineWidth = 1.5; t.lineCapStyle = .round
                (i < litCount ? lit : dim).set(); t.stroke()
            }
            // the knob, with a lighter cap so it reads as a dome
            grey.set(); NSBezierPath(ovalIn: NSRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)).fill()
            NSColor(white: 1, alpha: online ? 0.28 : 0.12).set()
            NSBezierPath(ovalIn: NSRect(x: c.x - 2.9, y: c.y - 2.9, width: 5.8, height: 5.8)).fill()
            // eyes: two low, wide squircle buttons with small dark pupils
            for x in [CGFloat(3.4), CGFloat(13.4)] {
                grey.set()
                NSBezierPath(roundedRect: NSRect(x: x, y: 18, width: 5.2, height: 2.8), xRadius: 1.3, yRadius: 1.3).fill()
                cut(ctx, NSBezierPath(ovalIn: NSRect(x: x + 1.95, y: 18.75, width: 1.3, height: 1.3)))
                NSColor.black.withAlphaComponent(online ? 1 : 0.5).set()
                NSBezierPath(ovalIn: NSRect(x: x + 1.95, y: 18.75, width: 1.3, height: 1.3)).fill()
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
