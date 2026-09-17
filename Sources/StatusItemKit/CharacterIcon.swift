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
/// close when paused, the bin's lid lifts when active, the monitor lizard's
/// screen fills with the brightness.
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
    /// The pupils can take a colour each — the left eye's for the session window, the right's for the
    /// weekly — so an app can tie each eye to the bar it stands for.
    public static func owl(session: CGFloat, weekly: CGFloat,
                           sessionPupil: NSColor = .black, weeklyPupil: NSColor = .black) -> NSImage {
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
            for (cx, frac, pupil) in [(CGFloat(8.6), session, sessionPupil), (CGFloat(23.4), weekly, weeklyPupil)] {
                let c = NSPoint(x: cx, y: 11); let r: CGFloat = 7.4
                let closed = max(0, min(1, frac))
                cut(ctx, NSBezierPath(ovalIn: NSRect(x: c.x - r - 1, y: c.y - r - 1, width: (r + 1) * 2, height: (r + 1) * 2)))
                eyelid.set(); NSBezierPath(ovalIn: NSRect(x: c.x - r - 0.8, y: c.y - r - 0.8, width: (r + 0.8) * 2, height: (r + 0.8) * 2)).fill()
                let eye = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                // Tiredness: once the eye is less than three-quarters open the
                // white picks up a pink that deepens as the lid comes down —
                // a cartoon's bloodshot sleepy eye, light pink (#FFB3B3) by the
                // time it is shut, never red — and short red veins appear.
                let tired = max(0, min(1, (closed - 0.25) / 0.75))
                let pr: CGFloat = 3.1
                NSColor(srgbRed: 1, green: 1 - 0.3 * tired, blue: 1 - 0.3 * tired, alpha: 1).set(); eye.fill()
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
                pupil.set(); NSBezierPath(ovalIn: NSRect(x: c.x - pr, y: c.y - pr, width: pr * 2, height: pr * 2)).fill()
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

    /// A chameleon hanging onto a brown stick. Brown like the stick when
    /// nothing is connected, with a short straight tail; green whenever
    /// something is. Tailscale: dark spots (its icon is dots) and the tail
    /// curls. Mullvad: a yellow hard hat and its tongue out. Both: green,
    /// spotted, hat, tongue and curled tail. `alert` overrides
    /// the body colour for Mullvad's in-between states (connecting, blocked).
    public static func chameleon(tailscale: Bool, mullvad: Bool, alert: NSColor? = nil) -> NSImage {
        let color = alert ?? ((mullvad || tailscale) ? NSColor.systemGreen : stick)
        return chameleon(color: color, tail: tailscale, tongue: mullvad, spots: tailscale)
    }

    public static func chameleon(color: NSColor, tail: Bool, tongue: Bool, spots: Bool = false) -> NSImage {
            canvas(width: 30, height: 22) { ctx in
            // body on an 18-grid, tilted nose-up ~35° like it is climbing; room on the left for the tongue
            let t = NSAffineTransform(); t.translateX(by: 17.6, yBy: 12.2); t.rotate(byDegrees: -35); t.scale(by: 1.12); t.translateX(by: -9, yBy: -7.5); t.concat()
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
            if spots {
                ctx.saveGraphicsState(); p.addClip()
                NSColor(white: 0.16, alpha: 1).set()
                for (x, y, w, h) in [(CGFloat(5.6), CGFloat(9.8), CGFloat(2.4), CGFloat(1.9)), (8.6, 6.6, 2.2, 1.8), (10.4, 9.4, 1.9, 1.6), (7.2, 11.0, 1.7, 1.3), (11.8, 6.8, 1.3, 1.2), (3.2, 6.2, 1.5, 1.2)] {
                    NSBezierPath(ovalIn: NSRect(x: x - w / 2, y: y - h / 2, width: w, height: h)).fill()
                }
                ctx.restoreGraphicsState(); color.set()
            }
            if tongue {
                // Mullvad's hard hat: a yellow dome with a dark outline (so it reads on
                // the yellow body), a short brim over the eye, and a headlamp.
                let navy = NSColor(red: 0.12, green: 0.18, blue: 0.27, alpha: 1)
                let hatYellow = NSColor(red: 1.0, green: 0.84, blue: 0.14, alpha: 1)
                let dome = NSBezierPath()
                dome.move(to: NSPoint(x: 2.2, y: 11.3))
                dome.curve(to: NSPoint(x: 9.6, y: 11.6), controlPoint1: NSPoint(x: 3.0, y: 15.0), controlPoint2: NSPoint(x: 9.2, y: 14.8))
                dome.close()
                hatYellow.set(); dome.fill()
                dome.lineWidth = 0.7; dome.lineJoinStyle = .round; navy.set(); dome.stroke()
                let brim = NSBezierPath(); brim.move(to: NSPoint(x: 0.4, y: 10.9)); brim.line(to: NSPoint(x: 4.4, y: 11.5))
                brim.lineWidth = 1.9; brim.lineCapStyle = .round; navy.set(); brim.stroke()
                brim.lineWidth = 1.0; hatYellow.set(); brim.stroke()
                navy.set(); NSBezierPath(ovalIn: NSRect(x: 2.5, y: 11.8, width: 2.2, height: 2.2)).fill()
                NSColor.white.set(); NSBezierPath(ovalIn: NSRect(x: 2.9, y: 12.2, width: 1.4, height: 1.4)).fill()
            }
            // feet, gripping the stick
            color.set()
            NSBezierPath(rect: NSRect(x: 5.6, y: 1.6, width: 1.9, height: 3.6)).fill()
            NSBezierPath(rect: NSRect(x: 10, y: 1.6, width: 1.9, height: 3.6)).fill()
            if !tail {
                // the resting tail: long and thin, sweeping out behind and curling
                // upward without closing the loop
                let st = NSBezierPath(); st.move(to: NSPoint(x: 12.9, y: 6.5))
                st.curve(to: NSPoint(x: 17.2, y: 8.6), controlPoint1: NSPoint(x: 16.4, y: 5.2), controlPoint2: NSPoint(x: 18.6, y: 6.2))
                st.curve(to: NSPoint(x: 15.6, y: 9.0), controlPoint1: NSPoint(x: 16.6, y: 9.6), controlPoint2: NSPoint(x: 15.9, y: 9.6))
                st.lineWidth = 1.1; st.lineCapStyle = .round; st.stroke()
            } else {
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
    }

    static let amber = NSColor(red: 1, green: 0.62, blue: 0.2, alpha: 1)

    static let lizardSand = NSColor(red: 0.95, green: 0.78, blue: 0.38, alpha: 1)
    static let lizardSpot = NSColor(red: 0.30, green: 0.18, blue: 0.07, alpha: 1)
    static let screenBlue = NSColor(red: 0.36, green: 0.72, blue: 0.98, alpha: 1)

    /// A tapering ribbon along a cubic: width `w0` at the start shrinking to `w1` at the end.
    /// A stroked path is one width end to end and reads as a cable; a taper reads as a tail.
    static func taper(_ p0: NSPoint, _ p1: NSPoint, _ p2: NSPoint, _ p3: NSPoint, from w0: CGFloat, to w1: CGFloat) -> NSBezierPath {
        func at(_ t: CGFloat) -> (NSPoint, NSPoint) {
            let u = 1 - t
            let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
            let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
            let dx = 3*u*u*(p1.x-p0.x) + 6*u*t*(p2.x-p1.x) + 3*t*t*(p3.x-p2.x)
            let dy = 3*u*u*(p1.y-p0.y) + 6*u*t*(p2.y-p1.y) + 3*t*t*(p3.y-p2.y)
            let len = max(0.001, (dx*dx + dy*dy).squareRoot())
            return (NSPoint(x: x, y: y), NSPoint(x: -dy/len, y: dx/len))
        }
        let n = 24
        var left: [NSPoint] = [], right: [NSPoint] = []
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let (c, nrm) = at(t)
            let w = (w0 + (w1 - w0) * t) / 2
            left.append(NSPoint(x: c.x + nrm.x*w, y: c.y + nrm.y*w))
            right.append(NSPoint(x: c.x - nrm.x*w, y: c.y - nrm.y*w))
        }
        let path = NSBezierPath()
        path.move(to: left[0])
        for q in left.dropFirst() { path.line(to: q) }
        path.appendArc(withCenter: at(1).0, radius: w1/2, startAngle: 0, endAngle: 360)
        for q in right.reversed() { path.line(to: q) }
        path.close()
        return path
    }

    // MONITOR LIZARD: a leopard gecko hugging a grey monitor, like the mascot. Its big head peers over
    // the top-right corner of the screen, two paws grip the top bezel, and a fat spotted tail comes out
    // from behind the stand, sweeps under the foot and curls up over the bottom-left of the screen. The
    // screen fills bottom-up in sky blue with the main display's brightness; Night Shift turns the fill
    // amber; a forked tongue flicks after a DDC write.
    public static func monitorLizard(brightness: CGFloat, nightShift: Bool, tongue: Bool = false) -> NSImage {
        let level = max(0, min(1, brightness))
        return canvas(width: 25, height: 22) { ctx in
            let outline = lizardSpot
            // Tail: root behind the stand, sweeping down-left under the foot, then a second segment
            // curling up over the screen. Drawn whole here (behind the monitor); the curl is redrawn
            // on top once the screen is filled so the tip sits over the glass.
            let r0 = NSPoint(x: 13.0, y: 2.4), r1 = NSPoint(x: 8.5, y: 0.9), r2 = NSPoint(x: 1.8, y: 1.0), r3 = NSPoint(x: 1.3, y: 5.0)
            let c0 = r3, c1 = NSPoint(x: 0.9, y: 8.2), c2 = NSPoint(x: 2.6, y: 10.6), c3 = NSPoint(x: 6.4, y: 9.2)
            let sweep = taper(r0, r1, r2, r3, from: 3.0, to: 2.0)
            let curl = taper(c0, c1, c2, c3, from: 2.0, to: 0.9)
            func drawTail(_ p: NSBezierPath, spots: [(CGFloat, CGFloat)]) {
                lizardSand.set(); p.fill()
                p.lineWidth = 0.6; p.lineJoinStyle = .round; outline.set(); p.stroke()
                lizardSpot.set()
                for (x, y) in spots { NSBezierPath(ovalIn: NSRect(x: x - 0.5, y: y - 0.5, width: 1.0, height: 1.0)).fill() }
            }
            drawTail(sweep, spots: [(5.0, 1.6), (1.8, 3.4)])
            drawTail(curl, spots: [(2.4, 7.4)])
            // Monitor: bezel 17 wide on a low stand — all mid grey. The screen is most of the glyph.
            body.set()
            let bezel = NSRect(x: 1.5, y: 5.0, width: 17, height: 10.6)
            NSBezierPath(roundedRect: bezel, xRadius: 1.6, yRadius: 1.6).fill()
            NSBezierPath(rect: NSRect(x: 8.5, y: 2.9, width: 3, height: 2.4)).fill()        // neck of the stand
            NSBezierPath(roundedRect: NSRect(x: 5.5, y: 1.7, width: 9, height: 1.5), xRadius: 0.75, yRadius: 0.75).fill() // foot
            // Screen: cut out of the bezel, then filled to the brightness level.
            let screen = NSRect(x: 2.6, y: 6.1, width: 14.8, height: 8.4)
            cut(ctx, NSBezierPath(rect: screen))
            if level > 0.02 {
                (nightShift ? amber : screenBlue).set()
                NSBezierPath(rect: NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: screen.height * level)).fill()
            }
            // The curl's tip lies over the glass.
            drawTail(curl, spots: [(2.4, 7.4)])
            // Paws gripping the top bezel, left of the head, with two toe notches each.
            for px in [CGFloat(3.6), 7.4] {
                let paw = NSBezierPath(roundedRect: NSRect(x: px, y: 13.4, width: 3.0, height: 2.8), xRadius: 1.1, yRadius: 1.1)
                lizardSand.set(); paw.fill()
                paw.lineWidth = 0.6; outline.set(); paw.stroke()
                outline.set()
                for tx in [px + 1.0, px + 2.0] {
                    let notch = NSBezierPath(); notch.move(to: NSPoint(x: tx, y: 13.4)); notch.line(to: NSPoint(x: tx, y: 14.3))
                    notch.lineWidth = 0.5; notch.stroke()
                }
            }
            // Head: big, in profile facing right, perched on the top-right corner and dipping below the
            // bezel line so it peers over the glass. Rounded crown, blunt wedge snout, jaw back to the bezel.
            let head = NSBezierPath()
            head.move(to: NSPoint(x: 11.4, y: 15.6))
            head.curve(to: NSPoint(x: 12.4, y: 20.6), controlPoint1: NSPoint(x: 11.0, y: 17.6), controlPoint2: NSPoint(x: 11.2, y: 19.8))
            head.curve(to: NSPoint(x: 17.6, y: 21.3), controlPoint1: NSPoint(x: 13.8, y: 21.6), controlPoint2: NSPoint(x: 15.8, y: 21.8))
            head.curve(to: NSPoint(x: 22.6, y: 18.0), controlPoint1: NSPoint(x: 19.8, y: 20.8), controlPoint2: NSPoint(x: 22.0, y: 19.4))
            head.curve(to: NSPoint(x: 20.6, y: 15.4), controlPoint1: NSPoint(x: 23.0, y: 16.8), controlPoint2: NSPoint(x: 22.2, y: 15.8))
            head.curve(to: NSPoint(x: 14.2, y: 13.6), controlPoint1: NSPoint(x: 18.6, y: 14.9), controlPoint2: NSPoint(x: 16.2, y: 13.5))
            head.curve(to: NSPoint(x: 11.4, y: 15.6), controlPoint1: NSPoint(x: 12.8, y: 13.7), controlPoint2: NSPoint(x: 11.8, y: 14.6))
            head.close()
            lizardSand.set(); head.fill()
            head.lineWidth = 0.6; head.lineJoinStyle = .round; outline.set(); head.stroke()
            // Crest bumps on the crown.
            let crest = NSBezierPath()
            for cx in [CGFloat(13.6), 15.6] {
                crest.move(to: NSPoint(x: cx - 0.7, y: 21.1)); crest.line(to: NSPoint(x: cx, y: 22.0)); crest.line(to: NSPoint(x: cx + 0.7, y: 21.3))
            }
            crest.lineWidth = 0.7; crest.lineJoinStyle = .round; outline.set(); crest.stroke()
            // Spots on the crown and cheek.
            lizardSpot.set()
            NSBezierPath(ovalIn: NSRect(x: 12.6, y: 18.6, width: 1.2, height: 1.2)).fill()
            NSBezierPath(ovalIn: NSRect(x: 14.6, y: 15.2, width: 1.0, height: 1.0)).fill()
            // Mouth: a line back from the nose.
            let mouth = NSBezierPath(); mouth.move(to: NSPoint(x: 22.3, y: 17.2)); mouth.line(to: NSPoint(x: 18.6, y: 16.3))
            mouth.lineWidth = 0.6; mouth.lineCapStyle = .round; outline.set(); mouth.stroke()
            // Eye with a highlight.
            NSColor(white: 0.05, alpha: 1).set()
            NSBezierPath(ovalIn: NSRect(x: 17.0, y: 17.5, width: 2.4, height: 2.4)).fill()
            NSColor.white.set()
            NSBezierPath(ovalIn: NSRect(x: 17.4, y: 18.6, width: 0.9, height: 0.9)).fill()
            if tongue {
                NSColor(red: 0.96, green: 0.42, blue: 0.56, alpha: 1).set()
                let t = NSBezierPath(); t.move(to: NSPoint(x: 22.4, y: 17.0)); t.line(to: NSPoint(x: 23.9, y: 16.6))
                t.move(to: NSPoint(x: 23.9, y: 16.6)); t.line(to: NSPoint(x: 24.7, y: 17.2))
                t.move(to: NSPoint(x: 23.9, y: 16.6)); t.line(to: NSPoint(x: 24.7, y: 15.9))
                t.lineWidth = 0.9; t.lineCapStyle = .round; t.stroke()
            }
        }
    }

    /// Homestead's house: the windows are the lights, and the right one gets a
    /// fan when one is running. Deliberately chimney-free — a chimney reads as
    /// heating, which this app does not control.
    public static func house(lightsOn: Int, fanOn: Bool, reachable: Bool, configured: Bool) -> NSImage {
        canvas(width: 22, height: 22) { ctx in
            let outline = NSBezierPath()
            outline.move(to: NSPoint(x: 1.6, y: 11))
            outline.line(to: NSPoint(x: 11, y: 20))
            outline.line(to: NSPoint(x: 20.4, y: 11))
            outline.line(to: NSPoint(x: 17.6, y: 11))
            outline.line(to: NSPoint(x: 17.6, y: 2.4))
            outline.line(to: NSPoint(x: 4.4, y: 2.4))
            outline.line(to: NSPoint(x: 4.4, y: 11))
            outline.close()
            outline.lineWidth = 1.6
            outline.lineJoinStyle = .round

            let lit = NSColor(red: 1, green: 0.82, blue: 0.34, alpha: 1)
            let dark = NSColor(white: 0.34, alpha: 1)

            if !configured {
                // Nothing to say yet: grey, but solid — dashes mean "lost", and
                // an app that has never been pointed at a server has lost nothing.
                NSColor(white: 0.45, alpha: 1).set()
            } else if !reachable {
                NSColor(white: 0.45, alpha: 1).set()
                outline.setLineDash([2.2, 1.8], count: 2, phase: 0)
            } else {
                body.set()
            }
            outline.stroke()

            // Door, so the silhouette still reads as a house at 22pt.
            let door = NSBezierPath(rect: NSRect(x: 9.7, y: 2.4, width: 2.6, height: 4.0))
            door.fill()

            let showLights = configured && reachable
            let left = NSRect(x: 6.1, y: 7.6, width: 3.4, height: 3.4)
            let right = NSRect(x: 12.5, y: 7.6, width: 3.4, height: 3.4)
            let leftLit = showLights && lightsOn >= 1
            let rightLit = showLights && lightsOn >= 2

            (leftLit ? lit : dark).set()
            NSBezierPath(rect: left).fill()
            (rightLit ? lit : dark).set()
            NSBezierPath(rect: right).fill()

            guard showLights, fanOn else { return }
            // Three curved blades around a hub, contrasting with the window
            // behind them. At this size a fan has to be a pinwheel silhouette;
            // straight wedges read as a hazard symbol instead.
            (rightLit ? dark : lit).set()
            let centre = NSPoint(x: right.midX, y: right.midY)
            let radius: CGFloat = 1.75
            for index in 0..<3 {
                let angle = Double(index) * 2 * Double.pi / 3 + 0.3
                let tip = NSPoint(x: centre.x + CGFloat(cos(angle)) * radius,
                                  y: centre.y + CGFloat(sin(angle)) * radius)
                let blade = NSBezierPath()
                blade.move(to: centre)
                blade.curve(to: tip,
                            controlPoint1: NSPoint(x: centre.x + CGFloat(cos(angle - 0.9)) * radius * 0.9,
                                                   y: centre.y + CGFloat(sin(angle - 0.9)) * radius * 0.9),
                            controlPoint2: NSPoint(x: centre.x + CGFloat(cos(angle - 0.3)) * radius,
                                                   y: centre.y + CGFloat(sin(angle - 0.3)) * radius))
                blade.curve(to: centre,
                            controlPoint1: NSPoint(x: centre.x + CGFloat(cos(angle + 0.35)) * radius * 0.85,
                                                   y: centre.y + CGFloat(sin(angle + 0.35)) * radius * 0.85),
                            controlPoint2: NSPoint(x: centre.x + CGFloat(cos(angle + 0.5)) * radius * 0.4,
                                                   y: centre.y + CGFloat(sin(angle + 0.5)) * radius * 0.4))
                blade.close()
                blade.fill()
            }
        }
    }
}
