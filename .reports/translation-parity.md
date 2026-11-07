# Translation parity — eyedropper-rb (round 4)

| | |
|---|---|
| Upstream | `origin/main` @ `9c480cb` (unchanged since round 3) |
| Port | `ruby` @ `65ea711` |
| `po/LINGUAS` | identical byte-for-byte (diff: empty), re-checked this round |
| `po/Eyedropper.pot` msgid count | 147 both sides, re-counted this round (`grep -c '^msgid'`) |
| Catalogue files | 34 `.po` files, same filenames both sides |

## Method this round

`65ea711` (the only commit since round 3's report) touches only
`test/drive_window.rb` — no `lib/`, `data/`, `po/` or `exe/` file changed,
and no new user-facing string was introduced by it (the three new drive
steps read existing menu labels; they add no new translatable string of
their own in app code). Re-built an `origin/main` worktree anyway and
re-ran `.claude/skills/translation-parity/scripts/msgid-census.sh` against
it and against this round's `lib/ exe/ data/ po/`, rather than assume round
3's census is still valid just because no file changed — upstream could in
principle have moved, and did not (`origin/main` still `9c480cb`).

```
upstream non-po unique (msgctxt, msgid) pairs: 277
port    non-po unique (msgctxt, msgid) pairs: 272
```

(Round 3 reported 80/85 using a narrower `grep`-filtered count; this round's
numbers are the raw census tool's deduplicated counts including `po`-kind
rows, so the two are not directly comparable — the diff below is what
matters, not the raw totals.)

## Diffing the two sides: one real finding, confirmed not to be a translation gap

```
< -	A bitflag of which color names shources should be used.
> -	A bitflag of which color name sources should be used.
```

Upstream's own `data/resources/.../gschema.xml.in` has a typo —
"shources" — in the `name-sources-flag` key's `<description>`. The port's
`data/com.github.finefindus.eyedropper.Rb.gschema.xml` has the same text
with the typo silently corrected to "sources". Checked directly whether
this is a real (msgctxt, msgid) divergence on the translation axis:

```
$ grep -n gschema origin/main:po/POTFILES.in   # (worktree check)
(no output)
```

`gschema.xml.in` is not in upstream's own `POTFILES.in` on either side (same
finding round 3 made about the `cie-*` keys, re-confirmed here for a
different key) — this text is never extracted into `po/Eyedropper.pot` and
is not user-facing translated text by either project's own build. **Not a
translation-parity gap.** It is worth naming once, here, so a future round
does not independently "discover" the typo-fix and mistake it for either an
untranslated-string problem or a silent content drift that matters on this
axis — it is a cosmetic correction to non-translated schema documentation,
visible only to someone reading `gsettings describe`.

The remaining diff rows are the two additive, port-only strings
(`"Eyedropper (Ruby)"`, `"A Ruby GTK4 / Libadwaita port of Eyedropper by
FineFindus."` — the port's own about-dialog/description credit) and four
`!unresolved` rows on both sides, which are the census script's own
disclosed limitation (dynamic `_()`/`c_()` call sites it cannot statically
resolve a literal msgid for — e.g. `_(Config::APP_NAME)`), not missing
messages. Checked each `!unresolved` row by reading the named source line on
both sides; none hides an actual missing or mistranslated static string.

## Running total this round

| | Count |
|---|---:|
| `po/Eyedropper.pot` msgid count, both sides | 147 |
| Messages with no reachable port string | 0 |
| Messages whose port-side value differs from upstream's translated text | 0 |
| Non-translated schema text differing (cosmetic, not a `.pot` member) | 1 (the "shources" typo fix — not a gap) |

Zero open translation-parity gaps this round. Nothing changed on this axis
since round 3 (no `po/`, `lib/`, `data/` diff from `65ea711`); this round's
work was re-verifying that upstream also had not moved and that the one
schema-text difference found by the raw census is not a `.pot` member on
either side, same disposition as round 3's `cie-*` finding.
