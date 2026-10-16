// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// The bitmaps `IconLayer` shows: an icon at the bar's scale, a template tinted
/// for the bar's appearance. Converting is the only real work a new frame costs,
/// so each image, scale and tint is converted once and kept while the image
/// lives; CharacterIcon caches its frames, so an animation converts each once.
enum IconBitmaps {
    private static let cache = NSMapTable<NSImage, NSMutableDictionary>.weakToStrongObjects()

    /// `image` as a bitmap of `scale` pixels per point: its own representation of
    /// exactly that size when it has one, else drawn at that scale under
    /// `appearance`, the bar's, which is what a colour resolved at draw time
    /// (Battery Time's ink) follows, as it did in the button's own drawing. A
    /// template is filled with `tint`; for any other image `tint` is ignored.
    static func bitmap(for image: NSImage, scale: CGFloat, tint: NSColor? = nil,
                       appearance: NSAppearance? = nil) -> CGImage? {
        let tint = image.isTemplate ? tint : nil
        let key = "\(scale)|\(tint.map(colorKey) ?? "-")|\(appearance?.name.rawValue ?? "-")" as NSString
        if let hit = cache.object(forKey: image)?[key] { return (hit as! CGImage) }
        guard let made = make(image, scale: scale, tint: tint, appearance: appearance) else { return nil }
        let entry = cache.object(forKey: image) ?? {
            let fresh = NSMutableDictionary()
            cache.setObject(fresh, forKey: image)
            return fresh
        }()
        entry[key] = made
        return made
    }

    /// A transparent image of `size`, carrying `description` for accessibility:
    /// what the status button itself shows, so the item keeps the icon's width.
    static func placeholder(size: NSSize, description: String?) -> NSImage {
        let image = NSImage(size: size)
        image.accessibilityDescription = description
        return image
    }

    private static func make(_ image: NSImage, scale: CGFloat, tint: NSColor?, appearance: NSAppearance?) -> CGImage? {
        let w = Int((image.size.width * scale).rounded()), h = Int((image.size.height * scale).rounded())
        guard w > 0, h > 0 else { return nil }
        if tint == nil,
           let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep })
               .first(where: { $0.pixelsWide == w && $0.pixelsHigh == h }),
           let cg = rep.cgImage {
            return cg
        }
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let rect = NSRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        let draw = { image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1) }
        if let appearance { appearance.performAsCurrentDrawingAppearance(draw) } else { draw() }
        if let tint {
            tint.set()
            rect.fill(using: .sourceIn)
        }
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    private static func colorKey(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        return String(format: "%.3f,%.3f,%.3f,%.3f", c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
    }
}
