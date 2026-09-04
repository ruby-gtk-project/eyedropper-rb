# frozen_string_literal: true

module Eyedropper
  module Widgets
    # One row of the format-order list: a switch that decides whether the format
    # appears in the main view, a menu that nudges it up or down, and a drag
    # handle that does the same by pointer.
    #
    # The drag payload is the format's identifier string rather than the row
    # object, because a Ruby object cannot cross a GdkContentProvider; the
    # identifier is enough for the list to find both ends of the move.
    class FormatOrderRow
      DRAG_NAME = "preferences-drag-format"

      attr_reader :notation

      def initialize(notation, example:, visible:, on_nudge:, on_drop:, on_toggle:)
        @notation = notation
        @example = example
        @visible = visible
        @on_nudge = on_nudge
        @on_drop = on_drop
        @on_toggle = on_toggle
      end

      def build
        row.tap do |widget|
          widget.add_prefix(drag_handle)
          widget.add_suffix(switch)
          widget.add_suffix(separator)
          widget.add_suffix(menu_button)
          widget.activatable_widget = switch

          switch.signal_connect("notify::active") do
            @on_toggle.call(@notation.identifier, switch.active?)
          end

          up_action.signal_connect("activate") { @on_nudge.call(@notation.identifier, -1) }
          down_action.signal_connect("activate") { @on_nudge.call(@notation.identifier, 1) }

          widget.insert_action_group("row", action_group)
          widget.add_controller(drag_source)
          widget.add_controller(drop_target)

          drag_source.signal_connect("prepare") do
            drag_source.set_icon(Gtk::WidgetPaintable.new(widget), 0, 0)
            Gdk::ContentProvider.new(@notation.identifier)
          end

          drop_target.signal_connect("drop") do |_target, value, _x, _y|
            @on_drop.call(value.to_s, @notation.identifier)
            true
          end
        end
      end

      def row
        @row ||= Adwaita::ActionRow.new.tap do |widget|
          widget.title = @notation.label
          widget.subtitle = @example
        end
      end

      def switch
        @switch ||= Gtk::Switch.new.tap do |widget|
          widget.valign = :center
          widget.can_focus = false
          widget.active = @visible
        end
      end

      def separator
        @separator ||= Gtk::Separator.new(:vertical).tap do |widget|
          widget.margin_top = 12
          widget.margin_bottom = 12
        end
      end

      def drag_handle
        @drag_handle ||= Gtk::Image.new(icon_name: "list-drag-handle-symbolic").tap do |widget|
          widget.add_css_class("drag-handle")
        end
      end

      def menu_button
        @menu_button ||= Gtk::MenuButton.new.tap do |widget|
          widget.valign = :center
          widget.icon_name = "view-more-symbolic"
          widget.menu_model = menu_model
          widget.add_css_class("flat")
        end
      end

      # The same two moves as the drag handle, reachable from the keyboard.
      def menu_model
        @menu_model ||= Gio::Menu.new.tap do |menu|
          menu.append("Move Up", "row.move-up")
          menu.append("Move Down", "row.move-down")
        end
      end

      def action_group
        @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
          group.add_action(up_action)
          group.add_action(down_action)
        end
      end

      def up_action = @up_action ||= Gio::SimpleAction.new("move-up")

      def down_action = @down_action ||= Gio::SimpleAction.new("move-down")

      def drag_source
        @drag_source ||= Gtk::DragSource.new.tap do |source|
          source.name = DRAG_NAME
          source.actions = Gdk::DragAction::MOVE
        end
      end

      def drop_target
        @drop_target ||= Gtk::DropTarget.new(String, Gdk::DragAction::MOVE).tap do |target|
          target.name = DRAG_NAME
          target.propagation_phase = :capture
        end
      end
    end
  end
end
