# Component inventory — eyedropper-rb

Upstream: `origin/main` (Rust/gtk-rs + blueprint). Port: `ruby` branch, `lib/`.

Upstream splits most components across a `src/**/*.rs` subclass and a
`data/resources/ui/*.blp` template. Each row below unions both halves, as
`component-identification` requires.

Legend for **present**: `yes` = a `lib/*.rb` component class exists and covers
the upstream widget tree; `partial` = exists with a named gap; `no` = absent.

---

## Unit map

| # | Upstream file(s) | Port file | Kind | Present |
|--:|---|---|---|---|
| 1 | `src/application.rs` | `lib/eyedropper/app.rb` | application | yes |
| 2 | `src/window.rs` + `data/resources/ui/window.blp` | `lib/eyedropper/window.rb` | window | yes |
| 3 | `data/resources/ui/window.blp` (`menu primary_menu`) | `lib/eyedropper/window.rb` (`primary_menu`) | menu | yes |
| 4 | `data/resources/ui/window.blp` (`StackPage "portal-error"`) | `lib/eyedropper/widgets/portal_error_page.rb` | error state | yes |
| 5 | `data/resources/ui/window.blp` (`sheet:` of `Adw.BottomSheet`) | `lib/eyedropper/widgets/edit_sheet.rb` | bottom sheet | yes |
| 6 | `src/widgets/placeholder_page.rs` + `placeholder-page.blp` | `lib/eyedropper/widgets/placeholder_page.rb` | empty state | yes |
| 7 | `src/widgets/color_format_row.rs` + `color-format-row.blp` | `lib/eyedropper/widgets/color_format_row.rb` | row | yes |
| 8 | `src/widgets/history_item.rs` + `history-item.blp` | `lib/eyedropper/widgets/history_item.rb` | row + popover menu | yes |
| 9 | `src/widgets/preferences/preferences_window.rs` + `preferences.blp` (`template $PreferencesWindow`) | `lib/eyedropper/widgets/preferences_dialog.rb` | preferences dialog | yes |
| 10 | `preferences.blp` (`Adw.NavigationPage name_source_page`) | `lib/eyedropper/widgets/preferences_dialog.rb` (`name_sources_page`) | preferences subpage | yes |
| 11 | `src/widgets/preferences/preferences_window.rs` (`create_format_row`) | `lib/eyedropper/widgets/format_order_row.rb` | row + row menu | yes |
| 12 | `src/widgets/about_window.rs` | `lib/eyedropper/widgets/about_dialog.rb` | dialog | yes |
| 13 | `src/model/history.rs`, `src/widgets/preferences/color_format.rs` | `lib/eyedropper/window.rb` (plain arrays), `lib/eyedropper/notation.rb` | model | yes (GObject models replaced by Ruby objects) |
| 14 | `data/resources/style.css` | `data/style.css` | stylesheet | yes |
| 15 | `data/com.github.finefindus.eyedropper.gschema.xml.in` | `lib/eyedropper/settings.rb`, `data/…Rb.gschema.xml` | settings schema | partial |
| 16 | `data/resources/resources.gresource.xml` + `data/resources/icons/*` | `data/icons/hicolor/**`, `data/icons/shattered-picker.svg` | resources | yes (icon theme dir replaces GResource) |
| 17 | `po/` (34 catalogues, `po/LINGUAS`) | `po/`, `lib/eyedropper/i18n.rb` | translations | yes |

---

## 1. `src/application.rs` — the application, its actions and accelerators

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `activate`, `startup` | sets default icon name to `APP_ID` |

Actions installed (`gio::ActionEntry`): `app.clear-history`, `app.random-color`,
`app.preferences`, `app.quit`, `app.about`, `app.placeholder`.

Accelerators: `win.pick-color` → `<Control>p`; `app.random-color` → `<Control>r`;
`app.preferences` → `<Control>comma`; `app.quit` → `<Control>w`, `<Control>q`.

Also: XDG background-access request, GNOME Shell search provider
(`SearchProviderImpl`), XDG global-shortcuts session with
`EyedropperColorPick`.

Port: `lib/eyedropper/app.rb` has all six actions and the exact accel table
(`ACCELS`). Search provider, D-Bus and shortcuts live in
`lib/eyedropper/search_provider.rb`, `lib/eyedropper/dbus.rb`,
`lib/eyedropper/global_shortcuts.rb`.

## 2. `src/window.rs` + `window.blp` — the main window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (dynamic, nightly profile only) | — | `hide-on-close: true` |
| `Adw.ToastOverlay` | 1 | — | — | host for every toast |
| `Adw.BottomSheet` | 1 | — | — | `edit_sheet`; content = main view, sheet = unit 5 |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | |
| `Adw.WindowTitle` | 1 | — | — | title "Eyedropper" |
| `Gtk.Button` | 1 | — | `clicked` → `pick_color` | `color_picker_button`, icon `color-select-symbolic`, desensitised on portal error |
| `Gtk.MenuButton` | 1 | — | menu-model `primary_menu` | `primary: true`, icon `open-menu-symbolic` |
| `Gtk.Stack` | 1 | — | — | `crossfade`; pages `placeholder`, `portal-error`, `main` |
| `Gtk.Box` | 2 | — | — | main page row box; `format_box` column |
| `Adw.Clamp` | 1 | — | — | tightening 35, max 50 |
| `Gtk.Button` | 1 | `no-padding` | `clicked` → `open_sheet` | the big swatch button, width-request 267 |
| `Gtk.ColorDialogButton` | 1 | — | — | `color_button`, presentation role, not focusable |
| `Gtk.ScrolledWindow` | 1 | — | — | hscrollbar never, min height 200 |
| `Gtk.ListBox` | 1 | `background` | — | `history_list`, selection none, bound to the history `ListStore` |

Actions installed on the window: `win.pick-color` (async), `win.show-toast`
`(si)`, `win.set-color` `s`, `win.remove-item` `s`.
Repeaters: `history_list` — one `HistoryItem` per `HistoryObject`;
`format_box` — one `ColorFormatRow` per visible notation, re-ordered from
`format-order`/`visible-formats`.
Conditional: `history_list` visible only when the history holds more than one
item, which also drives `app.clear-history`'s enabled state; scrollbar margin
recomputed on `gtk-overlay-scrolling`.

Port: `lib/eyedropper/window.rb` reproduces the tree, the `no-padding` and
`background` classes, the stack page names, the toast overlay, the clear/undo
toast and the scrollbar-offset workaround. **Note:** `win.pick-color` is the
only window action installed; `win.show-toast`, `win.set-color` and
`win.remove-item` are reached through Ruby callbacks from the search provider
and shortcut handlers instead of parameterised GActions — behaviourally
equivalent, but anything outside the process that activates those action names
would find them absent.

## 3. `window.blp` — `menu primary_menu`

Two sections, four items: `app.clear-history` ("_Clear History"),
`app.random-color` ("_Random Color"), `app.preferences` ("_Preferences"),
`app.about` ("_About Eyedropper"). Port: `primary_menu` / `history_section` /
`app_section` in `lib/eyedropper/window.rb`.

## 4. `window.blp` `StackPage "portal-error"` — color picker unavailable

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | `css-name: statuspage` | — | hand-built status page |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Gtk.Box` | 3 | — | — | |
| `Adw.Clamp` | 1 | — | — | |
| `Gtk.Picture` | 1 | — | — | `shattered-picker.svg`, presentation role |
| `Gtk.Label` | 2 | `title-1`; `body` | — | "Color Picker not Available" / "The system is not properly configured to allow for color picking" |
| `Gtk.Button` | 1 | `pill` | `action-name: app.placeholder` | "_Continue Regardless" |

Port: `lib/eyedropper/widgets/portal_error_page.rb` uses a real
`Adw.StatusPage` with the illustration as its paintable, keeping both strings,
the `pill` button and `app.placeholder`. The hand-rolled `Bin`/`ScrolledWindow`
scaffold is deliberately not reproduced.

## 5. `window.blp` `sheet:` — the HSL edit sheet

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` | 1 | — | — | |
| `Gtk.Box` | 1 | — | — | vertical |
| `Gtk.ColorDialogButton` | 1 | — | — | `color_preview`, not focusable/targetable |
| `Gtk.Scale` | 3 | `hue-slider`, `saturation-slider`, `value-slider` | `value-changed` → `on_color_preview_updated` | 0–360, 0–100, 0–100; `draw-value: false`, `has-origin: false` |
| `Gtk.Adjustment` | 3 | — | — | type, not widget |
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `clicked` → `on_color_preview_select` | "Apply" |

Port: `lib/eyedropper/widgets/edit_sheet.rb`, all three slider classes present,
CSS trough gradients kept in `data/style.css`.

## 6. `placeholder_page.rs` + `placeholder-page.blp` — empty state

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | template root |
| `Adw.StatusPage` | 1 | — | — | icon `color-select-symbolic`, "No Color" / "Select or enter a color to get started" |
| `Gtk.Box` | 1 | — | — | spacing 25 |
| `Gtk.Entry` | 1 | `error` (dynamic, on parse failure) | `activate` → `on_color_entry_active` | placeholder text rotates through example syntaxes |
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `clicked` → `on_color_entry_active` | "View", insensitive until the entry has text |

Port: `lib/eyedropper/widgets/placeholder_page.rb`, including the error flash
and the rotating placeholder list.

## 7. `color_format_row.rs` + `color-format-row.blp` — one notation row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | `linked` | — | template root |
| `Gtk.Entry` | 1 | `monospace`, plus `error` / `success` (dynamic, ~350 ms flash) | `changed`, `activate` | bound to the `color` property |
| `Gtk.Button` | 1 | `suggested-action` (dynamic, while the entry is dirty) | `clicked` → `on_button_pressed` | icon `edit-copy-symbolic`; tooltip flips to "Apply"; toast `Copied “{}”` |

Port: `lib/eyedropper/widgets/color_format_row.rb`, with `FLASH_MS = 350`.

## 8. `history_item.rs` + `history-item.blp` — one history swatch

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Button` | 1 | `shadow` | `action-name: history.clicked` | custom `snapshot` paints the rounded swatch; tooltip is the color's name/hex |
| `Gtk.Box` | 1 | — | — | |
| `Gtk.GestureClick` | 1 (controller) | — | `pressed` → `show_popover` | button 3 |
| `Gtk.GestureLongPress` | 1 (controller) | — | `pressed` → `show_popover` | touch only |
| `Gtk.PopoverMenu` | 1 | — | menu-model `popover_menu` | `has-arrow: false`, halign start |
| `menu popover_menu` | 1 item | — | `history.remove` | "Remove" |

Actions installed on the item: `history.remove`, `history.clicked`.

Port: `lib/eyedropper/widgets/history_item.rb`. A `Gtk::DrawingArea` inside a
plain button replaces the `snapshot` override (no GType registration from
Ruby); both gestures, the popover menu and both `history.*` actions are present.

## 9. `preferences_window.rs` + `preferences.blp` — preferences dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` | 1 | — | — | template root |
| `Adw.PreferencesPage` | 1 | — | — | "General" |
| `Adw.PreferencesGroup` | 2 | — | — | "Formatting"; "Color Formats" (+ description) |
| `Adw.ComboRow` | 2 | — | `notify::selected` (bound to settings) | "Alpha-Value Position" (None/End/Start); "RGB Notation" (Integer/Decimal) |
| `Gtk.StringList` | 2 | — | — | type, not widget |
| `Adw.ActionRow` | 1 | — | `activated` → `on_name_row_activated` | "Name Sources", activatable |
| `Gtk.Image` | 1 | — | — | suffix `go-next-symbolic` |
| `Adw.SpinRow` | 1 | — | bound to `precision-digits` | "Precision", 0–15 |
| `Gtk.Button` | 1 | `flat` | `clicked` → `on_reset_pressed` | header-suffix, icon `edit-clear-symbolic`, "Reset Order" |
| `Gtk.ListBox` | 1 | `boxed-list` | — | `order_list`, selection none |

Repeater: `order_list` — one row per entry of `format-order` (14 notations),
built by `create_format_row` (unit 11).

Port: `lib/eyedropper/widgets/preferences_dialog.rb` — all rows, the `flat`
reset button in `header_suffix`, and the `boxed-list` order list.

## 10. `preferences.blp` `Adw.NavigationPage name_source_page` — name sources subpage

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` | 1 | — | — | standalone blueprint root, title "Name Sources" |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | empty |
| `Gtk.Box` | 1 | — | — | |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 1 | — | — | |
| `Adw.SwitchRow` | 4 | — | `notify::active` → `bind_setting` flag | Basic / Extended / GNOME Color Palette / xkcd Color Survey, each a bit of `name-sources-flag` |

Port: `name_sources_page`, `name_sources_toolbar`, `name_source_switches` in
`lib/eyedropper/widgets/preferences_dialog.rb`, pushed with `push_subpage`.

## 11. `preferences_window.rs::create_format_row` — one format-order row

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | — | title = format label, subtitle = example rendering of a random color |
| `Gtk.Switch` | 1 | — | bidirectional bind ↔ `visible-formats` | the row's `activatable-widget`, `can-focus: false` |
| `Gtk.Separator` | 1 | — | — | vertical suffix |
| `Gtk.MenuButton` | 1 | `flat` | menu-model | icon `view-more-symbolic` |
| `Gio.Menu` | 2 items | — | `row.move-up`, `row.move-down` | "Move Up", "Move Down" |
| `Gtk.Image` | 1 | `drag-handle` | — | prefix `list-drag-handle-symbolic` |
| `Gtk.DragSource` | 1 (controller) | — | `prepare` | name `preferences-drag-format`, `MOVE` |
| `Gtk.DropTarget` | 1 (controller) | — | `drop` | same name, capture phase, `MOVE` |

Actions: a `row` action group holding `move-up` and `move-down`.

Port: `lib/eyedropper/widgets/format_order_row.rb`, `DRAG_NAME` matching. The
drag payload is the notation's identifier string rather than a
`ColorFormatObject`, because a plain Ruby object cannot cross a
`GdkContentProvider`.

## 12. `about_window.rs` — about dialog

`Adw.AboutDialog` with application icon, name, developer/designer/artist
credits, translator credits, GPL-3.0, version, website, issue URL, copyright,
a generated comments/details body, and a debug-info page written to
`eyedropper_debug_info`.

Port: `lib/eyedropper/widgets/about_dialog.rb`, including the debug-info page.

## 13–16. Supporting files

- `src/model/history.rs` (`HistoryObject`) and
  `src/widgets/preferences/color_format.rs` (`ColorFormatObject`) are GObject
  value holders; the port keeps the same data in plain Ruby objects
  (`Eyedropper::Color`, `Eyedropper::Notation`) plus arrays on the window.
- `data/resources/style.css` is reproduced byte-for-class in `data/style.css`:
  `.title-header`, `.no-padding`, `.invisible`, `.shadow`, `.hue-slider
  trough`, `.saturation-slider trough`, `.value-slider trough`.
- `po/` is shipped verbatim — `LINGUAS`, the template and all 34 catalogues —
  and read at runtime by `lib/eyedropper/i18n.rb`, which parses the `.po` for
  the environment's language instead of relying on a `msgfmt` build step.
  `I18n::Helpers` gives the ported classes `_()` and `c_()` in place of
  upstream's `gettext()` and blueprint's `_()` / `C_()`.
- GResource is replaced by an installed icon theme under
  `data/icons/hicolor/**` plus `data/icons/shattered-picker.svg`; all six
  bundled symbolics are present.

---

## Gaps

1. **GSettings keys `cie-illuminants` and `cie-standard-observer` (15).**
   Present in the upstream schema, absent from `lib/eyedropper/settings.rb`
   `DEFAULTS` and from `data/…Rb.gschema.xml`. Neither has a UI control
   upstream either, so this is a schema gap rather than a missing component —
   but the CIE conversions that read them cannot be configured.
2. **Parameterised window actions (2).** `win.show-toast` `(si)`,
   `win.set-color` `s` and `win.remove-item` `s` exist upstream as GActions and
   in the port only as Ruby callbacks. In-app behaviour matches; external
   activation of those names does not.
3. **Localised metadata (17).** The UI strings go through the catalogues, but
   the `.desktop` and `.metainfo.xml` files carry only their source English.
   Upstream merges translations into them with `msgfmt --desktop` / `--xml`
   during the meson build; the port has no build step, so `Name[de]=` and
   `<summary xml:lang="de">` are not generated.
