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
rake            # unit tests + rubocop
rake drive      # build the real window headlessly and drive it
```

- `test/test_color.rb` needs no display. It checks the color conversions and
  every parser against upstream's own test vectors, plus a round trip through
  all fourteen notations.
- `test/drive_window.rb` builds the real window with no display server, walks
  every page, dialog and control, and writes screenshots to `tmp/shots`.

`PORTING.md` records how this port maps onto the Rust original, what was left
out and why, and the upstream bugs it declines to reproduce.

## Style

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies, and fixed
multi-line argument and hash layout. Run `rubocop` before committing.

## License

GPL-3.0-or-later, as upstream.
