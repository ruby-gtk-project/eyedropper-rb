# frozen_string_literal: true

module Eyedropper
  # The small amount of D-Bus plumbing the search provider and the portals need,
  # kept in one place because the Ruby bindings constrain how it has to be done.
  #
  # Three constraints shape everything here:
  #
  # - `GLib::Variant.new(value, type)` refuses any tuple or `a{sv}`
  #   ("TODO: Ruby -> GVariant"). `GLib::Variant.parse` accepts the GVariant
  #   *text* format and builds anything, so every outgoing argument is written
  #   as text.
  # - `GLib::Variant` exposes only `type`, `value`, `to_s` and `inspect` — no
  #   child access — and `value` raises on any dictionary ("TODO: GVariant({sv})
  #   -> Ruby"). So incoming `a{sv}` is read back out of `to_s`, which is the
  #   same well-defined text format.
  # - `Gio.bus_own_name` raises `FrozenError` in the bindings whatever it is
  #   passed, so a well-known name is claimed by calling `RequestName` on the
  #   bus directly, which is what it would have done anyway.
  module DBus
    FREEDESKTOP = "org.freedesktop.DBus"
    FREEDESKTOP_PATH = "/org/freedesktop/DBus"

    # RequestName reply codes.
    PRIMARY_OWNER = 1
    ALREADY_OWNER = 4

    class << self
      def session = @session ||= Gio.bus_get_sync(:session)

      # The portals derive a request's object path from the caller's unique bus
      # name and a token, so it can be subscribed to before the method call is
      # made and no response can be missed.
      def request_path(connection, token)
        sender = connection.unique_name.sub(/\A:/, "").tr(".", "_")
        "/org/freedesktop/portal/desktop/request/#{sender}/#{token}"
      end

      # True when this process now owns `name`.
      def request_name(name)
        reply = session.call_sync(
          FREEDESKTOP,
          FREEDESKTOP_PATH,
          FREEDESKTOP,
          "RequestName",
          variant("(#{quote(name)}, uint32 0)"),
          nil,
          :none,
          -1,
        )

        # `call_sync` hands back the unwrapped Ruby value, not the variant.
        [PRIMARY_OWNER, ALREADY_OWNER].include?(Array(reply).first)
      end

      def release_name(name)
        session.call_sync(
          FREEDESKTOP,
          FREEDESKTOP_PATH,
          FREEDESKTOP,
          "ReleaseName",
          variant("(#{quote(name)},)"),
          nil,
          :none,
          -1,
        )
      rescue StandardError
        nil
      end

      # Builds a variant from GVariant text format.
      def variant(text) = GLib::Variant.parse(text)

      # Renders a Ruby string as a GVariant string literal. GVariant text
      # accepts single quotes, which keeps the result free of backslashes when
      # it is built inside a double-quoted Ruby string.
      def quote(string)
        escaped = string.to_s.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'")
        "'#{escaped}'"
      end

      # GVariant text cannot infer the element type of an empty list, so an
      # empty array has to name its type explicitly.
      def string_array(values)
        if values.empty?
          "@as []"
        else
          "[#{values.map { |value| quote(value) }.join(', ')}]"
        end
      end

      # Reads one key out of an `a{sv}` that arrived inside `variant`, returning
      # its value still in text form. `GLib::Variant#value` cannot walk a
      # dictionary, so this reads the text rendering instead.
      #
      # Values are `<...>` variants, and the content may itself contain brackets
      # and quotes, so the closing `>` is found by scanning rather than by regex.
      def lookup(variant, key)
        text = text_of(variant)
        marker = "'#{key}': <"
        start = text.index(marker)

        if start.nil?
          nil
        else
          extract_variant_body(text, start + marker.length)
        end
      end

      # Signal and reply payloads arrive either as a GLib::Variant or already
      # unwrapped, depending on the call; `to_s` is the one thing both answer
      # in the GVariant text format the readers here expect.
      def text_of(payload)
        if payload.is_a?(GLib::Variant)
          payload.to_s
        else
          payload.to_s
        end
      end

      # The leading `uint32 N` of a portal Response body.
      def response_code(body) = body.to_s[/\A\s*(?:uint32\s+)?(\d+)/, 1].to_i

      # Three doubles as written by the portals, e.g. `(0.5, 0.25, 0.125)`.
      def doubles(text)
        text.to_s.scan(/-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?/).map(&:to_f)
      end

      # Watches for one D-Bus signal and yields its body in GVariant text form.
      #
      # Signals are the one thing that cannot be done in-process: both
      # `signal_subscribe` and `Gio::DBusProxy`'s `g-signal` convert the
      # payload to Ruby before handing it over, and that conversion raises on
      # `a{sv}` — which is what every portal Response carries. The exception is
      # thrown inside the binding's own callback trampoline, so it cannot be
      # rescued by the callback and takes the process down with it.
      #
      # `gdbus monitor` is part of glib, which is already a hard dependency, and
      # it prints the same GVariant text format read everywhere else here.
      #
      # `block` returns true when it is done, which stops the monitor. Returns a
      # handle with `#stop` for watches that never finish on their own.
      def monitor(sender, object_path, member, &block)
        reader = IO.popen(
          ["gdbus", "monitor", "--session", "--dest", sender, "--object-path", object_path],
          err: %i[child out],
        )

        Monitor.new(reader).tap { |watch| watch.each_signal(member, &block) }
      rescue StandardError => error
        warn("eyedropper-rb: cannot watch #{object_path}: #{error.message}")
        nil
      end

      # Registers `handler` for every method call on `interface_name` at `path`.
      # The handler receives (method_name, parameters, invocation).
      #
      # `parameters` arrives as a plain Ruby Array of already-unwrapped
      # arguments, not as a GLib::Variant — the same asymmetry as `call_sync`,
      # which also hands back unwrapped values.
      def register(path, interface_xml, interface_name, &handler)
        info = Gio::DBusNodeInfo.new(interface_xml).lookup_interface(interface_name)

        session.register_object_with_closures2(
          path,
          info,
          lambda { |_connection, _sender, _path, _interface, method, parameters, invocation|
            handler.call(method, parameters, invocation)
          },
          nil,
          nil,
        )
      end

      def unregister(id)
        unless id.nil?
          session.unregister_object(id)
        end
      rescue StandardError
        nil
      end

        private

          # Walks from `index` to the `>` that closes a `<...>` variant, ignoring
          # anything inside string literals.
          def extract_variant_body(text, index)
            depth = 0
            in_string = false
            cursor = index

            while cursor < text.length
              character = text[cursor]

              if in_string
                if character == "'"
                  in_string = false
                end
                if character == "\\"
                  cursor += 1
                end
              else
                case character
                when "'" then in_string = true
                when "<" then depth += 1
                when ">"
                  if depth.zero?
                    break
                  end

                  depth -= 1
                end
              end

              cursor += 1
            end

            text[index...cursor]
          end
    end

    # Reads `gdbus monitor` output on a background thread and delivers whole
    # signal lines back on the main loop, so callers stay single-threaded.
    class Monitor
      # A signal line looks like:
      #   /path: org.freedesktop.portal.Request.Response (uint32 0, {...})
      SIGNAL = /:\s+([\w.]+)\.(\w+)\s+\((.*)\)\s*\z/

      def initialize(reader)
        @reader = reader
        @stopped = false
      end

      def each_signal(member, &block)
        Thread.new do
          @reader.each_line do |line|
            deliver(line, member, &block)
          end
        rescue StandardError
          nil
        end
      end

      def stop
        unless @stopped
          @stopped = true

          begin
            Process.kill("TERM", @reader.pid)
          rescue StandardError
            nil
          end

          begin
            @reader.close
          rescue StandardError
            nil
          end
        end
      end

        private

          # Hops back onto the main loop before running the caller's block, so
          # everything it touches — widgets, settings — is on the right thread.
          def deliver(line, member)
            match = line.match(SIGNAL)

            if !match.nil? && match[2] == member && !@stopped
              body = match[3]
              GLib::Idle.add do
                if yield(body)
                  stop
                end
                false
              end
            end
          end
    end
  end
end
