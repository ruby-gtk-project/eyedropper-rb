# frozen_string_literal: true

module Eyedropper
  # The application: owns the single window, the global actions behind the main
  # menu, and the keyboard shortcuts that reach them.
  class App
    # Upstream's accelerators, unchanged.
    ACCELS = {
      "win.pick-color"   => ["<Control>p"],
      "app.random-color" => ["<Control>r"],
      "app.preferences"  => ["<Control>comma"],
      "app.quit"         => ["<Control>w", "<Control>q"],
    }.freeze

    def build
      app.tap do |application|
        application.signal_connect("startup") do
          Gtk::Window.set_default_icon_name(Config::APP_ID)
          setup_actions
          setup_accels
          start_desktop_integration
        end

        application.signal_connect("shutdown") do
          search_provider.stop
          global_shortcuts.stop
        end

        application.signal_connect("activate") do
          window.build
          window.present
        end
      end
    end

    def run = app.run([])

    def app
      @app ||= Gtk::Application.new(Config::APP_ID, :default_flags).tap do |application|
        application.resource_base_path = Config::RESOURCE_PATH
      end
    end

    def window = @window ||= Window.new(self)

    # The preferences dialog currently on screen, or the last one shown. Kept
    # so the dialog outlives the method that presented it.
    attr_reader :preferences_dialog

    # Clearing the history is meaningless until there is a history to clear, so
    # the window drives the action's sensitivity.
    def set_clear_history_enabled(enabled)
      clear_history_action.enabled = enabled
    end

    def clear_history_action = @clear_history_action ||= Gio::SimpleAction.new("clear-history")

    # Serves the GNOME Shell search provider: typing a color into the shell's
    # search offers it as a result that opens the app on that color.
    def search_provider
      @search_provider ||= SearchProvider.new(on_activate: method(:activate_search_result))
    end

    # Binds Ctrl+P system-wide through the GlobalShortcuts portal, so a color
    # can be picked without focusing the app first.
    def global_shortcuts
      @global_shortcuts ||= GlobalShortcuts.new(on_activated: method(:pick_from_shortcut))
    end

      private

        def setup_actions
          clear_history_action.signal_connect("activate") { window.clear_history }
          clear_history_action.enabled = false
          app.add_action(clear_history_action)

          add_action("random-color") { window.set_color(Color.random) }
          add_action("preferences") { show_preferences }
          add_action("about") { show_about }
          add_action("placeholder") { window.show_placeholder_page }
          add_action("quit") do
            window.window.close
            app.quit
          end
        end

        def setup_accels
          ACCELS.each do |name, accels|
            app.set_accels_for_action(name, accels)
          end
        end

        def add_action(name, &block)
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect("activate") { block.call }
            app.add_action(action)
          end
        end

        # Reordering or hiding a format only takes effect on the main view once
        # the dialog is done, which is also when upstream re-reads the settings.
        def show_preferences
          @preferences_dialog = Widgets::PreferencesDialog.new

          @preferences_dialog.build.tap do |widget|
            widget.signal_connect("closed") { window.order_formats }
            widget.present(window.window)
          end
        end

        # Both of these talk to the session bus, and neither is allowed to stop
        # the app starting: a missing bus, a portal that refuses, or a name
        # already taken by another instance all just mean the app runs with its
        # own window and nothing else.
        def start_desktop_integration
          search_provider.start
          global_shortcuts.start
        end

        # A search result identifier is the color's own hex string.
        def activate_search_result(identifier)
          Color.from_hex(identifier).then do |color|
            unless color.nil?
              app.activate
              window.set_color(color)
              window.present
            end
          end
        end

        def pick_from_shortcut
          app.activate
          window.pick_color
          window.present
        end

        def show_about
          Widgets::AboutDialog.show(window.window)
        end
  end
end
