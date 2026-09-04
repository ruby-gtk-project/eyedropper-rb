# frozen_string_literal: true

module Eyedropper
  module Widgets
    # The preferences dialog: formatting options, and the list that decides
    # which formats the main view shows and in what order.
    class PreferencesDialog
      ALPHA_OPTIONS = ["None", "End", "Start"].freeze
      RGB_OPTIONS = %w[Integer Decimal].freeze

      NAME_SOURCES = [
        [ColorNames::HTML, "Basic", "Basic web colors"],
        [ColorNames::SVG, "Extended", "X11 and SVG color values"],
        [ColorNames::GNOME, "GNOME Color Palette", "Colors for GNOME app icons and illustrations"],
        [ColorNames::XKCD, "xkcd Color Survey", "954 RGB colors named by volunteers"],
      ].freeze

      # The rows currently in the order list, in display order.
      attr_reader :rows

      def initialize
        @settings = Settings.instance
        # One arbitrary color, so each row's subtitle shows what that format
        # actually looks like rather than a fixed sample.
        @example_color = Color.random
        @rows = []
      end

      def build
        dialog.tap do |widget|
          widget.add(general_page)

          general_page.tap do |page|
            page.add(formatting_group)
            page.add(formats_group)
          end

          formatting_group.tap do |group|
            group.add(alpha_row)
            group.add(rgb_row)
            group.add(name_sources_row)
            group.add(precision_row)

            name_sources_row.add_suffix(name_sources_arrow)
            name_sources_row.signal_connect("activated") do
              widget.push_subpage(name_sources_page)
            end
          end

          formats_group.tap do |group|
            group.header_suffix = reset_button
            group.add(order_list)

            reset_button.signal_connect("clicked") { reset_order }
          end

          bind_formatting
          bind_name_sources
          populate_formats
        end
      end

      def dialog = @dialog ||= Adwaita::PreferencesDialog.new

      def general_page
        @general_page ||= Adwaita::PreferencesPage.new.tap do |page|
          page.title = "General"
        end
      end

      def formatting_group
        @formatting_group ||= Adwaita::PreferencesGroup.new.tap do |group|
          group.title = "Formatting"
        end
      end

      def alpha_row
        @alpha_row ||= Adwaita::ComboRow.new.tap do |row|
          row.title = "Alpha-Value Position"
          row.subtitle = "Where the Alphavalue is positioned in the Hexstring"
          row.model = Gtk::StringList.new(ALPHA_OPTIONS)
        end
      end

      def rgb_row
        @rgb_row ||= Adwaita::ComboRow.new.tap do |row|
          row.title = "RGB Notation"
          row.subtitle = "Whether RGB values should be displayed as integers or decimals"
          row.model = Gtk::StringList.new(RGB_OPTIONS)
        end
      end

      def name_sources_row
        @name_sources_row ||= Adwaita::ActionRow.new.tap do |row|
          row.title = "Name Sources"
          row.subtitle = "Sources for displaying color names"
          row.activatable = true
        end
      end

      def name_sources_arrow
        @name_sources_arrow ||= Gtk::Image.new(icon_name: "go-next-symbolic")
      end

      def precision_row
        @precision_row ||= Adwaita::SpinRow.new(
          Gtk::Adjustment.new(
            2,
            0,
            15,
            1,
            1,
            0,
          ),
          1,
          0,
        ).tap do |row|
          row.title = "Precision"
          row.tooltip_text = "Precision"
          row.numeric = true
          row.valign = :center
        end
      end

      def formats_group
        @formats_group ||= Adwaita::PreferencesGroup.new.tap do |group|
          group.title = "Color Formats"
          group.description = "Customize the visible formats and in which order they are displayed"
        end
      end

      def reset_button
        @reset_button ||= Gtk::Button.new.tap do |widget|
          widget.icon_name = "edit-clear-symbolic"
          widget.tooltip_text = "Reset Order"
          widget.add_css_class("flat")
        end
      end

      def order_list
        @order_list ||= Gtk::ListBox.new.tap do |widget|
          widget.selection_mode = :none
          widget.add_css_class("boxed-list")
        end
      end

      # The name-source switches live on their own subpage, reached from the
      # "Name Sources" row.
      def name_sources_page
        @name_sources_page ||= Adwaita::NavigationPage.new(name_sources_toolbar, "Name Sources")
      end

      def name_sources_toolbar
        @name_sources_toolbar ||= Adwaita::ToolbarView.new.tap do |view|
          view.add_top_bar(Adwaita::HeaderBar.new)
          view.content = name_sources_inner_page

          name_sources_inner_page.add(name_sources_group)
          name_source_switches.each_value { |row| name_sources_group.add(row) }
        end
      end

      def name_sources_inner_page = @name_sources_inner_page ||= Adwaita::PreferencesPage.new

      def name_sources_group = @name_sources_group ||= Adwaita::PreferencesGroup.new

      def name_source_switches
        @name_source_switches ||= NAME_SOURCES.to_h do |flag, title, subtitle|
          row = Adwaita::SwitchRow.new.tap do |widget|
            widget.title = title
            widget.subtitle = subtitle
          end
          [flag, row]
        end
      end

        private

          def bind_formatting
            alpha_row.selected = @settings.alpha_position
            alpha_row.signal_connect("notify::selected") do
              @settings.write_key("alpha-position", alpha_row.selected)
            end

            if @settings.rgb_decimal?
              rgb_row.selected = 1
            else
              rgb_row.selected = 0
            end
            rgb_row.signal_connect("notify::selected") do
              @settings.write_key("rgb-notation", rgb_row.selected)
            end

            precision_row.value = @settings.precision
            precision_row.signal_connect("notify::value") do
              @settings.write_key("precision-digits", precision_row.value.to_i)
            end
          end

          def bind_name_sources
            flags = @settings.name_sources

            name_source_switches.each do |flag, row|
              row.active = flags.anybits?(flag)
              row.signal_connect("notify::active") do
                toggle_name_source(flag, row.active?)
              end
            end
          end

          def toggle_name_source(flag, enabled)
            current = @settings.name_sources
            if enabled
              @settings.name_sources = current | flag
            else
              @settings.name_sources = current & ~flag
            end
            refresh_examples
          end

          # Rebuilds the whole list from the saved order. Cheap enough at
          # fourteen rows that reordering does not need to move widgets around.
          def populate_formats
            @rows.each { |row| order_list.remove(row.row) }

            visible = @settings.visible_formats
            @rows = ordered_notations.map do |notation|
              FormatOrderRow.new(
                notation,
                example:   example_for(notation),
                visible:   visible.include?(notation.identifier),
                on_nudge:  method(:nudge),
                on_drop:   method(:drop),
                on_toggle: method(:toggle_visible),
              )
            end

            @rows.each { |row| order_list.append(row.build) }
            order_list.visible = !@rows.empty?
          end

          # The saved order can be missing formats added since it was written,
          # so anything absent is folded back in at its default position.
          def ordered_notations
            saved = @settings.format_order
            @settings.default_format_order.each_with_index do |identifier, index|
              unless saved.include?(identifier)
                saved.insert(index, identifier)
              end
            end
            @settings.format_order = saved

            saved.filter_map { |identifier| Notation.find(identifier) }
          end

          def example_for(notation)
            notation.format(
              @example_color,
              alpha_position: AlphaPosition::NONE,
              rgb_decimal:    false,
              precision:      2,
              name_sources:   @settings.name_sources,
            )
          end

          def refresh_examples
            @rows.each do |row|
              row.row.subtitle = example_for(row.notation)
            end
          end

          def nudge(identifier, delta)
            order = @settings.format_order
            index = order.index(identifier)

            unless index.nil?
              order.delete_at(index)
              order.insert((index + delta).clamp(0, order.length), identifier)
              @settings.format_order = order
              populate_formats
            end
          end

          def drop(source_identifier, target_identifier)
            order = @settings.format_order
            source_index = order.index(source_identifier)
            target_index = order.index(target_identifier)

            if !source_index.nil? && !target_index.nil? && source_index != target_index
              order.delete_at(source_index)
              order.insert(target_index, source_identifier)
              @settings.format_order = order
              populate_formats
            end
          end

          def toggle_visible(identifier, enabled)
            visible = @settings.visible_formats

            if enabled
              unless visible.include?(identifier)
                visible << identifier
              end
            else
              visible.delete(identifier)
            end

            @settings.visible_formats = visible
          end

          def reset_order
            @settings.reset_format_order
            populate_formats
          end
    end
  end
end
