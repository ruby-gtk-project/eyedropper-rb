# Translation parity — eyedropper-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| `po/LINGUAS` | identical byte-for-byte, both sides (diff: empty) |
| `po/Eyedropper.pot` msgid count | 147 both sides (`grep -c '^msgid "'`) |
| Catalogue files | 34 `.po` files, same filenames both sides |

The catalogues and `LINGUAS` are a straight copy — `po/` is checked in
unchanged, which is consistent with `PORTING.md`'s own description of
`lib/eyedropper/i18n.rb` reading the shipped `.po` files directly rather than
rebuilding them. That is the part of this skill that passes cleanly.

**What does not pass: the pot and catalogues were copied, but not every
msgid in them is still reachable from a message a user will actually see in
the port**, and the port's own non-`po/` surfaces (the GSettings schema, the
desktop entry, the metainfo file) carry messages that were never diffed
against the catalogue they are supposed to share a domain with.

## Method

Ran `translation-parity/scripts/msgid-census.sh` against an `origin/main`
worktree and against `lib/ exe/`, then compared the non-`.po`-sourced,
deduplicated (msgctxt, msgid) sets:

```
upstream non-po unique messages (from .rs/.blp/.xml.in/.desktop.in.in): 80
port    non-po unique messages (from .rb):                             64
```

Several of the 80-vs-64 differences are **scanner artifacts, not real
gaps** — investigated by hand per this skill's "read the script's output as
a lead" rule:

- Upstream's `Notation::format` match arms (`"Copy Hex Code"`, `"Copy RGB"`,
  …) collapse into one `!unresolved` row upstream because the scanner can't
  follow a `match`; the port's 13 `_("Copy ...")` calls are real, separate,
  and correctly marked. **Correspondence, not a gap** — covered already by
  `test_every_notation_round_trips` driving every format's label through its
  own notation object.
- The port's `gschema.xml` extension (`.xml`, not `.xml.in`) isn't in the
  scanner's glob, so its `<summary>`/`<description>` text (which *is*
  present and *does* match upstream, for the 6 keys both sides keep) reads
  as "missing" in the census. Verified by direct `diff` instead (below) —
  not a real gap for those 6 keys.
- `about_dialog.rb`'s `translator-credits` handling (`:20-46`) is flagged
  `!unresolved` by the scanner because the call spans multiple lines; reading
  it directly, `TRANSLATOR_CREDITS_MSGID = "translator-credits"` is the exact
  upstream msgid and the lookup is correct. **Not a gap.**

## Real gaps, found by reading rather than by the scanner

### 1. Two GSettings keys' translatable text has no port counterpart at all

`diff`ing `data/com.github.finefindus.eyedropper.gschema.xml.in` (upstream)
against `data/com.github.finefindus.eyedropper.Rb.gschema.xml` (port) key by
key: upstream declares 8 keys, the port declares 6. Missing, each with its
own `<summary>`/`<description>` pair that is a real (msgctxt, msgid) in
`po/Eyedropper.pot`:

| Key | Summary msgid | Description msgid |
|---|---|---|
| `cie-illuminants` | `Color Illuminant` | `Used XYZ Tristimulus values as the CIE illuminant` |
| `cie-standard-observer` | `CIE standard observer` | `If 2° or 10° values are used for the CIE standard observer. Can only be 0 (2°) or 1 (10°).` |

2 keys × 2 messages = **4 messages with no reachable string in the port**,
confirmed also missing from every `lib/*.rb` file (`grep -rn "CIE standard
observer\|Tristimulus" lib/` → no hits). `PORTING.md:131-136` names this
decision; see `accountability-ensurance.md` for why that note does not
close the gap.

### 2. The desktop entry's `Keywords` is not upstream's string

Upstream (`data/com.github.finefindus.eyedropper.desktop.in.in:9`):
```
Keywords=Gnome;GTK;Color;Colorpicker;Picker;Palette;
```
Port (`data/com.github.finefindus.eyedropper.Rb.desktop:10`):
```
Keywords=Color;Picker;Hex;RGB;HSL;CMYK;Palette;
```
This is a translatable string (upstream's `.pot` carries it, with a
translator comment forbidding touching the semicolons) and the port's value
is not a rewording — it drops `Gnome` and `Colorpicker` and adds `Hex`, `RGB`,
`HSL`, `CMYK`, none of which upstream's translators were ever asked to
translate. Every language's translation of upstream's `Keywords` line is now
orphaned: it exists in each `.po` file and nothing in the port reads it,
because the port's own source string differs. `Categories` likewise drops
`Development;WebDevelopment;` (not itself translatable, but the same file,
same finding class: values diverged from upstream silently).

### 3. The metainfo screenshot/feature block — 8 messages, not moved, not reworded, gone

`data/com.github.finefindus.eyedropper.metainfo.xml.in.in` (upstream) carries
8 translatable strings this census already listed in
`component-identification.md` (4 `<li>` feature bullets, 4 `<caption>`s).
`grep -rn` for any fragment of any of the 8 across `data/` and `lib/` in the
port finds nothing — not under a different tag, not inlined into the
`<description>`. These 8 messages are in `po/Eyedropper.pot` and every
`.po` file the port ships, translated into up to 34 languages, and the port
has no string anywhere that uses any of those 34 translations.

## Running total

| | Count |
|---|---:|
| Messages confirmed byte-identical and reachable | 147 − 12 = 135 |
| Messages with no reachable port string (schema: 4, metainfo: 8) | 12 |
| Messages whose port-side value differs from upstream's (desktop `Keywords`) | 1 (already counted toward the schema/metainfo set is wrong — this is additional) |

12 messages (plus the 1 reworded `Keywords` line, 13 total) ship translations
in 34 languages that the port cannot use, because the message itself is
either absent from the port or no longer the string those translations were
made against. This is the translation-parity equivalent of the component
gaps in `component-parity.md` units 15a/21a/21b — same three places, counted
on the message axis instead of the widget axis.
