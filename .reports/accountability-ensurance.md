# Accountability ensurance — eyedropper-rb (round 3)

Ran `.claude/skills/accountability-ensurance/scripts/find-excuses.sh` against
`lib/`, `exe/`, `PORTING.md`, and this round's own `.reports/*.md`, then read
every hit and the surrounding paragraphs by hand, and separately re-verified
(rather than re-asserted) every claim the *previous* round's own report made,
since a stale "fixed" or "gap" claim in last round's reports is itself the
kind of false-green this skill exists to catch.

## Script hit, read, dismissed (unchanged from last round)

```
lib/eyedropper/picker.rb:6  "no Ruby equivalent"
```

"`ashpd` has no Ruby equivalent, so this talks to the portal directly." The
behaviour (picking a colour through the portal) is fully built; the sentence
names a different mechanism, not a dropped feature. No rewrite owed.

## Last round's three "Real gaps" and one "undisclosed command": re-verified this round, not re-asserted

| Last round's finding | This round's independent check | Verdict |
|---|---|---|
| `cie-illuminants`/`cie-standard-observer` GSettings keys absent | `diff`'d both gschema files key-by-key; `grep`'d `lib/eyedropper/settings.rb`, `illuminant.rb`, `color.rb` for the keys being read and used, not just declared | **Fixed and wired**, not just declared for show |
| Metainfo screenshot/feature block (8 messages) absent | Read both `metainfo.xml(.in.in)` files in full | **Fixed** |
| Desktop entry `Keywords`/`Categories`/`DBusActivatable` diverged | Read both `.desktop` files in full | **Fixed** |
| `rake`/`rake schema` broken and undisclosed | Re-ran `rake test` in the dev shell (still fails, same error); read `CLAUDE.md`, `AGENTS.md`, and the dev shell banner | **The breakage is unchanged, but it is now disclosed** in all three places with the exact mechanism and working alternative commands named |

None of these four were taken on the previous report's word; each was
re-derived from the actual files and a real command run this session. This
matters because the previous round's own translation-parity report contained
a factual error (see below) found only by *not* trusting its citation.

## A factual error found in the previous round's own `translation-parity.md`, logged per this skill's own rule

Last round's report asserted the `cie-*` GSettings summary/description text
was "a real (msgctxt, msgid) in `po/Eyedropper.pot`." Checked directly this
round: it is not. `data/com.github.finefindus.eyedropper.gschema.xml.in` is
not in upstream's own `po/POTFILES.in`, so gschema text is never extracted
into the `.pot` on either side, and the strings in question appear nowhere in
`po/Eyedropper.pot`. The *conclusion* that round reached (there was a real
component gap) was still correct, and the gap is now fixed regardless — but
the *reason given* for why it mattered on the translation axis was
fabricated-by-inference rather than checked, which is exactly this skill's
target: a claim stated with the confidence of something verified, that
wasn't. Logged against `translation-parity.md` (last round's version, now
corrected in this round's version) rather than rewritten as an insult-bank
entry, since it is an error of verification, not an excuse construction —
this skill's own rule distinguishes the two, and only the latter gets the
first-person rewrite treatment.

## `PORTING.md`'s "Dropped settings keys" section: no longer an excuse, because the thing it excused no longer happens

The section the previous round rewrote as an excuse-bank entry
(`PORTING.md:131-136` at the time) has been replaced with a section titled
`## cie-illuminants and cie-standard-observer` that states plainly that
upstream declares both keys and reads neither, and that **this port carries
both over and wires them up**, naming the exact files
(`lib/eyedropper/illuminant.rb`, `Settings#white_point`) and being explicit
about which part of the mapping is the port's own invention
(`cie-illuminants`'s integer-to-name table) versus upstream-documented
(`cie-standard-observer`'s 0/1 meanings). This is the correct resolution of
last round's finding — not because the prose changed, but because the
underlying gap it used to excuse was actually closed. A reader could, in
principle, still object that the invented `cie-illuminants` mapping needs a
value-for-value justification beyond "chosen so default 5 means D65" — but
that is a design note, not a dropped feature, and the section already
discloses it as the port's own choice rather than asserting it as upstream
fact.

## The `GetResultMetas` false-green from last round: the fix is a disclosure fix, verify it stayed one

Re-read `test/drive_search_provider.rb` this round (not assumed unchanged):
check `[4]`'s name now states its own limitation
(`"call did not fail at the D-Bus protocol level (reply content unchecked
here)"`), and its assertion is narrower than before
(`error.nil? || error.is_a?(NotImplementedError)`, not merely "not a
`Gio::DBusError`"). The surrounding comment still correctly states that the
actual reply content is checked only in-process in step `[5]`, never over the
wire. This is accountability done right: the limitation is still there, the
check's own name says so, nothing is hidden behind a comment a reader of the
output would never see.

## What this round's own five reports must not do (re-checked, not re-asserted)

None of `component-identification.md`, `component-parity.md`,
`test-parity.md` or `translation-parity.md` cites `PORTING.md` or any other
port-authored document as the reason a row is closed; each states what was
checked this round (a diff, a grep, a reproduced test run) and points here
only for the accountability framing. The one correction made against last
round's own `translation-parity.md` is written into *this round's*
`translation-parity.md`, not smoothed over.

## Verdict

Zero excuse constructions found this round in `lib/`, `exe/`, `PORTING.md`.
One factual error found in the *previous* round's own report, corrected, not
excused. Zero undisclosed broken commands — the one broken command
(`rake`/`rake schema`) is disclosed in three places with working
alternatives. Two units remain genuinely unverified by any runtime check
(primary menu, stylesheet) — carried forward honestly as "unverified, not
done" in `component-parity.md` and `test-parity.md`, not folded into the
88/88 headline. `clean: true` would require those two units to gain a check,
not merely to be read and confirmed correct by a human — which is exactly
what distinguishes a port that passes its gate from one that has actually
been audited into every corner.
