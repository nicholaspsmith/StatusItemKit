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
}
