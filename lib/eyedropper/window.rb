# frozen_string_literal: true

module Eyedropper
  # The application window: a header bar with the picker button and main menu
  # over a stack of three pages — the empty state, the portal error state, and
  # the main view of format rows beside the color history.
  class Window
    # A history swatch is about this tall; the count decides whether the list
    # will scroll, and therefore whether room must be left for a scrollbar.
    ITEM_HEIGHT = 40
    SCROLLBAR_WIDTH = 24

    attr_reader :color, :history, :history_items, :format_rows

    def initialize(app)
      @app = app
      @color = nil
      @history = []
      @history_items = []
      @format_rows = []
    end

    def build
      window.tap do |win|
        win.content = toast_overlay

        toast_overlay.child = bottom_sheet

        bottom_sheet.tap do |sheet|
          sheet.content = toolbar_view
          sheet.sheet = edit_sheet.build

          toolbar_view.tap do |view|
            view.add_top_bar(header_bar)
            view.content = stack

            header_bar.tap do |bar|
              bar.title_widget = window_title
              bar.pack_start(color_picker_button)
              bar.pack_end(menu_button)

              color_picker_button.signal_connect("clicked") { pick_color }
            end

            stack.tap do |widget|
              widget.add_named(placeholder_page.build, "placeholder")
              widget.add_named(portal_error_page.build, "portal-error")
              widget.add_named(main_page, "main")
            end

            main_page.tap do |box|
              box.append(format_box)
              box.append(history_scroller)

              format_box.append(color_clamp)
              color_clamp.child = color_edit_button
              color_edit_button.child = color_button
              color_edit_button.signal_connect("clicked") { open_edit_sheet }

              history_scroller.child = history_list
            end
          end
        end

        install_actions(win)
        install_styles
        order_formats

        unless Picker.available?
          show_portal_error_page
        end
      end
    end

    def present = window.present

    # Makes `color` the current one, moving it to the front of the history and
    # rewriting every visible format row.
    def set_color(color)
      unless @color == color
        @history.delete(color)
        @history.unshift(color)
        refresh_history
      end

      @color = color
      stack.visible_child_name = "main"
      color_button.rgba = color.to_rgba
      @format_rows.each { |row| row.display_color(color) }
    end

    # Empties the history, offering one undo. The current color is re-added
    # immediately afterwards, so the main view still has something to show.
    def clear_history
      cleared = @history.dup
      @history.clear

      unless @color.nil?
        @history << @color
      end
      refresh_history

      toast_overlay.add_toast(undo_toast(cleared))
    end

    def remove_from_history(color)
      index = @history.index(color)

      unless index.nil?
        @history.delete_at(index)
        refresh_history

        # Removing the current color would otherwise leave it on screen with
        # nothing in the history pointing at it.
        if index.zero? && !@history.empty?
          set_color(@history.first)
        end
      end
    end

    def show_placeholder_page
      stack.visible_child_name = "placeholder"
    end

    def show_portal_error_page
      stack.visible_child_name = "portal-error"
      color_picker_button.sensitive = false
    end

    def show_toast(text, priority = Adwaita::ToastPriority::NORMAL)
      Adwaita::Toast.new(text).tap do |toast|
        toast.priority = priority
        toast_overlay.add_toast(toast)
      end
    end

    def pick_color
      Picker.pick(
        on_success: method(:adopt_picked_color),
        on_cancel:  -> {},
        on_error:   ->(_message) { report_pick_failure },
      )
    end

    # Rebuilds the format rows from the saved order and visibility. Called at
    # startup and again whenever the preferences dialog closes.
    def order_formats
      @format_rows.each { |row| format_box.remove(row.box) }
      @format_rows = visible_notations.map do |notation|
        Widgets::ColorFormatRow.new(
          notation,
          on_set_color: method(:set_color),
          on_toast:     method(:show_toast),
        )
      end

      @format_rows.each do |row|
        format_box.append(row.build)
        unless @color.nil?
          row.display_color(@color)
        end
      end
    end

    def window
      @window ||= Adwaita::ApplicationWindow.new(@app.app).tap do |win|
        win.title = Config::APP_NAME
        win.icon_name = Config::APP_ID
        win.set_default_size(360, 600)
        win.hide_on_close = true

        if Config.devel?
          win.add_css_class("devel")
        end
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    def bottom_sheet = @bottom_sheet ||= Adwaita::BottomSheet.new

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def window_title = @window_title ||= Adwaita::WindowTitle.new(Config::APP_NAME, "")

    def color_picker_button
      @color_picker_button ||= Gtk::Button.new.tap do |widget|
        widget.icon_name = "color-select-symbolic"
        widget.tooltip_text = "Pick a Color"
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |widget|
        widget.icon_name = "open-menu-symbolic"
        widget.tooltip_text = "Main Menu"
        widget.primary = true
        widget.menu_model = primary_menu
      end
    end

    def primary_menu
      @primary_menu ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, history_section)
        menu.append_section(nil, app_section)
      end
    end

    def history_section
      @history_section ||= Gio::Menu.new.tap do |menu|
        menu.append("_Clear History", "app.clear-history")
        menu.append("_Random Color", "app.random-color")
      end
    end

    def app_section
      @app_section ||= Gio::Menu.new.tap do |menu|
        menu.append("_Preferences", "app.preferences")
        menu.append("_About Eyedropper", "app.about")
      end
    end

    def stack
      @stack ||= Gtk::Stack.new.tap do |widget|
        widget.transition_type = :crossfade
      end
    end

    def placeholder_page
      @placeholder_page ||= Widgets::PlaceholderPage.new(on_set_color: method(:set_color))
    end

    def portal_error_page = @portal_error_page ||= Widgets::PortalErrorPage.new

    def main_page = @main_page ||= Gtk::Box.new(:horizontal, 0)

    def format_box
      @format_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.halign = :fill
        box.vexpand = false
        box.valign = :start
        box.margin_bottom = 12
      end
    end

    def color_clamp
      @color_clamp ||= Adwaita::Clamp.new.tap do |widget|
        widget.orientation = :vertical
        widget.tightening_threshold = 35
        widget.maximum_size = 50
      end
    end

    # The swatch is a button so the whole block opens the editor; the
    # ColorDialogButton inside it only ever paints, which is why it is hidden
    # from screen readers and cannot be focused.
    def color_edit_button
      @color_edit_button ||= Gtk::Button.new.tap do |widget|
        widget.tooltip_text = "Edit Color"
        widget.margin_top = 12
        widget.margin_start = 12
        widget.margin_end = 12
        widget.vexpand = true
        widget.width_request = 267
        widget.add_css_class("no-padding")
      end
    end

    def color_button
      @color_button ||= Gtk::ColorDialogButton.new(Gtk::ColorDialog.new).tap do |widget|
        widget.accessible_role = :presentation
        widget.can_focus = false
        widget.can_target = false
      end
    end

    def history_scroller
      @history_scroller ||= Gtk::ScrolledWindow.new.tap do |widget|
        widget.hscrollbar_policy = :never
        widget.min_content_height = 200
        widget.vexpand = true
      end
    end

    def history_list
      @history_list ||= Gtk::ListBox.new.tap do |widget|
        widget.selection_mode = :none
        widget.visible = false
        widget.add_css_class("background")
      end
    end

    def edit_sheet
      @edit_sheet ||= Widgets::EditSheet.new(
        on_apply:     method(:apply_edited_color),
        css_provider: css_provider,
      )
    end

    def css_provider = @css_provider ||= Gtk::CssProvider.new

      private

        def install_actions(win)
          win.add_action(action("pick-color") { pick_color })
        end

        # The app's own stylesheet, plus the provider the edit sheet rewrites to
        # keep the saturation slider's gradient in step with the current hue.
        def install_styles
          display = window.display
          install_icons(display)
          app_provider = Gtk::CssProvider.new
          app_provider.load(path: File.join(Eyedropper::DATA_DIR, "style.css"))

          Gtk::StyleContext.add_provider_for_display(
            display,
            app_provider,
            Gtk::StyleProvider::PRIORITY_APPLICATION,
          )
          Gtk::StyleContext.add_provider_for_display(
            display,
            css_provider,
            Gtk::StyleProvider::PRIORITY_APPLICATION,
          )
        end

        # The app icon and the handful of symbolic icons Eyedropper ships live
        # in the source tree, so a checkout resolves them without being
        # installed first. Upstream gets the same effect from a gresource.
        def install_icons(display)
          Gtk::IconTheme.get_for_display(display).add_search_path(
            File.join(Eyedropper::DATA_DIR, "icons"),
          )
        end

        def action(name, &block)
          Gio::SimpleAction.new(name).tap do |simple_action|
            simple_action.signal_connect("activate") { block.call }
          end
        end

        def visible_notations
          settings = Settings.instance
          visible = settings.visible_formats

          settings.format_order
            .select { |identifier| visible.include?(identifier) }
            .filter_map { |identifier| Notation.find(identifier) }
        end

        def apply_edited_color(color)
          set_color(color)
          bottom_sheet.open = false
        end

        def open_edit_sheet
          unless @color.nil?
            edit_sheet.show(@color)
            bottom_sheet.open = true
          end
        end

        # A single swatch is the current color and is already shown above, so
        # the strip only earns its space from the second color onwards.
        def refresh_history
          @history_items.each(&:destroy)
          @history_items = []

          while (row = history_list.first_child)
            history_list.remove(row)
          end

          @history.each do |color|
            item = Widgets::HistoryItem.new(
              color,
              on_select: method(:set_color),
              on_remove: method(:remove_from_history),
            )
            @history_items << item
            history_list.append(item.build)
          end

          visible = @history.length > 1
          history_list.visible = visible
          @app.set_clear_history_enabled(visible)
          adjust_scrollbar_offset
        end

        # GTK does not reserve room for a non-overlay scrollbar here, so the
        # list would be clipped by it. Measured, not assumed, because the
        # setting is a desktop-wide preference.
        def adjust_scrollbar_offset
          settings = Gtk::Settings.default
          capacity = history_list.allocated_height / ITEM_HEIGHT

          unless settings.nil? || capacity.zero?
            overlay = settings.get_property("gtk-overlay-scrolling")
            crowded = @history.length >= capacity
            margin = 0
            if !overlay && crowded
              margin = SCROLLBAR_WIDTH
            end
            history_list.margin_end = margin
          end
        end

        def undo_toast(cleared)
          Adwaita::Toast.new("Cleared history").tap do |toast|
            toast.button_label = "Undo"
            toast.priority = Adwaita::ToastPriority::HIGH
            toast.signal_connect("button-clicked") do
              @history.concat(cleared.reject { |color| @history.include?(color) })
              refresh_history
            end
          end
        end

        # The portal can answer successfully with no color at all, which is
        # neither a pick nor a cancellation.
        def adopt_picked_color(color)
          unless color.nil?
            set_color(color)
          end
        end

        def report_pick_failure
          show_toast("Failed to pick a color")
          show_portal_error_page
        end
  end
end
