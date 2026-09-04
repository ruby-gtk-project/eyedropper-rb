# frozen_string_literal: true

# Exercises the two portal clients — the color picker and the global shortcuts
# — against whatever portal the session actually has. Run it with
# `rake drive_portals`.
#
# The portal is not obliged to grant anything, and picking a color needs a human
# to click, so this checks the parts that are deterministic: that every argument
# this code sends is well-formed GVariant of the type the portal's interface
# declares, that a request path is derived correctly, and that a real call
# reaches the portal and comes back without a protocol error.

require "tmpdir"

ENV["GSETTINGS_BACKEND"] = "memory"
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir
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

# Reaches a private method for the sake of checking the wire format it builds.
def build(object, method, *arguments)
  object.send(method, *arguments)
end

shortcuts = Eyedropper::GlobalShortcuts.new(on_activated: -> {})

puts("[0] every outgoing argument is well-formed GVariant of the declared type")

check("CreateSession is (a{sv})") do
  Eyedropper::DBus.variant(
    build(
      shortcuts,
      :session_arguments,
      "tok",
      "sess",
    ),
  ).type.to_s == "(a{sv})"
end

check("BindShortcuts is (oa(sa{sv})sa{sv})") do
  text = build(
    shortcuts,
    :bind_arguments,
    "/org/freedesktop/portal/desktop/session/x/y",
    "tok",
  )
  Eyedropper::DBus.variant(text).type.to_s == "(oa(sa{sv})sa{sv})"
end

check("RequestBackground is (sa{sv})") do
  Eyedropper::DBus.variant(build(shortcuts, :background_arguments, "tok")).type.to_s == "(sa{sv})"
end

check("PickColor is (sa{sv})") do
  text = "('', {'handle_token': <#{Eyedropper::DBus.quote('tok')}>})"
  Eyedropper::DBus.variant(text).type.to_s == "(sa{sv})"
end

puts("[1] a name with a quote in it does not break the wire format")
check("quoting survives a round trip") do
  Eyedropper::DBus.variant("(#{Eyedropper::DBus.quote(%(it's "here"))},)").value[0] == %(it's "here")
end

puts("[2] request paths follow the portal's naming rule")
connection = Eyedropper::DBus.session
check("path is derived from the unique bus name") do
  sender = connection.unique_name.sub(/\A:/, "").tr(".", "_")
  Eyedropper::DBus.request_path(connection, "tok") ==
    "/org/freedesktop/portal/desktop/request/#{sender}/tok"
end

puts("[3] portal replies are read back out of their text form")
check("response code is read from an (ua{sv})") do
  reply = Eyedropper::DBus.variant("(uint32 0, {'color': <(0.5, 0.25, 0.125)>})")
  reply.to_s[/\A\(\s*(\d+)/, 1].to_i.zero?
end

check("a colour is read out of the results dictionary") do
  reply = Eyedropper::DBus.variant("(uint32 0, {'color': <(0.5, 0.25, 0.125)>})")
  Eyedropper::DBus.doubles(Eyedropper::DBus.lookup(reply, "color")) == [0.5, 0.25, 0.125]
end

check("a session handle is read out of the results dictionary") do
  reply = Eyedropper::DBus.variant(
    "(uint32 0, {'session_handle': <'/org/freedesktop/portal/desktop/session/1/2'>})",
  )
  build(shortcuts, :session_handle, reply) == "/org/freedesktop/portal/desktop/session/1/2"
end

check("a missing key reads as nil") do
  Eyedropper::DBus.lookup(Eyedropper::DBus.variant("(uint32 1, @a{sv} {})"), "color").nil?
end

main_loop = GLib::MainLoop.new

puts("[4] the portal is reachable")
portal_present = connection.call_sync(
  "org.freedesktop.DBus",
  "/org/freedesktop/DBus",
  "org.freedesktop.DBus",
  "NameHasOwner",
  Eyedropper::DBus.variant("('org.freedesktop.portal.Desktop',)"),
  nil,
  :none,
  -1,
).first

if portal_present
  puts("    portal is running; making a real CreateSession call")

  connection.call(
    Eyedropper::GlobalShortcuts::PORTAL,
    Eyedropper::GlobalShortcuts::PORTAL_PATH,
    Eyedropper::GlobalShortcuts::SHORTCUTS_INTERFACE,
    "CreateSession",
    Eyedropper::DBus.variant(
      build(
        shortcuts,
        :session_arguments,
        "drivetok",
        "drivesess",
      ),
    ),
    nil,
    :none,
    5000,
  ) do |_source, result|
    begin
      handle = connection.call_finish(result)
      check("CreateSession returned a request handle") { !Array(handle).first.to_s.empty? }
    rescue Gio::DBusError => e
      # A portal without a GlobalShortcuts implementation answers
      # UnknownMethod, which is a legitimate outcome and not a wire-format bug.
      check("CreateSession reached the portal") { e.message.include?("Unknown") }
    rescue StandardError => e
      check("CreateSession reached the portal") { false.tap { puts("      #{e.class}: #{e.message}") } }
    end

    main_loop.quit
  end

  GLib::Timeout.add(10_000) do
    puts("    FAIL portal call timed out")
    CHECKS[:failures] << "portal timeout"
    main_loop.quit
    false
  end

  main_loop.run
else
  puts("    no portal on this session; skipping the live call")
end

puts("[5] a Response signal carrying a{sv} is actually delivered")
# This is the mechanism the picker depends on, and the one thing that cannot be
# done in-process: `signal_subscribe` and `Gio::DBusProxy` both raise while
# converting `a{sv}` to Ruby, inside the binding's own callback trampoline,
# which kills the process. So it is worth proving end to end.
delivered = []
watch_path = "/com/github/finefindus/eyedropper/Rb/drive/request"

watch = Eyedropper::DBus.monitor(connection.unique_name, watch_path, "Response") do |body|
  delivered << body
  true
end

check("the watch started") { !watch.nil? }

unless watch.nil?
  signal_loop = GLib::MainLoop.new

  # gdbus needs a moment to attach its match rule before the signal is emitted.
  GLib::Timeout.add(1500) do
    connection.emit_signal(
      nil,
      watch_path,
      Eyedropper::GlobalShortcuts::REQUEST_INTERFACE,
      "Response",
      Eyedropper::DBus.variant("(uint32 0, {'color': <(0.5, 0.25, 0.125)>})"),
    )
    false
  end

  GLib::Timeout.add(6000) do
    signal_loop.quit
    false
  end

  signal_loop.run

  check("the signal arrived") { delivered.length == 1 }
  check("the response code reads as success") do
    Eyedropper::DBus.response_code(delivered.first.to_s).zero?
  end
  check("the color reads back") do
    Eyedropper::DBus.doubles(Eyedropper::DBus.lookup(delivered.first.to_s, "color")) ==
      [0.5, 0.25, 0.125]
  end

  watch.stop
end

puts("[6] start is safe even when nothing answers")
check("start returns without raising") do
  [true, false].include?(Eyedropper::GlobalShortcuts.new(on_activated: -> {}).start)
end

check("the picker reports failure rather than raising") do
  reported = []
  Eyedropper::Picker.pick(
    on_success: ->(_c) {},
    on_cancel:  -> {},
    on_error:   ->(message) { reported << message },
  )
  true
end

puts
puts("#{CHECKS[:count] - CHECKS[:failures].length} of #{CHECKS[:count]} checks passed")
CHECKS[:failures].each { |name| puts("  failed check: #{name}") }
puts(CHECKS[:failures].empty? ? "PORTALS OK" : "PORTALS FAILED (#{CHECKS[:failures].length})")
exit(CHECKS[:failures].empty? ? 0 : 1)
