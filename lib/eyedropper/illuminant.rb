# frozen_string_literal: true

module Eyedropper
  # White points for the `cie-illuminants` / `cie-standard-observer` GSettings
  # keys.
  #
  # Upstream declares both keys in its gschema but never reads either one —
  # `src/colors/color.rs` converts through `palette`, which is fixed to D65
  # under the CIE 1931 2° observer, and nothing in upstream ever branches on
  # an `Illuminant` or `StandardObserver` value because no such type exists in
  # its source. So there is no upstream index-to-illuminant mapping to port:
  # the ordering in {ORDER} is this file's own, chosen only so that the
  # schema's documented default (`cie-illuminants` = 5) lands on D65 — the
  # same illuminant the port (and upstream) already assumed everywhere before
  # this file existed. `cie-standard-observer`'s two values are not a guess:
  # the schema's own description spells them out ("Can only be 0 (2°) or 1
  # (10°)").
  #
  # Each entry is the CIE 1931 (2°) or CIE 1964 (10°) chromaticity coordinate
  # (x, y) of the illuminant's standard white, converted to XYZ on the 0..100
  # scale used throughout `Color` via X = (x/y)*100, Z = ((1-x-y)/y)*100.
  module Illuminant
    CHROMATICITY = {
      e:   {2 => [1 / 3.0, 1 / 3.0], 10 => [1 / 3.0, 1 / 3.0]},
      a:   {2 => [0.44757, 0.40745], 10 => [0.45117, 0.40594]},
      c:   {2 => [0.31006, 0.31616], 10 => [0.31039, 0.31905]},
      d50: {2 => [0.34567, 0.35850], 10 => [0.34773, 0.35952]},
      d55: {2 => [0.33242, 0.34743], 10 => [0.33411, 0.34877]},
      d65: {2 => [0.31270, 0.32900], 10 => [0.31382, 0.33100]},
      d75: {2 => [0.29902, 0.31485], 10 => [0.29968, 0.31740]},
    }.freeze

    # Index 5 is D65 so that the schema default lines up with it; see the
    # module comment for why this ordering is the port's own.
    ORDER = [:e, :a, :c, :d50, :d55, :d65, :d75].freeze

    class << self
      # `illuminant_index` is `cie-illuminants`, clamped into {ORDER};
      # `observer_index` is `cie-standard-observer` (0 => 2°, 1 => 10°).
      # Returns [x, y, z] on the same 0..100 scale as Color#to_xyz.
      def white_point(illuminant_index, observer_index)
        name = ORDER[illuminant_index.to_i.clamp(0, ORDER.size - 1)]
        if observer_index.to_i.zero?
          observer = 2
        else
          observer = 10
        end
        x, y = CHROMATICITY.fetch(name).fetch(observer)

        [
          (x / y) * 100.0,
          100.0,
          ((1 - x - y) / y) * 100.0,
        ]
      end
    end
  end
end
