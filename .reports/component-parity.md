# Component parity — eyedropper-rb (round 3)

| | |
|---|---|
| Upstream | `origin/main` @ `9c480cb` |
| Port | `ruby` @ `9d03426` |
| Runtime gate reproduced this round | `drive_window.rb` 55/55, `drive_search_provider.rb` 17/17, `drive_portals.rb` 16/16 = **88/88, 0 failed** — matches the stated gate exactly |

This round re-verifies the three gaps the previous round found (schema keys,
metainfo block, desktop fields) by reading current source and diffing, not
by trusting `PORTING.md` or the prior `.reports/*.md`, and re-checks whether
the two "unverified, no check looks" findings (primary menu, stylesheet) have
gained a check since.

## Previously-found gaps: all three closed, verified by direct comparison

**Unit 15a (settings schema).** `data/com.github.finefindus.eyedropper.Rb.gschema.xml`
now declares `cie-illuminants` (default `5`, same summary/description text as
upstream) and `cie-standard-observer` (default `0`, same text) — 8 keys on
both sides, byte-equivalent key-by-key. Not just declared: `lib/eyedropper/settings.rb`
reads both (`cie_illuminant`, `cie_standard_observer`, `white_point`), and
`lib/eyedropper/illuminant.rb` and `lib/eyedropper/color.rb` consume
`white_point` in the XYZ/Lab math the keys exist to control — the keys are
wired, not merely present for show. **Closed.**

**Unit 21a (metainfo screenshots/features).** Read in full: the port's
`<description>` now carries the same 4-item `<ul>` upstream has, and all 4
`<screenshot>`/`<caption>` pairs are present with the same captions and image
URLs. **Closed.**

**Unit 21b (desktop entry fields).** `Keywords=Gnome;GTK;Color;Colorpicker;Picker;Palette;`
and `Categories=GNOME;GTK;Development;Graphics;Utility;WebDevelopment;` now
match upstream verbatim, and `DBusActivatable=true` is present. **Closed.**

## Unit 3 (primary menu) and unit 14 (stylesheet): still unverified by any check

Both are structurally confirmed correct by direct reading this round (the
menu's two sections and four `action:` targets in `window.rb` match
`window.blp`'s `menu primary_menu` exactly; `data/style.css` is byte-identical
to upstream's `data/resources/style.css`). **Neither claim rests on a check
that actually ran** — `grep -n 'step('` across `test/drive_window.rb` (44
steps) has no step that opens the `GMenuButton`'s popover and reads a label,
and none renders a widget and asserts a CSS rule took effect. Per this
round's instruction, a component no check exercises is unverified, not done,
even when a human read confirms it. This is unchanged from last round — it
was not fixed and was not claimed fixed, but it is still open and should not
be absorbed into "88/88, 0 failed" as if the gate covers it.

## Bijection / test-depth gaps (carried from `test-parity.md`, not re-litigated here)

Not a widget gap, but it affects what "parity" can be claimed for units 2
(edit sheet color math) and the parser: see `test-parity.md` for the 2
upstream-test-pairs merged into 1 Ruby test each.

## Icon set (unit 16)

Not independently re-verified beyond last round's finding that no check
compares a rendered icon pixel-for-pixel against upstream's SVGs; the drive
run screenshots the window (so an icon that failed to load at all would be
visible in the PNG) but nothing asserts against it. Unverified, carried
forward unchanged.

## Worked totals this round

| Axis | Verified clean (read + driven) | Verified clean (read only, no driving check) | Open gap |
|---|---:|---:|---:|
| Units (of the ~23 identified) | 18 | 3 (primary menu, stylesheet, icon set) | 0 |

Three gaps closed since the last round, zero new gaps found, two
"unverified" units unchanged. `clean: false` is still the honest verdict for
*this* report only because of the unverified units, not because of any
remaining confirmed defect — see `accountability-ensurance.md` for why
"unverified" and "clean" are not the same word here.
