# frozen_string_literal: true

module Eyedropper
  # Eyedropper's internal color representation: encoded (gamma-corrected) sRGB
  # plus alpha, every component a float in 0.0..1.0.
  #
  # Upstream leans on the `palette` crate for the conversions; there is no Ruby
  # equivalent worth a dependency, so the matrices live here. Every conversion
  # is expressed against this one representation rather than as a graph of
  # pairwise converters — sRGB is the hub, and each format only needs a way in
  # and a way out.
  #
  # Scale note: XYZ, LMS and Hunter Lab are handled on the 0..100 scale, which
  # is what upstream *displays* and what every one of its parser test vectors
  # assumes. Upstream's own parsers read those same strings back on the 0..1
  # scale, so a value copied out of the UI does not survive being pasted back
  # in; this port uses one scale on both sides so the round trip holds.
  class Color
    # D65, 2 degree standard observer, on the same 0..100 scale as #to_xyz.
    WHITE_POINT = [95.047, 100.0, 108.883].freeze

    EPSILON = 216.0 / 24_389.0
    KAPPA = 24_389.0 / 27.0

    attr_reader :red, :green, :blue, :alpha

    class << self
      # Build from 0..255 integer components.
      def rgba(red, green, blue, alpha = 255)
        new(
          red / 255.0,
          green / 255.0,
          blue / 255.0,
          alpha / 255.0,
        )
      end

      def random
        rgba(rand(256), rand(256), rand(256))
      end

      def from_rgba(rgba)
        new(
          rgba.red,
          rgba.green,
          rgba.blue,
          rgba.alpha,
        )
      end

      # Parses the `#rrggbbaa` form written by #hex. Returns nil on anything else.
      def from_hex(string)
        Parser.hex(string, AlphaPosition::END_POSITION)
      end

      def from_hsl(hue, saturation, lightness, alpha = 1.0)
        chroma = (1 - ((2 * lightness) - 1).abs) * saturation
        from_hue_chroma(
          hue,
          chroma,
          lightness - (chroma / 2),
          alpha,
        )
      end

      def from_hsv(hue, saturation, value, alpha = 1.0)
        chroma = value * saturation
        from_hue_chroma(
          hue,
          chroma,
          value - chroma,
          alpha,
        )
      end

      def from_hwb(hue, whiteness, blackness, alpha = 1.0)
        # A hue at full saturation and value, then blended toward the achromatic
        # axis by the white/black pair. Sums over 1 are normalised, per CSS.
        scale = whiteness + blackness
        white = whiteness
        black = blackness
        if scale > 1.0
          white = whiteness / scale
          black = blackness / scale
        end
        base = from_hsv(
          hue,
          1.0,
          1.0,
          alpha,
        )
        new(
          (base.red * (1 - white - black)) + white,
          (base.green * (1 - white - black)) + white,
          (base.blue * (1 - white - black)) + white,
          alpha,
        )
      end

      def from_cmyk(cyan, magenta, yellow, key, alpha = 1.0)
        new(
          (1 - cyan) * (1 - key),
          (1 - magenta) * (1 - key),
          (1 - yellow) * (1 - key),
          alpha,
        )
      end

      # XYZ on the 0..100 scale.
      def from_xyz(x, y, z, alpha = 1.0)
        linear = [
          (x * 3.2404542) + (y * -1.5371385) + (z * -0.4985314),
          (x * -0.9692660) + (y * 1.8760108) + (z * 0.0415560),
          (x * 0.0556434) + (y * -0.2040259) + (z * 1.0572252),
        ].map { |component| encode(component / 100.0) }

        new(
          linear[0],
          linear[1],
          linear[2],
          alpha,
        )
      end

      def from_lab(lightness, a_star, b_star, alpha = 1.0)
        fy = (lightness + 16) / 116.0
        fx = fy + (a_star / 500.0)
        fz = fy - (b_star / 200.0)

        xyz = [inverse_f(fx), inverse_lab_y(lightness, fy), inverse_f(fz)]
        from_xyz(
          xyz[0] * WHITE_POINT[0],
          xyz[1] * WHITE_POINT[1],
          xyz[2] * WHITE_POINT[2],
          alpha,
        )
      end

      def from_lch(lightness, chroma, hue, alpha = 1.0)
        radians = hue * Math::PI / 180.0
        from_lab(
          lightness,
          chroma * Math.cos(radians),
          chroma * Math.sin(radians),
          alpha,
        )
      end

      def from_oklab(lightness, a_star, b_star, alpha = 1.0)
        long = (lightness + (0.3963377774 * a_star) + (0.2158037573 * b_star))**3
        medium = (lightness - (0.1055613458 * a_star) - (0.0638541728 * b_star))**3
        short = (lightness - (0.0894841775 * a_star) - (1.2914855480 * b_star))**3

        new(
          encode((4.0767416621 * long) - (3.3077115913 * medium) + (0.2309699292 * short)),
          encode((-1.2684380046 * long) + (2.6097574011 * medium) - (0.3413193965 * short)),
          encode((-0.0041960863 * long) - (0.7034186147 * medium) + (1.7076147010 * short)),
          alpha,
        )
      end

      def from_oklch(lightness, chroma, hue, alpha = 1.0)
        radians = hue * Math::PI / 180.0
        from_oklab(
          lightness,
          chroma * Math.cos(radians),
          chroma * Math.sin(radians),
          alpha,
        )
      end

      # LMS on the same 0..100 scale as #to_xyz.
      def from_lms(long, medium, short, alpha = 1.0)
        from_xyz(
          (long * 1.9102) + (medium * -1.1121) + (short * 0.2019),
          (long * 0.3710) + (medium * 0.6291) + (short * 0.0),
          short,
          alpha,
        )
      end

      # Hunter Lab, inverted against the same 0..100 XYZ scale as #to_hunter_lab.
      #
      # Upstream's inverse reads `(l / wp.y)^2 * 100`, which only round-trips if
      # the white point is itself on the 0..100 scale — its own is normalised to
      # 1.0, so the value comes back ~10^6 times too large and every Hunter Lab
      # string parses to white. `(l / 100)^2 * wp.y` is the same formula with the
      # scales lined up, and it reproduces upstream's test vector.
      def from_hunter_lab(lightness, a_star, b_star, alpha = 1.0)
        white_x, white_y, white_z = WHITE_POINT
        ka = (175.0 / 198.04) * (white_x + white_y)
        kb = (70.0 / 218.11) * (white_y + white_z)

        y = ((lightness / 100.0)**2) * white_y
        ratio = Math.sqrt(y / white_y)
        x = ((a_star / ka * ratio) + (y / white_y)) * white_x
        z = -((b_star / kb * ratio) - (y / white_y)) * white_z

        from_xyz(
          x,
          y,
          z,
          alpha,
        )
      end

      # sRGB transfer function and its inverse.
      def encode(linear)
        if linear <= 0.0031308
          linear * 12.92
        else
          (1.055 * (linear.abs**(1 / 2.4)) * (linear.negative? ? -1 : 1)) - 0.055
        end
      end

      def decode(encoded)
        if encoded <= 0.04045
          encoded / 12.92
        else
          ((encoded + 0.055) / 1.055)**2.4
        end
      end

        private

          def from_hue_chroma(hue, chroma, offset, alpha)
            sector = (hue % 360) / 60.0
            secondary = chroma * (1 - ((sector % 2) - 1).abs)
            rgb = [
              [chroma, secondary, 0.0],
              [secondary, chroma, 0.0],
              [0.0, chroma, secondary],
              [0.0, secondary, chroma],
              [secondary, 0.0, chroma],
              [chroma, 0.0, secondary],
            ][sector.floor % 6]

            new(
              rgb[0] + offset,
              rgb[1] + offset,
              rgb[2] + offset,
              alpha,
            )
          end

          def inverse_f(value)
            if (value**3) > EPSILON
              value**3
            else
              ((116 * value) - 16) / KAPPA
            end
          end

          def inverse_lab_y(lightness, fy)
            if lightness > (KAPPA * EPSILON)
              fy**3
            else
              lightness / KAPPA
            end
          end
    end

    def initialize(red, green, blue, alpha = 1.0)
      @red = red.to_f
      @green = green.to_f
      @blue = blue.to_f
      @alpha = alpha.to_f
      freeze
    end

    def ==(other)
      other.is_a?(Color) && to_bytes == other.to_bytes
    end
    alias eql? ==

    def hash = to_bytes.hash

    # 0..255 integer components, which is also the granularity at which two
    # colors are considered equal — the history list holds what the user can
    # actually distinguish, not float noise from a round trip.
    def to_bytes
      [@red, @green, @blue, @alpha].map { |component| byte(component) }
    end

    def hex
      format("#%02x%02x%02x%02x", *to_bytes)
    end

    def to_rgba
      Gdk::RGBA.new(
        clamp(@red),
        clamp(@green),
        clamp(@blue),
        clamp(@alpha),
      )
    end

    def with_alpha(alpha) = Color.new(
      @red,
      @green,
      @blue,
      alpha,
    )

    def opaque? = byte(@alpha) == 255

    # Linear-light sRGB.
    def to_linear = [@red, @green, @blue].map { |component| Color.decode(component) }

    # Hue in degrees, the rest in 0..1.
    def to_hsl
      max, min, chroma, hue = hue_chroma
      lightness = (max + min) / 2.0
      saturation = 0.0
      divisor = 1 - ((2 * lightness) - 1).abs
      if chroma.positive? && divisor.positive?
        saturation = chroma / divisor
      end

      [hue, saturation.clamp(0.0, 1.0), lightness]
    end

    def to_hsv
      max, _min, chroma, hue = hue_chroma
      saturation = 0.0
      if max.positive?
        saturation = chroma / max
      end

      [hue, saturation, max]
    end

    def to_hwb
      max, min, _chroma, hue = hue_chroma
      [hue, min, 1 - max]
    end

    def to_cmyk
      cyan, magenta, yellow = [@red, @green, @blue].map { |component| 1 - component }
      key = [cyan, magenta, yellow].min

      if key >= 1.0
        [0.0, 0.0, 0.0, 1.0]
      else
        [
          (cyan - key) / (1 - key),
          (magenta - key) / (1 - key),
          (yellow - key) / (1 - key),
          key,
        ]
      end
    end

    # XYZ on the 0..100 scale, D65.
    def to_xyz
      red, green, blue = to_linear
      [
        ((0.4124564 * red) + (0.3575761 * green) + (0.1804375 * blue)) * 100.0,
        ((0.2126729 * red) + (0.7151522 * green) + (0.0721750 * blue)) * 100.0,
        ((0.0193339 * red) + (0.1191920 * green) + (0.9503041 * blue)) * 100.0,
      ]
    end

    def to_lab
      fx, fy, fz = to_xyz.each_with_index.map { |value, index| lab_f(value / Color::WHITE_POINT[index]) }
      [(116 * fy) - 16, 500 * (fx - fy), 200 * (fy - fz)]
    end

    def to_lch
      lightness, a_star, b_star = to_lab
      [lightness, Math.sqrt((a_star**2) + (b_star**2)), degrees(Math.atan2(b_star, a_star))]
    end

    def to_oklab
      red, green, blue = to_linear
      long = Math.cbrt((0.4122214708 * red) + (0.5363325363 * green) + (0.0514459929 * blue))
      medium = Math.cbrt((0.2119034982 * red) + (0.6806995451 * green) + (0.1073969566 * blue))
      short = Math.cbrt((0.0883024619 * red) + (0.2817188376 * green) + (0.6299787005 * blue))

      [
        (0.2104542553 * long) + (0.7936177850 * medium) - (0.0040720468 * short),
        (1.9779984951 * long) - (2.4285922050 * medium) + (0.4505937099 * short),
        (0.0259040371 * long) + (0.7827717662 * medium) - (0.8086757660 * short),
      ]
    end

    def to_oklch
      lightness, a_star, b_star = to_oklab
      [lightness, Math.sqrt((a_star**2) + (b_star**2)), degrees(Math.atan2(b_star, a_star))]
    end

    # LMS on the 0..100 scale, from the matrix in
    # "Fundamentals of Imaging Colour Spaces". Assumed to be under illuminant E.
    def to_lms
      x, y, z = to_xyz
      [
        (x * 0.3897) + (y * 0.6890) + (z * -0.0787),
        (x * -0.2298) + (y * 1.1834) + (z * 0.0464),
        z,
      ]
    end

    def to_hunter_lab
      x, y, z = to_xyz
      white_x, white_y, white_z = WHITE_POINT
      ka = (175.0 / 198.04) * (white_x + white_y)
      kb = (70.0 / 218.11) * (white_y + white_z)

      ratio = Math.sqrt(y / white_y)
      if ratio.zero?
        [0.0, 0.0, 0.0]
      else
        [
          100.0 * ratio,
          ka * (((x / white_x) - (y / white_y)) / ratio),
          kb * (((y / white_y) - (z / white_z)) / ratio),
        ]
      end
    end

      private

        def byte(component) = (clamp(component) * 255).round

        def clamp(component) = component.clamp(0.0, 1.0)

        def degrees(radians) = (radians * 180.0 / Math::PI) % 360

        def lab_f(ratio)
          if ratio > EPSILON
            Math.cbrt(ratio)
          else
            ((KAPPA * ratio) + 16) / 116.0
          end
        end

        # max, min, chroma and hue in degrees — the shared head of HSL/HSV/HWB.
        def hue_chroma
          max = [@red, @green, @blue].max
          min = [@red, @green, @blue].min
          chroma = max - min

          hue = 0.0
          if chroma.positive?
            case max
            when @red then hue = 60 * (((@green - @blue) / chroma) % 6)
            when @green then hue = 60 * (((@blue - @red) / chroma) + 2)
            else hue = 60 * (((@red - @green) / chroma) + 4)
            end
          end

          [max, min, chroma, hue % 360]
        end
  end
end
