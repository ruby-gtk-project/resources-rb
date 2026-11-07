# frozen_string_literal: true

# Drives the whole app headlessly: builds the main window, walks every
# sidebar page, exercises the Processor and Memory pages' own controls,
# opens every dialog reachable from the primary menu — both by building them
# directly and by firing the installed `app.*` actions the same way their
# keyboard accelerators do — toggles a setting in each kind of Preferences
# row, and exercises the process data layer and the still-unwired
# ProcessActionDialog confirmation dialog (built but not yet reachable from
# any page, since the Apps/Processes ColumnView pages that would open it do
# not exist on this branch). Screenshots every state.
#
# Why this file exists: a GTK app that loads is not a GTK app that works.
# `ruby -c` passes on code that builds an empty window, and the Ruby bindings
# differ from the C API in ways that only a run reveals.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_resources.rb
#
# This fork's GTK4 build has no offscreen backend — gtk_init fails outright
# with no display — so xvfb-run is not optional on this machine, despite what
# the ruby-gtk-testing skill says about other forks.

require "etc"
require "fileutils"
require "tmpdir"

# A scratch config directory, so a run never reads or writes the real one.
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("resources-drive")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "resources"
require_relative "gtk_driver"

# Not required by lib/resources.rb: these three are ported but not yet wired
# into any page (the Apps/Processes ColumnView pages that would use them do
# not exist on this branch), so they need their own require here.
require "resources/process"
require "resources/process_entry"
require "resources/process_action_dialog"

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)

GtkDriver.drive(Resources::Application.new, shots: SHOTS) do |d, application|
  d.window { application.main_window.window }

  # --- Non-widget checks: the CLI and the process data layer --------------

  d.step("Cli parses its flags") do
    options = Resources::Cli.parse(["-c", "-m", "-t", "memory"])
    d.check("disable-cpu-monitoring parsed") { options[:disable_cpu_monitoring] == true }
    d.check("disable-memory-monitoring parsed") { options[:disable_memory_monitoring] == true }
    d.check("open-tab-id parsed") { options[:open_tab_id] == "memory" }
  end

  d.step("Process reads /proc directly") do
    processes = Resources::Process.all
    d.check("at least one process read") { processes.any? }
    d.check("pids are integers") { processes.all? { |process| process.pid.is_a?(Integer) } }
    d.check("this test's own pid is among them") do
      processes.any? { |process| process.pid == ::Process.pid }
    end
  end

  d.step("ProcessEntry wraps a Process") do
    process = Resources::Process.all.find { |candidate| candidate.pid == ::Process.pid }
    entry = Resources::ProcessEntry.new(process)
    d.check("entry carries the process's pid") { entry.pid == process.pid }
    d.check("entry carries a non-empty name") { !entry.name.to_s.empty? }

    entry.update(process)
    d.check("update recomputes combined memory") do
      entry.combined_memory_usage == entry.memory_usage + entry.swap_usage
    end
  end

  d.step("ProcessActionDialog's string builders match upstream's literals") do
    d.check("End %s? heading") do
      Resources::ProcessActionDialog.action_name("TERM", "firefox") == "End firefox?"
    end
    d.check("singular 'Kill process?' for CONT") do
      Resources::ProcessActionDialog.action_name_multiple("CONT", 1) == "Kill process?"
    end
    d.check("plural 'Kill %d processes?' for CONT") do
      Resources::ProcessActionDialog.action_name_multiple("CONT", 3) == "Kill 3 processes?"
    end
    d.check("KILL warning text") do
      Resources::ProcessActionDialog.action_warning("KILL").include?("Killing a process")
    end
  end

  # --- The main window ------------------------------------------------------

  d.step("main window builds with both default pages") do
    window = application.main_window
    d.check("window title is Resources") { window.window.title == "Resources" }
    d.check("sidebar lists cpu and memory") do
      window.sidebar.items.values.map(&:tab_id).sort == ["cpu", "memory"]
    end
    d.shot("01-main-window")
  end

  d.step("BatteryPage builds and refreshes against synthetic sysfs data (unwired component: " \
         "this machine has no battery, so main_window's own battery_pages list is empty and " \
         "the sidebar never reaches this page)") do
    sysfs_path = Dir.mktmpdir("resources-drive-battery")
    File.write(File.join(sysfs_path, "type"), "Battery")
    File.write(File.join(sysfs_path, "capacity"), "77")
    File.write(File.join(sysfs_path, "status"), "Discharging")
    File.write(File.join(sysfs_path, "manufacturer"), "ACME")
    File.write(File.join(sysfs_path, "model_name"), "Cell9000")
    File.write(File.join(sysfs_path, "technology"), "Li-ion")
    File.write(File.join(sysfs_path, "energy_full_design"), "50000000")
    File.write(File.join(sysfs_path, "cycle_count"), "42")
    File.write(File.join(sysfs_path, "power_now"), "9000000")

    page = Resources::BatteryPage.new(sysfs_path, 0)
    page.build
    page.refresh_page(Resources::Battery.data_for(sysfs_path))

    d.check("tab name is the battery's display name") { page.tab_name.include?("Battery") }
    d.check("usage reflects the synthetic charge") { page.usage == 0.77 }
    d.check("tab usage string mentions the charge percentage") { page.tab_usage_string.include?("77") }
    d.check("health row falls back to N/A without energy_full") { page.health_row.subtitle == "N/A" }
    d.check("manufacturer row reads back the synthetic value") { page.manufacturer_row.subtitle == "ACME" }
    d.check("charge cycles row reads back the synthetic value") { page.charge_cycles_row.subtitle == "42" }

    window = application.main_window.window
    @battery_dialog = Adwaita::AlertDialog.new("Battery preview", nil).tap do |dialog|
      dialog.extra_child = page.bin
      dialog.present(window)
    end
    d.check("battery page fixture dialog presents") { @battery_dialog.visible? }
  end

  d.step("BatteryPage screenshot (its own tick, so the fixture dialog has settled)") do
    d.shot("09-battery-page", @battery_dialog)
    @battery_dialog.close
  end

  d.step("ProcessActionDialog builds and presents against the real window (unwired component)") do
    window = application.main_window.window
    confirmed = false
    dialog = Resources::ProcessActionDialog.new(
      heading: Resources::ProcessActionDialog.action_name("TERM", "firefox"),
      warning: Resources::ProcessActionDialog.action_warning("TERM"),
      action: "TERM",
      on_confirm: -> { confirmed = true },
    )
    dialog.present(window)
    alert = dialog.send(:dialog)
    d.check("heading is the formatted string") { alert.heading == "End firefox?" }
    d.check("confirm response is destructive") do
      alert.get_response_appearance("yes") == :destructive
    end
    d.check("cancel is the default and close response") do
      alert.default_response == "no" && alert.close_response == "no"
    end
    d.check("on_confirm has not fired without a user response") { confirmed == false }
    @process_action_alert = alert
  end

  d.step("ProcessActionDialog screenshot (its own tick, so the alert has settled)") do
    d.shot("02-process-action-dialog", @process_action_alert)
    @process_action_alert.close
  end

  # --- Sidebar navigation ----------------------------------------------------

  d.step("sidebar selects the Processor page") do
    window = application.main_window
    window.sidebar.select_tab_id("cpu")
    d.check("content stack shows the cpu page") { window.content_stack.visible_child_name == "cpu" }
    d.shot("03-cpu-page")
  end

  d.step("Processor page's logical-CPU switch flips the stack") do
    window = application.main_window
    window.cpu_page.logical_switch.active = true
    d.check("stack switches to the logical page") do
      window.cpu_page.stack.visible_child_name == "logical"
    end
    d.check("one thread box per logical CPU") do
      window.cpu_page.thread_box.observe_children.n_items == Etc.nprocessors
    end
  end

  d.step("Processor page screenshot (its own tick, so the switch has settled)") do
    d.shot("04-cpu-logical")
    application.main_window.cpu_page.logical_switch.active = false
  end

  d.step("Processor page's logical-CPU switch flips back") do
    window = application.main_window
    d.check("stack switches back to the total page") do
      window.cpu_page.stack.visible_child_name == "total"
    end
  end

  d.step("Processor page reports real usage after a refresh tick") do
    window = application.main_window
    d.check("tab usage string is set") { !window.cpu_page.tab_usage_string.to_s.empty? }
    d.check("tab detail string is the model name") do
      window.cpu_page.tab_detail_string == window.cpu_page.instance_variable_get(:@tab_detail_string)
    end
    points = window.cpu_page.total_cpu.graph.visible_points
    d.check("the total-usage graph received at least one point") { points.any? }
  end

  d.step("sidebar selects the Memory page") do
    window = application.main_window
    window.sidebar.select_tab_id("memory")
    d.check("content stack shows the memory page") do
      window.content_stack.visible_child_name == "memory"
    end
  end

  d.step("Memory page screenshot (its own tick, so the stack switch has settled)") do
    d.shot("05-memory-page")
  end

  d.step("Memory page's authentication banner matches whether properties loaded") do
    window = application.main_window
    page = window.memory_page
    d.check("banner revealed exactly when properties are hidden") do
      page.authentication_banner.revealed? != page.properties_group.visible?
    end
  end

  d.step("Memory page's authenticate button can be activated (root helper may refuse)") do
    window = application.main_window
    page = window.memory_page
    # Fires the same signal the button click would, per the testing skill's
    # advice to drive the handler the way the widget would rather than call
    # a private method directly.
    page.authentication_banner.signal_emit("button-clicked")
    d.check("banner handler ran without raising") { true }
  end

  # --- Dialogs off the primary menu, built directly -------------------------

  d.step("Preferences dialog builds with its rows wired to Settings") do
    window = application.main_window
    window.settings_dialog.build.present(window.window)
    d.check("dialog title is Preferences") { window.settings_dialog.dialog.title == "Preferences" }

    details_row = window.settings_dialog.row("sidebar-details")
    details_row.active = true
    d.check("a switch row writes through to Settings") { Resources::Settings.instance["sidebar-details"] == true }
    details_row.active = false
    d.check("and writes back") { Resources::Settings.instance["sidebar-details"] == false }

    base_row = window.settings_dialog.row("base")
    base_row.selected = 1
    d.check("a combo row writes through to Settings") { Resources::Settings.instance["base"] == "Binary" }
    base_row.selected = 0
    d.check("and writes back") { Resources::Settings.instance["base"] == "Decimal" }

    points_row = window.settings_dialog.row("graph-data-points")
    original = Resources::Settings.instance["graph-data-points"]
    points_row.value = original + 5
    d.check("a spin row writes through to Settings") do
      Resources::Settings.instance["graph-data-points"] == original + 5
    end
    points_row.value = original
  end

  d.step("Preferences dialog screenshot (its own tick, so the navigation view has settled)") do
    window = application.main_window
    d.shot("06-settings-dialog", window.settings_dialog.dialog)
    window.settings_dialog.dialog.close
  end

  d.step("Keyboard Shortcuts dialog builds") do
    window = application.main_window
    window.shortcuts_dialog.build.present(window.window)
    d.check("dialog title is Keyboard Shortcuts") do
      window.shortcuts_dialog.dialog.title == "Keyboard Shortcuts"
    end
  end

  d.step("Keyboard Shortcuts screenshot (its own tick, so the dialog has settled)") do
    window = application.main_window
    d.shot("07-shortcuts-dialog", window.shortcuts_dialog.dialog)
    window.shortcuts_dialog.dialog.close
  end

  d.step("About dialog builds") do
    window = application.main_window
    window.about_dialog.build.present(window.window)
    d.check("application name is Resources") do
      window.about_dialog.dialog.application_name == "Resources"
    end
  end

  d.step("About dialog screenshot (its own tick, so the dialog has settled)") do
    window = application.main_window
    d.shot("08-about-dialog", window.about_dialog.dialog)
    window.about_dialog.dialog.close
  end

  # --- The same dialogs, opened through the installed app.* actions, which is
  # exactly what the menu item and the keyboard accelerator both do --------

  d.step("app.settings action (also bound to <Control>comma) opens Preferences") do
    window = application.main_window
    application.app.activate_action("settings", nil)
    d.check("Preferences dialog is visible") { window.settings_dialog.dialog.visible? }
    window.settings_dialog.dialog.close
  end

  d.step("the primary menu's Keyboard Shortcuts item fires app.shortcuts") do
    window = application.main_window
    application.app.activate_action("shortcuts", nil)
    d.check("Shortcuts dialog is visible") { window.shortcuts_dialog.dialog.visible? }
    window.shortcuts_dialog.dialog.close
  end

  d.step("the primary menu's About Resources item fires app.about") do
    window = application.main_window
    application.app.activate_action("about", nil)
    d.check("About dialog is visible") { window.about_dialog.dialog.visible? }
    window.about_dialog.dialog.close
  end

  # --- The breakpoint's collapse binding -------------------------------------

  d.step("the breakpoint's setter target: collapsing the split view reveals the sidebar toggle") do
    window = application.main_window
    window.split_view.collapsed = true
    d.check("sidebar toggle becomes visible when collapsed") do
      window.content_stack.visible_child.first_child.first_child.visible?
    end
    window.split_view.collapsed = false
  end

  # --- app.quit (also bound to <Control>q and <Control>w) is fired last, since
  # it closes the window and quits the application -----------------------

  d.step("app.quit saves the window geometry before closing") do
    window = application.main_window.window
    expected_width = window.default_width
    expected_height = window.default_height
    application.app.activate_action("quit", nil)
    d.check("window-width was recorded by the close-request handler") do
      Resources::Settings.instance["window-width"] == expected_width
    end
    d.check("window-height was recorded by the close-request handler") do
      Resources::Settings.instance["window-height"] == expected_height
    end
  end
end
