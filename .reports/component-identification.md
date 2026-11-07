# Component identification — eyedropper-rb (round 4)

| | |
|---|---|
| Upstream | `origin/main` @ `9c480cb` (unchanged since round 3) |
| Port | `ruby` @ `65ea711` |

Round 3 closed the only three *structural* identification gaps it found
(schema keys, metainfo block, desktop fields) and left two units flagged as
"structurally present but no runtime check": the primary menu (unit 3) and
the stylesheet (unit 14). This round's only code change since round 3 is
`test/drive_window.rb` growing from 55 to 67 checks
(`65ea711 Drive the primary menu, hue-slider gradient and icon theme for
real`). This report re-verifies that those checks actually land on the units
they claim to, rather than accepting the commit message's word.

## Unit map (unchanged in shape from round 3)

Same 21-unit map as `.reports/component-identification.md` (round 3) and
`.reports/component-inventory.md`. No new upstream unit found this round;
upstream has not moved (`origin/main` still `9c480cb`).

## What changed since round 3, read directly rather than taken from the commit message

- **Unit 3 (primary menu).** `test/drive_window.rb` now has a step
  ("the primary menu's real `Gio::Menu` model opens and lists its items")
  that calls `window.menu_button.popover.popup`, then reads
  `window.primary_menu` as a live `Gio::Menu`: `n_items == 2`,
  `get_item_link(0, "section")` / `get_item_link(1, "section")`, and
  `get_item_attribute_value(.., "action"/"label", string_type)` on each
  section's items. This opens the actual popover and reads the actual
  `Gio::Menu` model the running window built — not a re-parse of
  `window.blp`'s menu markup and not a call into `Window#primary_menu` that
  only checks the method returns non-nil. Confirmed by reading
  `test/drive_window.rb` lines ~211–236 directly.
- **Unit 14 (stylesheet, `.hue-slider trough` gradient).** The new step
  renders `window.edit_sheet.hue_scale` to a PNG via `d.shot` and reads back
  raw pixel bytes with `GdkPixbuf::Pixbuf`, asserting the left edge of the
  trough is red-dominant and a quarter of the way across has shifted hue.
  This can only pass if `data/style.css`'s gradient was actually loaded by
  the display and applied to the rendered widget — a `css_classes.include?`
  check or a read of the CSS file's text would have passed even with the
  stylesheet never loaded. Confirmed by reading lines ~179–211.
- **Icon set (part of unit 16, also newly driven).** A new step does
  `Gtk::IconTheme.get_for_display(window.window.display).has_icon?(...)` for
  three icon names (`color-select-symbolic`, the app's own symbolic icon,
  `list-drag-handle-symbolic`), proving `install_icons`'s search path
  resolves to files the real icon theme on this window's own display can
  find, not merely that a directory of that name exists on disk.

All three are now driven, not merely read. No remaining unit in the 21-unit
map lacks at least one runtime check that exercises it directly; see
`component-parity.md` for the full accounting and `test-parity.md` for the
check-count reconciliation (67 + 17 + 16 = 100).

## Nothing else re-derived from scratch

Upstream's style.css, gschema, metainfo and desktop files were not re-diffed
byte-for-byte in this round since upstream has not moved and round 3 already
did that diff; re-running the same diff against an unchanged upstream and an
unchanged file on the port side would reproduce the same result for no new
information. They are listed as closed here on that basis, not re-asserted
blindly — if a future round finds upstream has moved, that diff must be
redone.
