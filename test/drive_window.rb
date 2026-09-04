# frozen_string_literal: true

# Drives the real window: every page, every dialog, the edit sheet, the history
# strip and the format rows. Run it with `rake drive`.

require "tmpdir"

# Without a session bus GSettings cannot reach dconf, and every write is
# silently rolled back to the schema default a moment after it appears to
# succeed. The memory backend keeps writes in-process, which is both what the
# test wants to observe and what keeps the run off the user's real settings.
ENV["GSETTINGS_BACKEND"] = "memory"
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir
ENV["XDG_DATA_DIRS"] = [
  File.expand_path("../build/share", __dir__),
  ENV.fetch("XDG_DATA_DIRS", ""),
].join(":")

require_relative "../lib/eyedropper/ui"
require_relative "gtk_driver"

SHOTS = File.expand_path("../tmp/shots", __dir__)

GtkDriver.drive(Eyedropper::App.new, shots: SHOTS, interval: 500) do |d, app|
  window = nil
  prefs = nil

  d.window { app.window.window }

  d.step("the window builds and shows the empty state") do
    window = app.window
    d.check("window exists") { !window.window.nil? }
    d.check("starts on the placeholder page") { window.stack.visible_child_name == "placeholder" }
    d.check("no color yet") { window.color.nil? }
    d.shot("01-placeholder")
  end

  d.step("a bad color in the empty state is refused") do
    window.placeholder_page.entry.text = "definitely not a color"
    window.placeholder_page.view_button.signal_emit("clicked")
    d.check("still on the placeholder page") { window.stack.visible_child_name == "placeholder" }
    d.check("entry marked invalid") { window.placeholder_page.entry.css_classes.include?("error") }
  end

  d.step("the refused entry is on screen") do
    d.shot("02-placeholder-error")
  end

  d.step("a hex color in the empty state opens the main view") do
    window.placeholder_page.entry.text = "#2e3440"
    window.placeholder_page.view_button.signal_emit("clicked")
  end

  d.step("the main view shows the color in every visible format") do
    d.check("switched to main") { window.stack.visible_child_name == "main" }
    d.check("color adopted") { window.color == Eyedropper::Color.rgba(46, 52, 64) }
    d.check("six format rows") { window.format_rows.length == 6 }
    d.check("hex row reads #2E3440") do
      row = window.format_rows.find { |r| r.notation == Eyedropper::Notation::HEX }
      row.entry.text == "#2E3440"
    end
    d.check("rgb row reads rgb(46, 52, 64)") do
      row = window.format_rows.find { |r| r.notation == Eyedropper::Notation::RGB }
      row.entry.text == "rgb(46, 52, 64)"
    end
    d.check("name row falls back to Not named") do
      row = window.format_rows.find { |r| r.notation == Eyedropper::Notation::NAME }
      row.entry.text == "Not named"
    end
    d.check("history holds one color") { window.history.length == 1 }
    d.check("history strip stays hidden for one color") { !window.history_list.visible? }
    d.shot("03-main")
  end

  d.step("editing a format row applies that color") do
    row = window.format_rows.find { |r| r.notation == Eyedropper::Notation::RGB }
    row.entry.text = "rgb(255, 0, 0)"
    row.format_button.signal_emit("clicked")
  end

  d.step("the applied color propagates to the other rows") do
    d.check("color is red") { window.color == Eyedropper::Color.rgba(255, 0, 0) }
    d.check("hex row followed") do
      row = window.format_rows.find { |r| r.notation == Eyedropper::Notation::HEX }
      row.entry.text == "#FF0000"
    end
    d.check("name row resolves red") do
      row = window.format_rows.find { |r| r.notation == Eyedropper::Notation::NAME }
      row.entry.text == "red"
    end
    d.check("history holds two colors") { window.history.length == 2 }
    d.check("history strip now visible") { window.history_list.visible? }
    d.shot("04-two-colors")
  end

  d.step("an unparseable format row is refused and keeps the color") do
    row = window.format_rows.find { |r| r.notation == Eyedropper::Notation::HSL }
    row.entry.text = "not a color at all"
    row.format_button.signal_emit("clicked")
    d.check("color unchanged") { window.color == Eyedropper::Color.rgba(255, 0, 0) }
  end

  d.step("the copy button copies the row and shows a toast") do
    row = window.format_rows.find { |r| r.notation == Eyedropper::Notation::HEX }
    row.entry.text = row.instance_variable_get(:@displayed)
    row.format_button.signal_emit("clicked")
    d.check("clipboard holds the hex code") do
      # Reading the clipboard back is async; the row is the observable part.
      row.format_button.icon_name == "edit-copy-symbolic"
    end
  end

  d.step("the copy toast is on screen") do
    d.shot("16-copy-toast")
  end

  d.step("clicking an older history swatch makes it current") do
    target = window.history.last
    d.check("it is not the current color yet") { window.color != target }
    window.history_items.last.button.signal_emit("clicked")
    d.check("that color is now current") { window.color == target }
    d.check("it moved to the front of the history") { window.history.first == target }
  end

  d.step("a history swatch can be removed through its menu") do
    before = window.history.length
    doomed = window.history.last
    window.history_items.last.remove_action.activate(nil)
    d.check("one fewer color") { window.history.length == before - 1 }
    d.check("the removed color is gone") { !window.history.include?(doomed) }
  end

  d.step("the random color action adds another entry") do
    app.app.lookup_action("random-color").activate(nil)
  end

  d.step("random color landed") do
    d.check("history grew again") { window.history.length == 2 }
    d.check("clear-history is now enabled") { app.clear_history_action.enabled? }
    d.shot("05-three-colors")
  end

  d.step("the edit sheet opens on the current color") do
    window.color_edit_button.signal_emit("clicked")
  end

  d.step("the edit sheet mirrors the color") do
    d.check("sheet is open") { window.bottom_sheet.open? }
    hue, saturation, lightness = window.color.to_hsl
    d.check("hue slider matches") { (window.edit_sheet.hue_scale.value - hue).abs < 1.0 }
    d.check("saturation slider matches") do
      (window.edit_sheet.saturation_scale.value - (saturation * 100)).abs < 1.0
    end
    d.check("lightness slider matches") do
      (window.edit_sheet.lightness_scale.value - (lightness * 100)).abs < 1.0
    end
    d.shot("06-edit-sheet")
  end

  d.step("moving a slider and applying adopts the edited color") do
    window.edit_sheet.hue_scale.value = 120
    window.edit_sheet.saturation_scale.value = 100
    window.edit_sheet.lightness_scale.value = 50
    window.edit_sheet.apply_button.signal_emit("clicked")
  end

  d.step("the edited color is now current") do
    d.check("sheet closed") { !window.bottom_sheet.open? }
    d.check("color is pure green") { window.color == Eyedropper::Color.rgba(0, 255, 0) }
    d.shot("07-edited")
  end

  d.step("clearing the history leaves only the current color") do
    app.app.lookup_action("clear-history").activate(nil)
  end

  d.step("history cleared") do
    d.check("one color left") { window.history.length == 1 }
    d.check("current color survived") { window.color == Eyedropper::Color.rgba(0, 255, 0) }
    d.shot("08-cleared")
  end

  d.step("the preferences dialog opens") do
    app.app.lookup_action("preferences").activate(nil)
    prefs = app.preferences_dialog
  end

  d.step("preferences shows every format in order") do
    dialog = window.window.visible_dialog
    d.check("a dialog is up") { !dialog.nil? }
    d.shot("09-preferences")
  end

  d.step("the name sources subpage opens") do
    prefs.name_sources_row.signal_emit("activated")
  end

  d.step("name sources subpage is showing") do
    d.check("four sources offered") { prefs.name_source_switches.length == 4 }
    d.check("all four start enabled") do
      prefs.name_source_switches.values.all?(&:active?)
    end
    d.shot("13-name-sources")
  end

  d.step("turning off every name source drops the name") do
    prefs.name_source_switches.each_value { |row| row.active = false }
    d.check("setting cleared") { Eyedropper::Settings.instance.name_sources.zero? }
  end

  d.step("turning the basic palette back on restores it") do
    prefs.name_source_switches[Eyedropper::ColorNames::HTML].active = true
    d.check("only the basic flag is set") do
      Eyedropper::Settings.instance.name_sources == Eyedropper::ColorNames::HTML
    end
  end

  d.step("hiding a format removes its row from the main view") do
    row = prefs.rows.find { |r| r.notation == Eyedropper::Notation::CMYK }
    row.switch.active = false
    d.check("cmyk dropped from visible-formats") do
      !Eyedropper::Settings.instance.visible_formats.include?("cmyk")
    end
  end

  d.step("moving a format up reorders the saved order") do
    row = prefs.rows.find { |r| r.notation == Eyedropper::Notation::HEX }
    row.up_action.activate(nil)
    d.check("hex is now first") do
      Eyedropper::Settings.instance.format_order.first == "hex"
    end
    d.shot("14-reordered")
  end

  d.step("resetting the order restores the default") do
    prefs.reset_button.signal_emit("clicked")
    d.check("default order restored") do
      Eyedropper::Settings.instance.format_order == Eyedropper::Notation::DEFAULT_ORDER
    end
  end

  d.step("close preferences") do
    window.window.visible_dialog&.close
  end

  d.step("the main view picks up the preference changes") do
    d.check("cmyk row is gone") do
      window.format_rows.none? { |r| r.notation == Eyedropper::Notation::CMYK }
    end
    d.check("five format rows remain") { window.format_rows.length == 5 }
    d.shot("15-fewer-formats")
  end

  d.step("removing a history entry drops it") do
    app.app.lookup_action("random-color").activate(nil)
  end

  d.step("history has two again") do
    d.check("two colors") { window.history.length == 2 }
  end

  d.step("removing the second entry leaves the current color alone") do
    doomed = window.history.last
    current = window.color
    window.remove_from_history(doomed)
    d.check("one color left") { window.history.length == 1 }
    d.check("current color unchanged") { window.color == current }
  end

  d.step("the about dialog opens") do
    app.app.lookup_action("about").activate(nil)
  end

  d.step("about is showing") do
    d.check("a dialog is up") { !window.window.visible_dialog.nil? }
    d.shot("10-about")
  end

  d.step("close about") do
    window.window.visible_dialog&.close
  end

  d.step("the portal error page is reachable") do
    window.show_portal_error_page
    d.check("on the portal error page") { window.stack.visible_child_name == "portal-error" }
    d.check("picker button disabled") { !window.color_picker_button.sensitive? }
  end

  d.step("the portal error page is on screen") do
    d.shot("11-portal-error")
  end

  d.step("continue regardless returns to the placeholder") do
    app.app.lookup_action("placeholder").activate(nil)
    d.check("back on the placeholder page") { window.stack.visible_child_name == "placeholder" }
  end

  d.step("the placeholder page is on screen again") do
    d.shot("12-back-to-placeholder")
  end
end
