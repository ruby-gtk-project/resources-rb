# frozen_string_literal: true

# Opens the main window, lets the refresh loop run a few times, screenshots
# nothing and quits. Run it with:
#   nix develop --command xvfb-run -a ruby test/drive_main_window.rb
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "resources"

Resources::Application.new.then do |application|
  application.build
  GLib::Timeout.add(4000) do
    puts "window title: #{application.main_window.window.title}"
    puts "pages: #{application.main_window.pages.map(&:tab_id).join(", ")}"
    puts "cpu usage string: #{application.main_window.cpu_page.tab_usage_string}"
    puts "memory usage string: #{application.main_window.memory_page.tab_usage_string}"
    puts "cpu detail: #{application.main_window.cpu_page.tab_detail_string}"
    puts "memory detail: #{application.main_window.memory_page.tab_detail_string}"
    points = application.main_window.cpu_page.total_cpu.graph.visible_points
    puts "cpu graph points pushed: #{points.count { |value| value.positive? }}"
    application.app.quit
    false
  end
  application.run
end
