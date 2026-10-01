// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

// MARK: - Monitor Lizard

extension CharacterIcon {
    /// Monitor Lizard: Armando, a tan leopard gecko draped over a grey monitor, in
    /// the caterpillar's storybook style and posed like his mascot. The monitor
    /// fills most of the canvas; his small head peeks over its top-left corner
    /// facing left, smiling, his slim body lies along the top edge, and his thin
    /// spotted tail runs down the right side and tucks under the short stand. The screen is glass: it fills from the bottom with `brightness`
    /// (0...1), blue that lightens as the level rises, dark above the fill;
    /// `nightShift` turns the fill amber. `tongue` flicks a pink tongue out of his
    /// mouth to the left. One 25x22pt canvas for every state, so the bar never
    /// shifts. Drawn at 8x, downsampled to 2x and 1x bitmaps, and cached.
    public static func monitorLizard(brightness: CGFloat, nightShift: Bool, tongue: Bool = false) -> NSImage {
        MonitorLizardGlyph.image(.init(level: Int((max(0, min(1, brightness)) * 100).rounded()),
                                       nightShift: nightShift, tongue: tongue))
    }
}

/// Armando's drawing. See `CharacterIcon.monitorLizard(brightness:nightShift:tongue:)`.
private enum MonitorLizardGlyph {
    /// `level` is the brightness in hundredths, so the cache stays bounded.
    struct State: Hashable { let level: Int; let nightShift: Bool; let tongue: Bool }

    static let size = NSSize(width: 25, height: 22)
    static let supersample: CGFloat = 8
    private static var cache: [State: NSImage] = [:]

    static func image(_ s: State) -> NSImage {
        if let cached = cache[s] { return cached }
        let big = render(s, scale: supersample)
        let image = NSImage(size: size)
        for scale in [2, 1] as [CGFloat] { if let rep = downsample(big, scale: scale) { image.addRepresentation(rep) } }
        image.isTemplate = false
        cache[s] = image
        return image
    }

    // MARK: Palette

    static let ink = NSColor(red: 0.13, green: 0.10, blue: 0.08, alpha: 1)
    static let skin = (light: NSColor(red: 1.00, green: 0.88, blue: 0.58, alpha: 1), dark: NSColor(red: 0.86, green: 0.63, blue: 0.30, alpha: 1))
    static let spot = NSColor(red: 0.30, green: 0.19, blue: 0.09, alpha: 1)
    static let bezel = (light: NSColor(white: 0.80, alpha: 1), dark: NSColor(white: 0.52, alpha: 1))
    static let stand = (light: NSColor(white: 0.62, alpha: 1), dark: NSColor(white: 0.38, alpha: 1))
    static let darkGlass = (light: NSColor(red: 0.22, green: 0.25, blue: 0.31, alpha: 1), dark: NSColor(red: 0.09, green: 0.10, blue: 0.13, alpha: 1))
    /// The unlit glass under Night Shift: the same dark, faintly warm.
    static let warmGlass = (light: NSColor(red: 0.32, green: 0.25, blue: 0.21, alpha: 1), dark: NSColor(red: 0.13, green: 0.10, blue: 0.08, alpha: 1))
    static let tongue = (light: NSColor(red: 1.00, green: 0.50, blue: 0.64, alpha: 1), dark: NSColor(red: 0.88, green: 0.22, blue: 0.40, alpha: 1))

    /// The lit glass: blue (amber under Night Shift), deep at a low level and
    /// lightening toward full brightness.
    static func glass(_ s: State) -> (light: NSColor, dark: NSColor) {
        let t = CGFloat(s.level) / 100
        func mix(_ a: (CGFloat, CGFloat, CGFloat), _ b: (CGFloat, CGFloat, CGFloat)) -> NSColor {
            NSColor(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t, alpha: 1)
        }
        if s.nightShift {
            return (mix((0.80, 0.42, 0.10), (1.00, 0.80, 0.42)), mix((0.50, 0.22, 0.03), (0.96, 0.56, 0.12)))
        }
        return (mix((0.20, 0.50, 0.92), (0.62, 0.88, 1.00)), mix((0.06, 0.22, 0.60), (0.20, 0.58, 0.98)))
    }

    // MARK: Geometry

    static let bezelRect = NSRect(x: 1.4, y: 2.6, width: 20.4, height: 14.8)
    static let screenRect = NSRect(x: 2.8, y: 4.0, width: 17.6, height: 12.0)

    /// The head is drawn in its own 12x8 design space and placed over the bezel's
    /// top-left corner at this scale.
    static let headScale: CGFloat = 0.75
    static let headOrigin = NSPoint(x: 0.375, y: 5.175)

    /// The spine Armando's body and tail follow, back of the head to tail tip:
    /// along the top edge, round the top-right corner, down the right side and
    /// tucked under the stand.
    static let spine: [(NSPoint, NSPoint, NSPoint, NSPoint)] = [
        (NSPoint(x: 7.6, y: 18.6), NSPoint(x: 11.0, y: 18.9), NSPoint(x: 17.0, y: 18.8), NSPoint(x: 20.8, y: 18.1)),
        (NSPoint(x: 20.8, y: 18.1), NSPoint(x: 22.9, y: 17.5), NSPoint(x: 22.9, y: 13.0), NSPoint(x: 22.8, y: 8.0)),
        (NSPoint(x: 22.8, y: 8.0), NSPoint(x: 22.8, y: 4.0), NSPoint(x: 22.8, y: 1.3), NSPoint(x: 19.5, y: 0.9)),
        (NSPoint(x: 19.5, y: 0.9), NSPoint(x: 16.5, y: 0.6), NSPoint(x: 13.5, y: 0.8), NSPoint(x: 11.8, y: 1.6)),
    ]

    /// Body width along the spine, by overall position `t` 0...1.
    static func width(_ t: CGFloat) -> CGFloat {
        let stops: [(CGFloat, CGFloat)] = [(0, 2.5), (0.25, 2.0), (0.5, 1.6), (0.75, 1.2), (1, 0.6)]
        for i in 1..<stops.count where t <= stops[i].0 {
            let (t0, w0) = stops[i - 1], (t1, w1) = stops[i]
            return w0 + (w1 - w0) * (t - t0) / (t1 - t0)
        }
        return stops.last!.1
    }

    static func bez(_ s: (NSPoint, NSPoint, NSPoint, NSPoint), _ t: CGFloat) -> (NSPoint, NSPoint) {
        let (p0, p1, p2, p3) = s, u = 1 - t
        let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
        let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        let dx = 3*u*u*(p1.x-p0.x) + 6*u*t*(p2.x-p1.x) + 3*t*t*(p3.x-p2.x)
        let dy = 3*u*u*(p1.y-p0.y) + 6*u*t*(p2.y-p1.y) + 3*t*t*(p3.y-p2.y)
        let len = max(0.001, (dx*dx + dy*dy).squareRoot())
        return (NSPoint(x: x, y: y), NSPoint(x: -dy/len, y: dx/len))
    }

    /// A point on the spine at overall `t`, pushed `off` points along the normal
    /// (positive = the spine's left, i.e. the body's top/outer side).
    static func onSpine(_ t: CGFloat, _ off: CGFloat = 0) -> NSPoint {
        let n = CGFloat(spine.count), i = min(spine.count - 1, Int(t * n))
        let (c, nrm) = bez(spine[i], t * n - CGFloat(i))
        return NSPoint(x: c.x + nrm.x * off, y: c.y + nrm.y * off)
    }

    /// The body and tail as one tapering tube with a rounded tip.
    static func tube() -> NSBezierPath {
        let steps = 120
        var left: [NSPoint] = [], right: [NSPoint] = []
        for k in 0...steps {
            let t = CGFloat(k) / CGFloat(steps), w = width(t) / 2
            left.append(onSpine(t, w)); right.append(onSpine(t, -w))
        }
        let p = NSBezierPath()
        p.move(to: left[0])
        for q in left.dropFirst() { p.line(to: q) }
        p.appendArc(withCenter: onSpine(1), radius: width(1) / 2, startAngle: 0, endAngle: 360)
        for q in right.reversed() { p.line(to: q) }
        p.close()
        return p
    }

    // MARK: Rendering

    private static func render(_ s: State, scale: CGFloat) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        ctx.shouldAntialias = true
        let t = NSAffineTransform(); t.scale(by: scale); t.concat()
        draw(s)
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
    private static func shaded(_ path: NSBezierPath, _ c: (light: NSColor, dark: NSColor), ink width: CGFloat = 0.6) {
        NSGradient(starting: c.light, ending: c.dark)?.draw(in: path, angle: -70)
        ink.set(); path.lineWidth = width; path.lineJoinStyle = .round; path.stroke()
    }

    /// An ellipse centred on `c`, tilted by `deg` degrees.
    private static func oval(_ c: NSPoint, _ w: CGFloat, _ h: CGFloat, tilt deg: CGFloat = 0) -> NSBezierPath {
        let p = NSBezierPath(ovalIn: NSRect(x: -w / 2, y: -h / 2, width: w, height: h))
        let t = NSAffineTransform(); t.translateX(by: c.x, yBy: c.y); t.rotate(byDegrees: deg); p.transform(using: t as AffineTransform)
        return p
    }

    /// Runs `body` inside a saved graphics state (for clips).
    private static func clipped(_ clip: NSBezierPath, _ body: () -> Void) {
        NSGraphicsContext.saveGraphicsState(); clip.addClip(); body(); NSGraphicsContext.restoreGraphicsState()
    }

    private static func draw(_ s: State) {
        // Stand: a neck and a rounded foot, behind the tail.
        let neck = NSBezierPath(rect: NSRect(x: 10.4, y: 1.8, width: 2.6, height: 1.0))
        shaded(neck, stand, ink: 0.5)
        let foot = NSBezierPath(roundedRect: NSRect(x: 7.8, y: 1.0, width: 7.0, height: 1.1), xRadius: 0.55, yRadius: 0.55)
        shaded(foot, stand, ink: 0.5)

        // Bezel: grey with a soft bevel, a lighter inner lip round the glass.
        let bz = NSBezierPath(roundedRect: bezelRect, xRadius: 1.6, yRadius: 1.6)
        shaded(bz, bezel, ink: 0.65)
        let lip = NSBezierPath(roundedRect: screenRect.insetBy(dx: -0.55, dy: -0.55), xRadius: 0.9, yRadius: 0.9)
        NSGradient(starting: bezel.dark, ending: NSColor(white: 0.92, alpha: 1))?.draw(in: lip, angle: -70)

        // Glass: dark where unlit, the brightness filling it from the bottom.
        let glassPath = NSBezierPath(roundedRect: screenRect, xRadius: 0.6, yRadius: 0.6)
        let unlit = s.nightShift ? warmGlass : darkGlass
        NSGradient(starting: unlit.light, ending: unlit.dark)?.draw(in: glassPath, angle: -70)
        clipped(glassPath) {
            let level = CGFloat(s.level) / 100
            if level > 0 {
                let fill = NSRect(x: screenRect.minX, y: screenRect.minY, width: screenRect.width, height: screenRect.height * level)
                let g = glass(s)
                NSGradient(starting: g.light, ending: g.dark)?.draw(in: NSBezierPath(rect: fill), angle: -70)
                // a bright meniscus on the fill line, so the level reads at a glance
                if level < 1 {
                    NSColor(white: 1, alpha: 0.55).set()
                    NSBezierPath(rect: NSRect(x: fill.minX, y: fill.maxY - 0.35, width: fill.width, height: 0.35)).fill()
                }
            }
            // glare: a diagonal sheen across the top-left of the glass
            let glare = NSBezierPath()
            glare.move(to: NSPoint(x: screenRect.minX, y: screenRect.maxY - 3.6))
            glare.line(to: NSPoint(x: screenRect.minX + 3.6, y: screenRect.maxY))
            glare.line(to: NSPoint(x: screenRect.minX + 5.4, y: screenRect.maxY))
            glare.line(to: NSPoint(x: screenRect.minX, y: screenRect.maxY - 5.4))
            glare.close()
            NSColor(white: 1, alpha: 0.22).set(); glare.fill()
        }
        ink.withAlphaComponent(0.8).set(); glassPath.lineWidth = 0.45; glassPath.stroke()

        // Body and tail, with leopard spots.
        let body = tube()
        NSGradient(starting: skin.light, ending: skin.dark)?.draw(in: body, angle: -70)
        clipped(body) {
            spot.set()
            let spots: [(CGFloat, CGFloat, CGFloat)] = [   // (t along the spine, offset, size)
                (0.05, 0.5, 0.75), (0.10, -0.4, 0.65), (0.15, 0.4, 0.7), (0.20, -0.4, 0.6),
                (0.27, 0.3, 0.65), (0.34, -0.3, 0.6), (0.42, 0.3, 0.6), (0.50, -0.2, 0.55),
                (0.58, 0.2, 0.55), (0.66, -0.15, 0.5), (0.74, 0.1, 0.5), (0.82, 0, 0.45),
            ]
            for (t, off, d) in spots { oval(onSpine(t, off), d, d).fill() }
        }
        ink.set(); body.lineWidth = 0.5; body.lineJoinStyle = .round; body.stroke()

        // A hind foot gripping the bezel's right side.
        let hind = oval(NSPoint(x: 21.7, y: 12.0), 1.6, 1.1, tilt: -20)
        shaded(hind, skin, ink: 0.45)
        let toes = NSBezierPath()
        toes.move(to: NSPoint(x: 21.1, y: 11.6)); toes.line(to: NSPoint(x: 20.9, y: 11.3))
        toes.move(to: NSPoint(x: 21.1, y: 12.4)); toes.line(to: NSPoint(x: 20.8, y: 12.5))
        toes.lineWidth = 0.4; toes.lineCapStyle = .round; ink.set(); toes.stroke()

        // The head and tongue are drawn in their own design space, scaled down onto
        // the bezel's top-left corner; ink widths are divided by the scale so the
        // outlines stay as heavy as the rest.
        NSGraphicsContext.saveGraphicsState()
        let k = headScale
        let place = NSAffineTransform(); place.translateX(by: headOrigin.x, yBy: headOrigin.y); place.scale(by: k); place.concat()
        drawHead(s, k)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawHead(_ s: State, _ k: CGFloat) {
        // Head: big and round, in profile facing left, chin resting on the top-left
        // corner of the bezel. Domed crown, blunt rounded snout, full jaw.
        let head = NSBezierPath()
        head.move(to: NSPoint(x: 11.8, y: 17.8))
        head.curve(to: NSPoint(x: 6.4, y: 21.0), controlPoint1: NSPoint(x: 11.4, y: 20.2), controlPoint2: NSPoint(x: 9.0, y: 21.1))
        head.curve(to: NSPoint(x: 1.6, y: 18.6), controlPoint1: NSPoint(x: 4.0, y: 20.9), controlPoint2: NSPoint(x: 2.4, y: 20.0))
        head.curve(to: NSPoint(x: 1.2, y: 15.6), controlPoint1: NSPoint(x: 0.9, y: 17.6), controlPoint2: NSPoint(x: 0.7, y: 16.4))
        head.curve(to: NSPoint(x: 5.2, y: 13.2), controlPoint1: NSPoint(x: 1.8, y: 14.4), controlPoint2: NSPoint(x: 3.4, y: 13.3))
        head.curve(to: NSPoint(x: 10.6, y: 14.4), controlPoint1: NSPoint(x: 7.4, y: 13.1), controlPoint2: NSPoint(x: 9.4, y: 13.4))
        head.curve(to: NSPoint(x: 11.8, y: 17.8), controlPoint1: NSPoint(x: 11.6, y: 15.3), controlPoint2: NSPoint(x: 12.0, y: 16.4))
        head.close()
        NSGradient(starting: skin.light, ending: skin.dark)?.draw(in: head, angle: -70)
        clipped(head) {
            // pale throat
            NSColor(red: 1.0, green: 0.95, blue: 0.80, alpha: 0.8).set()
            oval(NSPoint(x: 5.6, y: 13.6), 7.0, 2.4).fill()
            spot.set()
            for (x, y, d) in [(8.6, 20.2, 1.0), (10.4, 18.6, 0.9), (9.8, 16.0, 0.8), (4.6, 20.6, 0.8), (3.2, 18.9, 0.6)] as [(CGFloat, CGFloat, CGFloat)] {
                oval(NSPoint(x: x, y: y), d, d).fill()
            }
        }
        ink.set(); head.lineWidth = 0.65 / k; head.lineJoinStyle = .round; head.stroke()

        // Eye: a big round eye with a dark pupil looking left and a white glint.
        let eyeC = NSPoint(x: 6.4, y: 18.3)
        let white = oval(eyeC, 3.8, 4.0)
        NSColor.white.set(); white.fill()
        ink.set(); white.lineWidth = 0.5 / k; white.stroke()
        ink.set(); oval(NSPoint(x: eyeC.x - 0.5, y: eyeC.y - 0.1), 2.5, 2.9).fill()
        NSColor.white.set(); oval(NSPoint(x: eyeC.x - 0.95, y: eyeC.y + 0.6), 1.1, 1.1).fill()
        // brow ridge
        let brow = NSBezierPath()
        brow.move(to: NSPoint(x: 4.6, y: 20.4)); brow.curve(to: NSPoint(x: 8.2, y: 20.5), controlPoint1: NSPoint(x: 5.6, y: 20.8), controlPoint2: NSPoint(x: 7.2, y: 20.9))
        brow.lineWidth = 0.45 / k; brow.lineCapStyle = .round; ink.set(); brow.stroke()

        // Nostril.
        ink.set(); oval(NSPoint(x: 1.9, y: 17.3), 0.55, 0.45).fill()

        // Smile: from the snout's corner back along the jaw, curling up at the cheek.
        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: 1.5, y: 15.9))
        smile.curve(to: NSPoint(x: 7.0, y: 15.4), controlPoint1: NSPoint(x: 3.0, y: 14.6), controlPoint2: NSPoint(x: 5.4, y: 14.5))
        smile.curve(to: NSPoint(x: 7.8, y: 16.3), controlPoint1: NSPoint(x: 7.5, y: 15.6), controlPoint2: NSPoint(x: 7.8, y: 15.9))
        smile.lineWidth = 0.7 / k; smile.lineCapStyle = .round; ink.set(); smile.stroke()

        // Tongue: a fat pink tongue curling out of the mouth to the left and down.
        if s.tongue {
            let t = NSBezierPath()
            t.move(to: NSPoint(x: 3.6, y: 15.1))
            t.curve(to: NSPoint(x: 0.9, y: 12.4), controlPoint1: NSPoint(x: 1.6, y: 15.4), controlPoint2: NSPoint(x: 0.8, y: 14.0))
            t.curve(to: NSPoint(x: 2.6, y: 8.2), controlPoint1: NSPoint(x: 0.9, y: 10.2), controlPoint2: NSPoint(x: 1.3, y: 8.2))
            t.curve(to: NSPoint(x: 4.0, y: 11.0), controlPoint1: NSPoint(x: 3.8, y: 8.2), controlPoint2: NSPoint(x: 4.2, y: 9.6))
            t.curve(to: NSPoint(x: 5.0, y: 14.6), controlPoint1: NSPoint(x: 3.8, y: 12.4), controlPoint2: NSPoint(x: 4.0, y: 14.0))
            t.close()
            shaded(t, tongue, ink: 0.45 / k)
            let crease = NSBezierPath()
            crease.move(to: NSPoint(x: 2.8, y: 14.0)); crease.curve(to: NSPoint(x: 2.5, y: 10.0), controlPoint1: NSPoint(x: 2.2, y: 13.0), controlPoint2: NSPoint(x: 2.2, y: 11.2))
            crease.lineWidth = 0.3 / k; crease.lineCapStyle = .round
            tongue.dark.set(); crease.stroke()
        }
    }
}
