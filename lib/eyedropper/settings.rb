# frozen_string_literal: true

module Eyedropper
  # Typed access to the app's GSettings schema.
  #
  # Everything that formats a color needs the same four preferences, and they
  # are read on every keystroke in every visible format row, so they go through
  # one object rather than a fresh `Gio::Settings` per widget.
  #
  # When the schema is not installed — a plain `ruby -Ilib` session, or the test
  # suite — `instance` falls back to an in-memory copy of the schema defaults
  # instead of aborting. GLib's behaviour on a missing schema is to abort the
  # process, which would make the color code untestable without a `make install`.
  class Settings
    DEFAULTS = {
      "visible-formats"   => %w[name hex rgb hsl hsv cmyk],
      "format-order"      => Notation::DEFAULT_ORDER,
      "alpha-position"    => AlphaPosition::NONE,
      "rgb-notation"      => 0,
      "precision-digits"  => 2,
      "name-sources-flag" => ColorNames::ALL.sum,
    }.freeze

    class << self
      def instance = @instance ||= new(gio_settings)

      # Test seam: swap in a Settings built over an explicit backing store.
      attr_writer :instance

      def reset! = @instance = nil

        private

          def gio_settings
            if schema_installed?
              Gio::Settings.new(Config::APP_ID)
            end
          end

          def schema_installed?
            source = Gio::SettingsSchemaSource.default
            !source.nil? && !source.lookup(Config::APP_ID, true).nil?
          rescue StandardError
            false
          end
    end

    def initialize(backend)
      @backend = backend
      @fallback = DEFAULTS.transform_values(&:dup)
    end

    # The live Gio::Settings, or nil when running against the fallback. Widgets
    # that want a two-way GSettings binding need the real thing.
    attr_reader :backend

    def alpha_position = AlphaPosition.from_setting(read("alpha-position"))

    def rgb_decimal? = read("rgb-notation") == 1

    def precision = read("precision-digits").to_i.clamp(0, 15)

    def name_sources = read("name-sources-flag").to_i

    def visible_formats = Array(read("visible-formats"))

    def format_order = Array(read("format-order"))

    def format_order=(identifiers)
      write("format-order", identifiers)
    end

    def visible_formats=(identifiers)
      write("visible-formats", identifiers)
    end

    def name_sources=(flags)
      write("name-sources-flag", flags)
    end

    # For the preference rows that write a key this class does not otherwise
    # expose as a typed accessor.
    def write_key(key, value)
      write(key, value)
    end

    def reset_format_order
      if @backend.nil?
        @fallback["format-order"] = DEFAULTS["format-order"].dup
      else
        @backend.reset("format-order")
      end
    end

    def default_format_order = DEFAULTS["format-order"]

    # Runs `block` whenever `key` changes, and once immediately so callers do
    # not have to duplicate the initial read.
    def on_change(key, &block)
      unless @backend.nil?
        @backend.signal_connect("changed::#{key}") { block.call }
      end
      block.call
    end

      private

        # `get_value` hands back a plain Ruby value for some types and a
        # GLib::Variant for others depending on the binding version, so unwrap
        # only when there is something to unwrap.
        def read(key)
          if @backend.nil?
            @fallback[key]
          else
            unwrap(@backend.get_value(key))
          end
        end

        def unwrap(value)
          if value.respond_to?(:value)
            value.value
          else
            value
          end
        end

        # Gio::Settings#set_value already wraps the value using the schema's own
        # type, so it takes the plain Ruby value — handing it a Variant makes it
        # wrap a Variant in a Variant and recurse until the stack gives out.
        def write(key, value)
          if @backend.nil?
            @fallback[key] = value
          else
            @backend.set_value(key, value)
          end
        end
  end
end
