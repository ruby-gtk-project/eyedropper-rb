# frozen_string_literal: true

module Eyedropper
  # Where the alpha pair sits in a hex string. Most hex strings put it last;
  # Android color values put it first.
  #
  # The integers are the indices of the AdwComboRow in preferences, which is
  # what the `alpha-position` setting stores.
  module AlphaPosition
    NONE = 0
    END_POSITION = 1
    START = 2

    def self.from_setting(value)
      if [NONE, END_POSITION, START].include?(value)
        value
      else
        NONE
      end
    end
  end
end
