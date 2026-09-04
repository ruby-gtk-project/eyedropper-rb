# frozen_string_literal: true

module Eyedropper
  module Widgets
    # One swatch in the history strip: click to make it the current color,
    # right-click or long-press for a menu that removes it.
    #
    # Upstream subclasses GtkButton and overrides `snapshot` to paint the
    # rounded rect. Subclassing a widget from Ruby means registering a GType,
    # so this port puts a Gtk::DrawingArea inside a plain button and paints in
    # its draw function instead — same picture, no GType registration.
    class HistoryItem
      SWATCH_WIDTH = 36
      SWATCH_HEIGHT = 34
      CORNER_RADIUS = 6

      attr_reader :color

      def initialize(color, on_select:, on_remove:)
        @color = color
        @on_select = on_select
        @on_remove = on_remove
      end

      # A GtkPopover parented to a widget has to be unparented before that
      # widget goes away, or GTK finalises the button with a child still
      # attached and warns. The history strip is rebuilt often enough for that
      # to be every rebuild.
      def destroy
        unless @popover.nil?
          @popover.unparent
          @popover = nil
        end
      end

      def build
        button.tap do |widget|
          widget.child = swatch

          swatch.set_draw_func do |_area, context, width, height|
            paint(context, width, height)
          end

          widget.signal_connect("clicked") { @on_select.call(@color) }

          popover.set_parent(widget)
          widget.add_controller(right_click_gesture)
          widget.add_controller(press_gesture)

          right_click_gesture.signal_connect("pressed") { popover.popup }
          press_gesture.signal_connect("pressed") { popover.popup }

          remove_action.signal_connect("activate") { @on_remove.call(@color) }
        end
      end

      # The tooltip drops the alpha pair for an opaque color, so the common case
      # reads as a plain `#RRGGBB`.
      def tooltip
        if @color.opaque?
          Notation::HEX.format(
            @color,
            alpha_position: AlphaPosition::NONE,
            rgb_decimal:    false,
            precision:      2,
            name_sources:   0,
          )
        else
          @color.hex
        end
      end

      def button
        @button ||= Gtk::Button.new.tap do |widget|
          widget.margin_start = 2
          widget.margin_end = 2
          widget.margin_top = 2
          widget.margin_bottom = 2
          widget.tooltip_text = tooltip
          widget.halign = :center
          widget.add_css_class("shadow")
          widget.insert_action_group("history", action_group)
        end
      end

      def swatch
        @swatch ||= Gtk::DrawingArea.new.tap do |area|
          area.content_width = SWATCH_WIDTH
          area.content_height = SWATCH_HEIGHT
        end
      end

      def popover
        @popover ||= Gtk::PopoverMenu.new(menu_model).tap do |widget|
          widget.halign = :start
          widget.has_arrow = false
        end
      end

      def menu_model
        @menu_model ||= Gio::Menu.new.tap do |menu|
          menu.append("Remove", "history.remove")
        end
      end

      def action_group
        @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
          group.add_action(remove_action)
        end
      end

      def remove_action = @remove_action ||= Gio::SimpleAction.new("remove")

      def right_click_gesture
        @right_click_gesture ||= Gtk::GestureClick.new.tap { |gesture| gesture.button = 3 }
      end

      def press_gesture
        @press_gesture ||= Gtk::GestureLongPress.new.tap { |gesture| gesture.touch_only = true }
      end

        private

          def paint(context, width, height)
            radius = CORNER_RADIUS
            context.new_sub_path
            context.arc(
              width - radius,
              radius,
              radius,
              -Math::PI / 2,
              0,
            )
            context.arc(
              width - radius,
              height - radius,
              radius,
              0,
              Math::PI / 2,
            )
            context.arc(
              radius,
              height - radius,
              radius,
              Math::PI / 2,
              Math::PI,
            )
            context.arc(
              radius,
              radius,
              radius,
              Math::PI,
              3 * Math::PI / 2,
            )
            context.close_path

            context.set_source_rgba(
              @color.red,
              @color.green,
              @color.blue,
              @color.alpha,
            )
            context.fill
          end
    end
  end
end
