# frozen_string_literal: true

# Opens every dialog the primary menu reaches, toggles the Processor page's
# logical-CPU switch and selects each sidebar row, so a binding mistake in any
# of them fails here rather than in front of a user. Run it with:
#   nix develop --command xvfb-run -a ruby test/drive_dialogs.rb
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "resources"

Resources::Application.new.then do |application|
  application.build
  GLib::Timeout.add(2500) do
    window = application.main_window
    puts "sidebar rows: #{window.sidebar.items.values.map(&:tab_id).join(", ")}"

    window.settings_dialog.build.present(window.window)
    puts "settings dialog: #{window.settings_dialog.dialog.title}"
    window.shortcuts_dialog.build.present(window.window)
    puts "shortcuts dialog: #{window.shortcuts_dialog.dialog.title}"
    window.about_dialog.build.present(window.window)
    puts "about dialog: #{window.about_dialog.dialog.application_name}"

    window.cpu_page.logical_switch.active = true
    puts "cpu stack page: #{window.cpu_page.stack.visible_child_name}"
    puts "thread boxes: #{window.cpu_page.thread_box.observe_children.n_items}"

    window.sidebar.select_tab_id("memory")
    puts "visible page: #{window.content_stack.visible_child_name}"

    application.app.quit
    false
  end
  application.run
end
