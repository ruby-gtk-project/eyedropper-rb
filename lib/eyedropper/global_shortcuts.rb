# frozen_string_literal: true

module Eyedropper
  # Binds Ctrl+P as a system-wide shortcut through the GlobalShortcuts portal,
  # so a color can be picked while the app is not focused, and asks for
  # background permission so it can keep listening while it has no window up.
  #
  # Upstream drives both portals through `ashpd`; this speaks to them directly
  # over the session bus, like Picker does.
  #
  # The whole thing is best-effort: portals that are absent, refuse, or answer
  # with an error leave the app running normally with only its in-window
  # accelerator.
  class GlobalShortcuts
    PORTAL = "org.freedesktop.portal.Desktop"
    PORTAL_PATH = "/org/freedesktop/portal/desktop"
    SHORTCUTS_INTERFACE = "org.freedesktop.portal.GlobalShortcuts"
    BACKGROUND_INTERFACE = "org.freedesktop.portal.Background"
    REQUEST_INTERFACE = "org.freedesktop.portal.Request"

    # Identifier of the color-picking shortcut, as upstream names it.
    SHORTCUT_PICK_COLOR = "EyedropperColorPick"

    def initialize(on_activated:)
      @on_activated = on_activated
      @connection = nil
      @activation = nil
    end

    # Stops watching. The app calls this on shutdown so the helper process the
    # watch runs in does not outlive it.
    def stop
      unless @activation.nil?
        @activation.stop
        @activation = nil
      end
    end

    # Starts listening. Safe to call when no portal exists.
    def start
      @connection = DBus.session
      listen_for_activation
      create_session
      request_background
      true
    rescue StandardError => error
      warn("eyedropper-rb: global shortcuts unavailable: #{error.message}")
      false
    end

      private

        # Watched before any session exists, because the signal carries the
        # shortcut id and nothing else this needs. This one never stops.
        def listen_for_activation
          @activation = DBus.monitor(PORTAL, PORTAL_PATH, "Activated") do |body|
            if body.include?(SHORTCUT_PICK_COLOR)
              @on_activated.call
            end
            false
          end
        end

        def create_session
          token = "eyedropper#{rand(1 << 32)}"
          session_token = "eyedroppersession#{rand(1 << 32)}"

          await(token) do |response, body|
            if response.zero?
              bind_shortcuts(session_handle(body))
            end
          end

          @connection.call(
            PORTAL,
            PORTAL_PATH,
            SHORTCUTS_INTERFACE,
            "CreateSession",
            DBus.variant(session_arguments(token, session_token)),
            nil,
            :none,
            -1,
          ) { |_source, result| finish(result) }
        end

        def session_arguments(token, session_token)
          "({'handle_token': <#{DBus.quote(token)}>, " \
            "'session_handle_token': <#{DBus.quote(session_token)}>},)"
        end

        def bind_shortcuts(handle)
          if handle.nil?
            nil
          else
            token = "eyedropperbind#{rand(1 << 32)}"
            await(token) { |_response, _body| nil }

            @connection.call(
              PORTAL,
              PORTAL_PATH,
              SHORTCUTS_INTERFACE,
              "BindShortcuts",
              DBus.variant(bind_arguments(handle, token)),
              nil,
              :none,
              -1,
            ) { |_source, result| finish(result) }
          end
        end

        # `(oa(sa{sv})sa{sv})`: the session, the shortcuts, the parent window,
        # and the request options.
        def bind_arguments(handle, token)
          shortcut = "(#{DBus.quote(SHORTCUT_PICK_COLOR)}, " \
                     "{'description': <#{DBus.quote('Pick a New Color')}>, " \
                     "'preferred_trigger': <#{DBus.quote('CTRL+p')}>})"

          "(objectpath #{DBus.quote(handle)}, [#{shortcut}], '', " \
            "{'handle_token': <#{DBus.quote(token)}>})"
        end

        # Asks to keep running in the background so the shortcut still works
        # when no window is open. Upstream passes the same command and flags.
        def request_background
          token = "eyedropperbg#{rand(1 << 32)}"
          await(token) { |_response, _body| nil }

          @connection.call(
            PORTAL,
            PORTAL_PATH,
            BACKGROUND_INTERFACE,
            "RequestBackground",
            DBus.variant(background_arguments(token)),
            nil,
            :none,
            -1,
          ) { |_source, result| finish(result) }
        end

        def background_arguments(token)
          reason = "Allow color selection while the application runs in the background"

          "('', {'handle_token': <#{DBus.quote(token)}>, " \
            "'reason': <#{DBus.quote(reason)}>, " \
            "'autostart': <true>, " \
            "'dbus-activatable': <false>, " \
            "'commandline': <['eyedropper-rb', '--gapplication-service']>})"
        end

        # Watches the Response signal for a request token, then hands the
        # response code and body to the block exactly once.
        def await(token)
          DBus.monitor(PORTAL, DBus.request_path(@connection, token), "Response") do |body|
            yield(DBus.response_code(body), body)
            true
          end
        end

        def session_handle(body)
          DBus.lookup(body, "session_handle").to_s[/'([^']+)'/, 1]
        end

        # Reports the call's own failure without letting it escape into the
        # main loop, where it would be an unhandled exception in a callback.
        def finish(result)
          @connection.call_finish(result)
        rescue StandardError => error
          warn("eyedropper-rb: global shortcuts portal: #{error.message}")
          nil
        end
  end
end
