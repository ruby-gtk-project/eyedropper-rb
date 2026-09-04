# frozen_string_literal: true

module Eyedropper
  module Widgets
    # Shown when the desktop cannot service a color-pick request. The rest of
    # the app still works, so the page offers a way past itself.
    #
    # Upstream hand-builds this out of a Bin with `css-name: statuspage` so it
    # can show an illustration where the icon would go. Adw.StatusPage takes a
    # paintable for exactly that, so this is the same page without the scaffold.
    class PortalErrorPage
      ILLUSTRATION = "shattered-picker.svg"

      def build
        status_page.tap do |page|
          page.child = continue_button
        end
      end

      def status_page
        @status_page ||= Adwaita::StatusPage.new.tap do |page|
          page.title = "Color Picker not Available"
          page.description = "The system is not properly configured to allow for color picking"

          unless illustration.nil?
            page.paintable = illustration
          end
        end
      end

      # A missing or unreadable asset must not take the error page down with it
      # — this page is what the user sees when something is already wrong.
      def illustration
        @illustration ||= Gdk::Texture.new(
          Gio::File.new_for_path(File.join(Eyedropper::DATA_DIR, "icons", ILLUSTRATION)),
        )
      rescue StandardError
        nil
      end

      def continue_button
        @continue_button ||= Gtk::Button.new(label: "_Continue Regardless").tap do |widget|
          widget.use_underline = true
          widget.halign = :center
          widget.action_name = "app.placeholder"
          widget.add_css_class("pill")
        end
      end
    end
  end
end
