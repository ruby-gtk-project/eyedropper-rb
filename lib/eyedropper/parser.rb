# frozen_string_literal: true

module Eyedropper
  # Parsers for every notation Eyedropper can display, so that each format row
  # is editable in its own notation.
  #
  # Upstream builds these out of `nom` combinators, one per format. The grammars
  # they describe all have the same shape — a prefix, then a run of numbers
  # separated by any of `,` `|` `/` or plain whitespace, then an optional `)` —
  # so this port tokenises once and lets each format say how to read its own
  # slots. That also keeps the leniency upstream advertises (mixed separators,
  # optional closing paren, optional prefix) in one place instead of fourteen.
  #
  # Two deliberate relaxations over upstream, both strict supersets: a
  # percentage may carry a fractional part in every format (upstream's shared
  # `percentage` combinator accepts integers only, so `hsl(220, 16.5%, 22%)`
  # is rejected there), and the format prefix is optional everywhere (upstream
  # requires it, except in the oklab/oklch test vectors, which omit it).
  module Parser
    NUMBER = /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/
    SEPARATOR = %r{[\s,|/]+}
    TOKEN = /#{NUMBER}(?:%|deg|°|turn)?/i

    # A single parsed number, remembering whether it was written as a percentage
    # so the format can decide what a percentage means for that slot.
    Token = Struct.new(:value, :percent, :decimal) do
      def percent? = percent

      # True when the literal carried a decimal point. RGB reads `0.5` as half
      # of full intensity but `46` as the byte 46, so the two cannot be told
      # apart by value alone.
      def decimal? = decimal

      # `scale` is what 100% means in this slot. A bare number is taken at face
      # value, which is what lets `lab(21.61, 0.70, -8.35)` and
      # `lab(21.61%, 0.56%, -6.68%)` both name the same color.
      def scaled(scale)
        if percent?
          value * scale
        else
          value
        end
      end

      # For slots that are a percentage of a whole — saturation, lightness, ink
      # coverage. A bare number is read as a percentage too, so `hsl(220, 16, 22)`
      # means what it looks like rather than failing.
      def fraction = (percent? ? value : value / 100.0).clamp(0.0, 1.0)
    end

    class << self
      # Hex is the odd one out: it is digits without separators, and the alpha
      # pair may lead or trail depending on the user's preference.
      def hex(input, alpha_position)
        digits = input.to_s.gsub(/[\s#]/, "")

        if digits.match?(/\A\h{6}(?:\h{2})?\z/)
          hex_color(digits, alpha_position)
        end
      end

      def rgb(input)
        tokens = tokenize(input, %w[rgba argb rgb])
        # `argb(...)` puts the alpha first; every other prefix puts it last.
        leading_alpha = input.to_s.strip.downcase.start_with?("argb") && tokens.length >= 4

        if leading_alpha
          tokens = tokens.rotate(1)
        end

        with_slots(tokens, 3) do
          values = tokens.first(4).map { |token| rgb_component(token) }
          Color.rgba(
            values[0],
            values[1],
            values[2],
            values.fetch(3, 255),
          )
        end
      end

      def hsl(input)
        tokens = tokenize(input, %w[hsla hsl])
        with_slots(tokens, 3) do
          Color.from_hsl(
            hue(tokens[0]),
            tokens[1].fraction,
            tokens[2].fraction,
            alpha_of(tokens[3]),
          )
        end
      end

      def hsv(input)
        tokens = tokenize(input, %w[hsva hsv])
        with_slots(tokens, 3) do
          Color.from_hsv(
            hue(tokens[0]),
            tokens[1].fraction,
            tokens[2].fraction,
            alpha_of(tokens[3]),
          )
        end
      end

      def hwb(input)
        tokens = tokenize(input, %w[hwb])
        with_slots(tokens, 3) do
          Color.from_hwb(
            hue(tokens[0]),
            tokens[1].fraction,
            tokens[2].fraction,
            alpha_of(tokens[3]),
          )
        end
      end

      def cmyk(input)
        tokens = tokenize(input, %w[cmyka cmyk])
        with_slots(tokens, 4) do
          values = tokens.first(4).map(&:fraction)
          Color.from_cmyk(
            values[0],
            values[1],
            values[2],
            values[3],
            alpha_of(tokens[4]),
          )
        end
      end

      def xyz(input)
        tokens = tokenize(input, %w[xyz])
        with_slots(tokens, 3) do
          Color.from_xyz(
            tokens[0].value,
            tokens[1].value,
            tokens[2].value,
            alpha_of(tokens[3]),
          )
        end
      end

      def cielab(input)
        tokens = tokenize(input, %w[cielab lab])
        with_slots(tokens, 3) do
          Color.from_lab(
            tokens[0].scaled(100.0).clamp(0.0, 100.0),
            tokens[1].scaled(125.0).clamp(-125.0, 125.0),
            tokens[2].scaled(125.0).clamp(-125.0, 125.0),
            alpha_of(tokens[3]),
          )
        end
      end

      def lch(input)
        tokens = tokenize(input, %w[cielch lch hcl])
        with_slots(tokens, 3) do
          Color.from_lch(
            tokens[0].scaled(100.0),
            tokens[1].scaled(150.0),
            hue(tokens[2]),
            alpha_of(tokens[3]),
          )
        end
      end

      def oklab(input)
        tokens = tokenize(input, %w[oklab])
        with_slots(tokens, 3) do
          Color.from_oklab(
            tokens[0].scaled(1.0),
            tokens[1].scaled(0.4),
            tokens[2].scaled(0.4),
            alpha_of(tokens[3]),
          )
        end
      end

      def oklch(input)
        tokens = tokenize(input, %w[oklch])
        with_slots(tokens, 3) do
          Color.from_oklch(
            tokens[0].scaled(1.0),
            tokens[1].scaled(0.4),
            hue(tokens[2], 360.0),
            alpha_of(tokens[3]),
          )
        end
      end

      # `L: 3.2, M: 3.5, S: 5.3` — the labelled triples share a tokenizer with
      # everything else, because the labels fall out as non-numeric noise.
      def lms(input)
        tokens = tokenize(input, [])
        with_slots(tokens, 3) do
          Color.from_lms(tokens[0].value, tokens[1].value, tokens[2].value)
        end
      end

      def hunter_lab(input)
        tokens = tokenize(input, [])
        with_slots(tokens, 3) do
          Color.from_hunter_lab(tokens[0].value, tokens[1].value, tokens[2].value)
        end
      end

        private

          def hex_color(digits, alpha_position)
            bytes = digits.scan(/\h{2}/).map { |pair| pair.to_i(16) }

            case alpha_position
            when AlphaPosition::START
              if bytes.length == 4
                Color.rgba(
                  bytes[1],
                  bytes[2],
                  bytes[3],
                  bytes[0],
                )
              else
                Color.rgba(bytes[0], bytes[1], bytes[2])
              end
            when AlphaPosition::END_POSITION
              Color.rgba(
                bytes[0],
                bytes[1],
                bytes[2],
                bytes.fetch(3, 255),
              )
            else
              Color.rgba(bytes[0], bytes[1], bytes[2])
            end
          end

          # Drops an optional format prefix and reads every number that follows.
          def tokenize(input, prefixes)
            body = input.to_s.strip
            prefixes.each do |prefix|
              if body.downcase.start_with?("#{prefix}(", prefix)
                body = body[prefix.length..].to_s.sub(/\A\(/, "")
                break
              end
            end

            body.scan(TOKEN).map { |match| token_for(match) }
          end

          def token_for(match)
            number = match[NUMBER].to_f
            decimal = match.include?(".")

            if match.end_with?("%")
              Token.new(number / 100.0, true, decimal)
            elsif match.downcase.end_with?("turn")
              Token.new(number * 360.0, false, decimal)
            else
              Token.new(number, false, decimal)
            end
          end

          # An RGB component is a byte, a percentage of a byte, or a 0..1
          # fraction of one. Mixed forms in one call are allowed.
          def rgb_component(token)
            if token.percent? || token.decimal?
              (token.value.clamp(0.0, 1.0) * 255).to_i
            else
              token.value.to_i.clamp(0, 255)
            end
          end

          # Every format needs a minimum number of slots; short input is a parse
          # failure rather than a color built out of zeroes.
          def with_slots(tokens, minimum)
            if tokens.length >= minimum
              yield
            end
          end

          def hue(token, percent_scale = 1.0)
            if token.percent?
              token.value * percent_scale
            else
              token.value
            end
          end

          # A trailing alpha may be written `50%` or `0.5`; absent means opaque.
          def alpha_of(token)
            if token.nil?
              1.0
            else
              token.value.clamp(0.0, 1.0)
            end
          end
    end
  end
end
