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

Make a status icon's frame changes cost a layer swap instead of a button redraw,
for every app built on StatusItemKit, without changing how apps draw or call it.

Non-goals: keyframe loops (the swap already brings a 6 fps loop to about 0.1%; a
second API is not worth it now), text items (`setTitle`), template images.

## Design

**One path, opt in per controller.** `StatusItemController` gains
`init(…, layerIcon: Bool = false)`. With it on, `setIcon(_:)` keeps its signature
and meaning but draws differently:

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

**Falls back to today's path** when the image is a template (`isTemplate`: AppKit
tints those for the bar's appearance and a layer cannot), when the button has no
layer or window yet, and for `setTitle`, which removes the layer.

**Highlight.** The button still draws its own highlight (menu open) underneath;
the icon layer sits above it, so a full-colour mascot looks as it does today on
the highlighted background. To be checked by eye (below).

**Rollout.**
1. StatusItemKit 0.33.0 adds `layerIcon`, default off. Nothing changes for any
   app until it opts in.
2. SoundChain 1.17.0 opts in (`layerIcon: true`). Its walk and sleep are the
   heaviest animations, and are what the numbers above measure.
3. After it has run on both Macs for a few days, the other apps opt in, or the
   default flips in a later StatusItemKit release — a separate decision.

## Verification

- **Unit tests** (StatusItemKit): the bitmap chosen for scales 1 and 2; template
  and title fall back; the placeholder matches the icon's size and keeps its
  accessibility description; the cache returns the same `CGImage` for the same
  image and scale; `setVisible(false)` hides the layer.
- **Cost:** SoundChain's CPU walking and asleep, before and after, measured the
  same way as above. Pass: under 1% walking at 24 fps.
- **By eye** (screen capture of the bar is blank on this display, so Nick looks):
  Carol on the built-in display and on the Dell; the menu open over her (the
  highlight); light and dark menu bars; moving the bar between displays while
  she walks; parity's launch check of the build.
- No other app is affected until it opts in, so their behaviour needs no checks
  in this round.

## Risks

- A layer that does not track the button exactly would show Carol offset or
  clipped. The bounds tracking above and the by-eye checks cover it.
- A wrong bitmap on a scale change would show her blurry or doubled in size until
  the next frame. The backing-properties notification covers it, as does the
  next swap, which re-reads the window's scale.
- AppKit could, in some state, redraw the placeholder image over the layer. It is
  transparent, so nothing would show.
