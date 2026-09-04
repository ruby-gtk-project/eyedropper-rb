# frozen_string_literal: true

module Eyedropper
  module Widgets
    # One editable row: the current color written in a single notation, with a
    # button that copies it — or applies it, once the entry has been edited.
    class ColorFormatRow
      # How long the error/success tint stays on the row.
      FLASH_MS = 350

      attr_reader :notation

      def initialize(notation, on_set_color:, on_toast:)
        @notation = notation
        @on_set_color = on_set_color
        @on_toast = on_toast
      end

      def build
        box.tap do |widget|
          widget.append(entry)
          widget.append(format_button)

          entry.signal_connect("activate") { apply_entry }
          entry.signal_connect("changed") { switch_button(text_changed?) }
          format_button.signal_connect("clicked") { on_button_pressed }

          switch_button(false)
        end
      end

      # Rewrites the entry in this row's notation. Called for every row whenever
      # the window's color changes, and again when a preference that affects
      # formatting changes.
      def display_color(color)
        settings = Settings.instance
        @displayed = @notation.format(
          color,
          alpha_position: settings.alpha_position,
          rgb_decimal:    settings.rgb_decimal?,
          precision:      settings.precision,
          name_sources:   settings.name_sources,
        )
        entry.text = @displayed
        switch_button(false)
      end

      def box
        @box ||= Gtk::Box.new(:horizontal, 0).tap do |widget|
          widget.margin_top = 12
          widget.margin_start = 12
          widget.margin_end = 12
          widget.add_css_class("linked")
        end
      end

      def entry
        @entry ||= Gtk::Entry.new.tap do |widget|
          widget.hexpand = true
          widget.add_css_class("monospace")
        end
      end

      def format_button
        @format_button ||= Gtk::Button.new.tap do |widget|
          widget.icon_name = "edit-copy-symbolic"
        end
      end

        private

          # Parses whatever the user typed and, if it names a color, adopts it.
          def apply_entry
            color = @notation.parse(entry.text, Settings.instance.name_sources)

            if color.nil?
              show_error
            else
              display_color(color)
              show_success
              @on_set_color.call(color)
            end
          end

          def on_button_pressed
            if text_changed?
              switch_button(false)
              apply_entry
            else
              copy_to_clipboard
            end
          end

          def copy_to_clipboard
            text = entry.text
            entry.clipboard.set(text)
            @on_toast.call("Copied “#{text}”", Adwaita::ToastPriority::HIGH)
          end

          # True once the entry holds something other than what was displayed,
          # which is what turns the copy button into an apply button.
          def text_changed?
            typed = entry.text.to_s.strip
            !typed.empty? && typed != @displayed.to_s.strip
          end

          def switch_button(show_apply)
            if show_apply
              format_button.icon_name = "check-plain-symbolic"
              format_button.add_css_class("suggested-action")
              format_button.tooltip_text = "Apply"
            else
              format_button.icon_name = "edit-copy-symbolic"
              format_button.remove_css_class("suggested-action")
              format_button.tooltip_text = @notation.copy_label
            end
          end

          def show_error = flash("error")

          def show_success = flash("success")

          # Applies a libadwaita entry style class briefly, so a rejected or
          # accepted edit is visible without a dialog.
          def flash(style_class)
            box.add_css_class(style_class)
            GLib::Timeout.add(FLASH_MS) do
              box.remove_css_class(style_class)
              GLib::Source::REMOVE
            end
          end
    end
  end
end
