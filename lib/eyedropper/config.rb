# frozen_string_literal: true

module Eyedropper
  # Build-time identity. Upstream generates this from meson; the port has no
  # build step, so the values are literals and the profile is read from the
  # environment for the `devel` window styling.
  module Config
    APP_ID = "com.github.finefindus.eyedropper.Rb"
    APP_NAME = "Eyedropper"
    VERSION = "0.1.0"
    RESOURCE_PATH = "/com/github/finefindus/eyedropper/Rb"

    WEBSITE = "https://apps.gnome.org/Eyedropper"
    ISSUE_TRACKER = "https://github.com/finefindus/eyedropper/issues/new/choose"
    COPYRIGHT = "Copyright © 2022 - 2025 FineFindus"

    DEVELOPERS = ["FineFindus https://github.com/FineFindus"].freeze
    DESIGNERS = ["FineFindus https://github.com/FineFindus"].freeze
    ARTISTS = [
      "Tobias Bernard  https://tobiasbernard.com",
      "Brage Fuglseth https://bragefuglseth.dev",
    ].freeze

    def self.profile = ENV.fetch("EYEDROPPER_PROFILE", "default")

    def self.devel? = profile == "Devel"
  end
end
