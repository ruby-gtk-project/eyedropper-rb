{
  description = "eyedropper-rb — a Ruby GTK4 port of Eyedropper";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ruby = pkgs.ruby_3_3;

        # Shared libraries every ruby-gnome extension links against.
        gtkStack = with pkgs; [
          glib
          gobject-introspection
          cairo
          pango
          gdk-pixbuf
          graphene
          atk
          gtk4
          libadwaita
          harfbuzz
          # The app icons are SVGs, and GTK loads icons through gdk-pixbuf —
          # without librsvg's loader it resolves them and then paints nothing.
          librsvg
        ]
        # The Ruby `pkg-config` gem resolves `Requires.private` transitively and
        # hard-fails if any .pc in the chain is missing, so gtk4's whole private
        # closure has to be on PKG_CONFIG_PATH, not just its public deps.
        ++ (with pkgs; [
          fontconfig
          freetype
          libepoxy
          libpng
          libxkbcommon
          pcre2
          util-linux
          wayland
          zlib
          fribidi
          libdatrie
          libthai
          libselinux
          libsepol
          expat
          brotli
          bzip2
          graphite2
          icu
          libffi
          libxml2
          lerc
          libdeflate
          xz
          zstd
        ])
        ++ (with pkgs; [
          libx11
          libxau
          libxcursor
          libxdmcp
          libxext
          libxfixes
          libxi
          libxinerama
          libxrandr
          libxrender
          libxcb
          xorgproto
        ]);

        # ruby-gnome gems build C extensions with extconf.rb + the pkg-config
        # gem; nixpkgs only ships gemConfig entries for the GTK3-era subset, so
        # the GTK4 gems get their build inputs declared here.
        rubyGnomeGem = attrs: {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = gtkStack;
        };

        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = rubyGnomeGem;
          gsk4 = rubyGnomeGem;
          gtk4 = rubyGnomeGem;
          graphene1 = rubyGnomeGem;
          adwaita = rubyGnomeGem;
        };

        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs — hence the explicit
        # `.out`. at-spi2-core is here for the Atk typelib.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) (gtkStack ++ [ pkgs.at-spi2-core ]));

        gems = pkgs.bundlerEnv {
          name = "eyedropper-rb-gems";
          inherit ruby gemConfig;
          gemdir = ./.;
        };
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "eyedropper-rb";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];
          buildInputs = [ gems ] ++ gtkStack;

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/eyedropper-rb $out/share/applications \
              $out/share/dbus-1/services
            cp -r lib data $out/share/eyedropper-rb/
            # bin/ has to sit next to lib/ for the launcher's require_relative.
            install -Dm755 bin/eyedropper-rb $out/share/eyedropper-rb/bin/eyedropper-rb

            cp data/com.github.finefindus.eyedropper.Rb.desktop $out/share/applications/

            # GNOME Shell reads the search provider's ini to learn the bus name
            # and object path; the two .service files let D-Bus start the app on
            # demand when the shell searches while it is not running.
            install -Dm644 data/com.github.finefindus.eyedropper.Rb.search-provider.ini \
              -t $out/share/gnome-shell/search-providers
            for service in data/*.service; do
              sed "s|@BINDIR@|$out/bin|g" "$service" \
                > "$out/share/dbus-1/services/$(basename "$service")"
            done
            install -Dm644 data/com.github.finefindus.eyedropper.Rb.metainfo.xml \
              -t $out/share/metainfo
            install -Dm644 data/icons/hicolor/scalable/apps/com.github.finefindus.eyedropper.Rb.svg \
              -t $out/share/icons/hicolor/scalable/apps
            install -Dm644 data/icons/hicolor/symbolic/apps/*-symbolic.svg \
              -t $out/share/icons/hicolor/symbolic/apps

            # The GSettings schema has to be compiled and on XDG_DATA_DIRS
            # before Gio::Settings will look it up.
            install -Dm644 data/com.github.finefindus.eyedropper.Rb.gschema.xml \
              -t $out/share/glib-2.0/schemas
            ${pkgs.glib.dev}/bin/glib-compile-schemas $out/share/glib-2.0/schemas

            # -rbundler/setup puts the bundled gems on the load path, and
            # GI_TYPELIB_PATH keeps GObject-Introspection from re-registering
            # types the cairo gem's C extension has already registered.
            makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/eyedropper-rb \
              --add-flags "-rbundler/setup" \
              --add-flags "$out/share/eyedropper-rb/bin/eyedropper-rb" \
              --set GI_TYPELIB_PATH "${typelibPath}" \
              --prefix PATH : "${pkgs.glib.bin}/bin" \
              --set GDK_PIXBUF_MODULE_FILE "${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" \
              --prefix XDG_DATA_DIRS : "$out/share" \
              --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share"

            runHook postInstall
          '';
        };

        apps.default = flake-utils.lib.mkApp { drv = self.packages.${system}.default; };

        devShells.default = pkgs.mkShell {
          name = "eyedropper-rb-devshell";

          packages = [
            gems
            gems.wrappedRuby
            pkgs.bundler
            pkgs.bundix
            pkgs.pkg-config
            pkgs.glib
            pkgs.adwaita-icon-theme
            pkgs.gsettings-desktop-schemas
            # The spec runner. The gems the full development bundle needs are
            # not in this shell — it carries the app's runtime closure — but
            # the suite is plain RSpec, so this is enough to run it.
            pkgs.rubyPackages_3_3.rspec
            # `exe/eyedropper-rb` has to be runnable from the shell, and this
            # machine may well have no display server at all, so the shell
            # carries one it can start itself: `xvfb-run ruby bin/eyedropper-rb`
            # both launches the app and is how the test/drive_*.rb scripts run.
            pkgs.xvfb-run
            # The drive scripts type into the running app to prove key capture
            # is wired to the window; see tally-rb's flake.nix for why this has
            # to come from the X server rather than a forged Gdk key event.
            pkgs.xdotool
          ] ++ gtkStack;

          # Icons, GSettings schemas and the GTK portal all resolve through
          # XDG_DATA_DIRS; without these the window opens with blank icons and
          # Gio::Settings aborts on the app's own schema. RUBYLIB is what makes
          # `ruby bin/eyedropper-rb` work from a checkout: the launcher's
          # `require "eyedropper"` otherwise only resolves against an installed
          # gem.
          shellHook = ''
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
            # `gdbus` reads the portal signals the bindings cannot; see PORTING.md.
            export PATH="${pkgs.glib.bin}/bin:$PATH"
            export GDK_PIXBUF_MODULE_FILE="${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
            export XDG_DATA_DIRS="$PWD/build/share:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}:${pkgs.adwaita-icon-theme}/share:$XDG_DATA_DIRS"
            unset BUNDLE_GEMFILE BUNDLE_FROZEN BUNDLE_PATH
            echo "eyedropper-rb devshell — ruby $(ruby -e 'print RUBY_VERSION')"
            echo "  rake schema        compile the GSettings schema into build/share"
            echo "  xvfb-run ruby ./bin/eyedropper-rb   run the app"
            echo "  xvfb-run ruby test/drive_window.rb  drive the main window"
            echo "  ruby -e 'require \"rspec/core\"; exit RSpec::Core::Runner.run([\"--format\", \"progress\", \"spec\"])'"
            echo "  rake               test + lint"
          '';
        };
      });
}
