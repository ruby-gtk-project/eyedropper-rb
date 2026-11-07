# Eyedropper — Ruby port

The Ruby GTK4 / Libadwaita port of Eyedropper, a color picker and format
converter. The upstream Rust implementation lives on the fork's `main` branch;
this branch is the port.

## Skills — use them

Two skills are installed in `.claude/skills/`. They are not optional reading.

- **ruby-gtk** — the house style for Ruby GTK4/Libadwaita: the declarative
  memoized-widget pattern, Adwaita binding quirks, worked examples. Load it
  before writing or reviewing ANY Ruby GTK code, including single widgets, and
  before planning a port. The bindings are quirky enough that code written from
  memory is unreliable.
- **ruby-gtk-testing** — run the app headlessly and drive its UI: click through
  dialogs, assert widget state, capture screenshots. Use it before claiming any
  GTK change works. `ruby -c` and a successful `require` prove nothing about a
  UI.

## Running and testing

`direnv allow` (or `nix develop`) gets Ruby, GTK4, Libadwaita, librsvg and the
bundled gems from `gemset.nix`. Regenerate that file with `bundix -l` whenever
`Gemfile.lock` moves; nix only sees git-tracked files, so `git add` it first.

- `bin/eyedropper-rb` runs the app.
- `rake` runs the tests and rubocop. **`rake` and `rake schema` do not
  currently run in this project's own `nix develop` shell.** `pkgs.bundlerEnv`
  (the thing that gives this shell its `rake` binstub) copies only `Gemfile`
  and `Gemfile.lock` into a throwaway store path and evaluates the Gemfile
  there — it never copies `eyedropper-rb.gemspec`, so the Gemfile's `gemspec`
  directive fails with `Bundler::Dsl::DSLError: There are no gemspecs at
  .../-gemfile-and-lockfile`. The dev shell's `rake` function in `flake.nix`
  works around that by re-running `Bundler.setup` against the real checkout's
  `Gemfile` with the unwrapped interpreter. That gets past the DSLError, but
  `gemfiles/modular/style.gemfile` declares `rubocop-packaging` from
  `github: "pboling/rubocop-packaging"`, and that gem is in neither
  `Gemfile.lock` nor `gemset.nix` — resolving it needs a network git checkout,
  and this sandbox has none, so `Bundler.setup` still fails
  (`Bundler::GitError: ... is not yet checked out`). Until the lockfile and
  `gemset.nix` carry that gem (or it is dropped from the style gemfile), use
  the commands below directly instead of `rake`/`rake schema`/`rake check`:
  - `test/test_color.rb` needs no display: the color conversions and every
    parser, checked against upstream's own test vectors. Run with
    `xvfb-run -a ruby test/test_color.rb`.
  - `test/drive_window.rb` builds the real window headlessly, drives every page,
    dialog and control, and writes screenshots to `tmp/shots`. Run with
    `xvfb-run -a ruby test/drive_window.rb`.
  - `test/drive_search_provider.rb` serves the GNOME Shell search provider on the
    real session bus and calls it back as a client. Run with
    `xvfb-run -a ruby test/drive_search_provider.rb`.
  - `test/drive_portals.rb` exercises the color picker and global-shortcuts
    portal clients against the session's real portal. Run with
    `xvfb-run -a ruby test/drive_portals.rb`.
  - The schema has to be compiled by hand too:
    `glib-compile-schemas --targetdir=build/share/glib-2.0/schemas data/`
    (mkdir -p that target dir first), with `build/share` already on
    `XDG_DATA_DIRS` per the shell's `shellHook`.
  - `rake check` (rubocop) is unaffected by the git-gem issue above but is
    still routed through the broken binstub; run `bundle exec rubocop` with
    `BUNDLE_GEMFILE="$PWD/Gemfile"` directly, or rubocop per-file, instead.
- `nix build` produces the installable app.

`PORTING.md` records how this port maps onto the Rust original and the
ruby-gnome, GTK and GDBus defects found while writing it — read it before
changing the color conversions, the parsers, anything under `dbus.rb`, or the
screenshot harness. In particular: no D-Bus signal carrying `a{sv}` can be
received in-process, which is why portal replies are read through
`gdbus monitor`.

## Style

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies, and fixed
multi-line argument/hash layout. Run `bundle exec rubocop` before committing.
