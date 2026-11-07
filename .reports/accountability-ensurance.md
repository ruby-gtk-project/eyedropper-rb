# Accountability ensurance — eyedropper-rb (round 4)

Ran `.claude/skills/accountability-ensurance/scripts/find-excuses.sh` against
`lib/`, `exe/`, `PORTING.md` and this round's own `.reports/*.md`, read the
one hit and its surrounding paragraph by hand, and independently re-verified
(rather than re-asserted) this round's own sibling reports' central claim —
that the three units carried as "unverified, not done" since round 2/3
(primary menu, stylesheet gradient, icon resolution) are now genuinely
driven by `65ea711`, not merely re-labeled as driven.

## Script hit, read, dismissed (unchanged since round 2/3, re-checked not re-copied)

```
lib/eyedropper/picker.rb:6  "no Ruby equivalent"
```

"Upstream calls this through `ashpd`. There is no Ruby equivalent, so this
talks to `org.freedesktop.portal.Screenshot.PickColor` over the session bus
directly." Read the full method body this round (not just the comment): the
portal call, the async `Response` signal wait, and the color-value
extraction are all implemented in the same file. The sentence names a
different *mechanism* for reaching the same behavior upstream reaches — it
does not excuse a missing feature. `test/drive_portals.rb` (16/16 this
round) exercises this exact path, including its failure mode (step 6,
"start is safe even when nothing answers"). No rewrite owed.

## This round's central claim, checked rather than trusted: are the three "unverified" units actually driven now?

The risk in a round that adds checks and immediately calls three gaps
closed is that the new checks assert something trivially true (a false
green dressed as progress) rather than the thing the gap named. Read each
new check's actual assertions directly in `test/drive_window.rb` (not the
commit message, not `component-parity.md`'s own description of them):

- **Primary menu.** The check reads `action`/`label` *attribute values* off
  a *live* `Gio::Menu` obtained from a popped-open real `GMenuButton`
  popover, not a call that only checks `window.primary_menu` is non-nil or a
  structural re-parse of `window.blp`. A check this shape cannot pass if the
  menu were empty, mis-ordered, or wired to the wrong actions. **Genuinely
  driven.**
- **Hue-slider gradient.** The check renders the actual widget to a PNG and
  decodes real pixel bytes with `GdkPixbuf::Pixbuf`, asserting a hue shift
  between two sampled x-positions. A check this shape cannot pass if
  `data/style.css` were never loaded for the display, or if the gradient
  stops were wrong — a flat-grey trough or a flat-red trough both fail the
  "quarter across has shifted away from red" assertion. **Genuinely driven,**
  not a restatement that the CSS class string is attached.
- **Icon resolution.** The check calls `has_icon?` on
  `Gtk::IconTheme.get_for_display` with the window's *own* display, for
  three names actually used by the running app. This fails if
  `install_icons` never registered the right search path, or if the
  directory layout didn't match GTK's icon-theme-directory conventions.
  **Genuinely driven** for the resolution claim it makes; the report is
  explicit (`component-parity.md`) that this is narrower than pixel-fidelity
  to upstream's SVGs, which remains unverified — the right scope, not an
  overclaim.

No false green found in any of the three. Each closes exactly the gap it
claims to close, no more.

## Checked whether this round's sibling reports overclaim anything

Re-read `component-identification.md`, `component-parity.md` and
`test-parity.md` (this round's versions) line by line for any sentence that
states a conclusion the evidence given doesn't support. None found. Each
names the exact check, the exact assertion, and the exact file/line range it
read. `component-parity.md` explicitly keeps two narrower residual claims
open (icon pixel-fidelity, schema/metainfo file content verified by diff,
not runtime) rather than letting "100/100, 0 failed" imply those are driven
too.

## `rake`/`rake schema`: still open, still disclosed, not re-litigated as a new finding

Re-ran `rake test` this round — same `Bundler::GitError` as rounds 2 and 3.
`CLAUDE.md`/`AGENTS.md` still carry the full disclosure with working
alternative commands, unchanged since round 3's fix. Not a new finding; not
re-flagged as a gap, since disclosed-and-worked-around is the correct
resolution this skill asks for, and the underlying packaging defect, while
still open, is not this port's own code.

## Verdict

Zero excuse constructions found this round in `lib/`, `exe/`, `PORTING.md`.
Zero false greens found in the 12 new checks `65ea711` added — each was read
at the assertion level and confirmed to actually exercise the claim in its
step name, not merely to restate source code or pass vacuously. Zero
overclaiming found in this round's own sibling reports. The two remaining
narrower residual claims (icon pixel-fidelity to upstream's SVGs; schema/
metainfo/desktop content verified by file diff rather than at runtime) are
disclosed as such in `component-parity.md` and are not confirmed defects —
they are honestly-scoped limits, which is what distinguishes them from the
three gaps this round actually closed.

`clean: true` is **not** the right verdict, and this report does not claim
it, even though the three gaps this round set out to check are genuinely
closed. Three narrower gaps remain open across the sibling reports and are
real parity gaps under this round's own standard (a component no check
exercises is unverified, not done), not merely stylistic hedges:

- **Test bijection** (`test-parity.md`): 4 upstream `#[test]` fns are
  covered by 2 merged Ruby tests (`test_rgb`, `test_hsl`). A change that
  breaks only the percent-component `rgb()` path or only the
  `deg`-suffixed `hsl()` path, while leaving the rest of the merged test's
  assertions green, has no test of its own to catch it.
- **Icon pixel-fidelity** (`component-parity.md`): `has_icon?` proves the
  three named icons resolve through the real icon theme, but no check
  compares rendered icon bytes against upstream's SVGs — a differently
  drawn icon of the same name would still pass.
- **Schema/metainfo/desktop content** (units 15/15a/21a/21b,
  `component-parity.md`): verified correct by direct file diff in round 3,
  not by any runtime check this round or last; no drive step reads GSettings
  schema text or metainfo/desktop XML back at runtime.

None of these three is an excuse, a TODO, or a false green — each is
disclosed plainly, in the report that found it, with no claim of being
fixed. But per this round's own instruction, disclosed-and-open is still
open, not clean. The honest verdict is `clean: false`, carried by these
three items alone; nothing else in `lib/`, `exe/`, `PORTING.md` or this
round's reports constitutes an excuse or a false claim of coverage.
