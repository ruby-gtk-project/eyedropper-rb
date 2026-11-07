# Component identification — eyedropper-rb (round 3)

| | |
|---|---|
| Upstream | `origin/main` @ `9c480cb` |
| Port | `ruby` @ `9d03426` |

This round re-reads the prior `component-inventory.md` (21 units) and the
prior round's additions (units 15a, 21a, 21b), re-derives nothing from
scratch, and instead verifies — unit by unit, by diff and by reading the
current source, not by trusting the previous report's prose — whether each
previously-identified unit still maps the way it did and whether the three
gaps the last round found are still gaps.

## Unit map (unchanged in shape)

| # | Upstream | Port |
|---|---|---|
| 1 | `src/application.rs` (actions, accelerators) | `lib/eyedropper/app.rb` |
| 2 | `src/window.rs` + `window.blp` (main window, header bar, stack) | `lib/eyedropper/window.rb` |
| 3 | `menu primary_menu` in `window.blp` | `Window#primary_menu`/`#history_section`/`#app_section` in `window.rb` |
| 4 | the `portal-error` stack page in `window.blp` | `lib/eyedropper/widgets/portal_error_page.rb` |
| 5 | the `sheet:` half of `window.blp` (HSL editor) | `lib/eyedropper/widgets/edit_sheet.rb` |
| 6 | `placeholder-page.blp` + part of `window.rs` | `lib/eyedropper/widgets/placeholder_page.rb` |
| 7 | `color-format-row.blp` + `color_format_row.rs` | `lib/eyedropper/widgets/color_format_row.rb` |
| 8 | `history-item.blp` + `history_item.rs` (incl. popover menu) | `lib/eyedropper/widgets/history_item.rb` |
| 9–10 | `preferences.blp` + `preferences_window.rs` (main page + name-sources subpage) | `lib/eyedropper/widgets/preferences_dialog.rb` |
| 11 | the per-row widget built in `create_format_row` (`preferences/color_format.rs` + inline code) | `lib/eyedropper/widgets/format_order_row.rb` |
| 12 | `about_window.rs` | `lib/eyedropper/widgets/about_dialog.rb` |
| 13 | `GListStore`-backed history + format-order models | plain Ruby arrays in `window.rb` / `notation.rb` (accepted replacement) |
| 14 | `data/resources/style.css` | `data/style.css` — **confirmed byte-identical this round** (`diff` exit 0) |
| 15 | `data/com.github.finefindus.eyedropper.gschema.xml.in` | `data/com.github.finefindus.eyedropper.Rb.gschema.xml` |
| 15a | `cie-illuminants` / `cie-standard-observer` keys | **now present** — see component-parity.md; closed since last round |
| 16 | icon set | `data/icons/...` |
| 18 | search-provider crate | `lib/eyedropper/search_provider.rb` |
| 19 | `ashpd` global-shortcuts/background calls | `lib/eyedropper/global_shortcuts.rb` |
| 20 | D-Bus activation files | `data/*.service`, `*.search-provider.ini` |
| 21a | metainfo screenshots/feature list | `data/com.github.finefindus.eyedropper.Rb.metainfo.xml` — **now present**, verified below |
| 21b | desktop entry fields (`Categories`, `Keywords`, `DBusActivatable`) | `data/com.github.finefindus.eyedropper.Rb.desktop` — **now matches upstream's values**, verified below |

No new units found this round beyond 15a/21a/21b, which were already named
by the prior round and are carried forward rather than re-discovered.

## Verification performed this round (not just re-reading the old report)

- `diff <(git show origin/main:data/resources/style.css) data/style.css` →
  identical.
- `diff`-by-key read of both gschema files → port now declares all 8 keys
  upstream declares, same names/types/defaults/summaries/descriptions.
- Full-text read of both `metainfo.xml(.in.in)` files → port's `<ul>` feature
  list and all 4 `<screenshot>`/`<caption>` pairs are now present verbatim
  (the port adds one extra `<p>` crediting the port, which is additive, not a
  loss).
- Full-text read of both desktop entry files → `Keywords`, `Categories`, and
  `DBusActivatable=true` now match upstream's values exactly (port still adds
  `Name=Eyedropper (Ruby)` to disambiguate from upstream's own install,
  which is expected for a side-by-side port and is not a translatable-string
  mismatch since it's the port's own `Name`, not upstream's).

## Still-unidentified-as-verified: unit 3 and unit 14 have no owning check

Identification is not the same question as parity-by-behaviour, but it is
worth recording here because it recurs in every other report: no test or
drive script in this repo ever opens `primary_menu` (unit 3) and reads its
item labels/actions, and none renders a widget and asserts a CSS rule from
`style.css` (unit 14) actually applied. Both are structurally present (read
directly, see component-parity.md) but neither is exercised by anything that
runs. See `test-parity.md` and `component-parity.md`.
