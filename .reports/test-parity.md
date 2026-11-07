# Test parity — eyedropper-rb (round 3)

| | |
|---|---|
| Upstream | `origin/main` @ `9c480cb` |
| Port | `ruby` @ `9d03426` |
| Upstream tests (active `#[test]` fns) | 14, all in `src/colors/parser.rs` (confirmed again: `git grep '#\[test\]' origin/main -- src/` returns only this file) |
| Ported 1:1 | 12 |
| Ported but merged 2:1 | 2 pairs → 2 port tests stand in for 4 upstream tests (unchanged from last round) |
| Documented entry point that works | now **disclosed as broken**, with working alternatives named — see below |

## The suite still does not run through `rake`, but this is no longer undisclosed

Reproduced this round, same failure as before:

```
$ nix develop --command xvfb-run -a rake test
.../bundler-2.7.2/lib/bundler/source/git/git_proxy.rb:367: The git source
https://github.com/pboling/rubocop-packaging.git is not yet checked out.
```

The dev shell banner itself now prints, unprompted:

```
NOTE: 'rake'/'rake schema' still fail here — gemfiles/modular/style.gemfile
      pulls rubocop-packaging from a github: source this sandbox has no
      network to fetch; see AGENTS.md. Use the commands below directly.
```

and `CLAUDE.md`/`AGENTS.md` both carry a full paragraph explaining the exact
Nix/Bundler mechanism and naming every direct command to use instead. This
closes the accountability finding from the previous round
(`accountability-ensurance.md` previously: "nobody wrote even a bad excuse
for it — the gap is in what was never written"). The underlying packaging
defect is **still not fixed** — `rake` and `rake schema` still do not run —
but it is now a disclosed limitation with a working workaround, not a silent
trap. Recorded here as: documentation gap closed, packaging defect still
open.

## Suite runs reproduced this round, via the disclosed direct commands

| Command | Result |
|---|---|
| `xvfb-run ruby test/test_color.rb` | 21 runs, 280 assertions, 0 failures, 0 errors, 0 skips |
| `xvfb-run ruby test/test_i18n.rb` | 12 runs, 65 assertions, 0 failures, 0 errors, 0 skips |
| `xvfb-run ruby test/drive_window.rb` | 55 of 55 checks passed, DRIVE OK |
| `xvfb-run ruby test/drive_search_provider.rb` | 17 of 17 checks passed, SEARCH PROVIDER OK |
| `xvfb-run ruby test/drive_portals.rb` | 16 of 16 checks passed, PORTALS OK |

55 + 17 + 16 = **88 checks, 0 failed** — matches the round's stated gate
exactly, reproduced independently rather than taken on faith.
`test_color.rb`'s run count (21) is higher than the 19 recorded last round;
not chased further here since the upstream-to-port bijection table below was
re-verified by reading both sides' test names directly and is unchanged — the
extra runs are additional self-authored coverage, not a change to which
upstream tests have a port counterpart.

## Upstream-to-port test bijection — unchanged from last round, re-verified by reading both sides again

| Upstream # | Port test | State |
|---|---|---|
| 1,2 (`rgb` basic + percent) | `test_rgb` | **merged, bijection gap** — one Ruby method for two upstream tests |
| 3,4 (`hsl` basic + deg) | `test_hsl` | **merged, bijection gap** — same shape |
| 5–14 | `test_hsv`, `test_cmyk`, `test_xyz`, `test_cielab`, `test_hwb`, `test_lch`, `test_lms`, `test_hunter_lab`, `test_oklab`, `test_oklch` | ported 1:1 |

Still true: a change that breaks only the percent-component `rgb()` path (or
only the `deg`-suffixed `hsl()` path) while leaving the other half of its
merged test green has no test of its own to fail on — it has to break the
whole merged method. 0 upstream tests are missing a counterpart outright;
the gap is bijection, not coverage.

## The `GetResultMetas` false-green finding from last round: fixed in the check itself, not worked around

Last round flagged `test/drive_search_provider.rb` check `[4]` for naming
itself "the server answers GetResultMetas" while actually only asserting
`!error.is_a?(Gio::DBusError)` — true regardless of the D-Bus reply's actual
content, because of a known ruby-gnome `aa{sv}` unwrapping limitation. Reading
the current file:

```ruby
check("call did not fail at the D-Bus protocol level (reply content unchecked here)") do
  error.nil? || error.is_a?(NotImplementedError)
end
```

The check's **name now states its own limitation plainly**, and the
assertion is now narrower (only `nil` or the specific known
`NotImplementedError` pass — any other exception class, including a
different `Gio::DBusError`, now fails it, where the old code only excluded
`Gio::DBusError`). This is the finding closed correctly: not by deleting the
honest caveat, not by papering over it, but by moving the caveat into the
thing a reader actually sees in the test output. The underlying limitation
(the reply's `aa{sv}` content is still checked only in-process, in step `[5]`,
never over the wire) is unchanged and is not claimed fixed — it's a binding
limitation, not a port bug — but the check no longer overstates what it
proved.

## What the 88-check gate covers and does not

Reading all three drive scripts' step lists directly (44 steps in
`drive_window.rb`, plus the search-provider and portal scripts' own steps):
no step in any of the three ever opens `primary_menu` and reads an item
label, and no step renders a widget and asserts a specific CSS rule from
`style.css` took effect. These are the same two units `component-parity.md`
names as unverified. Per this round's instruction, that makes them
unverified, not done, regardless of the 88/88 headline. Units 15/15a
(settings schema) and 21a/21b (desktop/metainfo metadata) — gaps last round —
are not exercised by any drive check either, but are now verified correct by
direct file comparison (see `component-parity.md`), which is a different and
weaker form of verification than a runtime check; recorded so "88 checks, 18
components" is not read as implying file-level correctness was driven at
runtime for those units — it was not, it was read.
