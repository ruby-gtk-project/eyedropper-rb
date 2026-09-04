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
      # True unless the desktop is known not to service a pick request, so the
      # window can show its error page without making the user try first.
      #
      # COSMIC's portal exports PickColor and then always fails, which upstream
      # special-cases by name for the same reason.
      def available?
        ENV.fetch("XDG_CURRENT_DESKTOP", "").downcase != "cosmic"
      end

      # Calls back with a Color on success, `on_cancel` when the user dismissed
      # the picker, and `on_error` for anything else. Raises nothing.
      def pick(on_success:, on_cancel:, on_error:)
        connection = DBus.session
        token = "eyedropper#{rand(1 << 32)}"

        watch_for_response(token) do |response, body|
          case response
          when SUCCESS then on_success.call(color_from(body))
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
              DBus.variant("('', {'handle_token': <#{DBus.quote(token)}>})"),
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

          # Watched before the call is made, because the portal derives the
          # request path from the token and may answer immediately.
          def watch_for_response(token)
            DBus.monitor(
              BUS_NAME,
              DBus.request_path(DBus.session, token),
              "Response",
            ) do |body|
              yield(DBus.response_code(body), body)
              true
            end
          end

          # The portal reports the color as three doubles in 0..1, without alpha.
          def color_from(body)
            components = DBus.doubles(DBus.lookup(body, "color"))

            if components.length < 3
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
