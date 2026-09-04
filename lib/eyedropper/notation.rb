# frozen_string_literal: true

module Eyedropper
  # One color notation: how it is written, how it is read back, and what it is
  # called in the UI.
  #
  # Upstream models this as a Rust enum with three parallel `match` arms —
  # format, parse, and label — which have to be kept in step by hand. Here each
  # notation is one object holding all three, and the identifier is the string
  # the `format-order` and `visible-formats` settings already store.
  class Notation
    attr_reader :identifier, :label, :copy_label

    def initialize(identifier, label, copy_label, formatter, parser)
      @identifier = identifier
      @label = label
      @copy_label = copy_label
      @formatter = formatter
      @parser = parser
      freeze
    end

    # Renders `color`. `alpha_position` decides whether an alpha component is
    # written at all, and where; the other options only matter to some formats,
    # but every formatter is handed all of them so the table stays uniform.
    def format(color, alpha_position:, rgb_decimal:, precision:, name_sources:)
      @formatter.call(
        color,
        {
          alpha_position: alpha_position,
          rgb_decimal:    rgb_decimal,
          precision:      precision,
          name_sources:   name_sources,
        },
      )
    end

    # Returns a Color, or nil when the text is not valid in this notation.
    def parse(text, name_sources)
      @parser.call(text.to_s, name_sources)
    end

    class << self
      # `%` of a 0..1 fraction, rounded — upstream prints these without decimals.
      def percent(value) = (value * 100.0).round

      def digits(value, precision) = format("%.#{precision}f", value)

      # Alpha reads better as a bare `1` or `0` than as `1.00`.
      def pretty_alpha(value)
        case value.round(2)
        when 1.0 then "1"
        when 0.0 then "0"
        else format("%.2f", value)
        end
      end

      def alpha_at_end?(options) = options[:alpha_position] == AlphaPosition::END_POSITION
    end

    HEX = new(
      "hex",
      "Hex Code",
      "Copy Hex Code",
      lambda do |color, options|
        red, green, blue, alpha = color.to_bytes.map { |byte| format("%02X", byte) }
        case options[:alpha_position]
        when AlphaPosition::START then "##{alpha}#{red}#{green}#{blue}"
        when AlphaPosition::END_POSITION then "##{red}#{green}#{blue}#{alpha}"
        else "##{red}#{green}#{blue}"
        end
      end,
      ->(text, _sources) { Parser.hex(text, Settings.instance.alpha_position) },
    )

    RGB = new(
      "rgb",
      "RGB",
      "Copy RGB",
      lambda do |color, options|
        red, green, blue = [color.red, color.green, color.blue].map do |component|
          if options[:rgb_decimal]
            format("%.2f", component)
          else
            (component * 255).round.to_s
          end
        end

        if Notation.alpha_at_end?(options)
          "rgba(#{red}, #{green}, #{blue}, #{Notation.pretty_alpha(color.alpha)})"
        else
          "rgb(#{red}, #{green}, #{blue})"
        end
      end,
      ->(text, _sources) { Parser.rgb(text) },
    )

    HSL = new(
      "hsl",
      "HSL",
      "Copy HSL",
      lambda do |color, options|
        hue, saturation, lightness = color.to_hsl
        head = "#{hue.round}, #{Notation.percent(saturation)}%, #{Notation.percent(lightness)}%"

        if Notation.alpha_at_end?(options)
          "hsla(#{head}, #{Notation.pretty_alpha(color.alpha)})"
        else
          "hsl(#{head})"
        end
      end,
      ->(text, _sources) { Parser.hsl(text) },
    )

    HSV = new(
      "hsv",
      "HSV",
      "Copy HSV",
      lambda do |color, _options|
        hue, saturation, value = color.to_hsv
        "hsv(#{hue.round}, #{Notation.percent(saturation)}%, #{Notation.percent(value)}%)"
      end,
      ->(text, _sources) { Parser.hsv(text) },
    )

    CMYK = new(
      "cmyk",
      "CMYK",
      "Copy CMYK",
      lambda do |color, _options|
        cyan, magenta, yellow, key = color.to_cmyk.map { |value| Notation.percent(value) }
        "cmyk(#{cyan}%, #{magenta}%, #{yellow}%, #{key}%)"
      end,
      ->(text, _sources) { Parser.cmyk(text) },
    )

    XYZ = new(
      "xyz",
      "XYZ",
      "Copy XYZ",
      lambda do |color, options|
        x, y, z = color.to_xyz.map { |value| Notation.digits(value, options[:precision]) }
        "XYZ(#{x}, #{y}, #{z})"
      end,
      ->(text, _sources) { Parser.xyz(text) },
    )

    CIELAB = new(
      "cielab",
      "CIELAB",
      "Copy CIELAB",
      lambda do |color, options|
        lightness, a_star, b_star = color.to_lab.map do |value|
          Notation.digits(value, options[:precision])
        end
        "lab(#{lightness}, #{a_star}, #{b_star})"
      end,
      ->(text, _sources) { Parser.cielab(text) },
    )

    HWB = new(
      "hwb",
      "HWB",
      "Copy HWB",
      lambda do |color, _options|
        hue, whiteness, blackness = color.to_hwb
        "hwb(#{hue.round}, #{Notation.percent(whiteness)}%, #{Notation.percent(blackness)}%)"
      end,
      ->(text, _sources) { Parser.hwb(text) },
    )

    HCL = new(
      "hcl",
      "CIELCh / HCL",
      "Copy CIELCh / HCL",
      lambda do |color, options|
        lightness, chroma, hue = color.to_lch.map do |value|
          Notation.digits(value, options[:precision])
        end
        "lch(#{lightness}, #{chroma}, #{hue})"
      end,
      ->(text, _sources) { Parser.lch(text) },
    )

    LMS = new(
      "lms",
      "LMS",
      "Copy LMS",
      lambda do |color, options|
        long, medium, short = color.to_lms.map { |value| Notation.digits(value, options[:precision]) }
        "L: #{long}, M: #{medium}, S: #{short}"
      end,
      ->(text, _sources) { Parser.lms(text) },
    )

    HUNTERLAB = new(
      "hunterlab",
      "Hunter Lab",
      "Copy Hunter Lab",
      lambda do |color, options|
        lightness, a_star, b_star = color.to_hunter_lab.map do |value|
          Notation.digits(value, options[:precision])
        end
        "L: #{lightness}, a: #{a_star}, b: #{b_star}"
      end,
      ->(text, _sources) { Parser.hunter_lab(text) },
    )

    OKLAB = new(
      "oklab",
      "Oklab",
      "Copy Oklab",
      lambda do |color, options|
        lightness, a_star, b_star = color.to_oklab
        head = "#{Notation.percent(lightness)}% #{Notation.digits(a_star, options[:precision])} " \
               "#{Notation.digits(b_star, options[:precision])}"

        if Notation.alpha_at_end?(options)
          "oklab(#{head} / #{Notation.pretty_alpha(color.alpha)})"
        else
          "oklab(#{head})"
        end
      end,
      ->(text, _sources) { Parser.oklab(text) },
    )

    OKLCH = new(
      "oklch",
      "Oklch",
      "Copy Oklch",
      lambda do |color, options|
        lightness, chroma, hue = color.to_oklch
        head = "#{Notation.percent(lightness)}% #{Notation.digits(chroma, options[:precision])} " \
               "#{Notation.digits(hue, options[:precision])}"

        if Notation.alpha_at_end?(options)
          "oklch(#{head} / #{Notation.pretty_alpha(color.alpha)})"
        else
          "oklch(#{head})"
        end
      end,
      ->(text, _sources) { Parser.oklch(text) },
    )

    NAME = new(
      "name",
      "Name",
      "Copy Name",
      lambda do |color, options|
        ColorNames.name(color, options[:name_sources]) || "Not named"
      end,
      ->(text, sources) { ColorNames.color(text, sources) },
    )

    ALL = [
      NAME,
      HEX,
      RGB,
      HSL,
      HSV,
      CMYK,
      XYZ,
      CIELAB,
      HWB,
      HCL,
      LMS,
      HUNTERLAB,
      OKLAB,
      OKLCH,
    ].freeze

    BY_IDENTIFIER = ALL.to_h { |notation| [notation.identifier, notation] }.freeze

    # The order the `format-order` setting defaults to, which is also the order
    # the preferences list resets to.
    DEFAULT_ORDER = ALL.map(&:identifier).freeze

    def self.find(identifier) = BY_IDENTIFIER[identifier.to_s.strip.downcase]
  end
end
