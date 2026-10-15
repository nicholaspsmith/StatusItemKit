// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import XCTest
@testable import StatusItemKit

final class MinuteCueTests: XCTestCase {
    let owl = "com.nicholaspsmith.ClaudeUsage", pimp = "com.nicholaspsmith.MacDaddy"
    let carol = "com.nicholaspsmith.SoundChain", cami = "com.nicholaspsmith.VPNDNSMenuBar"
    let lizard = "com.nicholaspsmith.MonitorLizard"

    // The worked example: Archimedes and Menu Pimp → :00 and :01; add Carol → :02.
    func testSlotsFollowTheOrderOfWhatIsRunning() {
        let two: Set = [owl, pimp]
        XCTAssertEqual(MinuteCue.slot(of: owl, running: two), 0)
        XCTAssertEqual(MinuteCue.slot(of: pimp, running: two), 1)
        let three = two.union([carol])
        XCTAssertEqual(MinuteCue.slot(of: carol, running: three), 2)
    }

    func testAbsentAppsLeaveNoGap() {
        XCTAssertEqual(MinuteCue.slot(of: lizard, running: [owl, lizard]), 1)
        XCTAssertEqual(MinuteCue.slot(of: cami, running: [cami]), 0)
    }

    func testUnlistedAppGoesLast() {
        XCTAssertEqual(MinuteCue.slot(of: "com.example.Other", running: [owl, carol, "com.example.Other"]), 2)
    }

    func testNextMinute() {
        XCTAssertEqual(MinuteCue.nextMinute(after: Date(timeIntervalSince1970: 1_000_000_030.4)).timeIntervalSince1970, 1_000_000_080)
        XCTAssertEqual(MinuteCue.nextMinute(after: Date(timeIntervalSince1970: 1_000_000_020)).timeIntervalSince1970, 1_000_000_080)
        // Cues fall on the half minute as well as the minute.
        XCTAssertEqual(MinuteCue.nextCue(after: Date(timeIntervalSince1970: 1_000_000_030.4)).timeIntervalSince1970, 1_000_000_050)
        XCTAssertEqual(MinuteCue.nextCue(after: Date(timeIntervalSince1970: 1_000_000_050)).timeIntervalSince1970, 1_000_000_080)
    }
}

final class MascotAnimationTests: XCTestCase {
    func testCaterpillarRunStartsAndEndsStanding() {
        let d = CharacterIcon.caterpillarRunDuration
        for t in [0, d] {
            let g = CaterpillarGait(time: t, duration: d)
            XCTAssertEqual(g.strength, 0)
            XCTAssertEqual(g.bob(2), 0)
            XCTAssertEqual(g.foot(2), 0)
        }
    }

    // Neighbouring feet always swing opposite ways.
    func testCaterpillarFeetAlternate() {
        let g = CaterpillarGait(time: 0.4, duration: CharacterIcon.caterpillarRunDuration)
        for i in 0..<4 { XCTAssertEqual(g.foot(i), -g.foot(i + 1), accuracy: 1e-9) }
        XCTAssertNotEqual(g.foot(0), 0)
    }

    /// The most opaque pixel in the top row of the image's largest bitmap, 0 … 1.
    private func topRowAlpha(_ image: NSImage) -> CGFloat {
        let rep = image.representations.compactMap { $0 as? NSBitmapImageRep }.max { $0.pixelsWide < $1.pixelsWide }!
        return (0..<rep.pixelsWide).map { rep.colorAt(x: $0, y: 0)?.alphaComponent ?? 0 }.max() ?? 0
    }

    // Her headband is a hair from the top of the canvas: no run frame or walk
    // pose may lift it into the top row, where it would be cut flat.
    func testCarolNeverLeavesTheCanvas() {
        XCTAssertEqual(topRowAlpha(CharacterIcon.caterpillar(effects: 3, state: .processing)), 0)
        for t in stride(from: 0.01, to: CharacterIcon.caterpillarRunDuration, by: 0.01) {
            let frame = CharacterIcon.caterpillar(effects: 3, state: .processing, running: t)
            XCTAssertLessThan(topRowAlpha(frame), 0.05, "run at \(t) s")
        }
        for frame in 0..<CaterpillarWalk.framesPerStride {
            XCTAssertLessThan(topRowAlpha(CharacterIcon.caterpillar(effects: 3, state: .processing,
                                                                    walking: walk(at: frame))), 0.05, "walk frame \(frame)")
        }
    }

    // MARK: Carol asleep

    private func bottomRowAlpha(_ image: NSImage) -> CGFloat {
        let rep = image.representations.compactMap { $0 as? NSBitmapImageRep }.max { $0.pixelsWide < $1.pixelsWide }!
        return (0..<rep.pixelsWide).map { rep.colorAt(x: $0, y: rep.pixelsHigh - 1)?.alphaComponent ?? 0 }.max() ?? 0
    }

    // Asleep she loops: the same moment of each loop is the same cached image,
    // and it is not her awake pose.
    func testSleepLoopsAndIsCached() {
        let loop = CharacterIcon.caterpillarSleepLoop
        for t in [0.0, 0.4, 1.7] {
            let a = CharacterIcon.caterpillar(effects: 0, state: .bypassed, sleeping: t)
            XCTAssertTrue(a === CharacterIcon.caterpillar(effects: 0, state: .bypassed, sleeping: t + loop * 3))
            XCTAssertFalse(a === CharacterIcon.caterpillar(effects: 0, state: .bypassed))
            XCTAssertEqual(a.size, NSSize(width: 36, height: 22))
        }
        // Asleep wins over a walk or a run.
        var w = CaterpillarWalk(); w.advance(by: 1, walking: true)
        XCTAssertTrue(CharacterIcon.caterpillar(effects: 0, state: .bypassed, running: 0.3, walking: w, sleeping: 0.4)
                      === CharacterIcon.caterpillar(effects: 0, state: .bypassed, sleeping: 0.4))
    }

    // She breathes in and out over one loop: her body rises on the in-breath and
    // her head nods lowest at the end of the out-breath. A Z is always rising.
    func testSleepBreathesNodsAndZsRise() {
        let n = CharacterIcon.caterpillarSleepFrames
        let doze = (0..<n).map { CaterpillarDoze(frame: $0) }
        XCTAssertEqual(doze[0].breath, 0, accuracy: 1e-9)
        XCTAssertEqual(doze.map(\.breath).max()!, 1, accuracy: 0.05)
        XCTAssertGreaterThan(doze[n / 2].bob(2), doze[0].bob(2))
        XCTAssertLessThan(doze[0].bob(-1), doze[n / 2].bob(-1))
        for d in doze {
            XCTAssertFalse(d.zs.isEmpty, "frame \(d.frame)")
            XCTAssertEqual(d.foot(1), 0)
            XCTAssertEqual(d.footLift(1), 0)
        }
        // Following one Z frame to frame: it climbs, and grows.
        let first = doze.compactMap { $0.zs.first { $0.id == 0 } }
        XCTAssertGreaterThan(first.count, n / 2)
        for (a, b) in zip(first, first.dropFirst()) {
            XCTAssertGreaterThan(b.center.y, a.center.y)
            XCTAssertGreaterThanOrEqual(b.size, a.size)
        }
        XCTAssertEqual(CaterpillarDoze.at(CharacterIcon.caterpillarSleepLoop * 2.5).frame, n / 2)
        XCTAssertEqual(CaterpillarDoze.at(-0.0001).frame, n - 1)
    }

    // Asleep she stays inside the icon, headphones on or off: no higher than the
    // top, and no lower at the bottom than she sits awake.
    func testSleepStaysInsideTheCanvas() {
        for headphones in [true, false] {
            let awake = bottomRowAlpha(CharacterIcon.caterpillar(effects: 0, state: .bypassed, headphones: headphones))
            for k in 0..<CharacterIcon.caterpillarSleepFrames {
                let t = Double(k) * CharacterIcon.caterpillarSleepFrameInterval
                let frame = CharacterIcon.caterpillar(effects: 0, state: .bypassed, sleeping: t, headphones: headphones)
                XCTAssertLessThan(topRowAlpha(frame), 0.05, "frame \(k), headphones \(headphones)")
                XCTAssertLessThanOrEqual(bottomRowAlpha(frame), awake + 0.1, "frame \(k), headphones \(headphones)")
            }
        }
    }

    // MARK: Carol's walk

    /// A walk brought to `drive` and then on to the middle of `frame`.
    private func walk(at frame: Int, drive: CGFloat = 1) -> CaterpillarWalk {
        var w = CaterpillarWalk()
        w.advance(by: CaterpillarWalk.release, drive: drive)
        XCTAssertEqual(w.strength, drive)
        let n = Double(CaterpillarWalk.framesPerStride)
        let target = (Double(frame) + 0.5) / n
        w.advance(by: (target - w.cycle + 1).truncatingRemainder(dividingBy: 1) / w.stridesPerSecond, drive: drive)
        XCTAssertEqual(w.frame, frame)
        return w
    }

    func testWalkStartsStanding() {
        let rest = CaterpillarWalk()
        XCTAssertEqual(rest.strength, 0)
        XCTAssertTrue(rest.isResting)
        for i in -1..<5 {
            XCTAssertEqual(rest.bob(i), 0)
            XCTAssertEqual(rest.foot(i), 0)
            XCTAssertEqual(rest.footLift(i), 0)
        }
    }

    // She follows the drive: quickly up (`attack` for the whole range), more
    // slowly down (`release`), and holds wherever it settles.
    func testWalkFollowsTheDrive() {
        var w = CaterpillarWalk()
        w.advance(by: CaterpillarWalk.attack / 2, drive: 1)
        XCTAssertEqual(w.strength, 0.5, accuracy: 1e-9)
        XCTAssertFalse(w.isResting)
        w.advance(by: CaterpillarWalk.attack, drive: 1)
        XCTAssertEqual(w.strength, 1)
        w.advance(by: CaterpillarWalk.release / 4, drive: 0)
        XCTAssertEqual(w.strength, 0.75, accuracy: 1e-9)
        w.advance(by: CaterpillarWalk.release, drive: 0.4)
        XCTAssertEqual(w.strength, 0.4, accuracy: 1e-9)
        w.advance(by: CaterpillarWalk.attack, drive: 0.6)
        XCTAssertEqual(w.strength, 0.6, accuracy: 1e-9)
        w.advance(by: CaterpillarWalk.release, drive: 0)
        XCTAssertEqual(w.strength, 0)
        XCTAssertTrue(w.isResting)
        // `walking:` is drive 1 or 0.
        w.advance(by: CaterpillarWalk.attack, walking: true)
        XCTAssertEqual(w.strength, 1)
    }

    // Louder, faster: her stride speed runs from `slowestStride` to `fastestStride`.
    func testLouderWalksFaster() {
        XCTAssertEqual(walk(at: 0, drive: 1).stridesPerSecond, CaterpillarWalk.fastestStride, accuracy: 1e-9)
        XCTAssertEqual(CaterpillarWalk().stridesPerSecond, CaterpillarWalk.slowestStride, accuracy: 1e-9)
        XCTAssertLessThan(walk(at: 0, drive: 0.3).stridesPerSecond, walk(at: 0, drive: 0.6).stridesPerSecond)
    }

    // Louder, higher: her height is her strength in `heightSteps` steps, rounded
    // up so the faintest sound still moves her.
    func testLouderStepsHigher() {
        let full = walk(at: 2), half = walk(at: 2, drive: 0.5), nearHalf = walk(at: 2, drive: 0.45)
        XCTAssertGreaterThan(full.bob(0), 0)
        XCTAssertEqual(half.bob(0), full.bob(0) / 2, accuracy: 1e-9)
        XCTAssertEqual(nearHalf.bob(0), half.bob(0), accuracy: 1e-9)
        XCTAssertEqual(walk(at: 2, drive: 0.01).bob(0), full.bob(0) / CGFloat(CaterpillarWalk.heightSteps), accuracy: 1e-9)
    }

    // The stride loops: after a whole stride she is in the same pose, however
    // long she has been walking.
    func testWalkLoopsEachStride() {
        var w = walk(at: 5)
        let before = (-1..<5).map { [w.bob($0), w.foot($0), w.footLift($0)] }
        for _ in 0..<1000 { w.advance(by: 1 / w.stridesPerSecond, drive: 1) }
        XCTAssertEqual(w.frame, 5)
        XCTAssertLessThan(w.cycle, 1)
        let after = (-1..<5).map { [w.bob($0), w.foot($0), w.footLift($0)] }
        for (a, b) in zip(before.joined(), after.joined()) { XCTAssertEqual(a, b, accuracy: 1e-9) }
    }

    // The wave travels from tail to head: each part does what the part behind
    // it did `lagFrames` earlier, and the head (-1) goes last, with a smaller nod.
    func testWalkWaveRunsTailToHead() {
        let n = CaterpillarWalk.framesPerStride, lag = CaterpillarWalk.lagFrames
        for frame in 0..<n {
            let now = walk(at: frame), later = walk(at: (frame + lag) % n)
            for i in 0..<4 {
                XCTAssertEqual(later.bob(i), now.bob(i + 1), accuracy: 1e-9, "part \(i) at frame \(frame)")
                XCTAssertEqual(later.foot(i), now.foot(i + 1), accuracy: 1e-9)
            }
            XCTAssertEqual(later.bob(-1) > 0, now.bob(0) > 0, "head at frame \(frame)")
            XCTAssertLessThan(later.bob(-1), CaterpillarWalk.bobHeight / 2)
        }
    }

    // A hump, not a wobble: a few parts are up at any moment, never most of her.
    func testWalkLiftsOnlyAHump() {
        for frame in 0..<CaterpillarWalk.framesPerStride {
            let w = walk(at: frame)
            let up = (-1..<5).filter { w.bob($0) > 0 }.count
            XCTAssertTrue((1...3).contains(up), "frame \(frame): \(up) parts up")
            for i in -1..<5 { XCTAssertGreaterThanOrEqual(w.bob(i), 0) }
        }
    }

    // Each foot steps forward (toward the head) while its segment is up, and
    // slides back while it is down, so she walks on the spot.
    func testWalkFeetStepForwardWhileLifted() {
        let n = CaterpillarWalk.framesPerStride
        for frame in 0..<n {
            let now = walk(at: frame), next = walk(at: (frame + 1) % n)
            for i in 0..<5 where now.bob(i) > 0 && next.bob(i) > 0 {
                XCTAssertGreaterThan(next.foot(i), now.foot(i), "foot \(i) at frame \(frame)")
                XCTAssertGreaterThan(now.footLift(i), 0)
            }
            for i in 0..<5 where now.bob(i) == 0 && next.bob(i) == 0 {
                XCTAssertLessThan(next.foot(i), now.foot(i), "foot \(i) at frame \(frame)")
                XCTAssertEqual(now.footLift(i), 0)
            }
        }
    }

    // Every frame at every height is drawn once and reused; at rest she is the
    // standing image.
    func testWalkFramesAreCached() {
        let a = CharacterIcon.caterpillar(effects: 2, state: .processing, walking: walk(at: 3))
        let b = CharacterIcon.caterpillar(effects: 2, state: .processing, walking: walk(at: 3))
        let c = CharacterIcon.caterpillar(effects: 2, state: .processing, walking: walk(at: 9))
        XCTAssertTrue(a === b)
        XCTAssertFalse(a === c)
        let low = CharacterIcon.caterpillar(effects: 2, state: .processing, walking: walk(at: 3, drive: 0.45))
        XCTAssertTrue(low === CharacterIcon.caterpillar(effects: 2, state: .processing, walking: walk(at: 3, drive: 0.5)))
        XCTAssertFalse(low === a)
        XCTAssertEqual(c.size, NSSize(width: 36, height: 22))
        let standing = CharacterIcon.caterpillar(effects: 2, state: .processing)
        XCTAssertTrue(CharacterIcon.caterpillar(effects: 2, state: .processing, walking: CaterpillarWalk()) === standing)
    }

    func testTongueLickReturnsToWhereItStarted() {
        let d = CharacterIcon.iguanaLickDuration
        XCTAssertEqual(CharacterIcon.tongueExtent(lickAt: 0, wrapped: false), 0, accuracy: 0.01)
        XCTAssertEqual(CharacterIcon.tongueExtent(lickAt: d * 0.999, wrapped: false), 0, accuracy: 0.01)
        XCTAssertEqual(CharacterIcon.tongueExtent(lickAt: 0, wrapped: true), 1, accuracy: 0.01)
        XCTAssertEqual(CharacterIcon.tongueExtent(lickAt: d * 0.5, wrapped: true), 0)
        XCTAssertEqual(CharacterIcon.tongueExtent(lickAt: d * 0.999, wrapped: true), 1, accuracy: 0.01)
    }

    func testAnimationFramesKeepTheCanvasSize() {
        XCTAssertEqual(CharacterIcon.caterpillar(effects: 2, state: .processing, running: 0.4).size, NSSize(width: 36, height: 22))
        XCTAssertEqual(CharacterIcon.iguana(tailscale: true, mullvad: true, lick: 0.3).size, NSSize(width: 30, height: 22))
        XCTAssertEqual(CharacterIcon.macDaddy(level: .cool, asleep: false, flourish: nil, grin: 0.5).size, NSSize(width: 24, height: 22))
        XCTAssertEqual(CharacterIcon.monitorLizard(brightness: 0.5, nightShift: false, lizard: false).size, NSSize(width: 25, height: 22))
    }

    // Out of the slot heading left, round the screen counterclockwise, and home.
    func testLizardTrackIsACounterclockwiseLoopFromTheSlot() {
        let start = NSPoint(x: 800, y: 888)
        let track = LizardTrack(bounds: NSRect(x: 0, y: 0, width: 1000, height: 900), start: start, topY: 888)
        XCTAssertEqual(track.points.first, start)
        XCTAssertEqual(track.points.last!.x, start.x, accuracy: 0.01)
        XCTAssertEqual(track.points.last!.y, start.y, accuracy: 0.01)
        XCTAssertLessThan(track.at(1).direction.dx, 0)
        var area: CGFloat = 0
        for (a, b) in zip(track.points, track.points.dropFirst()) { area += a.x * b.y - b.x * a.y }
        XCTAssertGreaterThan(area, 0)   // positive shoelace area = counterclockwise
    }

    // The icon lap starts and ends in his resting pose, facing the same way.
    func testMonitorLapReturnsToItsPose() {
        for p in [CGFloat(0), 1] {
            let lap = MonitorLizardGlyph.Lap(p)
            XCTAssertEqual(lap.blend, 0)
            XCTAssertEqual(lap.turn.truncatingRemainder(dividingBy: 2 * .pi), 0, accuracy: 1e-6)
            for t in [CGFloat(0), 0.5, 1] {
                let a = lap.spine(t, 0), b = MonitorLizardGlyph.onSpine(t)
                XCTAssertEqual(a.x, b.x, accuracy: 1e-6); XCTAssertEqual(a.y, b.y, accuracy: 1e-6)
            }
        }
        XCTAssertEqual(MonitorLizardGlyph.Lap(0.5).blend, 1)
    }

    // Counterclockwise round the glass: heading left along the top, then down.
    func testMonitorLapGoesCounterclockwise() {
        let loop = MonitorLizardGlyph.loop
        XCTAssertLessThan(loop.at(1).direction.dx, 0)
        XCTAssertLessThan(loop.at(loop.length * 0.25).direction.dy, 0)
    }

    // Lumen's gleam, Manny's focus and Gertie's door all end where they began.
    func testShimmerFocusAndDoorReturnToRest() {
        XCTAssertNil(LumenRays.wave(0)); XCTAssertNil(LumenRays.wave(1))
        XCTAssertNotNil(LumenRays.wave(0.5))
        XCTAssertGreaterThan(LumenRays.wave(0.5)!.max()!, 0.5)
        for p in [CGFloat(0), 1] {
            XCTAssertEqual(CharacterIcon.camcorderIrisClosure(at: p), 0)
            XCTAssertEqual(CharacterIcon.houseDoorOpening(at: p), 0)
        }
        XCTAssertEqual(CharacterIcon.camcorderIrisClosure(at: 0.35), 1)
        XCTAssertEqual(CharacterIcon.houseDoorOpening(at: 0.45), 1)
    }

    func testEndFramesMatchTheRestingGlyph() {
        func png(_ i: NSImage) -> Data? {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(i.size.width * 2), pixelsHigh: 44, bitsPerSample: 8,
                                       samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = i.size
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            i.draw(in: NSRect(origin: .zero, size: i.size)); NSGraphicsContext.restoreGraphicsState()
            return rep.representation(using: .png, properties: [:])
        }
        XCTAssertEqual(png(CharacterIcon.camcorder(recording: false, focus: 1)), png(CharacterIcon.camcorder(recording: false)))
        XCTAssertNotEqual(png(CharacterIcon.camcorder(recording: false, focus: 0.4)), png(CharacterIcon.camcorder(recording: false)))
        XCTAssertEqual(png(CharacterIcon.camcorder(recording: true, focus: 0.4)), png(CharacterIcon.camcorder(recording: true)))
        let house = { (d: CGFloat, r: Bool) in CharacterIcon.house(lightsOn: 1, fanOn: false, reachable: r, configured: true, door: d) }
        XCTAssertEqual(png(house(1, true)), png(house(0, true)))
        XCTAssertNotEqual(png(house(0.45, true)), png(house(0, true)))
        XCTAssertEqual(png(house(0.45, false)), png(house(0, false)))
    }
}

// Mendoza's once-a-minute grab: the bucket drops open, snaps shut, and lifts
// back to where it hangs, with the end frame the resting glyph.
final class CraneGrabTests: XCTestCase {
    func testGrabStartsAndEndsAtRest() {
        for t in [0, CharacterIcon.menuCraneGrabDuration] {
            let g = CharacterIcon.craneGrab(at: t)
            XCTAssertEqual(g.drop, 0, "t=\(t)"); XCTAssertEqual(g.jaw, 0, "t=\(t)"); XCTAssertFalse(g.happy, "t=\(t)")
        }
    }

    func testBucketDropsOpenThenSnapsShutAtTheBottom() {
        let lowering = CharacterIcon.craneGrab(at: 0.3)
        XCTAssertGreaterThan(lowering.drop, 0.3); XCTAssertGreaterThan(lowering.jaw, 0.5); XCTAssertFalse(lowering.happy)
        let bottom = CharacterIcon.craneGrab(at: 0.55)
        XCTAssertEqual(bottom.drop, 1); XCTAssertEqual(bottom.jaw, 0); XCTAssertTrue(bottom.happy)
        let lifting = CharacterIcon.craneGrab(at: 0.9)
        XCTAssertLessThan(lifting.drop, 1); XCTAssertGreaterThan(lifting.drop, 0); XCTAssertEqual(lifting.jaw, 0); XCTAssertTrue(lifting.happy)
    }

    func testGrabEndFrameIsTheRestingGlyph() {
        func png(_ i: NSImage) -> Data? {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 44, pixelsHigh: 44, bitsPerSample: 8,
                                       samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = i.size
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            i.draw(in: NSRect(origin: .zero, size: i.size)); NSGraphicsContext.restoreGraphicsState()
            return rep.representation(using: .png, properties: [:])
        }
        let rest = png(CharacterIcon.menuCrane(state: .idle))
        XCTAssertEqual(png(CharacterIcon.menuCrane(state: .idle, grab: CharacterIcon.menuCraneGrabDuration)), rest)
        XCTAssertEqual(png(CharacterIcon.menuCrane(state: .idle, grab: nil)), rest)
        XCTAssertNotEqual(png(CharacterIcon.menuCrane(state: .idle, grab: 0.4)), rest)
    }

    func testMendozaAndPanesTakeTheirTurnsAfterGertie() {
        let order = MinuteCue.order
        let gertie = order.firstIndex(of: "com.nicholaspsmith.Homestead")!
        XCTAssertEqual(order.firstIndex(of: "com.nicholaspsmith.MenuCrane"), gertie + 1)
        XCTAssertEqual(order.firstIndex(of: "com.nicholaspsmith.Panes"), gertie + 2)
    }
}
