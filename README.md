# Eyedropper — Ruby port

A Ruby GTK4 / Libadwaita port of [Eyedropper](https://github.com/finefindus/eyedropper)
by FineFindus. Pick a color from anywhere on screen, or type one in, and read it
back in fourteen notations.

The upstream Rust implementation lives on this fork's `main` branch; this `ruby`
branch is the port.

## What it does

- **Pick a color** from anywhere on screen through the XDG desktop portal, or
  enter one in any supported notation.
- **Read it in fourteen notations** — Name, Hex, RGB, HSL, HSV, CMYK, XYZ,
  CIELAB, HWB, CIELCh/HCL, LMS, Hunter Lab, Oklab, Oklch. Every row is
  editable: type a color in that notation and the whole window follows.
- **Edit in HSL** in a bottom sheet, with hue, saturation and lightness sliders.
- **Keep a history** of picked colors; click one to return to it, right-click to
  remove it, clear the lot with one undo.
- **Name colors** from four palettes — basic web colors, X11/SVG, the GNOME
  palette, and the xkcd color survey — individually switchable.
- **Choose which formats show and in what order**, by drag, by menu, or by
  keyboard.
- **Search for colors from the GNOME Shell overview** — type `blue` or
  `#2e3440` into the shell and get a swatch that opens the app on that color.
- **Pick a color with Ctrl+P from anywhere**, through the global-shortcuts
  portal, without focusing the app first.

## Running it

`direnv allow` (or `nix develop`) gets Ruby, GTK4, Libadwaita, librsvg and the
bundled gems from `gemset.nix`. Regenerate that file with `bundix -l` whenever
`Gemfile.lock` moves; nix only sees git-tracked files, so `git add` it first.

```sh
nix develop            # or: direnv allow
rake schema            # compile the GSettings schema into build/
./bin/eyedropper-rb
```

`nix build` produces the installable app, with the schema compiled, the icons
and desktop entry installed, and the gems wrapped.

## Testing

```sh
rake                  # unit tests + rubocop
rake drive            # build the real window headlessly and drive it
rake drive_search     # serve the search provider and call it back over D-Bus
rake drive_portals    # exercise the portal clients against the real portal
rake check            # all of the above
```

- `test/test_color.rb` needs no display. It checks the color conversions and
  every parser against upstream's own test vectors, plus a round trip through
  all fourteen notations.
- `test/drive_window.rb` builds the real window with no display server, walks
  every page, dialog and control, and writes screenshots to `tmp/shots`.
- `test/drive_search_provider.rb` serves the search provider on the real session
  bus and calls every one of its methods back as a client, the way GNOME Shell
  would.
- `test/drive_portals.rb` checks that every argument sent to the portals is
  well-formed GVariant of the declared type, that replies are read back
  correctly, and — where a portal is running — that a real call reaches it.

`PORTING.md` records how this port maps onto the Rust original, the D-Bus
binding limits that shape `lib/eyedropper/dbus.rb`, and the upstream bugs it
declines to reproduce.

## Style

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies, and fixed
multi-line argument and hash layout. Run `rubocop` before committing.

## License

GPL-3.0-or-later, as upstream.
