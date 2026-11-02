# frozen_string_literal: true

module Eyedropper
  # Ported from `po/` (`po/LINGUAS` plus the 34 gettext catalogues), which
  # upstream reads through `gettextrs::gettext` and blueprint's `_()` / `C_()`
  # after meson has compiled every catalogue with `msgfmt`.
  #
  # The port ships the same `.po` files and reads them directly: there is no
  # compile step to hook into, and a `.mo` loader would need either the gettext
  # gem or `msgfmt` present on the user's machine. A catalogue is parsed once,
  # on the first lookup, for whichever language the environment asks for.
  module I18n
    PO_DIR = File.expand_path("../../po", __dir__)
    LINGUAS_FILE = File.join(PO_DIR, "LINGUAS")

    # In gettext's own order of precedence. LANGUAGE holds a colon-separated
    # priority list; the rest hold a single locale.
    LOCALE_VARIABLES = %w[
      LANGUAGE
      LC_ALL
      LC_MESSAGES
      LANG
    ].freeze

    ESCAPES = {
      "n" => "\n",
      "t" => "\t",
      "r" => "\r",
      "\"" => "\"",
      "\\" => "\\",
    }.freeze

    # Parses one `.po` file into a `{[msgctxt, msgid] => msgstr}` hash.
    #
    # Entries that gettext itself would not use are dropped: fuzzy ones,
    # obsolete ones (commented out with `#~`), the header (an empty msgid) and
    # any entry whose translation is still empty. Plural entries are dropped
    # too — the app has none, and a half-honoured `Plural-Forms` expression
    # would be worse than falling back to the msgid.
    module Parser
      FIELD = /\A(msgctxt|msgid_plural|msgid|msgstr(?:\[\d+\])?)[ \t]+(".*")\z/
      CONTINUATION = /\A".*"\z/

      class << self
        def parse(path)
          blocks(path).each_with_object({}) do |block, entries|
            store(entries, block)
          end
        end

        private

          def blocks(path)
            File.read(path, encoding: Encoding::UTF_8).split(/\n[ \t]*\n/)
          rescue SystemCallError
            []
          end

          def store(entries, block)
            fields(block).then do |fields|
              if translatable?(block, fields)
                entries[[fields["msgctxt"], fields["msgid"]]] = fields["msgstr"]
              end
            end
          end

          def translatable?(block, fields)
            !fuzzy?(block) &&
              !fields.key?("msgid_plural") &&
              !fields["msgid"].to_s.empty? &&
              !fields["msgstr"].to_s.empty?
          end

          def fuzzy?(block)
            block.each_line.any? do |line|
              line.start_with?("#,") && line.include?("fuzzy")
            end
          end

          # A msgid or msgstr can be split over any number of quoted
          # continuation lines, which gettext concatenates with nothing in
          # between.
          def fields(block)
            {}.tap do |fields|
              key = nil
              block.each_line do |line|
                key = absorb(fields, key, line.strip)
              end
            end
          end

          # Returns the field the next continuation line would belong to.
          def absorb(fields, key, line)
            case line
            when FIELD
              assign(fields, Regexp.last_match(1), Regexp.last_match(2))
            when CONTINUATION
              append(fields, key, line)
            end
          end

          def assign(fields, name, token)
            name.sub(/\[\d+\]\z/, "").tap do |field|
              fields[field] = unquote(token)
            end
          end

          def append(fields, key, line)
            key.tap do
              unless key.nil?
                fields[key] += unquote(line)
              end
            end
          end

          def unquote(token)
            token[1..-2].to_s.gsub(/\\(.)/) do |escape|
              ESCAPES.fetch(escape[1], escape[1])
            end
          end
      end
    end

    # One language's translations, with the msgid as the fallback for anything
    # the catalogue does not cover.
    class Catalog
      def self.load(language)
        case language
        when nil then new({})
        else new(Parser.parse(File.join(PO_DIR, "#{language}.po")))
        end
      end

      def initialize(entries)
        @entries = entries
      end

      def lookup(context, msgid) = @entries.fetch([context, msgid], msgid)
    end

    class << self
      # Upstream's `gettext(msgid)`.
      def translate(msgid) = catalog.lookup(nil, msgid)

      # Upstream's `C_(context, msgid)`: the same msgid can be translated
      # differently per message context.
      def translate_with_context(context, msgid) = catalog.lookup(context, msgid)

      def catalog = @catalog ||= Catalog.load(language)

      # The first locale the environment asks for that the port actually ships
      # a catalogue for, or nil when the app should stay in its source English.
      def language
        unless defined?(@language)
          @language = select_language
        end
        @language
      end

      def available_languages
        @available_languages ||= read_linguas
      end

      # Re-reads the environment. Only the test drivers need this; the locale
      # does not change under a running app.
      def reset!
        @catalog = nil
        @available_languages = nil
        if defined?(@language)
          remove_instance_variable(:@language)
        end
        self
      end

      private

        def select_language
          if posix_locale?
            nil
          else
            requested_locales.find { |locale| available_languages.include?(locale) }
          end
        end

        # gettext ignores LANGUAGE when the message locale is explicitly C or
        # POSIX, which is how a script pins the source English. Nothing set at
        # all is treated as permissive instead, so `LANGUAGE=de ruby ...` works
        # in a bare environment.
        def posix_locale?
          %w[LC_ALL LC_MESSAGES LANG]
            .filter_map { |name| ENV.fetch(name, nil) }
            .reject(&:empty?)
            .first
            .then { |locale| %w[C POSIX].include?(locale.to_s.split(/[.@]/).first) }
        end

        def read_linguas
          File.readlines(LINGUAS_FILE, chomp: true)
              .map { |line| line.sub(/#.*\z/, "").strip }
              .reject(&:empty?)
        rescue SystemCallError
          []
        end

        # `de_DE.UTF-8@euro` asks for `de_DE`, then `de`.
        def requested_locales
          LOCALE_VARIABLES
            .flat_map { |name| ENV.fetch(name, "").split(":") }
            .flat_map { |value| expand(value) }
            .uniq
        end

        def expand(value)
          value.split(/[.@]/).first.to_s.strip.then do |base|
            [base, base.split("_").first].reject { |candidate| candidate.to_s.empty? }.uniq
          end
        end
    end

    # Mixed into the ported classes so their call sites read like upstream's
    # `gettext()` and `C_()`.
    module Helpers
      def _(msgid) = I18n.translate(msgid)

      def c_(context, msgid) = I18n.translate_with_context(context, msgid)
    end
  end
end
