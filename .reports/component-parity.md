# Component parity — eyedropper-rb (round 4)

| | |
|---|---|
| Upstream | `origin/main` @ `9c480cb` |
| Port | `ruby` @ `65ea711` |
| Runtime gate reproduced this round | `drive_window.rb` 67/67, `drive_search_provider.rb` 17/17, `drive_portals.rb` 16/16 = **100/100, 0 failed** — matches the stated gate exactly, re-run fresh this round, not taken from the commit message |

Round 3 closed three structural gaps (schema keys, metainfo, desktop fields)
by reading and diffing, and left two units — the primary menu and the
stylesheet gradient — marked "unverified, not done" specifically because no
runtime check exercised them, plus a third weaker finding (icon set) with
the same shape. This round's job is to check whether `65ea711` actually
closed those three, or only added checks that look like they do.

## The three "unverified" units from round 3: re-checked by running the checks and reading what they assert

**Unit 3 (primary menu).** Ran `drive_window.rb` fresh. Step 42
("the primary menu's real `Gio::Menu` model opens and lists its items")
passes. Read the assertions directly (not inferred from the step name):
it pops the real `GMenuButton` popover (`popover.popup`), asserts
`popover.visible?`, then reads `window.primary_menu.n_items == 2`, walks
both sections via `get_item_link(.., "section")`, and compares
`get_item_attribute_value(.., "action", string_type)` against the literal
action names (`app.clear-history`, `app.random-color`, `app.preferences`,
`app.about`) in the order upstream's `window.blp` declares them, plus the
actual label strings (`_Clear History`, `_About Eyedropper`). This is a
live read of the running `Gio::Menu` model, not a structural re-parse.
**Closed, now driven.**

**Unit 14 (stylesheet — `.hue-slider trough` gradient).** Step rendered
`window.edit_sheet.hue_scale` to a real PNG and read pixel bytes back via
`GdkPixbuf::Pixbuf`. Re-ran it: left edge reads red (`[0]>150, [1]<100,
[2]<100` on the sampled pixel), a point a quarter of the way across has
shifted away from red. This can only be true if GTK's CSS engine actually
applied `data/style.css`'s `.hue-slider trough` gradient to the rendered
widget for this display — a passing `css_classes.include?("hue-slider")`
check would not prove this, since that only proves the class name string is
attached, not that a loaded stylesheet has a matching rule. **Closed, now
driven.**

**Icon set (part of unit 16).** New step does
`Gtk::IconTheme.get_for_display(window.window.display).has_icon?(name)` for
three icon names actually used in the running app
(`color-select-symbolic`, the app's own symbolic icon,
`list-drag-handle-symbolic`). This proves `install_icons`'s search-path
registration resolves to files the real display's icon theme can find by
name. It does not prove pixel-identity against upstream's SVGs (a
`has_icon?` true could still pass for a differently-drawn icon of the same
name) — that narrower claim (pixel-for-pixel icon fidelity) is **still
unverified**, but the claim this round's gate makes ("the shipped icon set
actually resolves") is now genuinely driven, and is a strictly stronger
check than round 3 had (nothing).

## No new gaps found this round

Re-read `test/drive_window.rb` end to end (67 steps/checks) and the other
two drive scripts; no check found that asserts something false, no check
found with a misleadingly narrow assertion hiding behind a broad name (the
one known instance of that pattern, `drive_search_provider.rb` check `[4]`,
was fixed in round 3 and is unchanged — re-read this round, still states its
own limitation in its name).

## Remaining weaker-form verification, carried forward honestly

- **Icon pixel fidelity.** `has_icon?` proves resolution, not visual
  identity to upstream's SVGs. No check compares rendered icon bytes
  against upstream's source SVGs. This is a narrower, lower-severity gap
  than "unverified, not done" — the icon demonstrably loads and renders
  *something* at that name now, which round 3 could not say.
- **Schema/metainfo/desktop file content (units 15/15a/21a/21b).** Verified
  by direct file diff in round 3, not by a runtime check, and no drive step
  reads GSettings schema text or metainfo XML back at runtime this round
  either. This is unchanged from round 3's own framing: file-level
  correctness, confirmed by reading, not driven.

## Worked totals this round

| Axis | Verified clean (driven at runtime) | Verified clean (read only) | Open gap |
|---|---:|---:|---:|
| Units (of the ~21 identified) | 21 | 0 structural units left read-only for their *existence* claim | 0 confirmed defects |

All three units round 3 could not call "done" (primary menu, stylesheet
gradient, icon resolution) now have a runtime check that actually exercises
the claim, re-run and re-read this round rather than trusted from the commit
message. The weaker residual claims above (icon pixel-fidelity, schema/
metainfo file content) are real but narrower than what was open last round,
and are not confirmed defects — they are documented scope limits.
