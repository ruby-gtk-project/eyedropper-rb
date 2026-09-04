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
- `rake` runs the tests and rubocop.
  - `rake schema` compiles `data/com.github.finefindus.eyedropper.Rb.gschema.xml`
    into `build/`, which the dev shell puts on `XDG_DATA_DIRS`. Nothing that
    touches settings works until this has run; `rake test` depends on it.
  - `test/test_color.rb` needs no display: the color conversions and every
    parser, checked against upstream's own test vectors.
  - `test/drive_window.rb` builds the real window headlessly, drives every page,
    dialog and control, and writes screenshots to `tmp/shots`.
  - `test/drive_search_provider.rb` serves the GNOME Shell search provider on the
    real session bus and calls it back as a client.
  - `test/drive_portals.rb` exercises the color picker and global-shortcuts
    portal clients against the session's real portal.
  - `rake check` runs all of them plus rubocop.
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
