# Eyedropper component inventory (upstream `origin/main` vs `ruby` branch)

Surveyed 2026-11-07. Upstream is the Rust/gtk-rs + Blueprint source at
`origin/main`. This is a survey only — no app code was written.

## Summary

The `ruby` branch already has a `lib/*.rb` file for every upstream
component-bearing source file. Reading each pair (upstream `.rs`/`.blp` vs
`lib/eyedropper/**/*.rb`) shows the port is at or very near full parity:
every widget, CSS class, signal, action and GSettings key found upstream has
a corresponding construct in the Ruby file. No missing component files were
found. The items below record the mapping and spot findings, not gaps to fix
in this step.

## Components

| # | Upstream file(s) | `lib/*.rb` | Kind | Exists? |
|---|---|---|---|---|
| 1 | `src/application.rs` | `lib/eyedropper/app.rb` | Application class — actions (`clear-history`, `random-color`, `preferences`, `quit`, `about`, `placeholder`), accels, search-provider + global-shortcuts startup | Yes — present, actions/accels/signal wiring match |
| 2 | `src/window.rs` + `data/resources/ui/window.blp` | `lib/eyedropper/window.rb` | Main window: `Adw.ApplicationWindow` with `Adw.ToastOverlay` → `Adw.BottomSheet` → `Adw.ToolbarView` (header bar + `Gtk.Stack` of placeholder/portal-error/main pages), history `Gtk.ListBox`, primary menu (`app.clear-history`, `app.random-color`, `app.preferences`, `app.about`), `win.pick-color` action | Yes — present; stack pages, menu, history scroller/scrollbar-offset logic, edit-sheet wiring, toasts all ported |
| 3 | `data/resources/ui/window.blp` (the `sheet:` half — hue/saturation/lightness `Gtk.Scale`s, `Gtk.ColorDialogButton` preview, Apply button) | `lib/eyedropper/widgets/edit_sheet.rb` | Edit sheet: HSL sliders bound to a dynamic CSS gradient provider, Apply button (`suggested-action pill`) | Yes — present |
| 4 | `src/widgets/color_format_row.rs` + `data/resources/ui/color-format-row.blp` | `lib/eyedropper/widgets/color_format_row.rb` | One format row: `Gtk.Entry` (`monospace`) + copy `Gtk.Button` (`edit-copy-symbolic`), `linked` box | Yes — present |
| 5 | `src/widgets/history_item.rs` + `data/resources/ui/history-item.blp` | `lib/eyedropper/widgets/history_item.rb` | History swatch: `Gtk.Button` (`shadow`) wrapping a `Gtk.Box` with right-click (`Gtk.GestureClick`, button 3) and long-press (`Gtk.GestureLongPress`) gestures opening a `Gtk.PopoverMenu` with a `history.remove` action | Yes — present |
| 6 | `src/widgets/placeholder_page.rs` + `data/resources/ui/placeholder-page.blp` | `lib/eyedropper/widgets/placeholder_page.rb` | Empty state: `Adw.StatusPage` with an initial-color `Gtk.Entry` + `Gtk.Button` (`pill suggested-action`) | Yes — present |
| 7 | *(no dedicated upstream file — the `portal-error` `StackPage` inline in `window.blp`)* | `lib/eyedropper/widgets/portal_error_page.rb` | Error state: illustration `Gtk.Picture`, title/body labels, `Continue Regardless` button (`pill`, `app.placeholder` action) | Yes — present; correctly split out as its own port file even though upstream inlines it in the `.blp` |
| 8 | `src/widgets/about_window.rs` | `lib/eyedropper/widgets/about_dialog.rb` | `Adw.AboutDialog`: developers/designers/artists, GPL-3.0, website/issue URL, details/feature text, debug info | Yes — present |
| 9 | `src/widgets/preferences/preferences_window.rs` + `data/resources/ui/preferences.blp` (both the dialog root and the `name_source_page` `Adw.NavigationPage`) | `lib/eyedropper/widgets/preferences_dialog.rb` | Preferences: alpha-position/RGB-notation `Adw.ComboRow`s, precision `Adw.SpinRow`, Name Sources `Adw.ActionRow` → pushed `Adw.NavigationPage` of four `Adw.SwitchRow`s, format-order `Gtk.ListBox` with reset button | Yes — present; subpage push (`push_subpage`) and switch-row binding both ported |
| 10 | `src/widgets/preferences/color_format.rs` | `lib/eyedropper/widgets/format_order_row.rb` | One row in the format-order list: visibility checkbutton, drag handle, label | Yes — present |
| 11 | `src/model/history.rs` | *(behaviour folded into `window.rb`'s `@history`/`refresh_history`)* | Non-widget model (history list + persistence) | Yes — ported as plain state, no separate file needed (no widget) |
| 12 | `src/colors/*.rs` | `lib/eyedropper/color.rb`, `lib/eyedropper/notation.rb`, `lib/eyedropper/parser.rb`, `lib/eyedropper/color_names.rb`, `lib/eyedropper/illuminant.rb`, `lib/eyedropper/alpha_position.rb` | Non-widget color model/formatting | Yes — present |
| 13 | `data/com.github.finefindus.eyedropper.gschema.xml.in` | `lib/eyedropper/settings.rb` | GSettings schema (`visible-formats`, `format-order`, `alpha-position`, `rgb-notation`, `cie-illuminants`, `cie-standard-observer`, `precision-digits`, `name-sources-flag`) | Yes — every key has a matching accessor |
| 14 | Global shortcuts portal code in `src/application.rs` (`setup_global_shortcuts`) | `lib/eyedropper/global_shortcuts.rb` | Background/global-shortcuts portal integration (`EyedropperColorPick`) | Yes — present |
| 15 | Search-provider code in `src/application.rs` (`SearchProviderImpl`) + `data/com.github.finefindus.eyedropper.search-provider.ini` | `lib/eyedropper/search_provider.rb` | GNOME Shell search provider (color hex → activate result) | Yes — present |
| 16 | Color-picking portal calls (scattered across `src/window.rs`/`application.rs`) | `lib/eyedropper/picker.rb`, `lib/eyedropper/dbus.rb` | Color-picker portal/D-Bus plumbing | Yes — present |
| 17 | `po/*.po`, `po/Eyedropper.pot`, `po/LINGUAS` | `lib/eyedropper/i18n.rb` | Translation lookup helpers (`_`, `C_`) | Yes — present (translation catalogue/`.po` parity is a separate skill: `translation-parity`) |
| 18 | `data/resources/style.css` | *(consumed directly — `data/style.css` / dynamic `Gtk::CssProvider` in `window.rb`)* | Stylesheet (`.hue-slider`, `.saturation-slider`, `.value-slider`, `.no-padding`, etc.) | Yes — referenced from `window.rb`'s `install_styles`; confirm CSS file itself is copied verbatim (not re-scanned in this pass) |
| 19 | `data/com.github.finefindus.eyedropper.metainfo.xml.in.in`, `.desktop.in.in` | `lib/eyedropper/config.rb` | App metadata/identity constants (`APP_ID`, `APP_NAME`, `VERSION`, resource path) | Yes — present |

## Notes / things worth a second look in a later pass (not blockers)

- No upstream component file was found with **no** corresponding `lib/*.rb` — this is unusual for a "survey" step and suggests most or all of the port's widget work is already done. The remaining work for eyedropper-rb is more likely to be in behavioral/edge-case parity (checked by `component-parity`), translation catalogue parity, and test parity, rather than missing widgets.
- Row 7 (`portal_error_page.rb`) has no dedicated upstream `.rs`/standalone `.blp` — it is inlined as the `portal-error` `StackPage` in `window.blp`. The Ruby port correctly gives it its own file per house style even though upstream does not split it out; flagged here so a future reviewer does not mistake it for an extra/unported file.
- `data/resources/screenshots/*.png` and `data/resources/illustrations/shattered-picker.svg` are referenced by the metainfo and the portal-error page; confirm the SVG asset ships in the Ruby port's data dir (`lib`/`data` asset parity was not exhaustively diffed in this pass).
- `data/resources/assets/{basic,gnome,svg,xkcd}.txt` (color-name wordlists) back `lib/eyedropper/color_names.rb` — contents parity (not just file presence) was not verified in this survey and is worth a dedicated pass.
- The GTK symbol table (`.claude/skills/component-identification/scripts/symbols.tsv`) was not regenerated in this pass (no `nix develop` GIR environment used here); classifications above were made by direct reading of each file pair rather than the automated scan.
