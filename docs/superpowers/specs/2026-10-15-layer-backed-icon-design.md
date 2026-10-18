# Layer-backed status icons: cheap animation frames

Date: 2026-10-15 · Status: draft for review

## Problem

Every Menumon mascot animates by calling `StatusItemController.setIcon(_:)` once
per frame. `setIcon` sets `button.image`, which makes AppKit redraw the whole
status button (`NSControl drawRect`, the cell drawing the image) and Core
Animation commit a transaction. The frames themselves are cached, so all of that
cost is the redraw.

Measured on the M5 Pro (2026-10-15, throwaway harness animating Carol's real walk
frames in a visible status item, 20 s per run, two rounds):

| Per frame, via | App CPU at 24 fps |
|---|---|
| `button.image` (today) | 10.8–11.0% |
| a `CALayer`'s `contents`, swapped | 0.32–0.39% |
| a `CAKeyframeAnimation` of `contents` | 0.01% |
| nothing (idle) | 0.01% |

WindowServer sat at 47–52% in every run, idle included, and no method changed it
beyond that noise. In SoundChain terms: Carol walking to music costs about 11% of
a core today and would cost about 0.4%; asleep (6 fps) 3.3% → about 0.1%.

## Goal

Replace how `setIcon(_:)` draws, for every app built on StatusItemKit, so a frame
change costs a layer swap instead of a button redraw — without changing how apps
draw or call it, and only once testing shows no regressions anywhere.

Non-goals: keyframe loops (the swap already brings a 6 fps loop to about 0.1%; a
second API is not worth it now) and text items (`setTitle`, which stays as is).
MacRecorder builds its own status item and is not affected.

## Design

**One path, replacing the old one.** `setIcon(_:)` keeps its signature and
meaning; its implementation changes for every app at once, with no flag:

- The button's own `image` becomes a transparent placeholder the size of the
  icon. It still sizes the item (variable length), so width, position and the
  menu anchor behave exactly as now. It is replaced only when the icon's size
  changes, which re-lays out the item as today.
- A `CALayer` added to the button's layer shows the icon: `contents` is the
  icon's bitmap for the button window's `backingScaleFactor` (the 2x
  representation on the built-in display, the 1x one on a 1x display),
  `contentsScale` matches, implicit animations are off, and the swap happens
  inside a `CATransaction` with actions disabled.
- The `CGImage` for each `NSImage` and scale is cached (keyed weakly by image, so
  CharacterIcon's cached frames convert once).
- The layer is centred in the button's bounds and follows them: on a frame
  change (`postsFrameChangedNotifications`), on `setVisible(false)` (length 0,
  the layer hides), and on the window's
  `didChangeBackingPropertiesNotification` (moving to a display with another
  scale re-picks the bitmap and `contentsScale`).
- Accessibility: the placeholder carries the icon's `accessibilityDescription`.

**Template icons** (Battery Time's plain battery, KeyLight's non-key styles, Menu
Crane's alternate) are tinted by AppKit with the menu bar's vibrancy. The layer
path tints them itself: the template drawn in the button's effective appearance
(`labelColor`), re-drawn when that appearance changes. Whether that matches
AppKit's vibrant rendering can only be judged by eye. If it does, templates use
the layer too and the old path is gone entirely; if any difference shows, they
alone keep AppKit's path, and the spec is updated to say so.
Result (2026-10-15, `scripts/icon-compare.sh`, five templates old and new side
by side): Nick saw no difference, so templates use the layer too and the old
path is gone.

**Before a window exists** (the first `setIcon`, during launch) the icon is set
the old way and moved onto the layer once the button has a window. `setTitle`
removes the layer.

**Highlight.** The button still draws its own highlight (menu open) underneath;
the icon layer sits above it, so a full-colour mascot looks as it does today on
the highlighted background. To be checked by eye (below).

**Rollout: tested in three stages, released only after all three pass.** Every
push to StatusItemKit's `main` is a release that parity rolls into all eleven apps,
so nothing reaches `main` until the change is confirmed.
1. **Local, this Mac:** all eleven apps built against the `layer-icon` branch and
   run in place of the installed copies; the checklist below, app by app.
2. **Soak, both Macs:** the branch pushed while checked out, so parity merges it
   into its StatusItemKit build and installs every app built with it on both
   Macs (how it already carries a pushed feature branch). Lived with for two
   days, including the M1's display. Rollback is checking out `main` and deleting
   the branch: parity rebuilds without it.
3. **Release:** merged to `main` as StatusItemKit 0.33.0 (a minor: same API,
   new drawing). parity opens each app's release.

## Verification

- **Unit tests** (StatusItemKit): the bitmap chosen for scales 1 and 2; template
  tinting for light and dark appearances; the placeholder matches the icon's
  size and keeps its accessibility description; the cache returns the same
  `CGImage` for the same image and scale; `setVisible(false)` hides the layer;
  `setTitle` removes it; an icon set before the window exists moves onto the
  layer.
- **Cost:** SoundChain walking (24 fps) and asleep (6 fps), before and after,
  measured as above; pass under 1% walking. Every other app's idle CPU, before
  and after: no increase.
- **By eye, every app** (screen capture of the bar is blank on this display, so
  Nick looks; a checklist per app with its states and animations):
  - each icon state the app can show, and its minute animation at :00 and :30;
  - the menu open over it (the highlight), and closed again;
  - light and dark menu bars, and Reduce Transparency on;
  - the built-in display and the Dell, and moving the bar between them while an
    icon animates;
  - template styles (Battery Time, KeyLight, Menu Crane) side by side with the
    old path, for the vibrancy question above;
  - Start at Login, Settings, Quit: unchanged; parity's launch check passes.
- **Soak:** two days on both Macs with nothing found, before stage 3.

**Stage 1 results (2026-10-15/16, this Mac).**
- By eye: Battery Time's battery went the wrong colour. Its ink is a colour
  resolved at draw time; the layer drew it under the app's appearance (the
  system theme) instead of the bar's (the wallpaper's), and cached full-colour
  icons whatever the appearance. Fixed in `1a4ae45`: every icon draws under the
  button's `effectiveAppearance`, and the cache keys on it. After that, Nick:
  everything on this Mac looks right.
- parity pushed the checked-out branch itself and installed it on both Macs at
  15:19–15:32, before stage 1 paused it, so stage 2 began early, and on the M1
  without the fix until 21:49. The first "before" CPU figures were therefore
  layer builds and are void; the baseline below is every app at its installed
  commit built against `main`.
- Idle CPU, 60 s per run, each run 90 s after its swap (new / old / new): Battery
  Time 0.65 / 0.95 / 0.70%, Claude Usage 0.23 / 0.25 / 0.15, Homestead 2.40 /
  2.03 / 1.02, KeyLight 1.37 / 1.53 / 1.45, Mac Daddy 0.63 / 0.55 / 0.40, Menu
  Crane 0.38 / 0.57 / 0.28, Monitor Lizard 0.68 / 0.98 / 0.18, Panes 0.42 /
  0.55 / 0.33, VPN & DNS 0.50 / 0.62 / 0.38. No app higher on the layer beyond
  noise (±0.5). SoundChain is not comparable this way: its CPU follows what is
  playing.
- SoundChain walking to music, main thread over a 10 s `sample`, menu closed:
  old 16.2% (CA commit and `drawRect` under each frame), new 0.35%. Pass.

**Stage 2 results (soak, 2026-10-15 21:49 → 2026-10-16 07:42).** Cut short at
Nick's request: he is travelling and the M1 is off the LAN for days. About ten
hours on both Macs with the fix (the M1's mostly overnight): no crash report from
any Menumon app on either Mac, no failed launch check in parity's log, nothing
seen off. Released as 0.34.0, since another change took 0.33.0 meanwhile.

## Risks

- A layer that does not track the button exactly would show Carol offset or
  clipped. The bounds tracking above and the by-eye checks cover it.
- A wrong bitmap on a scale change would show her blurry or doubled in size until
  the next frame. The backing-properties notification covers it, as does the
  next swap, which re-reads the window's scale.
- AppKit could, in some state, redraw the placeholder image over the layer. It is
  transparent, so nothing would show.
- Because it changes every app at once, a regression found after release
  reaches all of them; the soak exists to find it first, and a revert is one
  patch release.
