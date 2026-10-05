// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// The weather outside Homestead's house. Coarser than Home Assistant's
/// conditions on purpose: at 22pt, "pouring" and "rainy" are only worth telling
/// apart by how hard it is coming down.
public enum HouseWeather: Sendable, CaseIterable {
    case clear
    case partlyCloudy
    case cloudy
    case rain
    case heavyRain
    case storm
    case snow
    /// Snow and rain together, or hail.
    case sleet
    case fog
    case wind
}

/// The house's sky. Everything is drawn in the room the house leaves: above
/// the roof's two slopes, and the strips beside the walls. Nothing crosses the
/// windows, which are already saying how many lights are on.
///
/// The sky moves, gently and for as long as it is asked to: one loop of
/// `houseWeatherLoopDuration` seconds, `weatherPhase` 0 ..< 1 through it. Every
/// motion completes a whole number of cycles a loop, so phase 1 is phase 0 and
/// the loop has no seam — and phase 0 is the still glyph, which is what Reduce
/// Motion shows.
extension CharacterIcon {
    static let skySun = NSColor(srgbRed: 1, green: 0.76, blue: 0.18, alpha: 1)
    static let skyMoon = NSColor(srgbRed: 0.98, green: 0.93, blue: 0.70, alpha: 1)
    static let skyCloud = NSColor(srgbRed: 0.96, green: 0.97, blue: 0.99, alpha: 1)
    static let skyCloudEdge = NSColor(srgbRed: 0.55, green: 0.60, blue: 0.68, alpha: 1)
    static let skyStormCloud = NSColor(srgbRed: 0.52, green: 0.56, blue: 0.64, alpha: 1)
    static let skyRain = NSColor(srgbRed: 0.24, green: 0.56, blue: 0.95, alpha: 1)
    static let skySnow = NSColor(srgbRed: 0.93, green: 0.97, blue: 1, alpha: 1)
    static let skySnowEdge = NSColor(srgbRed: 0.45, green: 0.62, blue: 0.82, alpha: 1)
    static let skyBolt = NSColor(srgbRed: 1, green: 0.84, blue: 0.10, alpha: 1)
    static let skyMist = NSColor(srgbRed: 0.62, green: 0.66, blue: 0.72, alpha: 1)

    /// One loop of the weather's motion, in seconds. `house(…, weatherPhase:)`
    /// is the fraction of the way through it.
    public static let houseWeatherLoopDuration: TimeInterval = 24

    /// How many frames a second each weather is worth drawing. Slow skies
    /// change by less than a pixel between frames any faster than this, so a
    /// caller can step the phase `rate × houseWeatherLoopDuration` times a loop
    /// (always a whole number) and draw nothing in between.
    public static func houseWeatherFrameRate(_ weather: HouseWeather) -> Double {
        switch weather {
        case .rain, .heavyRain, .storm, .sleet: return 12
        case .snow, .wind: return 10
        case .clear, .partlyCloudy, .cloudy, .fog: return 8
        }
    }

    /// Where in the loop, and how hard it is coming down.
    struct SkyMotion {
        /// 0 ..< 1 through the loop.
        let phase: CGFloat
        /// 0 … 1, or nil for the weather's own default (the still glyph's).
        let intensity: CGFloat?

        init(phase: CGFloat, intensity: CGFloat?) {
            self.phase = phase.isFinite ? phase - phase.rounded(.down) : 0
            self.intensity = intensity.flatMap { $0.isFinite ? min(max($0, 0), 1) : nil }
        }

        static let still = SkyMotion(phase: 0, intensity: nil)

        /// sin over `cycles` whole cycles a loop: 0 at the start and the end.
        func wave(_ cycles: CGFloat) -> CGFloat {
            sin(2 * .pi * cycles * phase)
        }

        /// 0 → 1 → 0, `cycles` times a loop, resting at 0 at the start.
        func swell(_ cycles: CGFloat) -> CGFloat {
            (1 - cos(2 * .pi * cycles * phase)) / 2
        }
    }

    // MARK: - Layers

    /// Behind the house: sun or moon over the left slope, clouds over the
    /// right. The roof is drawn after, so both sit *behind* it.
    static func drawSky(_ weather: HouseWeather, night: Bool, ctx: NSGraphicsContext, motion: SkyMotion = .still) {
        switch weather {
        case .clear:
            drawSunOrMoon(night: night, ctx: ctx, motion: motion)
        case .partlyCloudy:
            drawSunOrMoon(night: night, ctx: ctx, motion: motion)
            drawDriftingCloud(fill: skyCloud, motion: motion)
        case .cloudy:
            drawPassingClouds(fill: skyCloud, motion: motion)
        case .rain, .snow, .sleet:
            drawDriftingCloud(fill: skyCloud, motion: motion)
        case .heavyRain, .storm:
            drawPassingClouds(fill: skyStormCloud, motion: motion)
        case .fog:
            // Each bank slides out a little and back, at its own pace.
            drawMist(at: [NSPoint(x: 0.8 + 1.0 * motion.swell(1), y: 18.6),
                          NSPoint(x: 18.6 - 1.2 * motion.swell(2), y: 19.6),
                          NSPoint(x: 19.8 - 0.9 * motion.swell(3), y: 16.6)], width: 6)
        case .wind:
            drawGusts(motion: motion)
        }
    }

    /// In front of the house, beside its walls: what is falling.
    static func drawWeatherFront(_ weather: HouseWeather, ctx: NSGraphicsContext, motion: SkyMotion = .still) {
        let intensity = precipitationIntensity(weather, motion.intensity)
        switch weather {
        case .rain, .heavyRain, .storm, .snow, .sleet:
            // Falling things come out from under the eaves and pass behind the
            // walls, never in front of them.
            ctx.saveGraphicsState()
            precipitationClip().addClip()
            let drops = rainDropCount(weather, intensity), flakes = snowFlakeCount(weather, intensity)
            switch weather {
            case .snow:
                drawSnow(Array(snowSeeds.prefix(flakes)), motion: motion)
            case .sleet:
                drawSnow(Array(sleetSnowSeeds.prefix(flakes)), motion: motion)
                drawRain(Array(sleetRainSeeds.prefix(drops)), heavy: false, intensity: intensity, motion: motion)
            default:
                drawRain(Array(rainSeeds.prefix(drops)), heavy: weather == .heavyRain, intensity: intensity, motion: motion)
            }
            ctx.restoreGraphicsState()
            if weather == .storm { drawBolt(motion: motion) }
        case .fog:
            // A bank along the ground, under the windows.
            drawMist(at: [NSPoint(x: 0.5 - 0.4 * motion.swell(1), y: 0.6)], width: 25)
        case .clear, .partlyCloudy, .cloudy, .wind:
            break
        }
    }

    // MARK: - How hard it is coming down

    /// The intensity a weather falls at: what Home Assistant said, or the
    /// weather's own default — the one the still glyph has always drawn.
    /// Heavy rain is never lighter than its default.
    static func precipitationIntensity(_ weather: HouseWeather, _ given: CGFloat?) -> CGFloat {
        switch weather {
        case .heavyRain: return max(given ?? 0.6, 0.6)
        case .snow: return given ?? 0.5
        default: return given ?? 0.2
        }
    }

    /// Rain streaks: 3 at intensity 0 to 13 at 1 — 5 for rain and 9 for heavy
    /// rain at their defaults. Sleet's rain: 1 to 11, 3 at its default.
    static func rainDropCount(_ weather: HouseWeather, _ intensity: CGFloat) -> Int {
        switch weather {
        case .rain, .heavyRain, .storm: return 3 + Int((intensity * 10).rounded())
        case .sleet: return 1 + Int((intensity * 10).rounded())
        default: return 0
        }
    }

    /// Flakes: 2 to 10 for snow (6 at its default), 2 to 7 for sleet (3).
    static func snowFlakeCount(_ weather: HouseWeather, _ intensity: CGFloat) -> Int {
        switch weather {
        case .snow: return 2 + Int((intensity * 8).rounded())
        case .sleet: return 2 + Int((intensity * 5).rounded())
        default: return 0
        }
    }

    /// Where each streak's top is at phase 0, in the order they join as it
    /// rains harder. The first five are rain's, the first nine heavy rain's.
    private static let rainSeeds: [NSPoint] = [
        NSPoint(x: 23.0, y: 10.2), NSPoint(x: 2.0, y: 9.6), NSPoint(x: 24.6, y: 6.4),
        NSPoint(x: 3.4, y: 5.0), NSPoint(x: 22.6, y: 3.0),
        NSPoint(x: 25.0, y: 2.0), NSPoint(x: 1.0, y: 3.2), NSPoint(x: 1.4, y: 11.8), NSPoint(x: 24.8, y: 11.2),
        NSPoint(x: 22.4, y: 7.0), NSPoint(x: 0.6, y: 7.0), NSPoint(x: 25.4, y: 8.4), NSPoint(x: 2.8, y: 1.4),
    ]
    /// Sleet's rain: the first three are the still glyph's.
    private static let sleetRainSeeds: [NSPoint] = [
        NSPoint(x: 23.0, y: 10.2), NSPoint(x: 22.6, y: 3.0), NSPoint(x: 3.4, y: 5.0),
        NSPoint(x: 2.0, y: 9.6), NSPoint(x: 24.6, y: 6.4), NSPoint(x: 1.0, y: 3.2), NSPoint(x: 24.8, y: 11.2),
        NSPoint(x: 1.4, y: 11.8), NSPoint(x: 25.0, y: 2.0), NSPoint(x: 0.6, y: 7.0), NSPoint(x: 22.4, y: 7.0),
    ]
    /// Snow: the first six are the still glyph's.
    private static let snowSeeds: [NSPoint] = [
        NSPoint(x: 23.4, y: 9.6), NSPoint(x: 2.2, y: 9.0), NSPoint(x: 24.8, y: 5.2),
        NSPoint(x: 3.2, y: 4.2), NSPoint(x: 22.8, y: 2.0), NSPoint(x: 1.2, y: 1.6),
        NSPoint(x: 22.4, y: 6.8), NSPoint(x: 1.0, y: 6.4), NSPoint(x: 24.6, y: 11.0), NSPoint(x: 1.6, y: 11.6),
    ]
    /// Sleet's flakes: the first three are the still glyph's.
    private static let sleetSnowSeeds: [NSPoint] = [
        NSPoint(x: 24.8, y: 5.2), NSPoint(x: 2.2, y: 9.0), NSPoint(x: 1.2, y: 1.6),
        NSPoint(x: 23.4, y: 9.6), NSPoint(x: 3.2, y: 4.2), NSPoint(x: 22.8, y: 2.0), NSPoint(x: 1.0, y: 6.4),
    ]

    /// How high falling things show: just under the eaves.
    private static let precipitationCeiling: CGFloat = 12.6

    /// What falling things may cover: the canvas below the eaves, less the
    /// house itself.
    private static func precipitationClip() -> NSBezierPath {
        let clip = NSBezierPath(rect: NSRect(x: -1, y: -1, width: 28, height: precipitationCeiling + 1))
        let house = NSBezierPath()
        house.move(to: NSPoint(x: 5.0, y: 2.4))
        house.line(to: NSPoint(x: 21.0, y: 2.4))
        house.line(to: NSPoint(x: 21.0, y: 11.7))
        house.line(to: NSPoint(x: 23.8, y: 11.7))
        house.line(to: NSPoint(x: 23.8, y: 12.2))
        house.line(to: NSPoint(x: 13.0, y: 20.0))
        house.line(to: NSPoint(x: 2.2, y: 12.2))
        house.line(to: NSPoint(x: 2.2, y: 11.7))
        house.line(to: NSPoint(x: 5.0, y: 11.7))
        house.close()
        clip.append(house)
        clip.windingRule = .evenOdd
        return clip
    }

    /// `y0` moved down by `fall`, wrapping within `low ..< high`. A fall of
    /// zero leaves it exactly where it was, so phase 0 is the still glyph.
    private static func fallen(_ y0: CGFloat, by fall: CGFloat, low: CGFloat, high: CGFloat) -> CGFloat {
        let span = high - low
        var y = y0 - fall.truncatingRemainder(dividingBy: span)
        while y < low { y += span }
        return y
    }

    // MARK: - Drawing

    private static func drawSunOrMoon(night: Bool, ctx: NSGraphicsContext, motion: SkyMotion) {
        let centre = NSPoint(x: 4.4, y: 18.4)
        guard !night else {
            // A soft glow that comes and goes twice a loop.
            let glow = 0.22 * motion.swell(2)
            if glow > 0 {
                skyMoon.withAlphaComponent(glow).set()
                NSBezierPath(ovalIn: NSRect(x: centre.x - 3.7, y: centre.y - 3.7, width: 7.4, height: 7.4)).fill()
            }
            // A crescent: a disc with a bite out of its upper right. The sky
            // is drawn first, so punching the bite out removes only the moon.
            let moon = NSBezierPath(ovalIn: NSRect(x: centre.x - 2.6, y: centre.y - 2.6, width: 5.2, height: 5.2))
            skyCloudEdge.set()
            moon.lineWidth = 0.9
            moon.stroke()
            skyMoon.set()
            moon.fill()
            cut(ctx, NSBezierPath(ovalIn: NSRect(x: centre.x - 0.9, y: centre.y - 0.6, width: 4.6, height: 4.6)))
            // Two stars that twinkle in turn, clear of the moon and the roof.
            drawTwinkle(at: NSPoint(x: 9.4, y: 20.9), from: 0.15, to: 0.35, motion: motion)
            drawTwinkle(at: NSPoint(x: 1.2, y: 13.5), from: 0.6, to: 0.76, motion: motion)
            return
        }
        // The sun gleams: a soft halo swells and fades, the rays turn an
        // eighth of a turn a loop (one ray's worth, so the loop is seamless),
        // and alternate rays draw in and out of step with each other.
        let gleam = 0.3 * motion.swell(2)
        if gleam > 0 {
            skySun.withAlphaComponent(gleam).set()
            NSBezierPath(ovalIn: NSRect(x: centre.x - 3.1, y: centre.y - 3.1, width: 6.2, height: 6.2)).fill()
        }
        skySun.set()
        NSBezierPath(ovalIn: NSRect(x: centre.x - 2.1, y: centre.y - 2.1, width: 4.2, height: 4.2)).fill()
        let turn = Double(motion.phase) * Double.pi / 4
        let rays = NSBezierPath()
        for index in 0..<8 {
            let angle = Double(index) * Double.pi / 4 + turn
            let reach = 3.9 - 0.45 * (index.isMultiple(of: 2) ? motion.swell(3) : motion.swell(4))
            rays.move(to: NSPoint(x: centre.x + CGFloat(cos(angle)) * 2.9, y: centre.y + CGFloat(sin(angle)) * 2.9))
            rays.line(to: NSPoint(x: centre.x + CGFloat(cos(angle)) * reach, y: centre.y + CGFloat(sin(angle)) * reach))
        }
        rays.lineWidth = 0.9
        rays.lineCapStyle = .round
        rays.stroke()
    }

    /// A four-pointed glint that fades in and out between phases `start` and `end`.
    private static func drawTwinkle(at point: NSPoint, from start: CGFloat, to end: CGFloat, motion: SkyMotion) {
        guard motion.phase > start, motion.phase < end else { return }
        let glow = sin(.pi * (motion.phase - start) / (end - start))
        let reach = 0.5 + 0.5 * glow
        skyMoon.withAlphaComponent(glow).set()
        let star = NSBezierPath()
        star.move(to: NSPoint(x: point.x - reach, y: point.y)); star.line(to: NSPoint(x: point.x + reach, y: point.y))
        star.move(to: NSPoint(x: point.x, y: point.y - reach)); star.line(to: NSPoint(x: point.x, y: point.y + reach))
        star.lineWidth = 0.55
        star.lineCapStyle = .round
        star.stroke()
    }

    /// The upper-right cloud, wandering a little way behind the roof and back.
    private static func drawDriftingCloud(fill: NSColor, motion: SkyMotion) {
        drawCloud(centre: NSPoint(x: 21.2 - 1.4 * motion.swell(1), y: 18.2 + 0.25 * motion.wave(2)), scale: 1, fill: fill)
    }

    /// Clouds passing behind the house, left to right, once a loop: the
    /// still glyph's two, and a third waiting out of sight at phase 0 so that
    /// one is always over a slope while another is behind the roof.
    private static func drawPassingClouds(fill: NSColor, motion: SkyMotion) {
        // Wide enough that a cloud is wholly off the canvas before it wraps.
        let low: CGFloat = -4.8, span: CGFloat = 36
        let travel = span * motion.phase
        for (x0, y, scale) in [(CGFloat(4.6), CGFloat(18.6), CGFloat(0.8)),
                               (CGFloat(21.2), CGFloat(18.2), CGFloat(1)),
                               (CGFloat(30.6), CGFloat(18.9), CGFloat(0.9))] {
            var x = x0 + travel
            while x >= low + span { x -= span }
            guard x > low, x < 30.45 else { continue }   // out of sight
            drawCloud(centre: NSPoint(x: x, y: y), scale: scale, fill: fill)
        }
    }

    /// Three puffs on a flat base, outlined so a white cloud still reads on a
    /// light menu bar.
    private static func drawCloud(centre: NSPoint, scale: CGFloat, fill: NSColor) {
        let cloud = NSBezierPath()
        func puff(_ dx: CGFloat, _ dy: CGFloat, _ r: CGFloat) {
            cloud.append(NSBezierPath(ovalIn: NSRect(x: centre.x + (dx - r) * scale, y: centre.y + (dy - r) * scale,
                                                     width: 2 * r * scale, height: 2 * r * scale)))
        }
        puff(-2.0, -0.4, 1.9)
        puff(0.4, 0.6, 2.4)
        puff(2.5, -0.5, 1.7)
        cloud.append(NSBezierPath(roundedRect: NSRect(x: centre.x - 3.4 * scale, y: centre.y - 2.3 * scale,
                                                      width: 7.4 * scale, height: 2.4 * scale),
                                  xRadius: 1.2 * scale, yRadius: 1.2 * scale))
        cloud.windingRule = .nonZero

        // Outline first, fattened, then the fill over it: stroking a union of
        // overlapping ovals would draw every seam between the puffs.
        skyCloudEdge.set()
        cloud.lineWidth = 1.1
        cloud.stroke()
        fill.set()
        cloud.fill()
    }

    /// Slanted streaks falling in the strips beside the walls: faster, and
    /// more of them, the harder it rains. Each streak falls a whole number of
    /// times a loop, a little faster or slower than its neighbours.
    private static func drawRain(_ drops: [NSPoint], heavy: Bool, intensity: CGFloat, motion: SkyMotion) {
        let length: CGFloat = heavy ? 2.8 : 2.2
        let low: CGFloat = -0.8, high = precipitationCeiling + length + 0.6
        let falls = 6 + (intensity * 10).rounded()   // 6 to 16 times a loop
        skyRain.set()
        let streaks = NSBezierPath()
        for (index, drop) in drops.enumerated() {
            let speed = falls + CGFloat(index % 3) - 1
            let y = fallen(drop.y, by: speed * (high - low) * motion.phase, low: low, high: high)
            let x = drop.x + 0.15 * (y - drop.y)
            streaks.move(to: NSPoint(x: x, y: y))
            streaks.line(to: NSPoint(x: x - length * 0.35, y: y - length))
        }
        streaks.lineWidth = heavy ? 1.0 : 0.85
        streaks.lineCapStyle = .round
        streaks.stroke()
    }

    /// Flakes drifting down, swaying as they go.
    private static func drawSnow(_ flakes: [NSPoint], motion: SkyMotion) {
        let low: CGFloat = -1.4, high = precipitationCeiling + 1.4
        for (index, flake) in flakes.enumerated() {
            let speed = CGFloat(3 + index % 2)   // 3 or 4 times a loop
            let y = fallen(flake.y, by: speed * (high - low) * motion.phase, low: low, high: high)
            let sway = (index.isMultiple(of: 2) ? 0.5 : -0.5) * sin(2 * .pi * (y - flake.y) / 5)
            let x = flake.x + sway
            let dot = NSBezierPath(ovalIn: NSRect(x: x - 0.95, y: y - 0.95, width: 1.9, height: 1.9))
            skySnowEdge.set()
            dot.lineWidth = 0.6
            dot.stroke()
            skySnow.set()
            dot.fill()
        }
    }

    /// When the bolt flickers: twice a loop, about eleven seconds apart. It
    /// goes out for a moment, comes back bright with a glow, and settles.
    static let boltFlashes: [CGFloat] = [0.31, 0.77]

    /// The flash's brightness at `phase`, 0 … 1, or -1 while the bolt is out.
    static func boltFlash(at phase: CGFloat) -> CGFloat {
        let out = CGFloat(0.12 / houseWeatherLoopDuration)
        let fade = CGFloat(0.9 / houseWeatherLoopDuration)
        for start in boltFlashes where phase >= start && phase < start + out + fade {
            if phase < start + out { return -1 }
            let x = 1 - (phase - start - out) / fade
            return x * x
        }
        return 0
    }

    /// A bolt dropping from the cloud past the right-hand wall.
    private static func drawBolt(motion: SkyMotion) {
        let flash = boltFlash(at: motion.phase)
        guard flash >= 0 else { return }
        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: 24.4, y: 14.6))
        bolt.line(to: NSPoint(x: 22.2, y: 9.6))
        bolt.line(to: NSPoint(x: 24.0, y: 9.6))
        bolt.line(to: NSPoint(x: 22.4, y: 4.6))
        bolt.line(to: NSPoint(x: 25.6, y: 10.8))
        bolt.line(to: NSPoint(x: 23.8, y: 10.8))
        bolt.line(to: NSPoint(x: 25.8, y: 14.6))
        bolt.close()
        if flash > 0 {
            skyBolt.withAlphaComponent(0.35 * flash).set()
            bolt.lineJoinStyle = .round
            bolt.lineWidth = 2.0
            bolt.stroke()
            bolt.lineJoinStyle = .miter
        }
        NSColor(srgbRed: 0.62, green: 0.45, blue: 0, alpha: 1).set()
        bolt.lineWidth = 0.5
        bolt.stroke()
        (flash > 0 ? skyBolt.blended(withFraction: 0.6 * flash, of: .white) ?? skyBolt : skyBolt).set()
        bolt.fill()
    }

    private static func drawMist(at origins: [NSPoint], width: CGFloat) {
        skyMist.withAlphaComponent(0.85).set()
        for origin in origins {
            NSBezierPath(roundedRect: NSRect(x: origin.x, y: origin.y, width: width, height: 1.3),
                         xRadius: 0.65, yRadius: 0.65).fill()
        }
    }

    /// Two gusts curling over the right slope. Each blows out from behind the
    /// roof, curls, and fades, three and four times a loop.
    private static func drawGusts(motion: SkyMotion) {
        for (y, length, gusts) in [(CGFloat(19.6), CGFloat(7.0), CGFloat(3)), (CGFloat(16.4), CGFloat(5.6), CGFloat(4))] {
            // `u` runs 0 ..< 1 through one gust from the still glyph's pose,
            // fully blown out: on a hair further while it fades, then back
            // behind the roof to blow out again.
            var u = gusts * motion.phase
            u -= u.rounded(.down)
            let tail: CGFloat = 1.0 / 6.0
            let shift = u < tail ? 1.2 * u : -3.0 * (1 - u) / (1 - tail)
            let alpha: CGFloat
            if u < 0.04 { alpha = 1 }
            else if u < tail { alpha = (tail - u) / (tail - 0.04) }
            else if u < tail + 0.3 { alpha = (u - tail) / 0.3 }
            else { alpha = 1 }
            guard alpha > 0 else { continue }
            (alpha < 1 ? skyMist.withAlphaComponent(alpha) : skyMist).set()
            let x = 18.4 + shift
            let gust = NSBezierPath()
            gust.move(to: NSPoint(x: x, y: y))
            gust.line(to: NSPoint(x: x + length - 1.4, y: y))
            gust.curve(to: NSPoint(x: x + length - 1.6, y: y + 1.8),
                       controlPoint1: NSPoint(x: x + length + 0.4, y: y),
                       controlPoint2: NSPoint(x: x + length + 0.2, y: y + 1.9))
            gust.lineWidth = 1.0
            gust.lineCapStyle = .round
            gust.stroke()
        }
    }
}
