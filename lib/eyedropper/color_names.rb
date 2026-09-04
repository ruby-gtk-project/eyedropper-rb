# frozen_string_literal: true

module Eyedropper
  # The four named-color palettes, looked up in both directions.
  #
  # Upstream bakes these into the binary with a `build.rs` codegen step and a
  # perfect-hash crate. Ruby can just read the same four asset files once, on
  # first use, and hold two hashes per palette.
  module ColorNames
    # Bit values of the `name-sources-flag` setting. They match upstream's
    # ColorNameSources flags, so a settings value carries over unchanged.
    HTML = 1
    SVG = 2
    GNOME = 4
    XKCD = 8

    ALL = [HTML, SVG, GNOME, XKCD].freeze

    SOURCES = {
      HTML  => "basic",
      SVG   => "svg",
      GNOME => "gnome",
      XKCD  => "xkcd",
    }.freeze

    # Colors carrying two spellings; the second listing is dropped from the
    # hex-to-name direction so a lookup is deterministic.
    DUPLICATES = %w[
      aqua
      darkgray
      darkslategray
      dimgray
      gray
      olive
      lightgray
      lightslategray
      fuchsia
      slategray
    ].freeze

    class << self
      # The name of a color, searching each enabled palette in flag order.
      def name(color, sources)
        hex = color.hex.downcase
        enabled(sources).filter_map { |flag| palette(flag)[:by_hex][hex] }.first
      end

      # The color for a name, searching each enabled palette in flag order.
      def color(name, sources)
        key = name.to_s.strip.downcase
        enabled(sources)
          .filter_map { |flag| palette(flag)[:by_name][key] }
          .filter_map { |hex| Color.from_hex(hex) }
          .first
      end

        private

          def enabled(sources) = ALL.select { |flag| sources.to_i.anybits?(flag) }

          def palette(flag)
            @palettes ||= {}
            @palettes[flag] ||= load_palette(SOURCES.fetch(flag))
          end

          def load_palette(basename)
            by_name = {}
            by_hex = {}

            each_entry(basename) do |name, hex|
              by_name[name] = hex
              unless DUPLICATES.include?(name) || by_hex.key?(hex)
                by_hex[hex] = name
              end
            end

            { by_name: by_name.freeze, by_hex: by_hex.freeze }
          end

          def each_entry(basename)
            path = File.join(Eyedropper::DATA_DIR, "assets", "#{basename}.txt")
            File.foreach(path) do |line|
              stripped = line.strip
              name, hex = stripped.split(",", 2)

              if !stripped.empty? && !stripped.start_with?("#") && !hex.nil?
                # The assets store `#RRGGBB`; every color in them is opaque, and
                # Color#hex always writes the alpha pair, so the key gains `ff`.
                yield(name.strip.downcase, "#{hex.strip.downcase}ff")
              end
            end
          end
    end
  end
end
