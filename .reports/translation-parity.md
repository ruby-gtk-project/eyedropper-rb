# Translation parity — eyedropper-rb (round 3)

| | |
|---|---|
| Upstream | `origin/main` @ `9c480cb` |
| Port | `ruby` @ `9d03426` |
| `po/LINGUAS` | identical byte-for-byte (diff: empty) |
| `po/Eyedropper.pot` msgid count | 147 both sides |
| Catalogue files | 34 `.po` files, same filenames both sides |

## Method this round

Built an `origin/main` worktree and ran
`translation-parity/scripts/msgid-census.sh` against it and against this
port's `lib/ exe/ data/ po/`, then diffed the deduplicated non-`.po`-sourced
(msgctxt, msgid) sets — same method as last round, re-run rather than
assumed still valid.

```
upstream non-po unique messages: 80
port    non-po unique messages: 85
```

## Correcting a factual error in last round's own report, found while re-verifying it

Last round's report stated the `cie-illuminants`/`cie-standard-observer`
GSettings `<summary>`/`<description>` text was "a real (msgctxt, msgid) in
`po/Eyedropper.pot`." This is checked directly this round and is **false**:
`grep -n "Tristimulus\|CIE standard observer\|Color Illuminant"
po/Eyedropper.pot` (upstream) finds neither "Tristimulus" nor "Color
Illuminant" anywhere in the `.pot`, because
`data/com.github.finefindus.eyedropper.gschema.xml.in` is **not** in
upstream's own `po/POTFILES.in` — only the `.blp`/`.rs` files are extracted.
The underlying component gap (the port not shipping the two keys) was real
and is now fixed anyway (see `component-parity.md`), so nothing was left
unfixed by this error, but the report's *claim about why it mattered* was
wrong, and a translation-parity ledger overstating what's in the `.pot` is
exactly the kind of false-green risk this skill exists to catch — it is
flagged here, in this document, pointed at the document that made the claim,
per `accountability-ensurance.md`'s own rule that a gap is logged against the
document that gets it wrong.

## Previously-found real gaps: both confirmed closed by direct `.pot` membership check this round

Both of these messages **are** genuinely in `po/Eyedropper.pot` (confirmed:
`grep -n` for the exact caption/feature text and for the `Keywords=` source
line's extracted string), and both are extracted because their source files
(`metainfo.xml.in.in`, `desktop.in.in`) are listed in upstream's
`POTFILES.in`:

- **Metainfo feature/caption block** (8 messages) — now present verbatim in
  `data/com.github.finefindus.eyedropper.Rb.metainfo.xml`. Closed.
- **Desktop `Keywords`** (1 message) — now byte-identical to upstream's
  string in `data/com.github.finefindus.eyedropper.Rb.desktop`. Closed.

## Scanner artifacts re-checked, not re-flagged as gaps

The raw 80-vs-85 non-po diff surfaces several rows (`Alphavalue is not
shown`/`None`, the four name-source subtitles, both RGB-notation strings,
three tooltip strings) that look like upstream-only messages. Each was
checked by `grep -n` against `lib/eyedropper/widgets/preferences_dialog.rb`
and `lib/eyedropper/window.rb` this round, independently of trusting last
round's "scanner artifact" dismissal:

```
lib/eyedropper/widgets/preferences_dialog.rb:12: c_("Alphavalue is not shown", "None")
lib/eyedropper/widgets/preferences_dialog.rb:17: c_("RGB is format as integers (e.g. 127)", "Integer")
lib/eyedropper/window.rb:193:                  c_("Tooltip of the colorpicker button", "Pick a Color")
```

All present, same msgctxt/msgid pairs as upstream's `C_()` calls. The
mismatch is an artifact of comparing fields across a `msgctxt`/`msgid` pair
by position; not a real gap. **Confirmed, not merely re-asserted.**

## Running total this round

| | Count |
|---|---:|
| Messages confirmed byte-identical and reachable | 147 |
| Messages with no reachable port string | 0 |
| Messages whose port-side value differs from upstream's | 0 |

Zero open translation-parity gaps this round. The 9 messages (8 metainfo + 1
desktop keyword) open at the end of the last round are closed; the 4
`cie-*` schema messages this report's predecessor miscounted as `.pot`
members were never actually `.pot` members, so there was nothing there to
close on this axis (the GSettings *key* gap itself is a component-parity
matter, closed separately).
