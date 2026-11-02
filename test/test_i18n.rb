# frozen_string_literal: true

require "tempfile"

require_relative "test_helper"

# Two halves: the parser, checked against a catalogue written here so every
# shape gettext allows is covered, and the shipped `po/` catalogues, checked
# through real translations so a regression in locale selection or context
# handling fails loudly.
class TestI18n < Minitest::Test
  I18n = Eyedropper::I18n

  # Restores the locale environment afterwards, since the catalogue is memoized
  # off it.
  def with_locale(value)
    previous = I18n::LOCALE_VARIABLES.to_h { |name| [name, ENV.fetch(name, nil)] }
    I18n::LOCALE_VARIABLES.each { |name| ENV[name] = nil }
    ENV["LANGUAGE"] = value
    I18n.reset!
    yield
  ensure
    previous.each { |name, old| ENV[name] = old }
    I18n.reset!
  end

  def parse(source)
    Tempfile.create(["catalog", ".po"]) do |file|
      file.write(source)
      file.flush
      I18n::Parser.parse(file.path)
    end
  end

  def test_parses_the_shapes_gettext_allows
    entries = parse(<<~PO)
      # a header, which is an entry with an empty msgid
      msgid ""
      msgstr ""
      "Language: xx\\n"
      "Content-Type: text/plain; charset=UTF-8\\n"

      #: lib/eyedropper/window.rb:1
      msgid "Undo"
      msgstr "Dasweres"

      #: lib/eyedropper/window.rb:2
      msgid ""
      "A msgid long enough that xgettext wrapped it over two lines, which are "
      "joined with nothing in between."
      msgstr ""
      "A msgstr wrapped the same way, which is also "
      "joined with nothing in between."

      #: lib/eyedropper/window.rb:3
      msgid "Quoted \\"escapes\\" and a\\nnewline"
      msgstr "Dyalennow \\"kwotys\\" ha\\nlinenn nowydh"

      #: lib/eyedropper/window.rb:4
      msgctxt "Tooltip of the colorpicker button"
      msgid "Pick a Color"
      msgstr "Dewis unn Kolor"

      #, fuzzy
      #: lib/eyedropper/window.rb:5
      msgid "Apply"
      msgstr "Gorra"

      #: lib/eyedropper/window.rb:6
      msgid "Remove"
      msgstr ""

      #: lib/eyedropper/window.rb:7
      msgid "one color"
      msgid_plural "{} colors"
      msgstr[0] "unn kolor"
      msgstr[1] "{} kolor"

      #~ msgid "Removed the palette dialog"
      #~ msgstr "Dilewys"
    PO

    assert_equal("Dasweres", entries[[nil, "Undo"]])
    assert_equal(
      "A msgstr wrapped the same way, which is also joined with nothing in between.",
      entries[[
        nil,
        "A msgid long enough that xgettext wrapped it over two lines, which are joined with " \
          "nothing in between.",
      ]],
    )
    assert_equal(
      "Dyalennow \"kwotys\" ha\nlinenn nowydh",
      entries[[nil, "Quoted \"escapes\" and a\nnewline"]],
    )
    assert_equal("Dewis unn Kolor", entries[["Tooltip of the colorpicker button", "Pick a Color"]])

    # The header, the fuzzy entry, the untranslated entry, the plural entry and
    # the obsolete entry are all left out.
    assert_equal(4, entries.size)
    refute(entries.key?([nil, ""]))
    refute(entries.key?([nil, "Apply"]))
    refute(entries.key?([nil, "Remove"]))
    refute(entries.key?([nil, "one color"]))
    refute(entries.key?([nil, "Removed the palette dialog"]))
  end

  def test_every_lingua_has_a_catalogue
    assert_equal(34, I18n.available_languages.size)
    I18n.available_languages.each do |language|
      assert_path_exists(File.join(I18n::PO_DIR, "#{language}.po"))
    end
  end

  def test_a_locale_with_no_catalogue_leaves_the_source_strings_alone
    with_locale("xx") do
      assert_nil(I18n.language)
      assert_equal("Hex Code", I18n.translate("Hex Code"))
    end
  end

  def test_translates_through_the_catalogue
    with_locale("de") do
      assert_equal("de", I18n.language)
      assert_equal("_Verlauf löschen", I18n.translate("_Clear History"))
      assert_equal("Rückgängig", I18n.translate("Undo"))
    end
  end

  def test_a_region_locale_falls_back_to_its_language
    with_locale("de_AT.UTF-8@euro") do
      assert_equal("de", I18n.language)
      assert_equal("Allgemein", I18n.translate("General"))
    end
  end

  def test_a_region_locale_prefers_its_own_catalogue
    with_locale("pt_BR.UTF-8") do
      assert_equal("pt_BR", I18n.language)
    end
  end

  def test_a_priority_list_picks_the_first_available_language
    with_locale("xx:de:fr") do
      assert_equal("de", I18n.language)
    end
  end

  def test_message_contexts_are_honoured
    with_locale("fr") do
      assert_equal(
        "Choisir une couleur",
        I18n.translate_with_context("Tooltip of the colorpicker button", "Pick a Color"),
      )
      assert_equal("Aucune", I18n.translate_with_context("Alphavalue is not shown", "None"))
      # The same msgid outside that context is a different entry, and this
      # catalogue has none for it.
      assert_equal("None", I18n.translate("None"))
    end
  end

  def test_wrapped_entries_are_rejoined
    with_locale("de") do
      assert_equal(
        "Wähle eine Farbe vom Bildschirm und betrachte die verschiedenen Farbformate. " \
          "Ändere die ausgewählte Farbe, oder wähle eine vorherige ausgewählte Farbe aus dem " \
          "Verlauf. Generiere verschiedene Farbtöne basierend auf der ausgewählten Farbe.",
        I18n.translate(
          "Pick any color from your screen and view it in different formats. Change the picked " \
            "color or go back to a previously picked color from the history list. Generate a " \
            "list of different shades from the picked color.",
        ),
      )
    end
  end

  def test_an_entry_the_catalogue_misses_falls_back_to_the_source_string
    with_locale("ja") do
      assert_equal("ja", I18n.language)
      assert_equal("履歴を削除(_C)", I18n.translate("_Clear History"))
      assert_equal("Undo", I18n.translate("Undo"))
    end
  end

  def test_a_c_locale_pins_the_source_strings
    with_locale("de") do
      ENV["LC_ALL"] = "C.UTF-8"
      I18n.reset!

      assert_nil(I18n.language)
      assert_equal("Undo", I18n.translate("Undo"))
    end
  end

  # The mixin the ported widgets use, so a call site that stopped reaching the
  # catalogue would be caught here rather than on screen.
  def test_the_helpers_mixin_reaches_the_catalogue
    caller = Object.new.extend(I18n::Helpers)
    with_locale("de") do
      assert_equal("Entfernen", caller.send(:_, "Remove"))
      assert_equal(
        "Nicht anzeigen",
        caller.send(:c_, "Alphavalue is not shown", "None"),
      )
    end
  end
end
