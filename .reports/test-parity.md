# Test parity — eyedropper-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` @ `b72f734` |
| Upstream tests (active `#[test]` fns) | 14 |
| Upstream tests disabled in upstream's own source | 4 (`src/colors/parser.rs:179-230`, commented out along with their `#[cfg(test)] mod`) |
| Ported (named, 1:1) | 12 |
| Ported but merged 2:1 (bijection violated) | 2 pairs → 2 port tests stand in for 4 upstream tests |
| Gaps | 0 properties, 2 bijection violations |
| Test command that actually works | `xvfb-run ruby test/test_color.rb` (direct), **not** `rake test` |

## The suite does not run through its documented entry point

`CLAUDE.md` and the dev shell banner both point at `rake` (`rake` = "test +
lint"; `rake schema` is a stated precondition). Both are broken in the
project's own `nix develop` shell this session:

```
$ nix develop --command xvfb-run -a rake test
.../bundler/dsl.rb:88:in `gemspec': There are no gemspecs at
/nix/store/sp0vbwky77h33rqizma819iklqc1b9h3-gemfile-and-lockfile.
Bundler cannot continue.
```

Same failure for `rake schema` alone — rake cannot even boot far enough to
reach a task name, because `bundler/gem_tasks` evaluates the packaged
`Gemfile` (a Nix-substituted copy under `/nix/store/...-gemfile-and-lockfile`)
and that copy's `gemspec` directive finds no `.gemspec` file in the same
store path. This is a packaging defect in `flake.nix`/`gemset.nix`, not a
Ruby bug, but it means: **the command this port's own documentation names as
how to run its tests does not run its tests.** Every number below was
produced by invoking the individual test/drive files directly
(`ruby test/test_color.rb`, etc.), which is not the documented path and is
not what a CI job running `rake` would do — such a job fails at `bundle
install`/`gemspec` before a single assertion runs.

This is logged again in `accountability-ensurance.md`: nothing in `PORTING.md`
or the dev shell banner discloses that `rake` is non-functional.

## Upstream census

Censused by hand from `src/colors/parser.rs` (the only upstream file with
inline tests — confirmed: `git grep '#\[test\]' origin/main -- src/` returns
only this file).

| # | Upstream test | Module | Purpose |
|---|---|---|---|
| 1 | `it_parses_basic` | `parse_rgb` | `rgb(...)`/`rgba(...)` basic form |
| 2 | `it_parses_percent` | `parse_rgb` | percentage components in `rgb()` |
| 3 | `it_parses_basic` | `parse_hsl` | `hsl()`/`hsla()` basic form |
| 4 | `it_works_with_deg` | `parse_hsl` | hue suffixed `deg` |
| 5 | `it_parses` | `parse_hsv` | `hsv()` round trip |
| 6 | `it_parses` | `parse_cmyk` | `cmyk()` round trip |
| 7 | `it_parses` | `parse_xyz` | `XYZ(...)` round trip |
| 8 | `it_parses` | `parse_cie_lab` | `lab()` round trip |
| 9 | `it_parses` | `parse_hwb` | `hwb()` round trip |
| 10 | `it_parses_lch` | `parse_lch` | `lch()` round trip |
| 11 | `it_parses` | `parse_lms` | LMS triplet round trip |
| 12 | `parse_hunter_lab` | `tests` | Hunter Lab round trip |
| 13 | `parses_oklab` | `parse_oklab` | `oklab()` round trip |
| 14 | `parses_oklch` | `parse_oklch` | `oklch()` round trip |

Disabled upstream (not counted, not run by upstream's own suite, listed so a
re-enable on either side is noticed): `it_parse_hex_without_alpha`,
`it_parse_hex_with_alpha_start`, `it_parse_hex_with_alpha_end`,
`success_with_whitespace`, all commented out at `src/colors/parser.rs:179-230`
together with their `#[cfg(test)]`.

## Mapping to the port

`test/test_color.rb`, run this session: `19 runs, 275 assertions, 0 failures,
0 errors, 0 skips`.

| Upstream # | Port test | State |
|---|---|---|
| 1, 2 | `test_rgb` | **ported, merged** — one Ruby method asserts both the basic and the percent-component vectors. Per the test-parity skill's own rule ("never merge two upstream tests into one Ruby test to save typing"), this is a **bijection gap**: 2 upstream tests → 1 named port test. The property coverage survives (both vectors are literally asserted), but a future edit that breaks only the percent-component path and leaves the basic path green has no test of its own to fail on; it would have to break `test_rgb` outright, not a single named case. |
| 3, 4 | `test_hsl` | **ported, merged** — same shape as 1,2: basic and `deg`-suffix vectors asserted in one method. |
| 5 | `test_hsv` | ported |
| 6 | `test_cmyk` | ported |
| 7 | `test_xyz` | ported |
| 8 | `test_cielab` | ported |
| 9 | `test_hwb` | ported |
| 10 | `test_lch` | ported |
| 11 | `test_lms` | ported |
| 12 | `test_hunter_lab` | ported — and per `PORTING.md`, deliberately *not* reproducing upstream's own Hunter Lab white-point bug, so the numeric vector asserted is not literally upstream's broken one. The property ("Hunter Lab parses to the Nord colour") is still pinned. |
| 13 | `test_oklab` | ported |
| 14 | `test_oklch` | ported |

12 of 14 upstream tests have a clean 1:1 port test; 2 pairs (4 upstream tests)
collapse into 2 port tests. 0 upstream tests are missing a counterpart
entirely.

## `## Extra` (outside the count, not a parity claim)

- `test_hex_round_trip`, `test_hex_alpha_positions`, `test_hex_rejects_junk` —
  cover the ground upstream's own 4 *disabled* hex tests covered, written
  fresh since those upstream tests don't run either.
- `test_every_notation_round_trips`, `test_conversions_are_self_inverse`,
  `test_greyscale_edges_do_not_divide_by_zero`, `test_equality_is_by_byte` —
  port-authored, no upstream counterpart.
- `test/test_i18n.rb` — 12 runs, 65 assertions, this session. No upstream
  Rust test suite exists for the gettext reader because upstream uses
  `gettextrs` directly with no wrapper to test; this is pure port-side
  coverage of `lib/eyedropper/i18n.rb`.
- `test/drive_window.rb`, `test/drive_portals.rb`, `test/drive_search_provider.rb`
  — 52 + 16 + 17 = 85 checks this session, 0 failures. These are integration
  drives, not unit tests, and are the runtime gate's own source (see
  `component-parity.md` for which units they do and do not actually exercise).

## One drive check is narrower than its own "ok" line claims

`test/drive_search_provider.rb` check `[4] the server answers GetResultMetas`
asserts `!error.is_a?(Gio::DBusError)`. The run this session printed:

```
[4] the server answers GetResultMetas
    (error: NotImplementedError: TODO: GVariant({sv}) -> Ruby)
    ok   no D-Bus error
```

The check is engineered, with an honest comment at `test/drive_search_provider.rb:142-144`,
to not count a `NotImplementedError` (a known ruby-gnome binding limitation
unwrapping `aa{sv}`) as a failure — but it also means **check [4] passes
unconditionally regardless of whether the server's `GetResultMetas` D-Bus
reply is correct**, because the only error type that could fail it
(`Gio::DBusError`) is not the error type this code path can ever raise for
any other reason either. The actual content assertion in `[5]` calls
`provider.metas_text` directly in-process, never over the bus. So **the
`GetResultMetas` D-Bus method's wire behaviour is not verified by this
suite at all** — the drive run's "17 of 17 checks passed" is true and still
overstates what was tested. This is the "false green" shape the
`accountability-ensurance` skill asks to be hunted for, found in a test file
rather than in prose; logged there too.

## What the 85-check gate actually covers

85 = 52 (`drive_window.rb`) + 17 (`drive_search_provider.rb`) + 16
(`drive_portals.rb`), reproduced this session, 0 failures, matching the
stated gate. "16 components" is not derivable from any document in the repo
— no ledger states which 16 of the 21 (now 23, see
`component-identification.md`) identified units the drive run is claimed to
cover. Reading the three drive scripts directly: they exercise units
1, 2, 4–12, 16 (indirectly, via rendering only — never asserted against),
18, 19, 20 — roughly 15–16 units depending on whether the un-asserted icon
rendering counts, which is probably where "16" comes from, but it is this
auditor's reconstruction, not anything written down by the port. Units 3
(primary menu), 14 (stylesheet rules), 15/15a (settings schema incl. the two
dropped keys), 17 (translation at runtime — no check switches `LANGUAGE` and
asserts a translated string appears), and 21/21a/21b (desktop + metainfo
metadata) are exercised by **no** check in any of the three drive scripts.
Per this round's instruction, a component no check exercises is unverified,
not done — five to seven of the 21–23 identified units fall in that bucket.
