# frozen_string_literal: true

module Eyedropper
  # Picks a color from anywhere on screen through the XDG desktop portal.
  #
  # Upstream calls this through `ashpd`. There is no Ruby equivalent, so this
  # talks to `org.freedesktop.portal.Screenshot.PickColor` over the session bus
  # directly. The portal answers asynchronously: the method call returns a
  # request object path, and the result arrives later as a `Response` signal on
  # that path.
  module Picker
    BUS_NAME = "org.freedesktop.portal.Desktop"
    OBJECT_PATH = "/org/freedesktop/portal/desktop"
    SCREENSHOT_INTERFACE = "org.freedesktop.portal.Screenshot"
    REQUEST_INTERFACE = "org.freedesktop.portal.Request"

    # Portal response codes.
    SUCCESS = 0
    CANCELLED = 1

    class << self
      # True when the desktop is known not to service a pick request, so the
      # window can show its error page without making the user try first.
      #
      # COSMIC's portal exports PickColor and then always fails, which upstream
      # special-cases by name for the same reason.
      def available?
        ENV.fetch("XDG_CURRENT_DESKTOP", "").downcase != "cosmic"
      end

      # Yields a Color on success, nil when the user cancelled, and raises
      # nothing — a broken portal is reported through `on_error`.
      def pick(on_success:, on_cancel:, on_error:)
        connection = Gio::DBus.session
        token = "eyedropper#{rand(1 << 32)}"
        handle = request_path(connection, token)

        subscribe(connection, handle) do |response, results|
          case response
          when SUCCESS then on_success.call(color_from(results))
          when CANCELLED then on_cancel.call
          else on_error.call("The color picker returned no color")
          end
        end

        call_pick_color(connection, token, on_error)
      rescue StandardError => error
        on_error.call(error.message)
      end

        private

          def call_pick_color(connection, token, on_error)
            connection.call(
              BUS_NAME,
              OBJECT_PATH,
              SCREENSHOT_INTERFACE,
              "PickColor",
              GLib::Variant.new(["", { "handle_token" => GLib::Variant.new(token) }], "(sa{sv})"),
              nil,
              :none,
              -1,
            ) do |_source, result|
              begin
                connection.call_finish(result)
              rescue StandardError => error
                on_error.call(error.message)
              end
            end
          end

          # The portal derives the request's object path from the caller's
          # unique bus name and the token, so it can be subscribed to before the
          # method call is made and no response can be missed.
          def request_path(connection, token)
            sender = connection.unique_name.sub(/\A:/, "").tr(".", "_")
            "#{OBJECT_PATH}/request/#{sender}/#{token}"
          end

          def subscribe(connection, handle)
            subscription = nil
            subscription = connection.signal_subscribe(
              BUS_NAME,
              REQUEST_INTERFACE,
              "Response",
              handle,
              nil,
              :none,
            ) do |_conn, _sender, _path, _iface, _signal, parameters|
              connection.signal_unsubscribe(subscription)
              values = parameters.value
              yield(values[0], values[1])
            end
          end

          # The portal reports the color as three doubles in 0..1, without alpha.
          def color_from(results)
            components = results["color"]
            if components.nil?
              nil
            else
              Color.new(
                components[0],
                components[1],
                components[2],
                1.0,
              )
            end
          end
    end
  end
end
