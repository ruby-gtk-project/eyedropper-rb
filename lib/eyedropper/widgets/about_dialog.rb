# frozen_string_literal: true

module Eyedropper
  module Widgets
    # The about dialog, including the debug-info page GNOME apps are expected
    # to carry so a bug report can name the display server and library versions.
    module AboutDialog
      extend I18n::Helpers

      FEATURES = [
        _("Pick a Color"),
        _("Edit the viewed color in a simple HSL editor"),
        _("Enter a color in various formats"),
        _("Convert colors into other formats such as Hex, RGB, HSV, HSL, CMYK, XYZ, CIE-Lab…"),
      ].freeze

      # Translators fill this in through the catalogue; every catalogue that
      # leaves it untranslated gets no credits page rather than a page naming
      # the placeholder.
      TRANSLATOR_CREDITS_MSGID = "translator-credits"

      def self.show(parent)
        Adwaita::AboutDialog.new.tap do |dialog|
          dialog.application_icon = Config::APP_ID
          dialog.application_name = _(Config::APP_NAME)
          dialog.developer_name = "FineFindus"
          dialog.developers = Config::DEVELOPERS
          dialog.designers = Config::DESIGNERS
          dialog.artists = Config::ARTISTS
          dialog.translator_credits = translator_credits
          dialog.license_type = Gtk::License::GPL_3_0
          dialog.version = Config::VERSION
          dialog.website = Config::WEBSITE
          dialog.issue_url = Config::ISSUE_TRACKER
          dialog.copyright = Config::COPYRIGHT
          dialog.comments = details
          dialog.debug_info = debug_info
          dialog.debug_info_filename = "eyedropper_debug_info"
          dialog.present(parent)
        end
      end

      def self.translator_credits
        _(TRANSLATOR_CREDITS_MSGID).then do |credits|
          case credits
          when TRANSLATOR_CREDITS_MSGID then ""
          else credits
          end
        end
      end

      # Kept in step with the metainfo file, which is what the software centre
      # shows for the same app.
      def self.details
        lines = [
          "<b>#{_('Pick and format colors')}</b>",
          "",
          _("Enter or pick a color and view it in different formats."),
          "",
          "<b>#{_('Features')}</b>",
          "",
        ]
        FEATURES.each { |feature| lines << "- #{feature}" }
        lines.join("\n")
      end

      def self.debug_info
        [
          "Eyedropper: #{Config::VERSION} (Ruby port)",
          "Profile: #{Config.profile}",
          "Backend: #{backend}",
          "OS:",
          " - Name: #{os_info('NAME')}",
          " - Version: #{os_info('VERSION')}",
          "Libraries:",
          " - Ruby: #{RUBY_VERSION}",
          " - GTK: #{Gtk::Version::STRING}",
          " - Libadwaita: #{adwaita_version}",
          "",
          "Sandbox:",
          sandbox_info,
          "",
        ].join("\n")
      end

      # `g_get_os_info` is not bound, so this reads the same file it would.
      def self.os_info(key)
        os_release.fetch(key, "unknown")
      end

      def self.os_release
        @os_release ||= File.readlines("/etc/os-release").to_h do |line|
          name, value = line.strip.split("=", 2)
          [name, value.to_s.delete('"')]
        end
      rescue StandardError
        {}
      end

      # The display's class names the backend — GdkWaylandDisplay,
      # GdkX11Display and so on. Introspected classes can come back anonymous,
      # so this reads `to_s` rather than `name`.
      def self.backend
        display = Gdk::Display.default
        if display.nil?
          "none (headless)"
        else
          display.class.to_s.split("::").last.to_s.sub(/Display\z/, "")
        end
      end

      def self.adwaita_version
        [
          Adwaita::MAJOR_VERSION,
          Adwaita::MINOR_VERSION,
          Adwaita::MICRO_VERSION,
        ].join(".")
      rescue StandardError
        "unknown"
      end

      # Inside a Flatpak the runtime details matter more than the environment;
      # outside it, only whether GTK has been told to route through portals.
      def self.sandbox_info
        if File.exist?("/.flatpak-info")
          flatpak_info
        else
          " - GTK_USE_PORTAL: #{ENV.fetch('GTK_USE_PORTAL', '0') == '1'}"
        end
      end

      def self.flatpak_info
        wanted = {
          "name"            => "Name",
          "runtime"         => "Runtime",
          "runtime-commit"  => "Runtime commit",
          "arch"            => "Arch",
          "flatpak-version" => "Flatpak Version",
          "devel"           => "Devel",
        }

        File.readlines("/.flatpak-info").filter_map do |line|
          key, value = line.strip.split("=", 2)
          label = wanted[key]
          unless label.nil? || value.nil?
            " - #{label}: #{value}"
          end
        end.join("\n")
      rescue StandardError
        " - Flatpak Info: unavailable"
      end
    end
  end
end
