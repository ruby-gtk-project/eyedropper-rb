# Test parity — eyedropper-rb (round 4)

| | |
|---|---|
| Upstream | `origin/main` @ `9c480cb` (unchanged) |
| Port | `ruby` @ `65ea711` |
| Upstream tests (active `#[test]` fns) | 14, all in `src/colors/parser.rs` — re-confirmed this round: `git grep '#\[test\]' origin/main -- src/` returns only this file |
| Ported 1:1 | 12 |
| Ported but merged 2:1 | 2 pairs → 2 port tests stand in for 4 upstream tests (unchanged since round 2) |
| `rake test` entry point | still fails, still disclosed (unchanged since round 3) |

## Suite runs, reproduced fresh this round

| Command | Result |
|---|---|
| `xvfb-run ruby test/test_color.rb` | 21 runs, 280 assertions, 0 failures, 0 errors, 0 skips |
| `xvfb-run ruby test/test_i18n.rb` | 12 runs, 65 assertions, 0 failures, 0 errors, 0 skips |
| `xvfb-run ruby test/drive_window.rb` | **67 of 67** checks passed, DRIVE OK (was 55 last round) |
| `xvfb-run ruby test/drive_search_provider.rb` | 17 of 17 checks passed, SEARCH PROVIDER OK |
| `xvfb-run ruby test/drive_portals.rb` | 16 of 16 checks passed, PORTALS OK |
| `rake test` | still fails: `Bundler::GitError` — `rubocop-packaging`'s `github:` source has no network access in this sandbox. Same failure as round 3, reproduced again this round rather than assumed. |

67 + 17 + 16 = **100 checks, 0 failed** — matches this round's stated gate
(`drive_ok=true, 100 checks passed, 0 failed, covering 21 components`)
exactly, reproduced independently.

## What grew: the 12 new `drive_window.rb` checks, read not just counted

`65ea711` added 12 checks across 3 new steps (primary menu: 4 checks; hue
gradient: 4 checks including the file-write check; icon theme: 3 checks) —
55 + 12 = 67, matches. Each of the 12 was read in `component-parity.md`'s
round-4 pass and confirmed to assert something that requires the real
widget tree, the real display's CSS cascade, or the real icon theme to have
actually done its job — not a restatement of source code. Not re-litigated
here in full; see that report.

## `rake`/`rake schema` breakage: still open, still disclosed, re-confirmed this round

Reproduced the identical `Bundler::GitError` this round. `CLAUDE.md` and
`AGENTS.md` both still carry the explanatory paragraph (read in full this
round, not assumed present) naming the exact mechanism
(`pkgs.bundlerEnv`'s throwaway Gemfile-only store path, the git-source gem in
`gemfiles/modular/style.gemfile`) and listing the direct commands to use
instead. The underlying packaging defect is unchanged and still open as a
defect — it is not claimed fixed anywhere — but it remains a disclosed
limitation with working alternatives, not a silent trap. No regression since
round 3.

## Upstream-to-port test bijection — unchanged, re-verified by reading both sides' test names again

| Upstream # | Port test | State |
|---|---|---|
| 1,2 (`rgb` basic + percent) | `test_rgb` | merged — bijection gap, not a coverage gap |
| 3,4 (`hsl` basic + deg) | `test_hsl` | merged — same shape |
| 5–14 | `test_hsv`, `test_cmyk`, `test_xyz`, `test_cielab`, `test_hwb`, `test_lch`, `test_lms`, `test_hunter_lab`, `test_oklab`, `test_oklch` | ported 1:1 |

Still true, and still worth repeating rather than letting it quietly drop
out of the report now that other gaps have closed: a change that breaks
only the percent-component `rgb()` path (or only `deg`-suffixed `hsl()`)
while leaving the rest of its merged test's assertions green has no test of
its own to catch it — it must break the whole merged method to fail
anything. 0 upstream tests are missing a counterpart outright; this is a
bijection gap (test granularity), not a coverage gap.

## What the 100-check gate covers and does not, read fresh this round

Re-read all 3 drive scripts' full step lists (now 67 steps in
`drive_window.rb`, plus search-provider's and portals' own). Everything
round 3 named as lacking a driving check (primary menu, stylesheet
gradient, icon resolution) now has one — see `component-parity.md`. Nothing
in the 100-check gate drives GSettings schema text or metainfo/desktop XML
content at runtime; those remain file-diff-verified only (round 3's
finding, unchanged, not a regression). The merged-test bijection gap above
is the one place "100 checks, 0 failed" undercounts what upstream actually
tests — 4 upstream tests are represented by 2 port tests, which is fewer
failure-points than upstream has, not more coverage.
