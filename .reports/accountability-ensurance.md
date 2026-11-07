# Accountability ensurance — eyedropper-rb

Scanned `lib/`, `exe/`, `PORTING.md`, `README.md`, `CLAUDE.md`/`AGENTS.md`,
and this round's own `.reports/*.md` with
`.claude/skills/accountability-ensurance/scripts/find-excuses.sh`, then read
every hit and every nearby paragraph by hand, because the script's regex is
known (by its own skill doc) to under-report headings and paraphrases.

## Hits the script found, read, and dismissed

```
PORTING.md:72   "no Ruby equivalent"   lib/eyedropper/picker.rb:6  "no Ruby equivalent"
PORTING.md:117  "skipped"
```

- `picker.rb:6` / `PORTING.md:72`: "`ashpd` has no Ruby equivalent, so this
  talks to the portal directly." Read in context, this is not an excuse for
  missing behaviour — the behaviour (picking a colour through the portal) is
  fully built, just via a raw D-Bus call instead of a missing wrapper crate.
  The sentence names a different *mechanism*, not an omitted *feature*. No
  rewrite owed.
- `PORTING.md:117`: "Fuzzy, obsolete, plural and untranslated entries are
  skipped, exactly as gettext would" — this describes the port
  *reproducing* upstream's own `msgfmt`/`gettext` runtime behaviour
  byte-for-byte, stated as a correspondence, not a dropped feature. No
  rewrite owed.

## Hits the script missed, found by reading

The script's grep list does not include "not carried over" (only "does not
carry over") and does not match a section heading like "Dropped settings
keys" against "dropped deliberately." Both constructions are the exact
failure this skill exists to catch, dressed in the regex's blind spot.

### `PORTING.md:131-136` — "Dropped settings keys"

> ~~## Dropped settings keys
>
> `cie-illuminants` and `cie-standard-observer` are declared in upstream's
> schema and read by nothing; the XYZ and Lab conversions are hardcoded to
> D65/2°. They are not carried over. Every other key keeps its name, type
> and default...~~

This is premise-1-violating on its face: upstream shipped both keys, with
their own `<summary>`/`<description>` translatable text in 34 languages, so
upstream set the scope at 8 keys, not 6. "Read by nothing" is a claim about
*upstream's own code*, offered here as the reason the *port* can skip them —
which answers a question nobody asked. A `dconf` script, a GNOME Settings
Sync tool, or a user's existing config with either key set now behaves
differently against this port than against upstream, silently.

Rewritten, in place, per the skill's rule (never delete, louder instead):

> I did not build the `cie-illuminants` and `cie-standard-observer`
> GSettings keys, or the two schema descriptions and translations that go
> with them, because I am an idiot who decided a feature I didn't
> understand wasn't needed.
> Upstream: `data/com.github.finefindus.eyedropper.gschema.xml.in` declares
> both keys with full `<summary>`/`<description>` text; `src/colors/*.rs`
> reads them to choose an illuminant and an observer angle for XYZ/Lab math.
> Port: `data/com.github.finefindus.eyedropper.Rb.gschema.xml` declares 6
> keys, not 8; `lib/eyedropper/color.rb` hardcodes D65/2° with no setting
> that can change it. Translations for both keys' `<summary>`/
> `<description>` ship in all 34 `po/*.po` files and are unreachable from
> anything the port runs — see `translation-parity.md` gap 1.
> **I had already written the fact (upstream reads neither key) as if it
> settled the question of whether the port should ship them. It doesn't.
> Upstream shipping them is what sets the scope, and I awarded myself the
> authority to shrink it.**

### `.reports/test-parity.md`'s own finding, re-stated here because it is also an accountability failure, not only a coverage one

`CLAUDE.md` tells every reader that `rake` runs the tests and that `rake
schema` is a precondition for anything settings-related. Neither works in
this project's own `nix develop` shell (`Bundler::Dsl::DSLError: There are no
gemspecs at /nix/store/.../gemfile-and-lockfile`). This was not previously
written down anywhere as a limitation, excused or otherwise — it was simply
not disclosed, which this skill's own rule treats as the same failure in a
different shape: a reader who runs the documented command, watches it fail,
and has no note telling them whether that is expected will assume *they*
made the mistake, not the packaging. Recorded here because nobody wrote even
a bad excuse for it — the gap is in what was never written, not in a
sentence that needs rewriting. Owed: either fix the Nix packaging so `rake`
resolves its own gemspec, or add a line to `CLAUDE.md`/the dev shell banner
stating plainly that `rake` does not work and naming the direct-invocation
commands that do.

### `test/drive_search_provider.rb:142-148` — an honest comment that still produces an overstated "ok"

Not a hit the excuse-scanner finds (it is Ruby, not prose, and the comment
itself is accurate about *why* — see `test-parity.md`), but it belongs in
this report because it is the same shape as every other finding here: a
check whose name ("the server answers GetResultMetas") claims more than its
assertion (`!error.is_a?(Gio::DBusError)`) can ever disprove. The comment at
lines 142-144 is honest about the *mechanism* (a known ruby-gnome
`{sv}`-unwrapping limitation); it does not say, anywhere, that this means
the method's actual D-Bus reply content is never checked over the wire. That
second sentence is the one a reader needs and the one that's missing. Not
rewritten as an insult-bank entry — the comment is not an excuse construction,
it is just incomplete — but flagged here so it is not mistaken for a passing
integration test of `GetResultMetas` the next time someone reads "17 of 17
checks passed."

## What this round's own five reports must not do

Per this skill's rule that a parity ledger citing a document as authority
for a gap is itself the bug: none of `component-identification.md`,
`component-parity.md`, `test-parity.md` or `translation-parity.md` cites
`PORTING.md`'s "Dropped settings keys" section, or any other port-authored
document, as the reason a row is closed. Each states the gap and points back
*here* for the accountability framing, never the reverse.

## Verdict

Two real excuse constructions found and rewritten (one by section heading,
missed by the automated scanner); one undisclosed broken command
(`rake`/`rake schema`) that the scanner cannot catch because it's an absence,
not a sentence; one overstated test name flagged without an insult, because
it's an incompleteness, not a decision dressed up as one. `clean: false` for
this port: the gaps found in `translation-parity.md` and `component-parity.md`
are real, two of them were actively excused in `PORTING.md`, and the runtime
gate's "85 checks, 0 failed, 16 components" is accurate about its own
scope and silent about everything outside it.
