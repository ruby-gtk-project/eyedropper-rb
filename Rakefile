# frozen_string_literal: true

require "rake/testtask"

SCHEMA_DIR = "build/share/glib-2.0/schemas"

desc "Compile the GSettings schema into build/share so the app can find it"
task :schema do
  mkdir_p(SCHEMA_DIR)
  cp(Dir["data/*.gschema.xml"], SCHEMA_DIR)
  sh("glib-compile-schemas", SCHEMA_DIR)
end

Rake::TestTask.new(:test) do |t|
  t.libs << "lib" << "test"
  t.test_files = FileList["test/test_*.rb"]
  t.warning = false
end

desc "Drive the real window headlessly"
task drive: :schema do
  sh("env -u DISPLAY -u WAYLAND_DISPLAY ruby test/drive_window.rb")
end

desc "Serve the search provider on the session bus and call it back"
task drive_search: :schema do
  sh("ruby test/drive_search_provider.rb")
end

desc "Exercise the portal clients against the session's real portal"
task drive_portals: :schema do
  sh("ruby test/drive_portals.rb")
end

desc "Run rubocop"
task :lint do
  sh("rubocop")
end

task default: %i[test lint]

desc "Every check: units, the window, the search provider, the portals, and lint"
task check: %i[test drive drive_search drive_portals lint]
