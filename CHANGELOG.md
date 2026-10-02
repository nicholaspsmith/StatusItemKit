# Changelog

Every push to `main` is a release. Before pushing, add a `## [X.Y.Z] - YYYY-MM-DD`
section at the top with `- ` entries (minor for features, patch for fixes); if an
`## [Unreleased]` section is waiting, turn it into that section. GitHub tags it
and publishes the section as the release notes; a push or pull request
without one is refused (`[no release]` in the tip commit is the only exception).
Versions follow [Semantic Versioning](https://semver.org/). The full rule:
[StatusItemKit — Releases](https://github.com/nicholaspsmith/StatusItemKit#releases-every-push-is-one).

## [0.15.0] - 2026-10-02

- feat: `MinuteCue`: each animated mascot animates once a minute, a second after the one ahead of it (Archimedes, Menu Pimp, Carol, Caveepyan, Armonitor, counting only the apps that are running); skipped under Reduce Motion
- feat: `IconAnimation` drives an icon animation at 60 fps, including while a menu is open
- feat: Menu Pimp's grin: `macDaddy(…, grin:)` widens his smile to show white teeth while a gold gleam crosses them (550 ms, linear)
- feat: Carol's run: `caterpillar(…, running:)` scissors her feet, each one opposite its neighbour, while a bob ripples from tail to head (1 s)
- feat: Caveepyan's lick: `chameleon(…, lick:)` flicks her tongue at the air, or unwinds it from the branch, reels it in and wraps it again (1 s)
- feat: Armonitor's lap: `MonitorLizardLap` sends him out of the monitor and counterclockwise round the screen in an 8 s overlay; `monitorLizard(…, lizard: false)` draws the monitor without him while he is away
- Mascots renamed: Armando is Armonitor, Mac Daddy is Menu Pimp

## [0.14.0] - 2026-10-02

- The reusable release workflow is now `menumon-release.yml`. Repos calling the old `menubarn-release.yml` keep releasing unchanged, with a warning on each run asking them to switch

## [0.13.0] - 2026-10-01

- Illustrated icons: `IllustratedIcon` composes menu-bar images from mascot art plus live overlays; Mac Daddy (`macDaddy(art:…)`) and Lumen (`lumen(keycap:…)`) use it

## [0.12.3] - 2026-10-01

- Monitor Lizard's glyph is redrawn in the storybook style and faces left like its mascot

## [0.12.2] - 2026-10-01

- Mac Daddy's glyph now matches his mascot: dark brown skin and a grey beard

## [0.12.1] - 2026-10-01

- Mac Daddy's hat tip no longer clips the feather, and a sweat drop no longer hides under the brim

## [0.12.0] - 2026-10-01

- New `CharacterIcon.macDaddy(level:asleep:flourish:)`: Mac Daddy, a tiny pimp whose suit and sweat follow process load, who sleeps when his duties are paused, and who tips his hat or flashes his chain after a sweep; one 24x22pt canvas for every state

## [0.11.0] - 2026-09-28

- `StatusItemController.isSuppressed` takes the item off the bar when the app has nothing to show, independent of a manager's yield; uses `isVisible`, since on macOS 27 a zero-width item leaves a ~16pt gap
- New `CharacterIcon.bin`, `raccoon` and `camcorder`, redrawn in the caterpillar's storybook style (ink outlines, shading, faces); each state shares one canvas so the bar never shifts

## [0.10.0] - 2026-09-27
### Added
- `CharacterIcon.caterpillar(effects:state:)`: SoundChain's caterpillar in black headphones. One segment lights per running effect (up to five); green processing, grey bypassed, red on an error. Drawn at 8x and downsampled to crisp 2x and 1x bitmaps, and cached.

## [0.9.0] - 2026-09-26
### Added
- `CharacterIcon.menuCrane(state:)`: Mendoza, Menu Crane's crane, in four states (idle, searching, grabbed, miss).
- Menu Crane joins the release kit's app list.

## [0.8.0] - 2026-09-26
### Added
- `adopt.sh` sets branch protection on `main`: a PR cannot merge until
  `release / check` passes, i.e. until it carries a new version or its tip
  says `[no release]`. Applied to every Menubarn repo.

## [0.7.0] - 2026-09-26
### Added
- Pull requests to a Menubarn repo fail unless `CHANGELOG.md` carries a new,
  correctly formatted version (or the tip commit says `[no release]`).
- A GitHub Release made by hand is retitled to its tag, `vX.Y.Z`, and the run
  fails so it is noticed: one naming convention for every release.
### Changed
- `adopt.sh` writes the app workflow with `pull_request` and `release`
  triggers; re-run it to update an adopted repo.

## [0.6.1] - 2026-09-26
### Fixed
- The release check no longer exits silently in a repo with no tags yet (its
  first release); `adopt.sh` backfills such a repo's whole history under
  `[Unreleased]`.

## [0.6.0] - 2026-09-26
### Added
- `scripts/release/adopt.sh --hooks-only` re-arms the pre-push hook in every
  Menubarn repo cloned here, without touching files; the apps' `install.sh`
  and the macOS setup suite run it.
- HotkeyKit joins the release rule.
### Changed
- README: "Things to know" for releases — `[no release]`, `[Unreleased]`
  sections, never tagging by hand, the per-repo hook, pushing over SSH.

## [0.5.0] - 2026-09-26
### Added
- Every push is a release: `scripts/release/` holds the rule (`check-release.sh`),
  a `pre-push` hook, and `adopt.sh`, which puts an app under it; the reusable
  `menubarn-release.yml` workflow tags each push to `main` and publishes its
  changelog section as a GitHub Release.
- This changelog, backfilled from the existing tags.

## [0.4.0] - 2026-09-26

- feat: owl pupils and usage bars run #005401 → #FF5401; small veins; veins only in the last quarter

## [0.3.0] - 2026-09-26

- feat: owl pupils run green→yellow→orange→red; veins fade in with the week
- feat: owl lids follow the session, the week reddens its eyes

## [0.2.0] - 2026-09-23

- feat: stamp the version from the nearest vX.Y.Z tag, and AppVersion.menuItem() to show it
- LICENSE: name the copyright holder above the MPL text
- License: Mozilla Public License 2.0
- feat: accept-dns is cyan, not green
- feat: a longer, flatter chameleon
- feat: give the chameleon a chameleon's body
- feat: the dorsal crest becomes a real fin
- feat: the chameleon rests in olive rather than branch brown
- feat: redraw the chameleon, and give each connection its own limb
- feat: the chameleon gains the owl's level of detail
- feat: the house glyph gains cottage detail
- feat: draw the house glyph as a solid silhouette
- CharacterIcon: redraw the monitor lizard as the leopard-gecko mascot
- docs: LoginRequest and LoginCLI in the API table
- feat: house character icon for Homestead
- feat: shared --login CLI for every menu-bar app
- tweak: owl whites go properly pink as the lid drops
- CharacterIcon: monitor lizard — bigger screen, dark-green lizard
- CharacterIcon: colour the monitor lizard — tan spotted lizard, yellow screen fill
- test: pixel-sample the monitor lizard's screen fill and amber tint
- feat: monitor lizard glyph — screen fills with brightness, amber for Night Shift
- feat: owl pupils take a colour each; AppearanceMenu colorItems lets an app supply its own colour block
- fix: setIcon and length only touch the status item when something changes (redundant sets relayout the bar and cancel an open menu)
- feat: menu open/close hooks and isSecondaryClick so an app can attach one native menu and build it per click; chameleon resting tail curls up open
- fix: popped menus run via NSMenu.popUp under the button, tracking the press natively; chameleon hard hat for Mullvad
- feat: chameleon — spots and a curled tail for Tailscale, yellow and a tongue for Mullvad, brown on its stick otherwise
- fix: popUp keeps the menu attached until tracking ends (menus flashed shut when another app was frontmost); chameleon on a stick with connection colours
- fix: status-item click handlers fire on mouse down so popped menus track the press like native menus
- tweak: owl veins run radially from pupil to rim
- feat: owl gets tired — pink whites and red veins as the lids drop; bigger beak under the eyes
- docs: Curtain is now Barn
- docs: Apollo Monitor described without the vendor name
- feat: camcorder gets a face — lens-eye, smile, viewfinder hat, record light on top
- docs: Apollo face in the CharacterIcon row
- feat: Apollo Twin face replaces the rocket — knob and tick ring as the mouth, squircle eyes
- docs: CharacterIcon in the API table; chameleon in the suite table
- feat: idle octopus is the four-armed one in green; no two-arm stage
- tweak: smiling octopus's face sits higher
- feat: idle octopus is a smiling green one with two arms, not a squid
- feat: octopus escalates by shape and colour — green squid, yellow four arms, orange eight, red eight — on one 28x22 canvas
- feat: owl is eyelid-brown all over; pupils lose their glint
- feat: chameleon larger and climbing at 35°, tongue level and tail trailing behind
- feat: key icon grows to the bar's full 22pt
- fix: key icon lights its first ray at any nonzero backlight, not from 7%
- feat: owl eyes are eyes — white, black pupil, brown eyelid that closes with usage
- feat: owl eye whites take the RGB complement of the fill for maximum contrast
- feat: chameleon climbs at an incline with a long hanging tail (Tailscale) and a tongue (Mullvad)
- feat: key 10% larger; chameleon 10% wider and taller
- feat: owl on a 32×22 canvas with eyes twice the size on white; chameleon 10% larger
- feat: octopus idles pale blue below 15% and always lights one tentacle; raccoon eyes red; a guy peeks out of the bin
- feat: the full character set — key, battery, camcorder, rocket, raccoon, bin; owl and octopus reworked; chameleon grows a tail per connection
- feat: CharacterIcon — owl, chameleon, octopus glyphs that carry data
- feat: MeterIcon.symbol — a flat-colour SF Symbol on the 18pt meter canvas
- docs: mention the Menubarn widget library
- docs: why a standalone app beats a SwiftBar plugin
- docs: add the Menubarn mascot to the README
- Shell.run: optional env overlay merged over the inherited environment
- Add capture-menu.sh, and advertise the suite
- Add a shared Icon menu: meter shape and colour
- feat: alert-free LoginItem.setEnabled for headless callers
- feat: popUp so a left click can present an arbitrary menu
- feat: yield by width, and optional left-click actions
- feat: expose status item length and autosave name
- feat: menu-bar yield protocol with self-healing restore
- Document the MeterIcon styles with a rendered sheet
- Add hard timeout to Shell.run so a hung child can't wedge callers
- feat: stable code-signing identity so TCC grants survive rebuilds

## [0.1.0] - 2026-06-22

- docs: README + MIT LICENSE
- feat: demo app dogfooding the framework
- feat: parameterized build/sign script + Info.plist template
- feat: StatusItemController + render funnel
- feat: LoginItem + Notifier system wrappers
- feat: MeterIcon drawing (dot + gauge/arc/pie/wedge)
- feat: MenuBuilder label-width math + view-based item
- feat: Shell command runner
- feat: package skeleton + Severity ramp
- docs: add StatusItemKit framework implementation plan
- docs: add StatusItemKit + menu-bar apps design spec
