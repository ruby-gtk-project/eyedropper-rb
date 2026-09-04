# frozen_string_literal: true

require "fileutils"

module Eyedropper
  DATA_DIR = File.expand_path("../data", __dir__)
end

require_relative "eyedropper/config"
require_relative "eyedropper/alpha_position"
require_relative "eyedropper/color"
require_relative "eyedropper/parser"
require_relative "eyedropper/color_names"
require_relative "eyedropper/notation"
require_relative "eyedropper/settings"
