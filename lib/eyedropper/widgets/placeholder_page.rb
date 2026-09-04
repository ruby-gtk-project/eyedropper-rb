# frozen_string_literal: true

module Eyedropper
  module Widgets
    # The empty state, shown until a color has been picked or entered.
    class PlaceholderPage
      FLASH_MS = 350

      # Rotated so the empty state hints at more than one accepted syntax.
      PLACEHOLDER_COLORS = [
        "#2190A4",
        "Blue",
        "hsla(40.8, 100%, 39%, 1)",
        "rgb(58, 148, 74)",
      ].freeze

      def initialize(on_set_color:)
        @on_set_color = on_set_color
      end

      def build
        bin.tap do
          bin.child = status_page

          status_page.child = content_box

          content_box.tap do |box|
            box.append(entry)
            box.append(view_button)

            entry.signal_connect("activate") { submit }
            entry.signal_connect("changed") do
              view_button.sensitive = !entry.text.to_s.empty?
            end
            view_button.signal_connect("clicked") { submit }
          end
        end
      end

      def bin = @bin ||= Adwaita::Bin.new

      def status_page
        @status_page ||= Adwaita::StatusPage.new.tap do |page|
          page.icon_name = "color-select-symbolic"
          page.title = "No Color"
          page.description = "Select or enter a color to get started"
        end
      end

      def content_box
        @content_box ||= Gtk::Box.new(:vertical, 25).tap do |box|
          box.hexpand = true
          box.halign = :center
        end
      end

      def entry
        @entry ||= Gtk::Entry.new.tap do |widget|
          widget.placeholder_text = PLACEHOLDER_COLORS.sample
        end
      end

      def view_button
        @view_button ||= Gtk::Button.new(label: "View").tap do |widget|
          widget.halign = :center
          widget.sensitive = false
          widget.add_css_class("pill")
          widget.add_css_class("suggested-action")
        end
      end

        private

          # The empty state accepts anything any of the format rows would, so a
          # user who knows the syntax does not have to reach the picker first.
          def submit
            text = entry.text
            color = Parser.hex(text, Settings.instance.alpha_position) || parse_any(text)

            if color.nil?
              flash_error
            else
              @on_set_color.call(color)
            end
          end

          def parse_any(text)
            sources = Settings.instance.name_sources
            Notation::ALL.filter_map { |notation| notation.parse(text, sources) }.first
          end

          def flash_error
            entry.add_css_class("error")
            GLib::Timeout.add(FLASH_MS) do
              entry.remove_css_class("error")
              GLib::Source::REMOVE
            end
          end
    end
  end
end
