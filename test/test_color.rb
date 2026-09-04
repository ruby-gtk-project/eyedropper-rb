# frozen_string_literal: true

require_relative "test_helper"

# The vectors are upstream's own parser tests, which all name the Nord colour
# #2e3440 (rgb(46, 52, 64)). Keeping them means the conversions are checked
# against the crate this port replaced rather than against themselves.
class TestColor < Minitest::Test
  NORD = Eyedropper::Color.rgba(46, 52, 64)

  def assert_color(expected, actual, tolerance: 1)
    refute_nil(actual, "expected a color, got nil")
    expected.to_bytes.zip(actual.to_bytes).each_with_index do |(want, got), index|
      assert_in_delta(
        want,
        got,
        tolerance,
        "component #{index}: expected #{expected.to_bytes}, got #{actual.to_bytes}",
      )
    end
  end

  def test_hex_round_trip
    assert_equal("#2e3440ff", NORD.hex)
    assert_color(NORD, Eyedropper::Color.from_hex("#2e3440"))
    assert_color(NORD, Eyedropper::Color.from_hex("2e3440"))
  end

  def test_hex_alpha_positions
    with_alpha = Eyedropper::Color.rgba(
      46,
      52,
      64,
      40,
    )
    assert_color(
      with_alpha,
      Eyedropper::Parser.hex("2e344028", Eyedropper::AlphaPosition::END_POSITION),
    )
    assert_color(
      with_alpha,
      Eyedropper::Parser.hex("282e3440", Eyedropper::AlphaPosition::START),
    )
    # Whitespace and a stray `#` are tolerated, as upstream does.
    assert_color(
      with_alpha,
      Eyedropper::Parser.hex(" # 2e 34 40 28", Eyedropper::AlphaPosition::END_POSITION),
    )
  end

  def test_hex_rejects_junk
    assert_nil(Eyedropper::Parser.hex("nonsense", Eyedropper::AlphaPosition::NONE))
    assert_nil(Eyedropper::Parser.hex("#12345", Eyedropper::AlphaPosition::NONE))
  end

  def test_rgb
    assert_color(NORD, Eyedropper::Parser.rgb("rgb(46, 52, 64)"))
    # Mixed separators and a leading alpha.
    assert_color(
      Eyedropper::Color.rgba(
        46,
        52,
        64,
        100,
      ),
      Eyedropper::Parser.rgb("argb(100  46 | 52 / 64)"),
    )
    # A decimal is a fraction of full intensity; a bare integer is a byte.
    assert_color(
      Eyedropper::Color.rgba(127, 127, 127),
      Eyedropper::Parser.rgb("rgb(0.5, 0.5, 0.5)"),
    )
    assert_color(
      Eyedropper::Color.rgba(46, 51, 64),
      Eyedropper::Parser.rgb("rgb(46, 20%, 64)"),
    )
  end

  def test_hsl
    assert_color(NORD, Eyedropper::Parser.hsl("hsl(220, 16%, 22%)"), tolerance: 2)
    assert_color(
      Eyedropper::Color.rgba(
        47,
        53,
        65,
        127,
      ),
      Eyedropper::Parser.hsl("hsla(220, 16%, 22%, 0.5)"),
      tolerance: 2,
    )
  end

  def test_hsv
    assert_color(NORD, Eyedropper::Parser.hsv("hsv(220, 28%, 25%)"), tolerance: 2)
  end

  def test_hwb
    assert_color(NORD, Eyedropper::Parser.hwb("hwb(220, 18%, 75%)"), tolerance: 2)
  end

  def test_cmyk
    assert_color(NORD, Eyedropper::Parser.cmyk("cmyk(28%, 19%, 0%, 75%)"), tolerance: 2)
  end

  def test_xyz
    assert_color(NORD, Eyedropper::Parser.xyz("XYZ(3.280, 3.407, 5.335)"), tolerance: 2)
  end

  def test_cielab
    assert_color(NORD, Eyedropper::Parser.cielab("lab(21.61, 0.70, -8.35)"), tolerance: 2)
    assert_color(NORD, Eyedropper::Parser.cielab(" lab(21.61%, 0.56%,  -6.68%)"), tolerance: 2)
  end

  def test_lch
    assert_color(
      NORD,
      Eyedropper::Parser.lch("lch(21.605232, 8.378235, 274.76328)"),
      tolerance: 2,
    )
  end

  def test_lms
    assert_color(NORD, Eyedropper::Parser.lms("L: 3.20580, M: 3.52562, S: 5.33522"), tolerance: 2)
  end

  def test_hunter_lab
    assert_color(
      NORD,
      Eyedropper::Parser.hunter_lab("L: 18.45804, a: 0.41141, b: -5.42239"),
      tolerance: 2,
    )
  end

  def test_oklab
    assert_color(NORD, Eyedropper::Parser.oklab("oklab(32% -0.003600 -0.023222)"), tolerance: 2)
  end

  def test_oklch
    assert_color(NORD, Eyedropper::Parser.oklch("oklch(32% 0.023499 261.187836)"), tolerance: 2)
  end

  # Every format has to survive being displayed and read back, which is the
  # thing the app actually does when a user copies a value out of one row.
  def test_every_notation_round_trips
    Eyedropper::Notation::ALL.each do |notation|
      if notation == Eyedropper::Notation::NAME
        next
      end

      text = notation.format(
        NORD,
        alpha_position: Eyedropper::AlphaPosition::NONE,
        rgb_decimal:    false,
        precision:      6,
        name_sources:   0,
      )
      assert_color(NORD, notation.parse(text, 0), tolerance: 2)
    end
  end

  def test_conversions_are_self_inverse
    sample = Eyedropper::Color.rgba(210, 90, 30)

    assert_color(sample, Eyedropper::Color.from_hsl(*sample.to_hsl))
    assert_color(sample, Eyedropper::Color.from_hsv(*sample.to_hsv))
    assert_color(sample, Eyedropper::Color.from_hwb(*sample.to_hwb))
    assert_color(sample, Eyedropper::Color.from_cmyk(*sample.to_cmyk))
    assert_color(sample, Eyedropper::Color.from_xyz(*sample.to_xyz))
    assert_color(sample, Eyedropper::Color.from_lab(*sample.to_lab))
    assert_color(sample, Eyedropper::Color.from_lch(*sample.to_lch))
    assert_color(sample, Eyedropper::Color.from_oklab(*sample.to_oklab))
    assert_color(sample, Eyedropper::Color.from_oklch(*sample.to_oklch))
    assert_color(sample, Eyedropper::Color.from_lms(*sample.to_lms))
    assert_color(sample, Eyedropper::Color.from_hunter_lab(*sample.to_hunter_lab))
  end

  def test_greyscale_edges_do_not_divide_by_zero
    [Eyedropper::Color.rgba(0, 0, 0), Eyedropper::Color.rgba(255, 255, 255)].each do |color|
      assert_color(color, Eyedropper::Color.from_hsl(*color.to_hsl))
      assert_color(color, Eyedropper::Color.from_hsv(*color.to_hsv))
      assert_color(color, Eyedropper::Color.from_cmyk(*color.to_cmyk))
      assert_color(color, Eyedropper::Color.from_hunter_lab(*color.to_hunter_lab))
    end
  end

  def test_equality_is_by_byte
    assert_equal(Eyedropper::Color.rgba(1, 2, 3), Eyedropper::Color.new(1 / 255.0, 2 / 255.0, 3 / 255.0))
    refute_equal(Eyedropper::Color.rgba(1, 2, 3), Eyedropper::Color.rgba(1, 2, 4))
  end
end
