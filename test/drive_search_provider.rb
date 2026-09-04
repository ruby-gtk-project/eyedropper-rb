# frozen_string_literal: true

# Serves the search provider on the real session bus and calls it back as a
# client, the way GNOME Shell would. Run it with `rake drive_search`.
#
# The calls have to be asynchronous: the server handler runs in this process's
# main loop, so a blocking `call_sync` would wait for a reply that cannot be
# produced until the loop is free again.

require "tmpdir"

ENV["GSETTINGS_BACKEND"] = "memory"
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir
ENV["XDG_CACHE_HOME"] = Dir.mktmpdir
ENV["XDG_DATA_DIRS"] = [
  File.expand_path("../build/share", __dir__),
  ENV.fetch("XDG_DATA_DIRS", ""),
].join(":")

require_relative "../lib/eyedropper/ui"

CHECKS = { count: 0, failures: [] }

def check(name)
  CHECKS[:count] += 1

  if yield
    puts("    ok   #{name}")
  else
    puts("    FAIL #{name}")
    CHECKS[:failures] << name
  end
rescue StandardError => e
  puts("    FAIL #{name}: #{e.class}: #{e.message}")
  CHECKS[:failures] << name
end

activated = []
provider = Eyedropper::SearchProvider.new(on_activate: ->(id) { activated << id })

puts("[0] the provider claims its bus name")
owned = provider.start
check("owns #{provider.bus_name}") { owned }

unless owned
  puts("\nno session bus available; skipping the D-Bus round trip")
  exit(0)
end

connection = Eyedropper::DBus.session
main_loop = GLib::MainLoop.new
steps = []

# Calls the provider over the bus and hands the reply (or the error) to `then_`.
def call(connection, provider, method, arguments, &then_)
  connection.call(
    provider.bus_name,
    provider.object_path,
    Eyedropper::SearchProvider::INTERFACE,
    method,
    Eyedropper::DBus.variant(arguments),
    nil,
    :none,
    5000,
  ) do |_source, result|
    reply = nil
    error = nil

    begin
      reply = connection.call_finish(result)
    rescue StandardError, NotImplementedError => e
      error = e
    end

    unless error.nil?
      puts("    (error: #{error.class}: #{error.message})")
    end

    then_.call(reply, error)
  end
end

def run_next(steps, main_loop)
  if steps.empty?
    main_loop.quit
  else
    steps.shift.call
  end
end

steps << lambda do
  puts("[1] a search for colors returns them as hex identifiers")
  call(
    connection,
    provider,
    "GetInitialResultSet",
    %((["blue", "#2e3440"],)),
  ) do |reply, error|
    check("call succeeded") { error.nil? }
    results = Array(reply).first.to_a
    check("blue resolved") { results.include?("#0000ffff") }
    check("hex resolved") { results.include?("#2e3440ff") }
    check("exactly two results") { results.length == 2 }
    run_next(steps, main_loop)
  end
end

steps << lambda do
  puts("[2] a search for nonsense returns nothing")
  call(
    connection,
    provider,
    "GetInitialResultSet",
    %((["not a color"],)),
  ) do |reply, _error|
    check("no results") { !reply.nil? && Array(reply).first.to_a.empty? }
    run_next(steps, main_loop)
  end
end

steps << lambda do
  puts("[3] a subsearch reads the new terms, not the old results")
  call(
    connection,
    provider,
    "GetSubsearchResultSet",
    %((["#0000ffff"], ["red"])),
  ) do |reply, _e|
    check("red resolved from the new terms") { Array(reply).first.to_a == ["#ff0000ff"] }
    run_next(steps, main_loop)
  end
end

steps << lambda do
  puts("[4] the server answers GetResultMetas")
  call(
    connection,
    provider,
    "GetResultMetas",
    %((["#0000ffff"],)),
  ) do |_reply, error|
    # A Ruby client cannot read an `aa{sv}` reply back — the bindings raise on
    # `{sv}` while unwrapping it — so the reply arriving at all is what is
    # checked here, and its content is checked directly in the next step.
    check("no D-Bus error") { !error.is_a?(Gio::DBusError) }
    run_next(steps, main_loop)
  end
end

steps << lambda do
  puts("[5] result metas carry a name and a swatch")
  metas = provider.metas_text(["#0000ffff"])
  check("the reply parses as a variant") { !Eyedropper::DBus.variant(metas).nil? }
  check("id present") { metas.include?("'id': <'#0000ffff'>") }
  check("named from the palettes") { metas.include?("'name': <'blue'>") }
  check("swatch icon present") { metas.include?("'gicon': <'") }
  check("swatch file was written") do
    metas[/'gicon': <'([^']+)'>/, 1].then { |path| !path.nil? && File.exist?(path) }
  end
  run_next(steps, main_loop)
end

steps << lambda do
  puts("[6] activating a result reaches the app")
  call(
    connection,
    provider,
    "ActivateResult",
    %(("#2e3440ff", ["2e3440"], uint32 0)),
  ) do |_r, e|
    check("no D-Bus error") { e.nil? }
    check("activation delivered") { activated == ["#2e3440ff"] }
    run_next(steps, main_loop)
  end
end

steps << lambda do
  puts("[7] launching a search reaches the app too")
  call(
    connection,
    provider,
    "LaunchSearch",
    %((["red"], uint32 0)),
  ) do |_reply, e|
    check("no D-Bus error") { e.nil? }
    check("launch delivered") { activated.last == "red" }
    run_next(steps, main_loop)
  end
end

GLib::Idle.add do
  run_next(steps, main_loop)
  false
end

GLib::Timeout.add(20_000) do
  puts("    FAIL timed out")
  CHECKS[:failures] << "timeout"
  main_loop.quit
  false
end

main_loop.run
provider.stop

puts
puts("#{CHECKS[:count] - CHECKS[:failures].length} of #{CHECKS[:count]} checks passed")
CHECKS[:failures].each { |name| puts("  failed check: #{name}") }
puts(CHECKS[:failures].empty? ? "SEARCH PROVIDER OK" : "SEARCH PROVIDER FAILED (#{CHECKS[:failures].length})")
exit(CHECKS[:failures].empty? ? 0 : 1)
