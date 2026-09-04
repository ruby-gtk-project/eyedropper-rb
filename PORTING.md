# Porting notes

How this Ruby port maps onto the Rust original, and the things that only became
visible by running it.

## Shape

Upstream is GObject-subclass-per-widget: each screen is a `glib::wrapper!` type
with a `.blp` template, `#[template_child]` bindings and `install_action` calls.
Ruby can register GTypes, but the house style here does not — a widget is a
memoized method on a plain Ruby object, and `build` assembles the tree. So each
upstream composite template became a plain class with the same widgets:

| Upstream | Here |
|---|---|
| `src/application.rs` | `lib/eyedropper/app.rb` |
| `src/window.rs` + `data/resources/ui/window.blp` | `lib/eyedropper/window.rb` |
| `src/widgets/color_format_row.rs` + `.blp` | `lib/eyedropper/widgets/color_format_row.rb` |
| `src/widgets/history_item.rs` + `.blp` | `lib/eyedropper/widgets/history_item.rb` |
| `src/widgets/placeholder_page.rs` + `.blp` | `lib/eyedropper/widgets/placeholder_page.rb` |
| the `portal-error` stack page in `window.blp` | `lib/eyedropper/widgets/portal_error_page.rb` |
| the `sheet:` half of `window.blp` | `lib/eyedropper/widgets/edit_sheet.rb` |
| `src/widgets/preferences/preferences_window.rs` + `.blp` | `lib/eyedropper/widgets/preferences_dialog.rb` |
| the per-format row built in `create_format_row` | `lib/eyedropper/widgets/format_order_row.rb` |
| `src/widgets/about_window.rs` | `lib/eyedropper/widgets/about_dialog.rb` |
| `src/colors/*` and the `palette` crate | `lib/eyedropper/color.rb`, `parser.rb`, `notation.rb` |
| `src/colors/color_names.rs` + `build.rs` codegen | `lib/eyedropper/color_names.rb` |
| `src/model/history.rs` (a `GListStore` of GObjects) | a plain Ruby array in `Window` |

Three structural simplifications, all of which delete code rather than add it:

- **`Notation` is one object per format, not three parallel `match` arms.**
  Upstream spreads each format across `parse`, `as_str` and two label matches
  that have to be kept in step by hand. Here a notation holds its identifier,
  labels, formatter and parser together, and `Notation::ALL` is the list the
  settings order against.
- **`gio::ListStore` + `bind_model` became Ruby arrays.** The history and the
  format-order list are both short and both fully rebuilt on change; a
  GObject-per-row model bought nothing that a `map` does not.
- **The parsers tokenise once.** Upstream has fourteen `nom` parser functions
  describing the same grammar — a prefix, numbers separated by any of `,` `|`
  `/` or whitespace, an optional `)`. `Parser` scans that once and each format
  says how to read its own slots.

## Desktop integration

Both of upstream's system integrations are present.

**The GNOME Shell search provider** (`lib/eyedropper/search_provider.rb`) serves
`org.gnome.Shell.SearchProvider2` itself, where upstream uses the
`search-provider` crate. Typing a color into the shell's search returns it as a
result that opens the app on that color; result identifiers are the color's own
hex string, so nothing has to be remembered between the search and the
activation. Each result carries a swatch drawn in its own color — upstream
renders one with a GL renderer and hands it over as `icon-data`, which needs
child access to a GVariant that these bindings do not have, so this writes a
small SVG to the cache directory and passes its path as `gicon`, which is how a
`GFileIcon` serialises. `data/*.service` and
`data/*.search-provider.ini` are installed so the shell can find and
D-Bus-activate it.

**Global shortcuts and background access**
(`lib/eyedropper/global_shortcuts.rb`) drive the `GlobalShortcuts` and
`Background` portals directly, where upstream uses `ashpd`. Ctrl+P is bound
system-wide with the same shortcut id and preferred trigger upstream uses, and
background permission is requested with the same reason and command line. Every
part is best-effort: a portal that is absent, refuses, or errors leaves the app
running normally with only its in-window accelerator.

## The color picker

`ashpd` has no Ruby equivalent, so `lib/eyedropper/picker.rb` speaks to
`org.freedesktop.portal.Screenshot.PickColor` over the session bus directly.
The portal answers asynchronously: the call returns a request object path and
the color arrives later as a `Response` signal. The request path is derived from
the caller's unique bus name and a token, so it is computed and watched *before*
the call is made — otherwise a fast portal can answer before the watch exists.

Upstream's COSMIC special-case is kept: that portal exports `PickColor` and then
always fails, so it is treated as unavailable up front rather than after a
failed pick.

## Upstream bugs this port declines to reproduce

Three of upstream's formats cannot survive a copy-and-paste round trip, and the
evidence that they are meant to is upstream's own test suite.

- **XYZ, LMS and Hunter Lab are displayed on the 0..100 scale and parsed on the
  0..1 scale.** `notation.rs` multiplies XYZ by 100 for display; `parser.rs`
  feeds the same digits back to `palette::Xyz::new` unscaled. Every one of
  upstream's parser test vectors — `XYZ(3.280, 3.407, 5.335)`,
  `L: 3.20580, M: 3.52562, S: 5.33522`, `L: 18.45804, a: 0.41141, b: -5.42239`
  — is on the 0..100 scale and asserts it parses to `#2e3440`, which it cannot
  while the parser reads it as 0..1. This port uses one scale on both sides.
- **`HunterLab`'s inverse is scaled against the wrong white point.** It reads
  `y = (l / wp.y)^2 * 100`, which only round-trips when the white point is
  itself on the 0..100 scale; `palette`'s is normalised to `y = 1.0`, so the
  value comes back about a million times too large and every Hunter Lab string
  parses to white. `y = (l / 100)^2 * wp.y` is the same formula with the scales
  lined up, and it reproduces upstream's vector.

Two deliberate relaxations, both strict supersets of what upstream accepts:
percentages may carry a fractional part in every format (upstream's shared
`percentage` combinator is `digit1` followed by `%`, so `hsl(220, 16.5%, 22%)`
is rejected), and the format prefix is optional everywhere — which is what
upstream's own `oklab`/`oklch` test vectors assume, though its parsers require it.

## Dropped settings keys

`cie-illuminants` and `cie-standard-observer` are declared in upstream's schema
and read by nothing; the XYZ and Lab conversions are hardcoded to D65/2°. They
are not carried over. Every other key keeps its name, type and default, and
`name-sources-flag` keeps upstream's bit values, so an existing configuration
means the same thing here.

## D-Bus through these bindings

Everything in `lib/eyedropper/dbus.rb` is shaped by four binding limits, each
found by running into it:

- **`GLib::Variant.new(value, type)` cannot build a tuple or an `a{sv}`** — it
  raises `NotImplementedError: TODO: Ruby -> GVariant`. `GLib::Variant.parse`
  takes the GVariant *text* format and builds anything, so every outgoing
  argument is written as text. An empty array has to name its type (`@as []`),
  since text format cannot infer an element type from no elements.
- **`GLib::Variant` exposes only `type`, `value`, `to_s` and `inspect`.** There
  is no child access, and `value` raises on any dictionary. Incoming `a{sv}` is
  therefore read back out of `to_s`, which is the same text format.
- **`Gio.bus_own_name` raises `FrozenError`** however it is called, so a
  well-known name is claimed by calling `RequestName` on the bus directly.
- **No D-Bus signal carrying `a{sv}` can be received in-process.** Both
  `signal_subscribe` and `Gio::DBusProxy`'s `g-signal` convert the payload to
  Ruby before handing it over, hitting the same dictionary limit — and the
  exception is raised inside the binding's own callback trampoline, so the
  callback cannot rescue it and it takes the process down. `add_filter`, which
  would see the raw message, is dispatched on the D-Bus worker thread and the
  bindings refuse to call into Ruby from there. Since every portal `Response` is
  `(ua{sv})`, `DBus.monitor` shells out to `gdbus monitor` — part of glib, which
  is already a hard dependency — and parses the text form it prints. The reading
  thread hands whole lines back through `GLib::Idle` so callers stay
  single-threaded.

Asymmetries worth remembering: `call_sync` and `call_finish` hand back
*unwrapped* Ruby values, not variants, and a registered method handler receives
its parameters as a plain Ruby `Array` — but its reply must be a `GLib::Variant`
of exactly the declared type, or GDBus drops it and the caller waits out its
timeout instead of seeing an error.

## ruby-gnome and GTK notes found while writing this

Worth knowing before changing the widgets:

- **`Adwaita::ApplicationWindow.new` takes the `Gtk::Application`**, not a
  wrapper object, and it takes `content=`, not `child=`.
- **`Gtk::PopoverMenu.new(menu_model)`** — positional, no `:model` symbol. A
  popover parented with `set_parent` must be `unparent`ed before its parent is
  destroyed, or GTK warns about finalising a widget with children left. The
  history strip rebuilds often enough for that to be every rebuild.
- **`Gtk::Button#activate` does nothing** in these bindings — it returns `nil`
  without emitting `clicked`. Drive buttons with `signal_emit("clicked")`.
- **`Gio::Settings#set_value` already wraps the value** using the schema's own
  type. Handing it a `GLib::Variant` makes it wrap a variant in a variant and
  recurse until the stack gives out.
- **`Gtk::IconTheme.get_for_display`**, not `for_display`.
- **`css-name` is construct-only** and has no setter. Upstream's
  `Adw.Bin { css-name: "statuspage" }` trick is unavailable; `Adw.StatusPage`
  takes a `paintable`, which is what that trick was for.
- **`GLib.os_info` is not bound.** `/etc/os-release` is the same data.
- **`Gtk::Settings` has no `gtk_overlay_scrolling` reader**; use
  `get_property("gtk-overlay-scrolling")`.

## Testing notes

- **GSettings needs the memory backend headlessly.** Without a session bus,
  writes appear to succeed and are silently rolled back to the schema default a
  moment later, which reads as a bug in the code under test. `test/drive_window.rb`
  sets `GSETTINGS_BACKEND=memory`, which also keeps the run off the real config.
- **The screenshot harness in `test/gtk_driver.rb` needed two fixes.** Realising
  and unrealising a `GskCairoRenderer` per shot poisons the widget tree — the
  first couple of screenshots come out and every later one finds a nil render
  node — so one renderer is realised for the whole run and released deliberately
  at the end (`GskRenderer` aborts the process if it is disposed while still
  realised). And a widget only offers a render node once GTK has drawn it, so a
  failed shot is queued and retried on later ticks rather than in a loop, with
  steps held back until the queue drains so a retried shot still shows the right
  state. `queue_draw` before a retry makes it *less* likely to work, not more:
  it marks the widget dirty. Most runs now produce the full set; a minority
  still lose some, which is a limit of snapshotting a surfaceless widget. The
  checks never depend on rendering.
