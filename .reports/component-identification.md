# Component identification — eyedropper-rb

| | |
|---|---|
| Upstream | `origin/main` @ `b72f734` push time (ruby `head b72f734`, upstream main tip at audit time) |
| Port | `ruby` branch, `lib/`, `data/`, `po/` |

This audit builds on `.reports/component-inventory.md` (written 2025-11-02,
21 units, both-sides union per the `component-identification` skill). That
document is accurate as far as it goes for widget trees built in Ruby. This
pass adds three things it does not cover, because they are not widget trees:
the `.metainfo.xml` screenshot block, the GSettings schema's own translatable
keys, and the desktop entry's exact field values — all three are components
in the sense the skill defines (they are user-facing, upstream built them,
and a user can tell the difference), and none of them were walked key-by-key
against upstream text.

## Units already inventoried (no new findings on the widget/CSS/signal axes)

Units 1–14, 16, 18–20 of `component-inventory.md` stand: application actions
and accelerators, window, primary menu, portal-error stack page, edit sheet,
placeholder page, color-format row, history item + its popover, preferences
dialog + name-sources subpage, format-order row, about dialog, the
history/format-order model replacement, the stylesheet, the icon set, the
search provider, global shortcuts, and background/D-Bus activation all have a
named Ruby counterpart. This re-audit did not re-derive the widget/CSS/signal
tables; see component-parity.md below for what changed in the *verdict* on
some of those rows now that the runtime gate and the excuse-hunt are in.

## New unit — unit 21a: the metainfo screenshot block

`data/com.github.finefindus.eyedropper.metainfo.xml.in.in` (upstream) declares
a `<developer>` block, an `<update_contact>`, a `<description>` with a feature
`<ul>` of 4 `<li>` items, and a `<screenshots>` block of 4 `<screenshot>`
entries, each with an `<image>` URL and a `<caption>` — 4 translatable
captions plus the 4 feature bullets, 8 messages total:

```
<li>Pick a Color</li>
<li>Edit the viewed color in a simple HSL editor</li>
<li>Enter a color in various formats</li>
<li>Convert colors into other formats such as Hex, RGB, HSV, HSL, CMYK, XYZ, CIE-Lab…</li>
<caption>Main window with a color in different formats</caption>
<caption>Main window with customized formats</caption>
<caption>Editor with an HSL editor</caption>
<caption>Status page stating to pick a color to get started</caption>
```

Port: `data/com.github.finefindus.eyedropper.Rb.metainfo.xml` has `<name>`,
`<summary>` and a 2-paragraph `<description>` with none of the above. The
whole `<screenshots>` block, the `<developer>` block and `<update_contact>`
are absent — not reworded, not relocated, absent. This is unit 21a, and it is
a gap (see component-parity.md).

## New unit — unit 21b: the desktop entry's exact field values

`data/com.github.finefindus.eyedropper.desktop.in.in` (upstream) vs
`data/com.github.finefindus.eyedropper.Rb.desktop` (port):

| Field | Upstream | Port | Same? |
|---|---|---|---|
| `GenericName` | `Color Picker` | `Color Picker` | yes |
| `Comment` | `Pick and format colors` | `Pick and format colors` | yes |
| `Categories` | `GNOME;GTK;Development;Graphics;Utility;WebDevelopment;` | `GTK;GNOME;Graphics;Utility;` | **no** — `Development` and `WebDevelopment` dropped |
| `Keywords` | `Gnome;GTK;Color;Colorpicker;Picker;Palette;` | `Color;Picker;Hex;RGB;HSL;CMYK;Palette;` | **no** — different message entirely, not a reword |
| `DBusActivatable` | `true` | absent | **no** |

`Keywords` carries a translator comment upstream ("Do NOT translate or
localize the semicolons!") and is itself a translatable string in the `.pot`
— the port's replacement value has never been through any catalogue and
cannot be, since it does not match upstream's msgid. This is unit 21b.

## New unit — unit 15a: the two settings keys the schema drops

`component-inventory.md` unit 15 already marks the schema row `partial`.
Reading the schema files key-by-key: upstream's
`com.github.finefindus.eyedropper.gschema.xml.in` declares 8 keys; the port's
`com.github.finefindus.eyedropper.Rb.gschema.xml` declares 6.
`cie-illuminants` and `cie-standard-observer` — each with its own `<summary>`
and `<description>`, each a GSettings key a user's `dconf` can hold a
non-default value in — are absent from the port's schema file entirely, not
merely unread. `PORTING.md:131-136` documents this under a heading, "Dropped
settings keys," which is itself audited in `accountability-ensurance.md`.

## Scope note

`component-inventory.md`'s unit count (21) is the identification baseline
this audit uses. The runtime gate this round reports coverage of "16
components." No document anywhere states which 16, or maps them to the 21
identified units. See `component-parity.md` and `accountability-ensurance.md`
for why that gap in the gate's own documentation is treated as a finding, not
a rounding difference.
