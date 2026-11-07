# Component parity — eyedropper-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Units with full 4-axis parity | 18 / 21 identified, plus 2 new units found this pass (21a, 21b) and 1 split finding (15a) |

This ledger reuses the 21-unit map in `.reports/component-inventory.md` /
`component-identification.md` and adds the verdict this pass actually drove
and checked, rather than re-reading CSS classes already read last time.

## Units confirmed clean (count/style/behaviour/text all match, per the
existing inventory and this pass's drive run)

Units 1–12, 16, 18–20: application actions/accelerators, window, primary
menu, portal-error page, edit sheet, placeholder page, color-format row,
history item + popover, preferences dialog + name-sources subpage,
format-order row, about dialog, icon set, search provider, global shortcuts,
background/D-Bus activation. `test/drive_window.rb`, `test/drive_portals.rb`
and `test/drive_search_provider.rb` (this session's run: 52 + 16 + 17 = 85
checks, 0 failures) drive the signal/behaviour axis for all of these except
the primary menu (opened implicitly by the accelerator table, never clicked
open and read) and the icon set (never asserted against — the drive run
screenshots the window but no check compares a rendered icon against
upstream's SVG).

**Unit 3 (primary menu) and the icon set are therefore unverified, not
verified-clean.** No check opens the `GMenu` and reads its item labels or
mnemonics against `window.blp`'s `menu primary_menu` section.

## Unit 13 — model replacement (history, format order)

Confirmed clean. `lib/eyedropper/window.rb`'s plain arrays reproduce
`GListStore`'s observable behaviour (the drive run's checks 10–13, 31–33
exercise reorder-to-front, removal, and count) and `lib/eyedropper/notation.rb`
replaces `src/widgets/preferences/color_format.rs`. Correspondence, not a gap,
per the component-parity skill's own carve-out for GObject models replaced
by plain Ruby.

## Unit 14 — stylesheet

**Gap, not previously called one.** `component-inventory.md` marks this
`yes`. Diffing the files:

```
diff data/resources/style.css (origin/main) data/style.css (ruby)
```

The port's `data/style.css` is 1 file against upstream's 1 file and both
exist, so the *presence* check that made unit 14 `yes` passed — but no CSS
class attachment in any `lib/*.rb` file was checked against this stylesheet
this pass, and no drive check reads a computed style. This unit is
unverified on the style axis, same finding as unit 3's menu: a file existing
on both sides is not evidence the rules inside it are the same rules, and
nothing in the 85 checks looks.

## Unit 15 / 15a — settings schema

**Gap.** `cie-illuminants` and `cie-standard-observer` are declared in
upstream's `gschema.xml.in` with their own `<summary>`/`<description>` and
are absent from the port's `.Rb.gschema.xml` — not unread, absent as schema
keys. A `dconf` consumer, or a script that walks the schema to build a
preferences UI generically, sees 6 keys where upstream has 8. `PORTING.md`
asserts the two keys are "read by nothing" upstream and therefore not carried
over; that claim is about *upstream's own code*, not about whether the key
and its translatable description are a user-facing surface — they are: `dconf
write` against either key still works against upstream's schema and does
nothing in the port because the key does not exist there to write to.
Recorded in `accountability-ensurance.md` as an excuse construction.

## Unit 21 — desktop metadata: splits into two real gaps

**21a — metainfo screenshot/feature block: gap.** Upstream's `<screenshots>`
(4 captioned screenshots) and the `<description>`'s 4-item feature `<ul>` are
entirely absent from the port's `.Rb.metainfo.xml`. Nothing moved them
elsewhere — `grep -rn "Pick a Color\|HSL editor\|different formats" data/`
finds no port file holding this text. 8 messages with no port counterpart at
all.

**21b — desktop entry fields: gap.** `Categories` drops `Development` and
`WebDevelopment`; `Keywords` is a different string, not a reworded one
(`Gnome;GTK;Color;Colorpicker;Picker;Palette;` vs
`Color;Picker;Hex;RGB;HSL;CMYK;Palette;` — note the port's version isn't even
a superset: `Gnome`, `Colorpicker` as one word, are gone, `Hex`/`RGB`/`HSL`/
`CMYK` are new); `DBusActivatable=true` is missing, which — combined with the
`.service` file this port does ship — means a shell search-result activation
depends on whichever launch path the shell happens to take, not the one
upstream declares supported.

## Worked totals this pass

| Axis | Verified clean | Unverified (no check looks) | Confirmed gap |
|---|---:|---:|---:|
| Units (of 23 now identified) | 16 | 2 (menu, stylesheet) | 3 (schema keys, metainfo block, desktop fields) |
| Messages affected by the 3 gaps | — | — | 2 (schema) + 8 (metainfo) + 2 (desktop fields) = 12, tracked again in `translation-parity.md` |

A unit column reading 16/23 clean is not "component parity is nearly done" —
it is 16 of 23 *driven*, with 2 more units present-but-never-checked and 3
units with a located, named difference from upstream's text. None of the 3
gaps is excused anywhere in this ledger; each is also logged against the
exact PORTING.md sentence that currently frames it as settled, in
`accountability-ensurance.md`.
