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

        def show_about
          Widgets::AboutDialog.show(window.window)
        end
  end
end
