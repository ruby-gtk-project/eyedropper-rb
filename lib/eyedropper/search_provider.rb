# frozen_string_literal: true

module Eyedropper
  # The GNOME Shell search provider: type a color into the shell's search and
  # get it back as a result that opens the app on that color.
  #
  # Upstream gets this from the `search-provider` crate, which implements
  # `org.gnome.Shell.SearchProvider2` for it. Here the interface is served
  # directly through `Eyedropper::DBus`.
  #
  # Result identifiers are the color's own hex string, so no state has to be
  # kept between the search and the activation.
  class SearchProvider
    INTERFACE = "org.gnome.Shell.SearchProvider2"

    XML = <<~XML
      <node>
        <interface name="org.gnome.Shell.SearchProvider2">
          <method name="GetInitialResultSet">
            <arg type="as" name="terms" direction="in"/>
            <arg type="as" name="results" direction="out"/>
          </method>
          <method name="GetSubsearchResultSet">
            <arg type="as" name="previous_results" direction="in"/>
            <arg type="as" name="terms" direction="in"/>
            <arg type="as" name="results" direction="out"/>
          </method>
          <method name="GetResultMetas">
            <arg type="as" name="identifiers" direction="in"/>
            <arg type="aa{sv}" name="metas" direction="out"/>
          </method>
          <method name="ActivateResult">
            <arg type="s" name="identifier" direction="in"/>
            <arg type="as" name="terms" direction="in"/>
            <arg type="u" name="timestamp" direction="in"/>
          </method>
          <method name="LaunchSearch">
            <arg type="as" name="terms" direction="in"/>
            <arg type="u" name="timestamp" direction="in"/>
          </method>
        </interface>
      </node>
    XML

    # A swatch is drawn once per color and cached, because the shell asks for
    # metas every time the search is re-run.
    SWATCH_SIZE = 48

    def initialize(on_activate:)
      @on_activate = on_activate
    end

    def bus_name = "#{Config::APP_ID}.SearchProvider"

    def object_path = "#{Config::RESOURCE_PATH}/SearchProvider"

    # Serves the interface and claims the well-known name. Returns false when
    # the bus is unavailable, which must not stop the app from starting.
    def start
      @registration = DBus.register(object_path, XML, INTERFACE) do |method, parameters, invocation|
        dispatch(method, parameters, invocation)
      end

      DBus.request_name(bus_name)
    rescue StandardError => error
      warn("eyedropper-rb: search provider unavailable: #{error.message}")
      false
    end

    def stop
      DBus.unregister(@registration)
      DBus.release_name(bus_name)
      @registration = nil
    end

    # The `aa{sv}` reply to GetResultMetas, in GVariant text form. Public
    # because a Ruby client cannot read a dictionary back off the bus — the
    # bindings raise on `{sv}` — so this is the only way to check what the
    # shell would receive.
    def metas_text(identifiers)
      metas = Array(identifiers).map { |identifier| meta_text(identifier) }

      if metas.empty?
        "(@aa{sv} [],)"
      else
        "([#{metas.join(', ')}],)"
      end
    end

    # The terms that name a color, as hex strings. Anything the app can parse
    # counts, so `blue`, `#2e3440` and `rgb(1,2,3)` all resolve.
    def results_for(terms)
      sources = Settings.instance.name_sources

      Array(terms)
        .filter_map { |term| parse_term(term, sources) }
        .map(&:hex)
        .uniq
    end

    # One meta entry in GVariant text form.
    def meta_text(identifier)
      color = Color.from_hex(identifier)
      name = describe(color, identifier)

      entries = [
        "'id': <#{DBus.quote(identifier)}>",
        "'name': <#{DBus.quote(name)}>",
        "'description': <#{DBus.quote(identifier)}>",
      ]

      swatch = swatch_path(color)
      unless swatch.nil?
        entries << "'gicon': <#{DBus.quote(swatch)}>"
      end

      "{#{entries.join(', ')}}"
    end

      private

        def dispatch(method, parameters, invocation)
          case method
          when "GetInitialResultSet"
            invocation.return_value(results_variant(terms_of(parameters, 0)))
          when "GetSubsearchResultSet"
            # The shell passes the previous results first; the terms are what
            # matter, and re-running the parse is cheaper than filtering.
            invocation.return_value(results_variant(terms_of(parameters, 1)))
          when "GetResultMetas"
            invocation.return_value(metas_variant(terms_of(parameters, 0)))
          when "ActivateResult"
            @on_activate.call(Array(parameters)[0])
            invocation.return_value(nil)
          when "LaunchSearch"
            @on_activate.call(terms_of(parameters, 0).first)
            invocation.return_value(nil)
          else
            invocation.return_value(nil)
          end
        rescue StandardError => error
          warn("eyedropper-rb: search provider #{method} failed: #{error.message}")
          # A reply of the wrong type is dropped on the floor and the shell
          # waits out its timeout, so failures still answer in the right shape.
          invocation.return_value(empty_reply(method))
        end

        # An empty but correctly typed reply for a method that failed.
        def empty_reply(method)
          case method
          when "GetInitialResultSet", "GetSubsearchResultSet"
            results_variant([])
          when "GetResultMetas"
            metas_variant([])
          end
        end

        # Arguments arrive already unwrapped, as a plain Ruby Array.
        def terms_of(parameters, index) = Array(Array(parameters)[index])

        def parse_term(term, sources)
          Parser.hex(term, AlphaPosition::END_POSITION) ||
            Notation::ALL.filter_map { |notation| notation.parse(term, sources) }.first
        end

        def results_variant(terms)
          DBus.variant("(#{DBus.string_array(results_for(terms))},)")
        end

        # Each meta carries the hex code as both id and name, and a swatch drawn
        # in the color itself as the icon.
        def metas_variant(identifiers) = DBus.variant(metas_text(identifiers))

        def describe(color, identifier)
          if color.nil?
            identifier
          else
            ColorNames.name(color, Settings.instance.name_sources) ||
              Notation::HEX.format(
                color,
                alpha_position: AlphaPosition::NONE,
                rgb_decimal:    false,
                precision:      2,
                name_sources:   0,
              )
          end
        end

        # A GIcon serialises to a plain path for a file icon, so the swatch is
        # written to the cache directory and named by its own color.
        def swatch_path(color)
          if color.nil?
            nil
          else
            File.join(cache_dir, "#{color.hex.delete('#')}.svg").tap do |path|
              unless File.exist?(path)
                File.write(path, swatch_svg(color))
              end
            end
          end
        rescue StandardError
          nil
        end

        def cache_dir
          @cache_dir ||= File.join(
            ENV.fetch("XDG_CACHE_HOME", File.join(Dir.home, ".cache")),
            "eyedropper-rb",
            "swatches",
          ).tap { |path| FileUtils.mkdir_p(path) }
        end

        def swatch_svg(color)
          radius = SWATCH_SIZE / 2
          <<~SVG
            <svg xmlns="http://www.w3.org/2000/svg" width="#{SWATCH_SIZE}" height="#{SWATCH_SIZE}">
              <circle cx="#{radius}" cy="#{radius}" r="#{radius - 1}"
                      fill="#{Notation::HEX.format(
                        color,
                        alpha_position: AlphaPosition::NONE,
                        rgb_decimal:    false,
                        precision:      2,
                        name_sources:   0,
                      )}"/>
            </svg>
          SVG
        end
  end
end
