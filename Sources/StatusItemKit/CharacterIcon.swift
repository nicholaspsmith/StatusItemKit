// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// Status-item glyphs that look like an app's mascot and still carry its data.
///
/// Same 18pt non-template canvas as `MeterIcon`, so an app can offer a
/// character alongside the geometric meters and switching moves nothing. Each
/// silhouette is hand-drawn as a path — at this size a mascot has to become a
/// pictogram — and the number lives in something the character *does*: the
/// owl's eyes are pie meters, the iguana changes colour and wraps its tail or
/// tongue round its branch per connection, the octopus grows and heats from four green arms to eight red ones, the key's rays light
/// with the backlight, the Apollo's volume arc is the level, the raccoon's eyes
/// close when paused, the bin's lid lifts when active, the monitor lizard's
/// screen fills with the brightness, and the caterpillar lights a segment per
/// running effect.
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
    /// The owl is eyelid-brown all over, and its two eyes always match. Each is a real eye: white,
    /// pupil, and a brown eyelid. The lids drop with the `session` fraction — wide open at 0, half
    /// closed at 0.5, shut at 1. The `weekly` fraction is the owl's health: the whites go bloodshot
    /// past a quarter used, and both pupils run `MeterColor.health` from #005401 at 0 to #FF5401 at 1.
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
            let closed = max(0, min(1, session))
            let health = max(0, min(1, weekly))
            // Pupils: dark green on a fresh week, reddening as it is spent.
            let pupil = MeterColor.health(health)
            for cx in [CGFloat(8.6), 23.4] {
                let c = NSPoint(x: cx, y: 11); let r: CGFloat = 7.4
                cut(ctx, NSBezierPath(ovalIn: NSRect(x: c.x - r - 1, y: c.y - r - 1, width: (r + 1) * 2, height: (r + 1) * 2)))
                eyelid.set(); NSBezierPath(ovalIn: NSRect(x: c.x - r - 0.8, y: c.y - r - 0.8, width: (r + 0.8) * 2, height: (r + 0.8) * 2)).fill()
                let eye = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                // Tiredness: past a quarter of the week used the white picks
                // up a pink that deepens as the week is spent — a cartoon's
                // bloodshot sleepy eye, light pink (#FFB3B3) at 100%, never
                // red. Short red veins appear in the last quarter of the week:
                // 1% opaque at 75% used, rising straight to solid at 100%.
                let tired = max(0, min(1, (health - 0.25) / 0.75))
                let veins: CGFloat = health < 0.75 ? 0 : 0.01 + 0.99 * (health - 0.75) / 0.25
                let pr: CGFloat = 3.1
                NSColor(srgbRed: 1, green: 1 - 0.3 * tired, blue: 1 - 0.3 * tired, alpha: 1).set(); eye.fill()
                if veins > 0 {
                    ctx.saveGraphicsState(); eye.addClip()
                    // Veins run radially: one end near the pupil, the other near
                    // the rim, all the way round the eye at slightly uneven
                    // angles. Each has its own shape — a bow, an S-wiggle, or a
                    // bow with a short fork — and the right eye mirrors the left
                    // so the face stays balanced. Between each pair sits a small
                    // vein: thinner, fainter (60% of the big ones' opacity), and
                    // only reaching in from the rim part way. Drawn before the
                    // lid, which hides them as it drops.
                    let mirror: CGFloat = cx > 16 ? -1 : 1
                    let big: [(CGFloat, Int, CGFloat)] = [(24, 0, 0.9), (97, 1, 0.8), (139, 2, -0.8),
                                                          (206, 0, -0.9), (263, 1, -0.8), (318, 2, 0.9)]
                    let small: [(CGFloat, Int, CGFloat)] = [(62, 0, -0.5), (116, 0, 0.5), (174, 1, 0.45),
                                                            (237, 0, 0.5), (288, 0, -0.5), (349, 1, -0.45)]
                    for (deg, shape, bend, isSmall) in big.map({ ($0.0, $0.1, $0.2, false) }) + small.map({ ($0.0, $0.1, $0.2, true) }) {
                        NSColor(srgbRed: 0.95, green: 0.12, blue: 0.12, alpha: veins * (isSmall ? 0.6 : 1)).set()
                        let a = (mirror > 0 ? deg : 180 - deg) * .pi / 180, b = bend * mirror
                        let from: CGFloat = isSmall ? 0.45 : 0
                        // A point `t` of the way along the vein (which starts
                        // `from` of the way out to the rim), pushed `off` sideways.
                        func at(_ t: CGFloat, _ off: CGFloat) -> NSPoint {
                            let d = pr + 0.6 + (from + t * (1 - from)) * (r - 0.5 - pr - 0.6)
                            return NSPoint(x: c.x + cos(a) * d - sin(a) * off, y: c.y + sin(a) * d + cos(a) * off)
                        }
                        let v = NSBezierPath(); v.move(to: at(0, 0))
                        if shape == 1 {
                            v.curve(to: at(1, 0), controlPoint1: at(0.35, b * 1.4), controlPoint2: at(0.65, -b * 1.4))
                        } else {
                            v.curve(to: at(1, 0), controlPoint1: at(0.5, b), controlPoint2: at(0.5, b))
                        }
                        if shape == 2 {
                            v.move(to: at(0.5, b * 0.75))
                            v.curve(to: at(0.95, b * 2.2), controlPoint1: at(0.7, b * 1.1), controlPoint2: at(0.8, b * 1.8))
                        }
                        v.lineWidth = isSmall ? 0.35 : 0.5; v.lineCapStyle = .round; v.stroke()
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

    // IGUANA
    /// The iguana's branch, and the wood colour.
    static let stick = NSColor(red: 0.45, green: 0.28, blue: 0.14, alpha: 1)

    /// The iguana at rest: a muted olive, far enough from the vivid green of a
    /// live connection never to be mistaken for one, and clear of the
    /// branch's brown.
    static let restingSkin = NSColor(srgbRed: 0.588, green: 0.651, blue: 0.416, alpha: 1)

    /// accept-dns, in the eye and on its menu row's dot. Cyan holds against
    /// every body colour the iguana takes: olive at rest, green connected,
    /// red blocked.
    public static let dnsCyan = NSColor(srgbRed: 0.24, green: 0.83, blue: 0.93, alpha: 1)

    /// VPN & DNS: Iguanamous the iguana on a branch, where each thing it does
    /// is one connection.
    ///
    /// - Tailscale: the tail comes down off the back and wraps the branch.
    /// - Mullvad: the tongue shoots out and wraps the branch ahead of it.
    /// - accept-dns: the eye turns cyan.
    ///
    /// Olive when nothing is connected, green when anything is; `alert`
    /// overrides the body colour for Mullvad's in-between states
    /// (connecting, blocked).
    ///
    /// - Parameter lick: seconds into the once-a-minute lick (see
    ///   `iguanaLickDuration`), or nil when still.
    public static func iguana(tailscale: Bool, mullvad: Bool, acceptDNS: Bool = false,
                              alert: NSColor? = nil, lick: TimeInterval? = nil) -> NSImage {
        let color = alert ?? ((mullvad || tailscale) ? NSColor.systemGreen : restingSkin)
        return iguana(color: color, tail: tailscale, tongue: mullvad, eyeLit: acceptDNS, lick: lick)
    }

    /// How long Iguanamous's lick lasts.
    public static let iguanaLickDuration: TimeInterval = 1.0

    @available(*, deprecated, renamed: "iguana(tailscale:mullvad:acceptDNS:alert:lick:)")
    public static func chameleon(tailscale: Bool, mullvad: Bool, acceptDNS: Bool = false,
                                 alert: NSColor? = nil, lick: TimeInterval? = nil) -> NSImage {
        iguana(tailscale: tailscale, mullvad: mullvad, acceptDNS: acceptDNS, alert: alert, lick: lick)
    }

    @available(*, deprecated, renamed: "iguana(color:tail:tongue:eyeLit:lick:)")
    public static func chameleon(color: NSColor, tail: Bool, tongue: Bool, eyeLit: Bool = false,
                                 lick: TimeInterval? = nil) -> NSImage {
        iguana(color: color, tail: tail, tongue: tongue, eyeLit: eyeLit, lick: lick)
    }

    @available(*, deprecated, renamed: "iguanaLickDuration")
    public static var chameleonLickDuration: TimeInterval { iguanaLickDuration }

    /// How much of the tongue is out, 0...1 along its path, `t` seconds into
    /// the lick. Tongue in the mouth: it shoots out, flicks twice at the air
    /// and draws back. Tongue wrapped round the branch: it unwinds and reels
    /// back into the mouth, rests a beat, then shoots out and wraps again.
    /// Going out eases out (a fast launch that decelerates); reeling in eases
    /// in.
    static func tongueExtent(lickAt t: TimeInterval, wrapped: Bool) -> CGFloat {
        let d = iguanaLickDuration
        func easeOut(_ x: Double) -> Double { 1 - pow(1 - max(0, min(1, x)), 3) }
        func easeIn(_ x: Double) -> Double { pow(max(0, min(1, x)), 2) }
        let x: Double
        if wrapped {
            if t < 0.4 * d { x = 1 - easeIn(t / (0.4 * d)) }
            else if t < 0.55 * d { x = 0 }
            else { x = easeOut((t - 0.55 * d) / (0.4 * d)) }
        } else {
            if t < 0.18 * d { x = easeOut(t / (0.18 * d)) }
            else if t < 0.62 * d { x = 1 - 0.3 * abs(sin(2 * .pi * (t - 0.18 * d) / (0.44 * d))) }
            else { x = 1 - easeIn((t - 0.62 * d) / (0.3 * d)) }
        }
        return CGFloat(max(0, min(1, x)))
    }

    /// - Parameter eyeLit: accept-dns: the iris turns cyan.
    public static func iguana(color: NSColor, tail: Bool, tongue: Bool, eyeLit: Bool = false,
                              lick: TimeInterval? = nil) -> NSImage {
        // Drawn for a Retina bar, like the owl: the crest spines, claws and tongue
        // are sub-point marks that land on half pixels at 2x. Icon ▸ Dot is
        // there for anyone who wants a flat glyph.
        let base = color.usingColorSpace(.sRGB) ?? color
        let shade = base.blended(withFraction: 0.30, of: .black) ?? base
        let deep = base.blended(withFraction: 0.50, of: .black) ?? base
        let highlight = base.blended(withFraction: 0.38, of: .white) ?? base
        let barkDark = stick.blended(withFraction: 0.35, of: .black) ?? stick
        let barkLight = stick.blended(withFraction: 0.22, of: .white) ?? stick

        return canvas(width: 30, height: 22) { ctx in
            // The branch runs the full width, rising slightly, and everything
            // else is positioned off it: feet stand on it, the tail wraps under
            // it, the tongue catches it ahead of the snout.
            // The animal sits `shift` right of the canvas's left edge so the
            // tongue's wrap round the branch is never cut off; the branch itself
            // spans the whole width. `branchY` takes animal coordinates.
            let shift: CGFloat = 1.2
            func branchLine(_ x: CGFloat) -> CGFloat { 5.0 + x * 0.05 }
            func branchY(_ x: CGFloat) -> CGFloat { branchLine(x + shift) }
            let branchThickness: CGFloat = 2.5

            let branch = NSBezierPath()
            branch.move(to: NSPoint(x: -0.5, y: branchLine(-0.5)))
            branch.line(to: NSPoint(x: 30.5, y: branchLine(30.5)))
            branch.lineWidth = branchThickness
            branch.lineCapStyle = .round
            stick.set(); branch.stroke()
            barkDark.set(); branch.lineWidth = 0.7
            let underside = NSBezierPath()
            underside.move(to: NSPoint(x: 0, y: branchLine(0) - 0.85))
            underside.line(to: NSPoint(x: 30, y: branchLine(30) - 0.85))
            underside.lineWidth = 0.6; underside.lineCapStyle = .round; underside.stroke()
            barkLight.set()
            for x in [CGFloat(3.0), 12.0, 24.0] {
                let nub = NSBezierPath()
                nub.move(to: NSPoint(x: x, y: branchLine(x) + 0.2))
                nub.line(to: NSPoint(x: x + 1.2, y: branchLine(x) + 0.5))
                nub.lineWidth = 0.45; nub.lineCapStyle = .round; nub.stroke()
            }

            let animal = NSAffineTransform()
            animal.translateX(by: shift, yBy: 0)
            animal.concat()

            /// Redraw a span of the branch on top of whatever has been drawn.
            /// A limb that crosses the wood and comes back is what reads as
            /// wrapped; a loop laid over the top just reads as a loop.
            func branchOver(from: CGFloat, to: CGFloat) {
                // Repainted exactly as the branch was drawn, or the span shows
                // up as a patch of slightly different wood.
                let span = NSBezierPath()
                span.move(to: NSPoint(x: from, y: branchY(from)))
                span.line(to: NSPoint(x: to, y: branchY(to)))
                span.lineWidth = branchThickness
                span.lineCapStyle = .butt
                stick.set(); span.stroke()
                let shadowed = NSBezierPath()
                shadowed.move(to: NSPoint(x: from, y: branchY(from) - 0.85))
                shadowed.line(to: NSPoint(x: to, y: branchY(to) - 0.85))
                shadowed.lineWidth = 0.6; shadowed.lineCapStyle = .butt
                barkDark.set(); shadowed.stroke()
            }

            // MARK: the tail, drawn behind the body

            let tailBase = NSPoint(x: 21.2, y: 12.6)
            let tailPath = NSBezierPath()
            tailPath.move(to: tailBase)
            if tail {
                // Down off the rump and round the branch: the curl closes under
                // it, which is how a prehensile tail actually holds on.
                let centre = NSPoint(x: 25.0, y: branchY(25.0))
                tailPath.curve(to: NSPoint(x: centre.x + 2.2, y: centre.y + 1.6),
                               controlPoint1: NSPoint(x: 23.6, y: 12.0),
                               controlPoint2: NSPoint(x: 26.8, y: 10.0))
                tailPath.appendArc(withCenter: centre, radius: 2.7, startAngle: 30, endAngle: -260, clockwise: true)
            } else {
                // At rest the tail is carried rolled up behind.
                let centre = NSPoint(x: 25.0, y: 13.6)
                tailPath.curve(to: NSPoint(x: centre.x - 0.2, y: centre.y + 2.1),
                               controlPoint1: NSPoint(x: 23.0, y: 13.8),
                               controlPoint2: NSPoint(x: 24.2, y: 15.6))
                tailPath.appendArc(withCenter: centre, radius: 2.1, startAngle: 96, endAngle: -150, clockwise: true)
                tailPath.appendArc(withCenter: NSPoint(x: centre.x + 0.35, y: centre.y - 0.45),
                                   radius: 1.15, startAngle: -150, endAngle: 60, clockwise: false)
            }
            tailPath.lineWidth = 1.9; tailPath.lineCapStyle = .round; tailPath.lineJoinStyle = .round
            base.set(); tailPath.stroke()
            highlight.withAlphaComponent(0.5).set(); tailPath.lineWidth = 0.55; tailPath.stroke()
            // The dark rings an iguana's tail is banded with.
            let rings = tailPath.copy() as! NSBezierPath
            rings.lineWidth = 1.9; rings.lineCapStyle = .butt
            rings.setLineDash([0.7, 1.6], count: 2, phase: 1.2)
            deep.withAlphaComponent(0.55).set(); rings.stroke()
            if tail {
                // The far side of the curl goes behind the wood, and the tip
                // comes back over it.
                // Past the curl's right side, which goes behind the wood.
                branchOver(from: 22.8, to: 25.0 + 2.7 + 1.1)
                let tip = NSBezierPath()
                tip.appendArc(withCenter: NSPoint(x: 25.0, y: branchY(25.0)), radius: 2.7,
                              startAngle: 200, endAngle: 100, clockwise: true)
                tip.lineWidth = 1.9; tip.lineCapStyle = .round
                base.set(); tip.stroke()
                highlight.withAlphaComponent(0.5).set(); tip.lineWidth = 0.55; tip.stroke()
            }

            // MARK: legs, behind the body so the near pair reads on top

            func leg(hip: NSPoint, knee: NSPoint, foot: NSPoint, thickness: CGFloat, color legColor: NSColor) {
                let limb = NSBezierPath()
                limb.move(to: hip)
                limb.curve(to: knee, controlPoint1: NSPoint(x: hip.x, y: hip.y - 0.8), controlPoint2: knee)
                limb.curve(to: foot, controlPoint1: knee, controlPoint2: NSPoint(x: foot.x, y: foot.y + 0.9))
                limb.lineWidth = thickness; limb.lineCapStyle = .round; limb.lineJoinStyle = .round
                legColor.set(); limb.stroke()

                // Long splayed toes, clawed, spread over the top of the branch.
                let top = branchY(foot.x) + branchThickness / 2
                let claws = NSBezierPath()
                for (dx, reach) in [(-1.3, 0.9), (0.0, 1.0), (1.3, 0.8)] as [(CGFloat, CGFloat)] {
                    claws.move(to: NSPoint(x: foot.x, y: top + 0.5))
                    claws.line(to: NSPoint(x: foot.x + dx, y: top + 0.1 - 0.15 * reach))
                }
                claws.lineWidth = 0.6; claws.lineCapStyle = .round
                legColor.set(); claws.stroke()
            }
            // The far pair, in shadow behind the body.
            leg(hip: NSPoint(x: 18.6, y: 10.4), knee: NSPoint(x: 20.6, y: 7.8),
                foot: NSPoint(x: 19.8, y: branchY(19.8) + 1.0), thickness: 1.4, color: deep)
            leg(hip: NSPoint(x: 10.2, y: 9.8), knee: NSPoint(x: 8.2, y: 7.4),
                foot: NSPoint(x: 9.2, y: branchY(9.2) + 1.0), thickness: 1.4, color: deep)

            // MARK: the body

            // One closed outline: a blunt, blocky head, the dewlap hanging under
            // the chin, and a long low body to the rump the tail leaves from.
            // Long and low, close to the branch.
            let body = NSBezierPath()
            body.move(to: NSPoint(x: 2.0, y: 12.6))                        // the snout, blunt and rounded
            body.curve(to: NSPoint(x: 5.6, y: 15.2),                       // up over the brow
                       controlPoint1: NSPoint(x: 2.1, y: 14.4), controlPoint2: NSPoint(x: 3.6, y: 15.2))
            body.curve(to: NSPoint(x: 9.4, y: 14.8),                       // the flat crown, dipping to the neck
                       controlPoint1: NSPoint(x: 7.2, y: 15.2), controlPoint2: NSPoint(x: 8.4, y: 14.8))
            body.curve(to: NSPoint(x: 16.4, y: 15.4),                      // the back, long and nearly level
                       controlPoint1: NSPoint(x: 11.6, y: 15.0), controlPoint2: NSPoint(x: 14.2, y: 15.6))
            body.curve(to: NSPoint(x: 21.2, y: 12.6),                      // taper to the rump
                       controlPoint1: NSPoint(x: 18.6, y: 15.1), controlPoint2: NSPoint(x: 20.6, y: 14.2))
            body.curve(to: NSPoint(x: 13.6, y: 9.4),                       // the belly, low along the branch
                       controlPoint1: NSPoint(x: 21.4, y: 10.6), controlPoint2: NSPoint(x: 17.4, y: 9.4))
            body.curve(to: NSPoint(x: 9.2, y: 10.0),                       // forward to the chest
                       controlPoint1: NSPoint(x: 11.4, y: 9.4), controlPoint2: NSPoint(x: 10.0, y: 9.6))
            // The dewlap: the big flap of skin under the chin, the one shape
            // that says "iguana" at this size.
            body.curve(to: NSPoint(x: 5.4, y: 8.4),
                       controlPoint1: NSPoint(x: 8.6, y: 9.0), controlPoint2: NSPoint(x: 6.8, y: 8.2))
            body.curve(to: NSPoint(x: 3.0, y: 11.6),
                       controlPoint1: NSPoint(x: 4.2, y: 8.6), controlPoint2: NSPoint(x: 3.2, y: 10.2))
            body.curve(to: NSPoint(x: 2.0, y: 12.6),                       // the jaw back to the snout
                       controlPoint1: NSPoint(x: 2.6, y: 11.9), controlPoint2: NSPoint(x: 2.1, y: 12.2))
            body.close()
            base.set(); body.fill()

            // Form: a shaded belly and dewlap, a lit ridge along the back, and
            // the dark bands an iguana carries across its flanks.
            ctx.saveGraphicsState(); body.addClip()
            shade.set()
            let belly = NSBezierPath()
            belly.move(to: NSPoint(x: 2.4, y: 11.6))
            belly.curve(to: NSPoint(x: 21.6, y: 11.4),
                        controlPoint1: NSPoint(x: 8.0, y: 10.6), controlPoint2: NSPoint(x: 17.4, y: 9.8))
            belly.line(to: NSPoint(x: 21.6, y: 7.0)); belly.line(to: NSPoint(x: 2.4, y: 7.0)); belly.close()
            belly.fill()
            shade.withAlphaComponent(0.55).set()
            for x in [CGFloat(12.4), 15.4, 18.4] {
                let band = NSBezierPath()
                band.move(to: NSPoint(x: x, y: 15.6))
                band.curve(to: NSPoint(x: x - 1.0, y: 10.0),
                           controlPoint1: NSPoint(x: x - 0.2, y: 13.6), controlPoint2: NSPoint(x: x - 1.1, y: 11.8))
                band.lineWidth = 1.2; band.lineCapStyle = .round; band.stroke()
            }
            highlight.withAlphaComponent(0.6).set()
            let backLight = NSBezierPath()
            backLight.move(to: NSPoint(x: 10.4, y: 14.6))
            backLight.curve(to: NSPoint(x: 20.0, y: 13.4),
                            controlPoint1: NSPoint(x: 13.6, y: 15.2), controlPoint2: NSPoint(x: 18.4, y: 14.8))
            backLight.lineWidth = 1.0; backLight.lineCapStyle = .round; backLight.stroke()
            ctx.restoreGraphicsState()
            // The dewlap's edge, so the flap reads as hanging from the throat
            // rather than as more belly.
            deep.withAlphaComponent(0.7).set()
            let flap = NSBezierPath()
            flap.move(to: NSPoint(x: 8.8, y: 9.6))
            flap.curve(to: NSPoint(x: 5.4, y: 8.4),
                       controlPoint1: NSPoint(x: 8.2, y: 8.9), controlPoint2: NSPoint(x: 6.8, y: 8.2))
            flap.curve(to: NSPoint(x: 3.2, y: 11.2),
                       controlPoint1: NSPoint(x: 4.2, y: 8.6), controlPoint2: NSPoint(x: 3.3, y: 10.0))
            flap.lineWidth = 0.5; flap.lineCapStyle = .round; flap.stroke()

            // The dorsal crest: a row of separate spines from the back of the
            // head down the spine, tallest at the neck, set on the back curve so
            // they follow the spine.
            func backPoint(_ t: CGFloat) -> NSPoint {
                let segments: [(NSPoint, NSPoint, NSPoint, NSPoint)] = [
                    (NSPoint(x: 8.4, y: 14.9), NSPoint(x: 11.6, y: 15.0),
                     NSPoint(x: 14.2, y: 15.6), NSPoint(x: 16.4, y: 15.4)),
                    (NSPoint(x: 16.4, y: 15.4), NSPoint(x: 18.6, y: 15.1),
                     NSPoint(x: 20.6, y: 14.2), NSPoint(x: 21.2, y: 12.6)),
                ]
                let scaled = t * CGFloat(segments.count)
                let index = min(Int(scaled), segments.count - 1)
                let local = scaled - CGFloat(index)
                let (p0, c1, c2, p3) = segments[index]
                let u = 1 - local
                let b0: CGFloat = u * u * u, b1: CGFloat = 3 * u * u * local
                let b2: CGFloat = 3 * u * local * local, b3: CGFloat = local * local * local
                return NSPoint(x: b0 * p0.x + b1 * c1.x + b2 * c2.x + b3 * p3.x,
                               y: b0 * p0.y + b1 * c1.y + b2 * c2.y + b3 * p3.y)
            }

            let spines = 10
            let comb = NSBezierPath()
            for spine in 0..<spines {
                let t0 = CGFloat(spine) / CGFloat(spines)
                let t1 = CGFloat(spine + 1) / CGFloat(spines)
                let root = backPoint(t0), next = backPoint(t1)
                // Tall at the neck, down to nubs at the rump.
                let height = 2.6 - 2.0 * t0
                let dx = next.x - root.x, dy = next.y - root.y
                let length = max(sqrt(dx * dx + dy * dy), 0.001)
                let normal = NSPoint(x: -dy / length, y: dx / length)
                // Each spine its own narrow triangle, raked back towards the
                // tail, with a gap of back between it and the next.
                let foot = NSPoint(x: root.x + dx * 0.15, y: root.y + dy * 0.15 - 0.4)
                let heel = NSPoint(x: root.x + dx * 0.75, y: root.y + dy * 0.75 - 0.4)
                let tip = NSPoint(x: root.x + dx * 0.7 + normal.x * height, y: root.y + dy * 0.7 + normal.y * height)
                comb.move(to: foot); comb.line(to: tip); comb.line(to: heel); comb.close()
            }
            highlight.set(); comb.fill()
            deep.set(); comb.lineWidth = 0.35; comb.lineJoinStyle = .round; comb.stroke()

            // MARK: the head

            // The eye: small, round and set high, with a ring of lid around it.
            // The iris is the accept-dns light.
            let eye = NSPoint(x: 5.4, y: 13.7)
            shade.set()
            NSBezierPath(ovalIn: NSRect(x: eye.x - 1.4, y: eye.y - 1.4, width: 2.8, height: 2.8)).fill()
            NSColor(white: 0.97, alpha: 1).set()
            NSBezierPath(ovalIn: NSRect(x: eye.x - 1.05, y: eye.y - 1.05, width: 2.1, height: 2.1)).fill()
            (eyeLit ? CharacterIcon.dnsCyan
                    : NSColor(srgbRed: 0.30, green: 0.34, blue: 0.42, alpha: 1)).set()
            NSBezierPath(ovalIn: NSRect(x: eye.x - 0.8, y: eye.y - 0.8, width: 1.6, height: 1.6)).fill()
            NSColor(white: 0.08, alpha: 1).set()
            NSBezierPath(ovalIn: NSRect(x: eye.x - 0.45, y: eye.y - 0.45, width: 0.9, height: 0.9)).fill()
            NSColor.white.set()
            NSBezierPath(ovalIn: NSRect(x: eye.x + 0.2, y: eye.y + 0.35, width: 0.45, height: 0.45)).fill()

            // The cheek shield: the big round scale below the ear.
            let shield = NSBezierPath(ovalIn: NSRect(x: 7.3, y: 11.2, width: 1.9, height: 1.9))
            highlight.set(); shield.fill()
            deep.withAlphaComponent(0.6).set(); shield.lineWidth = 0.35; shield.stroke()

            // The near pair of legs, drawn over the body, set out to the side
            // and bent at the elbow the way a lizard holds itself up.
            leg(hip: NSPoint(x: 17.6, y: 10.0), knee: NSPoint(x: 19.4, y: 7.4),
                foot: NSPoint(x: 18.0, y: branchY(18.0) + 1.0), thickness: 1.6, color: shade)
            leg(hip: NSPoint(x: 9.8, y: 10.0), knee: NSPoint(x: 8.0, y: 7.4),
                foot: NSPoint(x: 9.0, y: branchY(9.0) + 1.0), thickness: 1.6, color: shade)

            // Mouth: a short, slightly downturned line back from the snout.
            deep.withAlphaComponent(0.8).set()
            let mouth = NSBezierPath()
            mouth.move(to: NSPoint(x: 2.2, y: 12.4))
            mouth.curve(to: NSPoint(x: 6.8, y: 12.1),
                        controlPoint1: NSPoint(x: 3.8, y: 11.9), controlPoint2: NSPoint(x: 5.4, y: 11.9))
            mouth.lineWidth = 0.5; mouth.lineCapStyle = .round; mouth.stroke()

            // MARK: the tongue

            let extent = lick.map { $0 > 0 && $0 < iguanaLickDuration ? tongueExtent(lickAt: $0, wrapped: tongue) : (tongue ? 1 : 0) }
                ?? (tongue ? 1 : 0)
            guard extent > 0 else { return }
            // Out of the snout and round the branch ahead: the wrap is what says
            // "caught", where a straight line just says "pointing".
            let catchPoint = NSPoint(x: 1.7, y: branchY(1.7))
            let tonguePink = NSColor(srgbRed: 0.95, green: 0.38, blue: 0.52, alpha: 1)
            let tongueDeep = NSColor(srgbRed: 0.78, green: 0.24, blue: 0.40, alpha: 1)
            let wrapRadius = branchThickness / 2 + 0.55

            func strokeTongue(_ path: NSBezierPath) {
                path.lineCapStyle = .round; path.lineJoinStyle = .round
                path.lineWidth = 1.0; tongueDeep.set(); path.stroke()
                path.lineWidth = 0.55; tonguePink.set(); path.stroke()
            }

            if tongue && extent >= 1 {
                let shot = NSBezierPath()
                shot.move(to: NSPoint(x: 2.1, y: 12.4))
                shot.curve(to: NSPoint(x: catchPoint.x + 1.55, y: catchPoint.y + 0.6),
                           controlPoint1: NSPoint(x: 2.4, y: 11.4), controlPoint2: NSPoint(x: 2.0, y: 9.4))
                shot.appendArc(withCenter: catchPoint, radius: wrapRadius,
                               startAngle: 20, endAngle: -300, clockwise: true)
                strokeTongue(shot)
                // Past the wrap's right side, which goes behind the wood.
                branchOver(from: -0.5 - shift, to: catchPoint.x + wrapRadius + 0.7)
                let curlBack = NSBezierPath()
                curlBack.appendArc(withCenter: catchPoint, radius: wrapRadius,
                                   startAngle: 190, endAngle: 60, clockwise: true)
                strokeTongue(curlBack)
                return
            }

            // Mid-lick: the tongue as points along its path, drawn only as far
            // as `extent` of its length, with the club tip a real tongue has.
            func cubic(_ p0: NSPoint, _ p1: NSPoint, _ p2: NSPoint, _ p3: NSPoint, steps: Int) -> [NSPoint] {
                (0...steps).map { k in
                    let t = CGFloat(k) / CGFloat(steps), u = 1 - t
                    // Bernstein weights, named so the type checker need not solve one long expression.
                    let b0: CGFloat = u * u * u, b1: CGFloat = 3 * u * u * t
                    let b2: CGFloat = 3 * u * t * t, b3: CGFloat = t * t * t
                    let x: CGFloat = b0 * p0.x + b1 * p1.x + b2 * p2.x + b3 * p3.x
                    let y: CGFloat = b0 * p0.y + b1 * p1.y + b2 * p2.y + b3 * p3.y
                    return NSPoint(x: x, y: y)
                }
            }
            var points: [NSPoint]
            // Where the wrap passes in front of the branch (the curl back over it).
            var frontFrom: Int?
            if tongue {
                points = cubic(NSPoint(x: 2.1, y: 12.4), NSPoint(x: 2.4, y: 11.4), NSPoint(x: 2.0, y: 9.4),
                               NSPoint(x: catchPoint.x + 1.55, y: catchPoint.y + 0.6), steps: 24)
                let arcSteps = 64
                for k in 1...arcSteps {
                    let deg = 20 - 320 * CGFloat(k) / CGFloat(arcSteps)
                    if deg <= -170 && frontFrom == nil { frontFrom = points.count - 1 }
                    points.append(NSPoint(x: catchPoint.x + wrapRadius * cos(deg * .pi / 180),
                                          y: catchPoint.y + wrapRadius * sin(deg * .pi / 180)))
                }
            } else {
                // Free: out past the snout and curling up into the air ahead of it.
                points = cubic(NSPoint(x: 2.1, y: 12.4), NSPoint(x: 1.0, y: 12.6), NSPoint(x: 0.4, y: 14.0),
                               NSPoint(x: 0.8, y: 15.8), steps: 20)
                points += cubic(NSPoint(x: 0.8, y: 15.8), NSPoint(x: 1.1, y: 17.3), NSPoint(x: 2.0, y: 17.9),
                                NSPoint(x: 2.6, y: 17.2), steps: 16).dropFirst()
            }
            var lengths: [CGFloat] = [0]
            for k in 1..<points.count { lengths.append(lengths[k - 1] + hypot(points[k].x - points[k - 1].x, points[k].y - points[k - 1].y)) }
            let reach = extent * lengths.last!
            var shown: [NSPoint] = [points[0]]
            for k in 1..<points.count {
                if lengths[k] <= reach { shown.append(points[k]); continue }
                let f = (reach - lengths[k - 1]) / max(0.0001, lengths[k] - lengths[k - 1])
                shown.append(NSPoint(x: points[k - 1].x + (points[k].x - points[k - 1].x) * f,
                                     y: points[k - 1].y + (points[k].y - points[k - 1].y) * f))
                break
            }
            func polyline(_ pts: ArraySlice<NSPoint>) -> NSBezierPath {
                let p = NSBezierPath(); p.move(to: pts.first!)
                for q in pts.dropFirst() { p.line(to: q) }
                return p
            }
            strokeTongue(polyline(shown[...]))
            if let front = frontFrom, shown.count > front + 1 {
                // Past the wrap's right side, which goes behind the wood.
                branchOver(from: -0.5 - shift, to: catchPoint.x + wrapRadius + 0.7)
                strokeTongue(polyline(shown[front...]))
            }
            // The club tip.
            let tip = shown.last!
            let club = NSBezierPath(ovalIn: NSRect(x: tip.x - 0.6, y: tip.y - 0.6, width: 1.2, height: 1.2))
            tonguePink.set(); club.fill()
            tongueDeep.set(); club.lineWidth = 0.3; club.stroke()
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
    // APOLLO: an Apollo Twin's face — the monitor knob with its tick arc is
    // the mouth, and two squircle buttons above it are the eyes. The arc runs
    // from bottom-left over the top to bottom-right, ticks lighting green with
    // the level. Everything dims when the level cannot be changed.
    /// How long Apollo's once-a-minute blink lasts, the same 550 ms as Archimedes'.
    public static let apolloBlinkDuration: TimeInterval = 0.55

    /// How shut Apollo's eyes are `t` seconds into his blink, 0 open to 1 shut:
    /// a quick close, a beat shut, a slower open.
    public static func apolloBlinkClosure(at t: TimeInterval) -> CGFloat {
        let closing = 0.14, hold = 0.05, opening = 0.36
        if t <= 0 { return 0 }
        if t < closing { let p = t / closing; return CGFloat(p * p * p) }
        if t <= closing + hold { return 1 }
        if t < closing + hold + opening { let p = (t - closing - hold) / opening; return CGFloat(pow(1 - p, 3)) }
        return 0
    }

    /// - Parameters:
    ///   - blink: 0 eyes open … 1 shut (see `apolloBlinkClosure`).
    ///   - tickColor: the lit ticks' colour while online — e.g. red for muted.
    public static func apollo(level: CGFloat, online: Bool, blink: CGFloat = 0,
                              tickColor: NSColor = .systemGreen) -> NSImage {
        canvas(width: 22, height: 22) { ctx in
            let grey = online ? body : NSColor(white: 0.45, alpha: 1)
            let dim = NSColor(white: 0.62, alpha: 0.35)
            let lit = online ? tickColor : NSColor(white: 0.55, alpha: 1)
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
            // eyes: two low, wide squircle buttons with small dark pupils. A
            // blink squashes each button down to a slit and hides the pupil.
            let shut = max(0, min(1, blink))
            let eyeH = 2.8 - 2.0 * shut
            for x in [CGFloat(3.4), CGFloat(13.4)] {
                grey.set()
                NSBezierPath(roundedRect: NSRect(x: x, y: 19.4 - eyeH / 2, width: 5.2, height: eyeH),
                             xRadius: min(1.3, eyeH / 2), yRadius: min(1.3, eyeH / 2)).fill()
                guard shut < 0.5 else { continue }
                cut(ctx, NSBezierPath(ovalIn: NSRect(x: x + 1.95, y: 18.75, width: 1.3, height: 1.3)))
                NSColor.black.withAlphaComponent(online ? 1 : 0.5).set()
                NSBezierPath(ovalIn: NSRect(x: x + 1.95, y: 18.75, width: 1.3, height: 1.3)).fill()
            }
        }
    }

    /// Homestead's house: a cottage whose windows are the lights, with a fan
    /// turning in one of them when a fan is running. Deliberately chimney-free —
    /// a chimney reads as heating, which this app does not control.
    ///
    /// Drawn at the owl's level of detail, and on the same assumption: a Retina
    /// bar. Half-point sills, mullions and shingle courses land on half pixels
    /// at 2x and hold. Anyone on a non-Retina display can pick the plain Dot in
    /// Icon ▸, which is what it is there for.
    ///
    /// - Parameters:
    ///   - weather: drawn around the house — sky over the roof, rain or snow
    ///     beside the walls — never across the windows. Nil is a clear,
    ///     empty sky, the glyph as it always was. Only a reachable house has
    ///     weather: a hollow one is not reporting any.
    ///   - night: the moon instead of the sun.
    ///   - door: progress through the once-a-minute welcome, 0 … 1: the front
    ///     door swings open a crack on its left hinge and shuts again, warm
    ///     light in the gap when any light is on. 0 and 1 are the resting
    ///     glyph; an unreachable or unconfigured house ignores it.
    ///   - weatherPhase: how far through the weather's loop of
    ///     `houseWeatherLoopDuration` seconds, 0 ..< 1 (wrapped, so 1 is 0).
    ///     The sun gleams, clouds drift or pass behind the roof, rain and snow
    ///     fall, fog banks slide, gusts blow out and fade, and a storm's bolt
    ///     flickers now and then. 0 is the still glyph.
    ///   - intensity: how hard it is raining or snowing, 0 (a drizzle, a few
    ///     flakes) … 1 (a downpour): the number of drops, and how fast rain
    ///     falls. Nil is the weather's own default — the still glyph's count.
    ///     Heavy rain is never drawn lighter than its default.
    public static func house(lightsOn: Int, fanOn: Bool, reachable: Bool, configured: Bool,
                             weather: HouseWeather? = nil, night: Bool = false, door doorProgress: CGFloat = 0,
                             weatherPhase: CGFloat = 0, intensity: CGFloat? = nil) -> NSImage {
        let motion = SkyMotion(phase: weatherPhase, intensity: intensity)
        return
        canvas(width: 26, height: 22) { ctx in
            let wallLight = NSColor(srgbRed: 0.96, green: 0.93, blue: 0.86, alpha: 1)
            let wallShade = NSColor(srgbRed: 0.85, green: 0.81, blue: 0.72, alpha: 1)
            let roofColor = NSColor(srgbRed: 0.33, green: 0.42, blue: 0.64, alpha: 1)
            let roofShade = NSColor(srgbRed: 0.24, green: 0.31, blue: 0.51, alpha: 1)
            let frame = NSColor(srgbRed: 0.28, green: 0.33, blue: 0.45, alpha: 1)
            let glassLit = NSColor(srgbRed: 1, green: 0.79, blue: 0.29, alpha: 1)
            let glassLitTop = NSColor(srgbRed: 1, green: 0.90, blue: 0.62, alpha: 1)
            let glassDark = NSColor(srgbRed: 0.27, green: 0.31, blue: 0.42, alpha: 1)
            let doorColor = NSColor(srgbRed: 0.52, green: 0.35, blue: 0.20, alpha: 1)
            let knob = NSColor(srgbRed: 1, green: 0.84, blue: 0.47, alpha: 1)
            let dim = NSColor(white: 0.62, alpha: 1)

            let wall = NSRect(x: 5.0, y: 2.4, width: 16.0, height: 9.8)
            let eaves = wall.maxY
            let apex = NSPoint(x: 13, y: 20.0)

            let roof = NSBezierPath()
            roof.move(to: NSPoint(x: 2.2, y: eaves))
            roof.line(to: NSPoint(x: apex.x - 0.9, y: apex.y - 0.5))
            roof.curve(to: NSPoint(x: apex.x + 0.9, y: apex.y - 0.5),
                       controlPoint1: NSPoint(x: 12.6, y: apex.y + 0.4),
                       controlPoint2: NSPoint(x: 13.4, y: apex.y + 0.4))
            roof.line(to: NSPoint(x: 23.8, y: eaves))
            roof.close()

            let silhouette = NSBezierPath()
            silhouette.appendRect(wall)
            silhouette.append(roof)
            silhouette.windingRule = .nonZero

            // Unconfigured or unreachable: one flat statement, no detail to read.
            guard configured else {
                dim.withAlphaComponent(0.5).set()
                silhouette.fill()
                return
            }
            guard reachable else {
                // Hollow, not dashed: an empty house reads instantly as
                // "nobody home", where dashes turn to noise at this size.
                dim.withAlphaComponent(0.9).set()
                silhouette.lineWidth = 1.6
                silhouette.lineJoinStyle = .round
                silhouette.stroke()
                return
            }

            if let weather { drawSky(weather, night: night, ctx: ctx, motion: motion) }

            // Walls, lit from above.
            wallLight.set()
            NSBezierPath(rect: wall).fill()
            wallShade.set()
            NSBezierPath(rect: NSRect(x: wall.minX, y: wall.minY, width: wall.width, height: 2.2)).fill()

            // Roof, with a lighter sunward face and two shingle courses.
            roofColor.set()
            roof.fill()
            ctx.saveGraphicsState()
            roof.addClip()
            roofShade.set()
            NSBezierPath(rect: NSRect(x: 13, y: eaves, width: 11, height: 9)).fill()
            NSColor(white: 1, alpha: 0.16).set()
            for course in [CGFloat(2.6), 5.2] {
                let line = NSBezierPath()
                line.move(to: NSPoint(x: 2, y: eaves + course))
                line.line(to: NSPoint(x: 24, y: eaves + course))
                line.lineWidth = 0.5
                line.stroke()
            }
            ctx.restoreGraphicsState()

            // The eaves line, which is what makes the roof sit *on* the wall.
            roofShade.set()
            NSBezierPath(rect: NSRect(x: 2.2, y: eaves - 0.5, width: 21.6, height: 0.9)).fill()

            // Windows: frame, glass, a sill, and a mullion cross.
            let windows = [NSRect(x: 6.4, y: 6.6, width: 4.6, height: 4.4),
                           NSRect(x: 15.0, y: 6.6, width: 4.6, height: 4.4)]
            for (index, window) in windows.enumerated() {
                let isLit = lightsOn >= index + 1
                frame.set()
                NSBezierPath(rect: window.insetBy(dx: -0.5, dy: -0.5)).fill()

                let glass = window
                (isLit ? glassLit : glassDark).set()
                NSBezierPath(rect: glass).fill()
                if isLit {
                    glassLitTop.set()
                    NSBezierPath(rect: NSRect(x: glass.minX, y: glass.midY, width: glass.width, height: glass.height / 2)).fill()
                }

                // Mullions — except in the window the fan occupies, where they
                // would read as more blades and the fan would stop being legible.
                let holdsFan = fanOn && index == 1
                (isLit ? frame : NSColor(white: 0.45, alpha: 0.8)).set()
                if !holdsFan {
                let cross = NSBezierPath()
                cross.move(to: NSPoint(x: glass.midX, y: glass.minY)); cross.line(to: NSPoint(x: glass.midX, y: glass.maxY))
                cross.move(to: NSPoint(x: glass.minX, y: glass.midY)); cross.line(to: NSPoint(x: glass.maxX, y: glass.midY))
                cross.lineWidth = 0.5
                cross.stroke()
                }

                // Sill.
                wallShade.set()
                NSBezierPath(rect: NSRect(x: window.minX - 1.0, y: window.minY - 1.1, width: window.width + 2.0, height: 0.6)).fill()
            }

            // Door: a panelled slab with a step and a knob.
            let door = NSRect(x: 11.4, y: 2.4, width: 3.2, height: 5.0)
            let doorPath = NSBezierPath()
            doorPath.move(to: NSPoint(x: door.minX, y: door.minY))
            doorPath.line(to: NSPoint(x: door.minX, y: door.maxY - 0.9))
            doorPath.curve(to: NSPoint(x: door.maxX, y: door.maxY - 0.9),
                           controlPoint1: NSPoint(x: door.minX, y: door.maxY + 0.5),
                           controlPoint2: NSPoint(x: door.maxX, y: door.maxY + 0.5))
            doorPath.line(to: NSPoint(x: door.maxX, y: door.minY))
            doorPath.close()
            // Swinging in on its left hinge, the slab foreshortens towards the
            // hinge and the doorway behind it shows: lamplight if any light is
            // on, the dark hall if not.
            let ajar = houseDoorOpening(at: doorProgress.isFinite ? doorProgress : 0)
            if ajar > 0 {
                (lightsOn > 0 ? glassLit : glassDark).set()
                doorPath.fill()
                if lightsOn > 0 {   // the light falls brightest at the floor
                    glassLitTop.withAlphaComponent(0.8).set()
                    NSBezierPath(rect: NSRect(x: door.minX, y: door.minY, width: door.width, height: 1.4)).fill()
                }
            }
            ctx.saveGraphicsState()
            if ajar > 0 {
                let swing = NSAffineTransform()
                swing.translateX(by: door.minX, yBy: 0)
                swing.scaleX(by: 1 - 0.62 * ajar, yBy: 1)
                swing.translateX(by: -door.minX, yBy: 0)
                swing.concat()
            }
            doorColor.set()
            doorPath.fill()
            NSColor(white: 0, alpha: 0.18).set()
            NSBezierPath(rect: NSRect(x: door.midX - 0.25, y: door.minY + 0.6, width: 0.5, height: 3.2)).fill()
            if ajar > 0 {   // the swinging edge catches the light
                NSColor(white: 1, alpha: 0.22 * ajar).set()
                NSBezierPath(rect: NSRect(x: door.maxX - 0.6, y: door.minY, width: 0.6, height: door.height - 0.9)).fill()
            }
            knob.set()
            NSBezierPath(ovalIn: NSRect(x: door.maxX - 1.1, y: door.minY + 2.1, width: 0.7, height: 0.7)).fill()
            ctx.restoreGraphicsState()
            wallShade.set()
            NSBezierPath(rect: NSRect(x: door.minX - 0.9, y: wall.minY - 0.5, width: door.width + 1.8, height: 0.6)).fill()

            if let weather { drawWeatherFront(weather, ctx: ctx, motion: motion) }

            guard fanOn else { return }
            // Blades in the right window, contrasting with the glass behind them.
            (lightsOn >= 2 ? frame : glassLit).set()
            let right = windows[1]
            let centre = NSPoint(x: right.midX, y: right.midY)
            let radius: CGFloat = 2.0
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
            // Hub, so the three blades read as one spinning thing.
            NSBezierPath(ovalIn: NSRect(x: centre.x - 0.45, y: centre.y - 0.45, width: 0.9, height: 0.9)).fill()
        }
    }

    /// How long Gertie's once-a-minute welcome lasts: the door opens a crack and shuts.
    public static let houseDoorDuration: TimeInterval = 1.2

    /// How far ajar Gertie's front door is at `progress` (0 … 1) through her
    /// welcome, 0 shut to 1 open a crack: eased open, held a beat, eased shut.
    public static func houseDoorOpening(at progress: CGFloat) -> CGFloat {
        let opening: CGFloat = 0.3, hold: CGFloat = 0.3, closing: CGFloat = 0.36
        let p = progress
        if p <= 0 { return 0 }
        if p < opening { let x = p / opening; return x * x * (3 - 2 * x) }
        if p <= opening + hold { return 1 }
        if p < opening + hold + closing { let x = (p - opening - hold) / closing; return 1 - x * x * (3 - 2 * x) }
        return 0
    }

    // MENU CRANE: Mendoza's head side-on — red cap, two big touching eyes, a long beak to the
    // right with a clamshell grab bucket hanging from a ring near its tip. The bucket opens
    // while the panel is up, snaps shut on a copy, and hangs open and empty on no results.
    public enum CraneState: Sendable { case idle, searching, grabbed, miss }

    static let craneRed = NSColor(red: 0.88, green: 0.27, blue: 0.23, alpha: 1)
    static let craneBeak = NSColor(red: 0.89, green: 0.78, blue: 0.56, alpha: 1)
    static let craneBucket = NSColor(red: 0.97, green: 0.78, blue: 0.22, alpha: 1)
    static let craneInk = NSColor(white: 0.12, alpha: 1)

    /// How long Mendoza's once-a-minute grab lasts: the bucket drops open,
    /// snaps shut, and lifts back to where it hangs.
    public static let menuCraneGrabDuration: TimeInterval = 1.4

    /// Where the bucket is `t` seconds into the grab.
    public struct CraneGrab: Equatable, Sendable {
        /// 0 hanging where it rests … 1 lowered as far as it goes.
        public var drop: CGFloat
        /// 0 shut … 1 jaws wide open.
        public var jaw: CGFloat
        /// Eyes closed in happy crescents: from the snap until the bucket is home.
        public var happy: Bool
        public static let rest = CraneGrab(drop: 0, jaw: 0, happy: false)
    }

    /// The grab's phases: lower with the jaws opening, snap shut at the bottom,
    /// a beat, lift, and a short settle so the last frame is the resting glyph.
    public static func craneGrab(at t: TimeInterval) -> CraneGrab {
        let lower = 0.4, snap = 0.1, hold = 0.2, lift = 0.5
        func smooth(_ x: Double) -> CGFloat { let x = min(max(x, 0), 1); return CGFloat(x * x * (3 - 2 * x)) }
        guard t > 0, t < menuCraneGrabDuration else { return .rest }
        if t < lower { return CraneGrab(drop: smooth(t / lower), jaw: smooth(t / (lower * 0.75)), happy: false) }
        if t < lower + snap { let x = (t - lower) / snap; return CraneGrab(drop: 1, jaw: CGFloat(pow(1 - x, 3)), happy: false) }
        if t < lower + snap + hold { return CraneGrab(drop: 1, jaw: 0, happy: true) }
        if t < lower + snap + hold + lift { return CraneGrab(drop: 1 - smooth((t - lower - snap - hold) / lift), jaw: 0, happy: true) }
        return .rest
    }

    /// - Parameter grab: seconds into the once-a-minute grab (see
    ///   `craneGrab(at:)`), or nil when the bucket just hangs.
    public static func menuCrane(state: CraneState, grab: TimeInterval? = nil) -> NSImage {
        let grab = grab.map(craneGrab(at:)) ?? .rest
        return canvas(width: 22, height: 22) { _ in
            let line: CGFloat = 0.9
            func inked(_ p: NSBezierPath, _ fill: NSColor) {
                fill.set(); p.fill()
                craneInk.set(); p.lineWidth = line; p.lineJoinStyle = .round; p.stroke()
            }
            func clipped(to p: NSBezierPath, _ fill: NSColor, _ rect: NSRect) {
                NSGraphicsContext.saveGraphicsState()
                p.addClip(); fill.set(); NSBezierPath(rect: rect).fill()
                NSGraphicsContext.restoreGraphicsState()
                craneInk.set(); p.lineWidth = line; p.stroke()
            }

            // Neck, rising from the bottom-left edge, with its white collar.
            let neck = NSBezierPath()
            neck.move(to: NSPoint(x: 1.2, y: -1))
            neck.curve(to: NSPoint(x: 2.6, y: 11), controlPoint1: NSPoint(x: 0.8, y: 4), controlPoint2: NSPoint(x: 1.2, y: 8))
            neck.line(to: NSPoint(x: 8.6, y: 10))
            neck.curve(to: NSPoint(x: 7.4, y: -1), controlPoint1: NSPoint(x: 6.6, y: 7), controlPoint2: NSPoint(x: 6.8, y: 3))
            neck.close()
            inked(neck, body)
            clipped(to: neck, .white, NSRect(x: 0, y: 1.2, width: 10, height: 1.6))

            // Head and red cap.
            let head = NSBezierPath(ovalIn: NSRect(x: 1.2, y: 8.8, width: 11, height: 11))
            inked(head, body)
            clipped(to: head, craneRed, NSRect(x: 0, y: 17.4, width: 14, height: 5))

            // Beak, then the eyes on top of it.
            let beak = NSBezierPath()
            beak.move(to: NSPoint(x: 8.2, y: 12.6))
            beak.line(to: NSPoint(x: 21.4, y: 10.8))
            beak.line(to: NSPoint(x: 8.6, y: 10.0))
            beak.close()
            inked(beak, craneBeak)

            let eyes = [NSPoint(x: 5.6, y: 14.8), NSPoint(x: 9.8, y: 15.2)]
            for c in eyes { inked(NSBezierPath(ovalIn: NSRect(x: c.x - 2.7, y: c.y - 2.7, width: 5.4, height: 5.4)), .white) }
            if state == .grabbed || grab.happy {
                for c in eyes {   // happy closed crescents
                    let arc = NSBezierPath()
                    arc.appendArc(withCenter: NSPoint(x: c.x, y: c.y - 0.6), radius: 1.4, startAngle: 20, endAngle: 160)
                    arc.lineWidth = 1; arc.lineCapStyle = .round
                    craneInk.set(); arc.stroke()
                }
            } else {
                let look: [CGSize]
                switch state {
                case .searching: look = [CGSize(width: 0.9, height: -1.1), CGSize(width: 0.9, height: -1.1)]
                case .miss: look = [CGSize(width: -1.0, height: 0.8), CGSize(width: 1.0, height: -0.6)]
                default:   // following the bucket down as it drops
                    let d = CGSize(width: 1.1 - 0.2 * grab.drop, height: -1.1 * grab.drop)
                    look = [d, d]
                }
                craneInk.set()
                for (c, d) in zip(eyes, look) {
                    NSBezierPath(ovalIn: NSRect(x: c.x + d.width - 0.8, y: c.y + d.height - 0.8, width: 1.6, height: 1.6)).fill()
                }
            }

            // Ring on the beak, cable, bucket.
            let ringC = NSPoint(x: 17.6, y: 10.6)
            let ring = NSBezierPath(ovalIn: NSRect(x: ringC.x - 1.1, y: ringC.y - 1.1, width: 2.2, height: 2.2))
            ring.lineWidth = 0.9; NSColor(white: 0.55, alpha: 1).set(); ring.stroke()
            let open = state == .searching || state == .miss
            let top: CGFloat = (open ? 6.8 : 7.8) - 2.2 * grab.drop
            let cable = NSBezierPath()
            cable.move(to: NSPoint(x: ringC.x, y: ringC.y - 1.1)); cable.line(to: NSPoint(x: ringC.x, y: top))
            cable.lineWidth = 0.8; craneInk.set(); cable.stroke()
            if open || grab.jaw > 0 {
                // Each jaw swings between its half of the shut bucket and wide open.
                let shut: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: 3.4, y: 0), CGPoint(x: 2.2, y: -4.6), CGPoint(x: 0, y: -4.6)]
                let wide: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: 3.8, y: -1.4), CGPoint(x: 2.6, y: -5.2), CGPoint(x: 0.6, y: -3.4)]
                let k = open ? 1 : grab.jaw
                for side: CGFloat in [-1, 1] {
                    let jaw = NSBezierPath()
                    for (i, (a, b)) in zip(shut, wide).enumerated() {
                        let pt = NSPoint(x: ringC.x + side * (a.x + (b.x - a.x) * k), y: top + a.y + (b.y - a.y) * k)
                        if i == 0 { jaw.move(to: pt) } else { jaw.line(to: pt) }
                    }
                    jaw.close()
                    inked(jaw, craneBucket)
                }
            } else {
                let bucket = NSBezierPath()
                bucket.move(to: NSPoint(x: ringC.x - 3.4, y: top))
                bucket.line(to: NSPoint(x: ringC.x + 3.4, y: top))
                bucket.line(to: NSPoint(x: ringC.x + 2.2, y: top - 4.6))
                bucket.line(to: NSPoint(x: ringC.x - 2.2, y: top - 4.6))
                bucket.close()
                inked(bucket, craneBucket)
                let seam = NSBezierPath()
                seam.move(to: NSPoint(x: ringC.x, y: top)); seam.line(to: NSPoint(x: ringC.x, y: top - 4.6))
                seam.lineWidth = 0.7; craneInk.set(); seam.stroke()
            }
            if state == .miss {   // sweat drop beside the head
                let drop = NSBezierPath()
                drop.move(to: NSPoint(x: 13.6, y: 20.4))
                drop.curve(to: NSPoint(x: 13.6, y: 16.6), controlPoint1: NSPoint(x: 12.2, y: 18.2), controlPoint2: NSPoint(x: 12.4, y: 16.6))
                drop.curve(to: NSPoint(x: 13.6, y: 20.4), controlPoint1: NSPoint(x: 14.8, y: 16.6), controlPoint2: NSPoint(x: 15.0, y: 18.2))
                NSColor.systemBlue.set(); drop.fill()
            }
        }
    }
}

// MARK: - Caterpillar (SoundChain)

/// What SoundChain's caterpillar shows: processing (green), bypassed (grey) or an
/// error (red).
public enum CaterpillarState: Hashable, Sendable { case processing, bypassed, error }

extension CharacterIcon {
    /// SoundChain: a caterpillar in black headphones, drawn in a storybook style (ink
    /// outlines, soft shading). Its body is always five segments; each running effect
    /// puts a bright highlight on one, counting back from the head. Colour is the
    /// state. One 36x22pt canvas for every variant, so the bar never shifts. Drawn at
    /// 8x and downsampled to 2x and 1x bitmaps (smoother than drawing at bar size),
    /// and cached.
    ///
    /// - Parameter running: seconds into her once-a-minute run (see
    ///   `caterpillarRunDuration`), or nil standing still. Running frames
    ///   are not cached.
    public static func caterpillar(effects: Int, state: CaterpillarState, running: TimeInterval? = nil) -> NSImage {
        CaterpillarGlyph.image(effects: effects, state: state, running: running)
    }

    /// How long Carol's run lasts.
    public static let caterpillarRunDuration: TimeInterval = 1.0
}

/// Carol's run, as offsets for each part at a moment of it.
///
/// A caterpillar moves by a wave travelling from tail to head: each segment
/// lifts, swings forward and sets down just after the one behind it. Here
/// that wave runs at three strides a second; each segment's bob lags the one
/// behind it by a fixed phase, so the lift visibly ripples forward and ends at
/// the head. The feet scissor: alternate feet swing in opposite directions, so
/// while one is forward its neighbours are back. Everything ramps in over the
/// first tenth of a second and out over the last, so the run starts and stops
/// from the standing pose without a jump.
struct CaterpillarGait: Equatable {
    /// Strides per second.
    static let stride: Double = 3
    /// Phase lag between neighbouring parts, as a fraction of a stride.
    static let lag: Double = 0.16
    static let bobHeight: CGFloat = 0.75
    static let footSwing: CGFloat = 0.85

    let time: TimeInterval
    let duration: TimeInterval

    /// 0 standing, 1 at full stride.
    var strength: CGFloat {
        let ramp = 0.1
        return CGFloat(max(0, min(1, time / ramp, (duration - time) / ramp)))
    }

    /// Phase of part `index` (0 is the segment behind the head, rising toward
    /// the tail; the head is -1). Parts nearer the tail lead.
    private func phase(_ index: Int) -> Double {
        2 * .pi * (Self.stride * time + Double(index) * Self.lag)
    }

    /// How far part `index` is lifted. Only ever up: a bob, not a wobble.
    func bob(_ index: Int) -> CGFloat {
        strength * Self.bobHeight * CGFloat(max(0, sin(phase(index))))
    }

    /// How far foot `index` is swung forward (positive, toward the head) or back.
    func foot(_ index: Int) -> CGFloat {
        let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        return strength * Self.footSwing * side * CGFloat(sin(2 * .pi * Self.stride * time))
    }
}

/// The caterpillar's drawing. See `CharacterIcon.caterpillar(effects:state:)`.
private enum CaterpillarGlyph {
    typealias State = CaterpillarState

    static let bodySegments = 5
    static let size = NSSize(width: 36, height: 22)
    static let supersample: CGFloat = 8
    /// The artwork is laid out on a 28x22 grid spanning y 2.05…17.0; this scale and
    /// offset stretch it to fill the canvas.
    static let gridScale: CGFloat = 1.34
    static let gridOffset = NSPoint(x: -0.3, y: 1 - 2.05 * 1.34)

    private struct Key: Hashable { let lit: Int; let state: State }
    private static var cache: [Key: NSImage] = [:]

    static func image(effects: Int, state: State, running: TimeInterval? = nil) -> NSImage {
        let key = Key(lit: max(0, min(effects, bodySegments)), state: state)
        let gait = running.flatMap { t in
            t > 0 && t < CharacterIcon.caterpillarRunDuration
                ? CaterpillarGait(time: t, duration: CharacterIcon.caterpillarRunDuration) : nil
        }
        if gait == nil, let cached = cache[key] { return cached }
        let big = render(lit: key.lit, palette: Palette(state), gait: gait, scale: supersample)
        let image = NSImage(size: size)
        for scale in [2, 1] as [CGFloat] {
            if let rep = downsample(big, scale: scale) { image.addRepresentation(rep) }
        }
        image.isTemplate = false
        if gait == nil { cache[key] = image }
        return image
    }

    // MARK: Palette

    struct Palette {
        let light, mid, dark: NSColor          // lit segment / head shading
        static let ink = NSColor(red: 0.22, green: 0.14, blue: 0.09, alpha: 1)
        static let cheek = NSColor(red: 0.98, green: 0.66, blue: 0.68, alpha: 0.9)
        static let phones = NSColor(white: 0.07, alpha: 1)
        static let phonesSheen = NSColor(white: 0.42, alpha: 1)
        /// A faint light edge that keeps dark parts visible on a dark menu bar.
        static let rim = NSColor(white: 1, alpha: 0.85)

        init(_ state: State) {
            let base: NSColor
            switch state {
            case .processing: base = NSColor(red: 0.44, green: 0.74, blue: 0.33, alpha: 1)
            case .bypassed: base = NSColor(white: 0.64, alpha: 1)
            case .error: base = NSColor(red: 0.90, green: 0.33, blue: 0.26, alpha: 1)
            }
            let cream = NSColor(red: 0.97, green: 0.94, blue: 0.84, alpha: 1)
            light = base.blended(withFraction: 0.35, of: cream) ?? base
            mid = base
            dark = base.blended(withFraction: 0.30, of: .black) ?? base
        }
    }

    // MARK: Rendering

    private static func render(lit: Int, palette: Palette, gait: CaterpillarGait?, scale: CGFloat) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        ctx.shouldAntialias = true
        let t = NSAffineTransform()
        t.scale(by: scale)
        t.translateX(by: gridOffset.x, yBy: gridOffset.y)
        t.scale(by: gridScale)
        t.concat()
        draw(lit: lit, palette: palette, gait: gait)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func downsample(_ source: NSBitmapImageRep, scale: CGFloat) -> NSBitmapImageRep? {
        guard let cg = source.cgImage else { return nil }
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let out = context.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: out)
        rep.size = size
        return rep
    }

    /// Fills `path` with a top-left-lit gradient, then outlines it in ink.
    private static func shaded(_ path: NSBezierPath, light: NSColor, dark: NSColor, ink: CGFloat = 0.55) {
        NSGradient(starting: light, ending: dark)?.draw(in: path, angle: -60)
        Palette.ink.set()
        path.lineWidth = ink
        path.stroke()
    }

    // MARK: Headphones

    /// The band as one cubic from the near earpad, over the crown, down behind the far
    /// side of the head. It is drawn in two pieces split at `bandSplit`, a point above
    /// the head: the back piece before the head (so the head hides its end) and the
    /// front piece after it. Both are black with round caps, so the join is invisible.
    static let band = (p0: NSPoint(x: 17.4, y: 10.4), p1: NSPoint(x: 17.6, y: 17.6),
                       p2: NSPoint(x: 25.0, y: 18.2), p3: NSPoint(x: 24.8, y: 12.0))
    static let bandSplit: CGFloat = 0.6
    static let cupRect = NSRect(x: 16.1, y: 6.8, width: 3.4, height: 5.0)

    /// The part of the band's cubic between parameters `t0` and `t1` (de Casteljau).
    static func bandPath(from t0: CGFloat, to t1: CGFloat) -> NSBezierPath {
        func split(_ p: [NSPoint], at t: CGFloat) -> (left: [NSPoint], right: [NSPoint]) {
            func lerp(_ a: NSPoint, _ b: NSPoint) -> NSPoint { NSPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
            let a = lerp(p[0], p[1]), b = lerp(p[1], p[2]), c = lerp(p[2], p[3])
            let d = lerp(a, b), e = lerp(b, c), f = lerp(d, e)
            return ([p[0], a, d, f], [f, e, c, p[3]])
        }
        var pts = [band.p0, band.p1, band.p2, band.p3]
        pts = split(pts, at: t0).right
        pts = split(pts, at: t0 >= 1 ? 0 : (t1 - t0) / (1 - t0)).left
        let path = NSBezierPath()
        path.move(to: pts[0])
        path.curve(to: pts[3], controlPoint1: pts[1], controlPoint2: pts[2])
        path.lineCapStyle = .round
        return path
    }

    private static func draw(lit: Int, palette: Palette, gait: CaterpillarGait?) {
        let groundY: CGFloat = 3.2
        // The head rides last in the wave, after the segment behind it.
        let headBob = gait?.bob(-1) ?? 0

        // Light rims for the headphones go down first, so they show only against the
        // background (keeping the parts readable on a dark bar), never over the face.
        NSGraphicsContext.saveGraphicsState()
        lift(headBob)
        Palette.rim.set()
        let rimBand = bandPath(from: 0, to: 1)
        rimBand.lineWidth = 1.9; rimBand.stroke()
        let rimCup = NSBezierPath(roundedRect: cupRect.insetBy(dx: -0.3, dy: -0.3), xRadius: 1.6, yRadius: 1.6)
        rimCup.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Body: tail first so each segment overlaps the one behind it.
        let firstX: CGFloat = 15.4, spacing: CGFloat = 2.95
        for i in (0..<bodySegments).reversed() {
            let cx = firstX - CGFloat(i) * spacing
            let r: CGFloat = 3.25 - CGFloat(max(0, i - 2)) * 0.35
            let lift: CGFloat = (i % 2 == 0 ? 0.5 : 0) + (gait?.bob(i) ?? 0)
            let bottom = groundY + 0.6 + lift
            // Running, each foot swings forward and back (the head is to the
            // right) and leaves the ground as it comes forward.
            let swing = gait?.foot(i) ?? 0
            let footX = cx + swing, footY = groundY + max(0, swing) * 0.35

            // leg with a little round foot, rimmed in light so it reads on a dark bar
            let leg = NSBezierPath()
            leg.move(to: NSPoint(x: cx, y: bottom + 0.8))
            leg.line(to: NSPoint(x: footX, y: footY - 0.2))
            leg.lineCapStyle = .round
            let foot = NSBezierPath(ovalIn: NSRect(x: footX - 0.85, y: footY - 0.75, width: 1.7, height: 1.0))
            Palette.rim.set()
            leg.lineWidth = 1.45; leg.stroke()
            foot.lineWidth = 0.7; foot.stroke()
            Palette.ink.set()
            leg.lineWidth = 0.75; leg.stroke()
            foot.fill()

            let segment = NSBezierPath(ovalIn: NSRect(x: cx - r, y: bottom, width: r * 2, height: r * 2))
            shaded(segment, light: palette.light, dark: palette.dark)
            // each running effect: a bright highlight on top of its segment
            if i < lit {
                NSColor(white: 1, alpha: 0.85).set()
                NSBezierPath(ovalIn: NSRect(x: cx - r * 0.5, y: bottom + r * 1.25, width: r * 0.95, height: r * 0.5)).fill()
            }
        }

        // Head, face and headphones all bob together.
        NSGraphicsContext.saveGraphicsState()
        lift(headBob)

        // Back piece of the band: goes behind the head.
        Palette.phones.set()
        let back = bandPath(from: bandSplit, to: 1)
        back.lineWidth = 1.3; back.stroke()

        // Head.
        let head = NSBezierPath(ovalIn: NSRect(x: 16.6, y: 4.4, width: 10.2, height: 10.2))
        shaded(head, light: palette.light, dark: palette.dark, ink: 0.6)
        Palette.cheek.set()
        NSBezierPath(ovalIn: NSRect(x: 20.6, y: 6.2, width: 2.4, height: 1.5)).fill()

        // Eye: white, pupil, glint.
        let eye = NSBezierPath(ovalIn: NSRect(x: 22.3, y: 9.0, width: 2.7, height: 3.1))
        NSColor.white.set(); eye.fill()
        Palette.ink.set(); eye.lineWidth = 0.4; eye.stroke()
        NSBezierPath(ovalIn: NSRect(x: 23.5, y: 9.6, width: 1.3, height: 1.7)).fill()
        NSColor.white.set()
        NSBezierPath(ovalIn: NSRect(x: 24.0, y: 10.6, width: 0.5, height: 0.5)).fill()

        // Smile.
        Palette.ink.set()
        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: 22.4, y: 7.1))
        smile.curve(to: NSPoint(x: 25.6, y: 7.7), controlPoint1: NSPoint(x: 23.4, y: 5.9), controlPoint2: NSPoint(x: 25.0, y: 6.2))
        smile.lineWidth = 0.55; smile.lineCapStyle = .round; smile.stroke()

        // Front piece of the band and the near earpad, over the head.
        Palette.phones.set()
        let front = bandPath(from: 0, to: bandSplit)
        front.lineWidth = 1.3; front.stroke()
        let cup = NSBezierPath(roundedRect: cupRect, xRadius: 1.4, yRadius: 1.4)
        NSGradient(starting: Palette.phonesSheen, ending: Palette.phones)?.draw(in: cup, angle: -70)
        // sheen along the band
        Palette.phonesSheen.withAlphaComponent(0.8).set()
        let sheen = NSBezierPath()
        sheen.move(to: NSPoint(x: 19.0, y: 14.8))
        sheen.curve(to: NSPoint(x: 22.6, y: 16.4), controlPoint1: NSPoint(x: 19.8, y: 16.0), controlPoint2: NSPoint(x: 21.2, y: 16.5))
        sheen.lineWidth = 0.35; sheen.lineCapStyle = .round; sheen.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Shifts everything drawn after it up by `dy`, until the state is restored.
    private static func lift(_ dy: CGFloat) {
        guard dy != 0 else { return }
        let t = NSAffineTransform(); t.translateX(by: 0, yBy: dy); t.concat()
    }
}
