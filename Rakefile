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

desc "Run rubocop"
task :lint do
  sh("rubocop")
end

task default: %i[test lint]
