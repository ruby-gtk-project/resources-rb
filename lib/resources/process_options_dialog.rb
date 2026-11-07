# frozen_string_literal: true

require "adwaita"

require_relative "process"
require_relative "settings"

module Resources
  # ProcessOptionsDialog is the dialog the Processes page opens to renice a
  # process and set which logical CPUs it may run on.
  #
  # Ported from upstream's data/resources/ui/dialogs/process_options_dialog.ui
  # and src/ui/dialogs/process_options_dialog.rs. Upstream sends the change
  # through an async action channel to a central controller that shows a
  # toast; this calls `Process#adjust`/`Process#set_affinity` directly and
  # shows the toast itself on the overlay it is given.
  class ProcessOptionsDialog
    NICE_MIN = -20
    NICE_MAX = 19

    # Upstream's NICE_TO_LABEL, folded into ranges rather than one entry per
    # niceness value.
    PRIORITY_RANGES = [
      [(-20..-8), "Very High", 0],
      [(-7..-3), "High", 1],
      [(-2..2), "Normal", 2],
      [(3..6), "Low", 3],
      [(7..19), "Very Low", 4],
    ].freeze

    # `process` is a Resources::Process (not a ProcessEntry: this dialog acts
    # on the process, it only reads its current name/pid/niceness/affinity to
    # seed the widgets); `name` is the display name to show and to report in
    # the toast.
    def initialize(process, name, toast_overlay)
      @process = process
      @name = name
      @toast_overlay = toast_overlay
      @cpu_rows = []
    end

    def build
      dialog.tap do |alert|
        alert.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.add_bottom_bar(bottom_bar)
          view.content = scrolled_window

          bottom_bar.append(apply_button)

          scrolled_window.tap do |window|
            window.child = clamp

            clamp.tap do |area|
              area.child = box

              box.tap do |column|
                column.append(name_box)
                column.append(options_group)

                name_box.append(name_label)

                options_group.tap do |group|
                  group.add(nice_row)
                  group.add(priority_row)
                  group.add(affinity_row)
                end
              end
            end
          end
        end

        setup_widgets
        setup_signals
      end
    end

    def present(parent)
      build.present(parent)
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |alert|
        alert.width_request = 360
        alert.content_width = 480
        alert.content_height = 600
        alert.title = "Process Options"
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.title_widget = window_title }
    def window_title = @window_title ||= Adwaita::WindowTitle.new("", "").tap { |title| title.visible = false }

    def bottom_bar
      @bottom_bar ||= Gtk::Box.new(:horizontal, 16).tap do |box|
        box.hexpand = true
        box.margin_top = 16
        box.margin_bottom = 16
        box.margin_start = 16
        box.margin_end = 16
      end
    end

    def apply_button
      @apply_button ||= Gtk::Button.new.tap do |button|
        button.label = "Apply"
        button.halign = :center
        button.hexpand = true
        button.css_classes = ["pill", "suggested-action"]
      end
    end

    def scrolled_window = @scrolled_window ||= Gtk::ScrolledWindow.new.tap { |window| window.vexpand = true }
    def clamp = @clamp ||= Adwaita::Clamp.new

    def box
      @box ||= Gtk::Box.new(:vertical, 16).tap do |column|
        column.margin_bottom = 16
        column.margin_start = 16
        column.margin_end = 16
      end
    end

    def name_box = @name_box ||= Gtk::Box.new(:vertical, 8)

    def name_label
      @name_label ||= Gtk::Label.new.tap do |label|
        label.hexpand = true
        label.wrap = true
        label.css_classes = ["title-2"]
      end
    end

    def options_group
      @options_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = "Process Options" }
    end

    def nice_row
      @nice_row ||= Adwaita::SpinRow.new(nice_adjustment, 1, 0).tap do |row|
        row.title = "Niceness"
        row.subtitle = "The priority of a process is given by its niceness. A lower niceness " \
          "value correspond to a higher priority."
        row.snap_to_ticks = true
      end
    end

    def nice_adjustment = @nice_adjustment ||= Gtk::Adjustment.new(0, NICE_MIN, NICE_MAX, 1, 5, 0)

    def priority_row
      @priority_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = "Priority"
        row.model = Gtk::StringList.new(PRIORITY_RANGES.map { |(_, label, _)| label })
      end
    end

    def affinity_row
      @affinity_row ||= Adwaita::ExpanderRow.new.tap do |row|
        row.title = "Processor Affinity"
        row.subtitle = "Select which processor cores the process is allowed to run on"
        row.add_suffix(select_all_button)
      end
    end

    def select_all_button
      @select_all_button ||= Gtk::Button.new.tap do |button|
        button.valign = :center
        button.icon_name = "select-all-symbolic"
        button.tooltip_text = "Toggle All"
      end
    end

    attr_reader :cpu_rows

    private

      def setup_widgets
        name_label.label = @name
        nice_row.value = current_process_niceness.to_f

        priority_row.selected = priority_index_for(current_process_niceness)
        if Settings.instance.detailed_priority?
          priority_row.visible = false
        else
          nice_row.visible = false
        end

        @process.affinity.each_with_index do |active, index|
          affinity_row.add_row(cpu_row(index, active))
        end
      end

      def cpu_row(index, active)
        Adwaita::SwitchRow.new.tap do |row|
          row.title = "CPU #{index + 1}"
          row.active = active
          row.signal_connect("notify::active") { on_cpu_row_toggled }
          @cpu_rows << row
        end
      end

      def on_cpu_row_toggled
        apply_button.sensitive = @cpu_rows.any?(&:active?)
      end

      def setup_signals
        select_all_button.signal_connect("clicked") { on_select_all }
        apply_button.signal_connect("clicked") { on_apply }
      end

      def on_select_all
        setting = !@cpu_rows.all?(&:active?)
        @cpu_rows.each { |row| row.active = setting }
      end

      def on_apply
        @process.adjust(current_niceness)
        @process.set_affinity(@cpu_rows.map(&:active?))
        @toast_overlay.add_toast(Adwaita::Toast.new("Applied settings for #{@name}"))
      end

      def current_niceness
        if priority_row.visible?
          PRIORITY_RANGES.fetch(priority_row.selected).first.first
        else
          nice_row.value.to_i
        end
      end

      def priority_index_for(niceness)
        PRIORITY_RANGES.each_with_index.find { |(range, _, _), _| range.cover?(niceness) }&.last || 2
      end

      def current_process_niceness
        ::Process.getpriority(::Process::PRIO_PROCESS, @process.pid)
      rescue Errno::ESRCH
        0
      end
  end
end
