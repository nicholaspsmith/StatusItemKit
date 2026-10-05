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

    /// Behind the house: sun or moon over the left slope, clouds over the
    /// right. The roof is drawn after, so both sit *behind* it.
    static func drawSky(_ weather: HouseWeather, night: Bool, ctx: NSGraphicsContext) {
        switch weather {
        case .clear:
            drawSunOrMoon(night: night, ctx: ctx)
        case .partlyCloudy:
            drawSunOrMoon(night: night, ctx: ctx)
            drawCloud(centre: NSPoint(x: 21.2, y: 18.2), scale: 1, fill: skyCloud)
        case .cloudy:
            drawCloud(centre: NSPoint(x: 4.6, y: 18.6), scale: 0.8, fill: skyCloud)
            drawCloud(centre: NSPoint(x: 21.2, y: 18.2), scale: 1, fill: skyCloud)
        case .rain, .snow, .sleet:
            drawCloud(centre: NSPoint(x: 21.2, y: 18.2), scale: 1, fill: skyCloud)
        case .heavyRain, .storm:
            drawCloud(centre: NSPoint(x: 4.6, y: 18.6), scale: 0.8, fill: skyStormCloud)
            drawCloud(centre: NSPoint(x: 21.2, y: 18.2), scale: 1, fill: skyStormCloud)
        case .fog:
            drawMist(at: [NSPoint(x: 0.8, y: 18.6), NSPoint(x: 18.6, y: 19.6), NSPoint(x: 19.8, y: 16.6)], width: 6)
        case .wind:
            drawGusts()
        }
    }

    /// In front of the house, beside its walls: what is falling.
    static func drawWeatherFront(_ weather: HouseWeather) {
        switch weather {
        case .rain:
            drawRain(heavy: false)
        case .heavyRain:
            drawRain(heavy: true)
        case .storm:
            drawRain(heavy: false)
            drawBolt()
        case .snow:
            drawSnow()
        case .sleet:
            drawSnow(sparse: true)
            drawRain(heavy: false, sparse: true)
        case .fog:
            // A bank along the ground, under the windows.
            drawMist(at: [NSPoint(x: 0.5, y: 0.6)], width: 25)
        case .clear, .partlyCloudy, .cloudy, .wind:
            break
        }
    }

    private static func drawSunOrMoon(night: Bool, ctx: NSGraphicsContext) {
        let centre = NSPoint(x: 4.4, y: 18.4)
        guard !night else {
            // A crescent: a disc with a bite out of its upper right. The sky
            // is drawn first, so punching the bite out removes only the moon.
            let moon = NSBezierPath(ovalIn: NSRect(x: centre.x - 2.6, y: centre.y - 2.6, width: 5.2, height: 5.2))
            skyCloudEdge.set()
            moon.lineWidth = 0.9
            moon.stroke()
            skyMoon.set()
            moon.fill()
            cut(ctx, NSBezierPath(ovalIn: NSRect(x: centre.x - 0.9, y: centre.y - 0.6, width: 4.6, height: 4.6)))
            return
        }
        skySun.set()
        NSBezierPath(ovalIn: NSRect(x: centre.x - 2.1, y: centre.y - 2.1, width: 4.2, height: 4.2)).fill()
        let rays = NSBezierPath()
        for index in 0..<8 {
            let angle = Double(index) * Double.pi / 4
            rays.move(to: NSPoint(x: centre.x + CGFloat(cos(angle)) * 2.9, y: centre.y + CGFloat(sin(angle)) * 2.9))
            rays.line(to: NSPoint(x: centre.x + CGFloat(cos(angle)) * 3.9, y: centre.y + CGFloat(sin(angle)) * 3.9))
        }
        rays.lineWidth = 0.9
        rays.lineCapStyle = .round
        rays.stroke()
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

    /// Slanted streaks in the strips beside the walls.
    private static func drawRain(heavy: Bool, sparse: Bool = false) {
        var drops: [NSPoint] = [NSPoint(x: 23.0, y: 10.2), NSPoint(x: 24.6, y: 6.4), NSPoint(x: 22.6, y: 3.0),
                                NSPoint(x: 2.0, y: 9.6), NSPoint(x: 3.4, y: 5.0)]
        if heavy { drops += [NSPoint(x: 25.0, y: 2.0), NSPoint(x: 1.0, y: 3.2), NSPoint(x: 1.4, y: 11.8), NSPoint(x: 24.8, y: 11.2)] }
        if sparse { drops = drops.enumerated().filter { $0.offset % 2 == 0 }.map(\.element) }
        let length: CGFloat = heavy ? 2.8 : 2.2
        skyRain.set()
        let streaks = NSBezierPath()
        for drop in drops {
            streaks.move(to: drop)
            streaks.line(to: NSPoint(x: drop.x - length * 0.35, y: drop.y - length))
        }
        streaks.lineWidth = heavy ? 1.0 : 0.85
        streaks.lineCapStyle = .round
        streaks.stroke()
    }

    private static func drawSnow(sparse: Bool = false) {
        var flakes: [NSPoint] = [NSPoint(x: 23.4, y: 9.6), NSPoint(x: 24.8, y: 5.2), NSPoint(x: 22.8, y: 2.0),
                                 NSPoint(x: 2.2, y: 9.0), NSPoint(x: 3.2, y: 4.2), NSPoint(x: 1.2, y: 1.6)]
        if sparse { flakes = flakes.enumerated().filter { $0.offset % 2 == 1 }.map(\.element) }
        for flake in flakes {
            let dot = NSBezierPath(ovalIn: NSRect(x: flake.x - 0.95, y: flake.y - 0.95, width: 1.9, height: 1.9))
            skySnowEdge.set()
            dot.lineWidth = 0.6
            dot.stroke()
            skySnow.set()
            dot.fill()
        }
    }

    /// A bolt dropping from the cloud past the right-hand wall.
    private static func drawBolt() {
        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: 24.4, y: 14.6))
        bolt.line(to: NSPoint(x: 22.2, y: 9.6))
        bolt.line(to: NSPoint(x: 24.0, y: 9.6))
        bolt.line(to: NSPoint(x: 22.4, y: 4.6))
        bolt.line(to: NSPoint(x: 25.6, y: 10.8))
        bolt.line(to: NSPoint(x: 23.8, y: 10.8))
        bolt.line(to: NSPoint(x: 25.8, y: 14.6))
        bolt.close()
        NSColor(srgbRed: 0.62, green: 0.45, blue: 0, alpha: 1).set()
        bolt.lineWidth = 0.5
        bolt.stroke()
        skyBolt.set()
        bolt.fill()
    }

    private static func drawMist(at origins: [NSPoint], width: CGFloat) {
        skyMist.withAlphaComponent(0.85).set()
        for origin in origins {
            NSBezierPath(roundedRect: NSRect(x: origin.x, y: origin.y, width: width, height: 1.3),
                         xRadius: 0.65, yRadius: 0.65).fill()
        }
    }

    /// Two gusts curling over the right slope.
    private static func drawGusts() {
        skyMist.set()
        for (y, length) in [(CGFloat(19.6), CGFloat(7.0)), (CGFloat(16.4), CGFloat(5.6))] {
            let gust = NSBezierPath()
            gust.move(to: NSPoint(x: 18.4, y: y))
            gust.line(to: NSPoint(x: 18.4 + length - 1.4, y: y))
            gust.curve(to: NSPoint(x: 18.4 + length - 1.6, y: y + 1.8),
                       controlPoint1: NSPoint(x: 18.4 + length + 0.4, y: y),
                       controlPoint2: NSPoint(x: 18.4 + length + 0.2, y: y + 1.9))
            gust.lineWidth = 1.0
            gust.lineCapStyle = .round
            gust.stroke()
        }
    }
}
