# frozen_string_literal: true

require "adwaita"

require_relative "process"
require_relative "process_action_dialog"
require_relative "process_dialog"
require_relative "process_entry"
require_relative "process_name_cell"
require_relative "process_options_dialog"
require_relative "units"

module Resources
  # ProcessesPage is the Processes view: every running process in a sortable,
  # searchable list, with actions to end/kill/halt/continue one or several and
  # dialogs to inspect or adjust one.
  #
  # Ported from upstream's data/resources/ui/pages/processes.ui and
  # src/ui/pages/processes/mod.rs. Upstream backs the list with a
  # GtkColumnView over a GListModel of GObject-backed ProcessEntry rows, whose
  # columns sort through GtkExpression property bindings; neither
  # GtkColumnView nor GtkExpression is reachable from these Ruby bindings
  # without the segfaults `gnome-system-monitor-rb`'s `list_refresh.rb`
  # documents, so the table here is a plain `Gtk::ListBox` of hand-built rows,
  # fully rebuilt in process order on every refresh and every search/sort
  # change -- the same rebuild-rather-than-bind approach this port's own
  # `CpuPage` already uses for its per-thread boxes. Per-column visibility
  # settings (`processes-show-*`) are not wired: the list always shows name,
  # PID, user, CPU and memory, upstream's four columns that default to
  # visible. GPU/encoder/decoder, priority and the drive-rate columns are left
  # out, matching the gaps `ProcessEntry` and `ProcessDialog` already carry
  # (no `gpu.rb`/`app.rb` in this port).
  class ProcessesPage
    TAB_ID = "processes"
    PRIMARY_ORD = 1

    MAIN_GRAPH_COLOR = [0x61, 0x35, 0x64].freeze

    NAME_COLUMN_WIDTH = -1
    PID_COLUMN_WIDTH = 72
    USER_COLUMN_WIDTH = 110
    CPU_COLUMN_WIDTH = 72
    MEMORY_COLUMN_WIDTH = 96

    SORT_KEYS = {
      "name"   => ->(entry) { entry.name.to_s.downcase },
      "pid"    => ->(entry) { entry.pid },
      "user"   => ->(entry) { entry.user.to_s.downcase },
      "cpu"    => ->(entry) { entry.cpu_usage },
      "memory" => ->(entry) { entry.combined_memory_usage },
    }.freeze

    def initialize
      @processes = {}
      @entries = {}
      @rows = {}
      @name_cells = {}
      @sort_key = "cpu"
      @sort_ascending = false
      @search_text = ""
      @usage = 0.0
      @tab_usage_string = ""
      @open_info_pid = nil
      @open_info_dialog = nil
      @open_options_pid = nil
    end

    def tab_id = TAB_ID
    def tab_name = "Processes"
    def tab_detail_string = ""
    def icon_name = "system-processes-symbolic"
    def primary_ord = PRIMARY_ORD
    def secondary_ord = 0
    def uses_progress_bar = false
    def graph_locked_max_y = true
    def main_graph_color = MAIN_GRAPH_COLOR

    attr_reader :usage, :tab_usage_string

    def build
      bin.tap do |page|
        page.child = toolbar_view
        page.insert_action_group("processes", action_group)

        toolbar_view.tap do |view|
          view.add_top_bar(search_entry)
          view.content = toast_overlay
          view.add_bottom_bar(bottom_bar)

          bottom_bar.tap do |bar|
            bar.append(options_button)
            bar.append(information_button)
            bar.append(end_process_button)
          end

          toast_overlay.tap do |overlay|
            overlay.child = content_box

            content_box.tap do |column|
              column.append(header_row)
              column.append(scrolled_window)

              header_row.tap do |row|
                row.append(name_header_button)
                row.append(pid_header_button)
                row.append(user_header_button)
                row.append(cpu_header_button)
                row.append(memory_header_button)
              end

              scrolled_window.child = list_box
            end
          end
        end

        setup_signals
      end
    end

    # Upstream's refresh, folded into one call: roll each still-running
    # process's counters forward, drop the ones that exited, rebuild the
    # derived rows, and keep any open info/options dialog in step.
    def refresh_page(fresh_processes)
      fresh_by_pid = fresh_processes.to_h { |process| [process.pid, process] }

      fresh_by_pid.each do |pid, fresh|
        if @processes[pid]
          @processes[pid].update(fresh.data)
        else
          @processes[pid] = fresh
        end
      end

      (@processes.keys - fresh_by_pid.keys).each do |pid|
        @processes.delete(pid)
        @entries.delete(pid)
      end

      @processes.each do |pid, process|
        if @entries[pid]
          @entries[pid].update(process)
        else
          @entries[pid] = ProcessEntry.new(process)
        end
      end

      rebuild_rows
      refresh_open_info_dialog
      update_selection_state

      @tab_usage_string = "Running Processes: #{@entries.size}"
    end

    def bin = @bin ||= Adwaita::Bin.new
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.placeholder_text = "Search processes"
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def header_row
      @header_row ||= Gtk::Box.new(:horizontal, 0).tap do |row|
        row.margin_start = 12
        row.margin_end = 12
        row.css_classes = ["caption-heading"]
      end
    end

    def name_header_button = @name_header_button ||= header_button("Name", "name", hexpand: true)
    def pid_header_button = @pid_header_button ||= header_button("PID", "pid", width: PID_COLUMN_WIDTH)
    def user_header_button = @user_header_button ||= header_button("User", "user", width: USER_COLUMN_WIDTH)
    def cpu_header_button = @cpu_header_button ||= header_button("CPU", "cpu", width: CPU_COLUMN_WIDTH)

    def memory_header_button
      @memory_header_button ||= header_button("Memory", "memory", width: MEMORY_COLUMN_WIDTH)
    end

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
        window.hexpand = true
        window.vexpand = true
      end
    end

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :multiple
        list.css_classes = ["boxed-list"]
        list.margin_start = 12
        list.margin_end = 12
        list.margin_bottom = 12
      end
    end

    def bottom_bar
      @bottom_bar ||= Gtk::Box.new(:horizontal, 16).tap do |box|
        box.margin_top = 16
        box.margin_bottom = 16
        box.margin_start = 16
        box.margin_end = 16
        box.hexpand = true
        box.halign = :end
      end
    end

    def options_button
      @options_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "options-symbolic"
        button.tooltip_text = "Show Process Options"
        button.action_name = "processes.options"
        button.css_classes = ["circular"]
      end
    end

    def information_button
      @information_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "info-symbolic"
        button.tooltip_text = "Show Process Information"
        button.action_name = "processes.information"
        button.css_classes = ["circular"]
      end
    end

    def end_process_button
      @end_process_button ||= Adwaita::SplitButton.new.tap do |button|
        button.label = "End Process"
        button.action_name = "processes.end-process"
        button.menu_model = end_process_menu
        button.css_classes = ["destructive-action"]
      end
    end

    def end_process_menu
      @end_process_menu ||= Gio::Menu.new.tap do |menu|
        menu.append("Kill Process", "processes.kill-process")
        menu.append("Halt Process", "processes.halt-process")
        menu.append("Continue Process", "processes.continue-process")
      end
    end

    def context_menu_model
      @context_menu_model ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, end_section)
        menu.append_section(nil, inspect_section)
      end
    end

    def end_section
      @end_section ||= Gio::Menu.new.tap do |section|
        section.append("End Process", "processes.end-process")
        section.append("Kill Process", "processes.kill-process")
        section.append("Halt Process", "processes.halt-process")
        section.append("Continue Process", "processes.continue-process")
      end
    end

    def inspect_section
      @inspect_section ||= Gio::Menu.new.tap do |section|
        section.append("Options", "processes.options")
        section.append("Information", "processes.information")
      end
    end

    def context_popover
      @context_popover ||= Gtk::PopoverMenu.new(context_menu_model).tap do |popover|
        popover.set_parent(list_box)
        popover.has_arrow = false
      end
    end

    def action_group
      @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(end_process_action)
        group.add_action(kill_process_action)
        group.add_action(halt_process_action)
        group.add_action(continue_process_action)
        group.add_action(options_action)
        group.add_action(information_action)
      end
    end

    def end_process_action
      @end_process_action ||= Gio::SimpleAction.new("end-process").tap do |action|
        action.enabled = false
        action.signal_connect("activate") { open_process_action_dialog(Process::Action::TERM) }
      end
    end

    def kill_process_action
      @kill_process_action ||= Gio::SimpleAction.new("kill-process").tap do |action|
        action.enabled = false
        action.signal_connect("activate") { open_process_action_dialog(Process::Action::KILL) }
      end
    end

    def halt_process_action
      @halt_process_action ||= Gio::SimpleAction.new("halt-process").tap do |action|
        action.enabled = false
        action.signal_connect("activate") { open_process_action_dialog(Process::Action::STOP) }
      end
    end

    def continue_process_action
      @continue_process_action ||= Gio::SimpleAction.new("continue-process").tap do |action|
        action.enabled = false
        action.signal_connect("activate") { continue_selected }
      end
    end

    def options_action
      @options_action ||= Gio::SimpleAction.new("options").tap do |action|
        action.enabled = false
        action.signal_connect("activate") { open_options_dialog }
      end
    end

    def information_action
      @information_action ||= Gio::SimpleAction.new("information").tap do |action|
        action.enabled = false
        action.signal_connect("activate") { open_information_dialog }
      end
    end

    private

      def header_button(label, key, hexpand: false, width: nil)
        Gtk::Button.new.tap do |button|
          button.label = label
          button.css_classes = ["flat"]
          button.hexpand = hexpand
          if width
            button.width_request = width
          end
          button.signal_connect("clicked") { on_header_clicked(key) }
        end
      end

      def setup_signals
        search_entry.signal_connect("search-changed") { on_search_changed }
        list_box.signal_connect("selected-rows-changed") { update_selection_state }
        list_box.signal_connect("row-activated") { |_list, row| on_row_activated(row) }
      end

      def on_search_changed
        @search_text = search_entry.text.to_s
        rebuild_rows
      end

      def on_header_clicked(key)
        if @sort_key == key
          @sort_ascending = !@sort_ascending
        else
          @sort_key = key
          @sort_ascending = key == "name" || key == "user"
        end
        rebuild_rows
      end

      def on_row_activated(row)
        pid_for_row(row).then { |pid| pid && open_information_dialog_for(pid) }
      end

      def pid_for_row(row)
        @rows.key(row)
      end

      # Upstream's secondary-click handler: the clicked row joins the
      # selection (becoming the only selected row unless it was already part
      # of a multi-selection), then the shared action-backed popover opens at
      # the pointer.
      def show_context_menu(pid, x, y)
        row = @rows[pid]
        if row && !row.selected?
          list_box.unselect_all
          list_box.select_row(row)
        end
        update_selection_state
        context_popover.pointing_to = Gdk::Rectangle.new(x.to_i, y.to_i, 0, 0)
        context_popover.popup
      end

      def selected_pids
        @rows.filter_map { |pid, row| pid if row.selected? }
      end

      def update_selection_state
        count = selected_pids.length
        multiple_enabled = count >= 1
        single_enabled = count == 1

        end_process_action.enabled = multiple_enabled
        kill_process_action.enabled = multiple_enabled
        halt_process_action.enabled = multiple_enabled
        continue_process_action.enabled = multiple_enabled
        options_action.enabled = single_enabled
        information_action.enabled = single_enabled
      end

      def open_process_action_dialog(action)
        pids = selected_pids
        if !pids.empty?
          entries = pids.filter_map { |pid| @entries[pid] }
          heading = action_dialog_heading(action, entries)
          ProcessActionDialog.new(
            heading:    heading,
            warning:    ProcessActionDialog.action_warning(action),
            action:     action,
            on_confirm: -> { entries.each { |entry| perform_action(entry.pid, action) } },
          ).present(bin.root)
        end
      end

      def action_dialog_heading(action, entries)
        if entries.length == 1
          ProcessActionDialog.action_name(action, entries.first.name)
        else
          ProcessActionDialog.action_name_multiple(action, entries.length)
        end
      end

      # Continuing a process has nothing destructive to confirm, so it skips
      # the dialog entirely, as upstream does.
      def continue_selected
        selected_pids.each { |pid| perform_action(pid, Process::Action::CONT) }
      end

      def perform_action(pid, action)
        @processes[pid]&.execute_process_action(action)
      end

      def open_options_dialog
        selected_pids.first.then do |pid|
          pid && @processes[pid].then do |process|
            @open_options_pid = pid
            ProcessOptionsDialog.new(process, @entries[pid].name, toast_overlay).present(bin.root)
          end
        end
      end

      def open_information_dialog
        selected_pids.first.then { |pid| pid && open_information_dialog_for(pid) }
      end

      def open_information_dialog_for(pid)
        @entries[pid].then do |entry|
          @open_info_pid = pid
          @open_info_dialog = ProcessDialog.new(entry, entry.user)
          @open_info_dialog.present(bin.root)
        end
      end

      # Keeps an open info dialog's figures live while its process keeps
      # running, mirroring upstream's open_info_dialog bookkeeping.
      def refresh_open_info_dialog
        if @open_info_pid
          entry = @entries[@open_info_pid]
          if entry
            @open_info_dialog&.update(entry)
          else
            @open_info_pid = nil
            @open_info_dialog = nil
          end
        end
      end

      def rebuild_rows
        list_box.remove_all
        @rows = {}
        @name_cells = {}

        sorted_entries.each do |entry|
          row = row_for(entry)
          @rows[entry.pid] = row
          list_box.append(row)
        end
      end

      def sorted_entries
        matching = @entries.values.select { |entry| matches_search?(entry) }
        key = SORT_KEYS.fetch(@sort_key)
        sorted = matching.sort_by { |entry| key.call(entry) }
        @sort_ascending ? sorted : sorted.reverse
      end

      def matches_search?(entry)
        if @search_text.empty?
          true
        else
          [entry.name, entry.user.to_s, entry.pid.to_s, entry.commandline.to_s].any? do |field|
            field.downcase.include?(@search_text.downcase)
          end
        end
      end

      def row_for(entry)
        Gtk::ListBoxRow.new.tap do |row|
          row.child = row_box(entry)
          row.add_controller(secondary_click_gesture(entry.pid))
        end
      end

      # A fresh secondary-click gesture per row, matching `rebuild_rows`
      # rebuilding every row from scratch each refresh.
      def secondary_click_gesture(pid)
        Gtk::GestureClick.new.tap do |gesture|
          gesture.button = 3
          gesture.signal_connect("pressed") { |_g, _n, x, y| show_context_menu(pid, x, y) }
        end
      end

      def row_box(entry)
        Gtk::Box.new(:horizontal, 12).tap do |box|
          box.margin_top = 6
          box.margin_bottom = 6
          box.margin_start = 6
          box.margin_end = 6

          box.append(name_cell(entry))
          box.append(value_label(entry.pid.to_s, PID_COLUMN_WIDTH, :end))
          box.append(value_label(entry.user.to_s, USER_COLUMN_WIDTH, :start))
          box.append(value_label(Units.convert_fraction(entry.cpu_usage, false), CPU_COLUMN_WIDTH, :end))
          box.append(value_label(Units.convert_storage(entry.combined_memory_usage, false), MEMORY_COLUMN_WIDTH, :end))
        end
      end

      # The ProcessNameCell wrapper is kept in `@name_cells`, alongside the
      # row widget in `@rows`, for as long as its built widget sits in the
      # list box -- the same reason `StackSidebarItem` is kept in
      # `StackSidebar#items` rather than discarded once built.
      def name_cell(entry)
        ProcessNameCell.new.tap do |cell|
          cell.name = entry.name
          cell.tooltip = tooltip_for(entry)
          @name_cells[entry.pid] = cell
        end.build
      end

      def tooltip_for(entry)
        if entry.commandline.to_s.empty?
          entry.name
        else
          entry.commandline
        end
      end

      def value_label(text, width, align)
        Gtk::Label.new(text).tap do |label|
          label.width_request = width
          label.xalign = alignment(align)
          label.ellipsize = :end
        end
      end

      def alignment(align)
        if align == :end
          1.0
        else
          0.0
        end
      end
  end
end
