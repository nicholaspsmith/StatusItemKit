# Changelog

Every push to `main` is a release. Add a `## [X.Y.Z] - YYYY-MM-DD` section at
the top (minor for features, patch for fixes); GitHub tags it and publishes
the section as the release notes. Versions follow [Semantic
Versioning](https://semver.org/).

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
