# frozen_string_literal: true

module Eyedropper
  module Widgets
    # The bottom sheet's contents: a preview swatch over hue, saturation and
    # lightness sliders, and a button that adopts the result.
    class EditSheet
      def initialize(on_apply:, css_provider:)
        @on_apply = on_apply
        @css_provider = css_provider
      end

      def build
        toolbar_view.tap do
          toolbar_view.content = box

          box.tap do |widget|
            widget.append(color_preview)
            widget.append(hue_scale)
            widget.append(saturation_scale)
            widget.append(lightness_scale)
            widget.append(apply_button)

            [hue_scale, saturation_scale, lightness_scale].each do |scale|
              scale.signal_connect("value-changed") { update_preview(scale) }
            end

            apply_button.signal_connect("clicked") { @on_apply.call(preview_color) }
          end
        end
      end

      # Points the sliders at `color` before the sheet opens, so the editor
      # starts from the color the user is looking at.
      def show(color)
        hue, saturation, lightness = color.to_hsl
        @updating = true
        color_preview.rgba = color.to_rgba
        hue_scale.value = hue
        saturation_scale.value = saturation * 100.0
        lightness_scale.value = lightness * 100.0
        @updating = false
        refresh_saturation_gradient(color)
      end

      def preview_color = Color.from_rgba(color_preview.rgba)

      def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

      def box
        @box ||= Gtk::Box.new(:vertical, 0).tap do |widget|
          widget.margin_start = 8
          widget.margin_end = 8
          widget.margin_bottom = 12
        end
      end

      def color_preview
        @color_preview ||= Gtk::ColorDialogButton.new(Gtk::ColorDialog.new).tap do |widget|
          widget.can_focus = false
          widget.can_target = false
        end
      end

      def hue_scale = @hue_scale ||= build_scale(360, "hue-slider")

      def saturation_scale = @saturation_scale ||= build_scale(100, "saturation-slider")

      def lightness_scale = @lightness_scale ||= build_scale(100, "value-slider")

      def apply_button
        @apply_button ||= Gtk::Button.new(label: "Apply").tap do |widget|
          widget.use_underline = true
          widget.halign = :center
          widget.add_css_class("pill")
          widget.add_css_class("suggested-action")
        end
      end

        private

          def build_scale(upper, style_class)
            adjustment = Gtk::Adjustment.new(
              0,
              0,
              upper,
              1,
              10,
              0,
            )

            Gtk::Scale.new(:horizontal, adjustment).tap do |widget|
              widget.digits = 0
              widget.has_origin = false
              widget.draw_value = false
              widget.add_css_class(style_class)
            end
          end

          def update_preview(scale)
            unless @updating
              color = Color.from_hsl(
                hue_scale.value,
                saturation_scale.value / 100.0,
                lightness_scale.value / 100.0,
              )
              color_preview.rgba = color.to_rgba

              # Moving the saturation slider must not redraw its own gradient
              # under the user's thumb.
              unless scale.equal?(saturation_scale)
                refresh_saturation_gradient(color)
              end
            end
          end

          # The saturation trough fades from white to the fully saturated form
          # of the current hue, which the stylesheet reads as a CSS variable.
          def refresh_saturation_gradient(color)
            @css_provider.load(
              data: ":root { --saturation-color: #{color.hex}; }",
            )
          end
    end
  end
end
