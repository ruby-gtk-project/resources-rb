# frozen_string_literal: true

require "adwaita"

require_relative "process_entry"
require_relative "units"

module Resources
  # ProcessDialog is the read-only detail dialog the Processes page opens for
  # a single row: usage figures plus the process's static properties.
  #
  # Ported from upstream's data/resources/ui/dialogs/process_dialog.ui and
  # src/ui/dialogs/process_dialog.rs. The GPU/encoder/decoder rows and the
  # control-group/containerization rows always read "N/A" here: upstream fills
  # them from `gpu.rb` and `app.rb`, neither of which exist yet in this port,
  # the same gap `ProcessEntry`'s own doc comment notes.
  class ProcessDialog
    NOT_AVAILABLE = "N/A"

    def initialize(process_entry, user)
      @process_entry = process_entry
      @user = user
    end

    def build
      dialog.tap do |alert|
        alert.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = scrolled_window

          scrolled_window.tap do |window|
            window.child = clamp

            clamp.tap do |area|
              area.child = box

              box.tap do |column|
                column.append(name_box)
                column.append(usage_group)
                column.append(properties_group)

                name_box.append(name_label)

                usage_group.tap do |group|
                  group.add(cpu_usage_row)
                  group.add(memory_usage_row)
                  group.add(swap_usage_row)
                  group.add(drive_read_speed_row)
                  group.add(drive_read_total_row)
                  group.add(drive_write_speed_row)
                  group.add(drive_write_total_row)
                  group.add(gpu_usage_row)
                  group.add(vram_usage_row)
                  group.add(encoder_usage_row)
                  group.add(decoder_usage_row)
                  group.add(total_cpu_time_row)
                  group.add(user_cpu_time_row)
                  group.add(system_cpu_time_row)
                end

                properties_group.tap do |group|
                  group.add(pid_row)
                  group.add(running_since_row)
                  group.add(commandline_row)
                  group.add(user_row)
                  group.add(cgroup_row)
                  group.add(containerized_row)
                end
              end
            end
          end
        end

        setup_widgets
      end
    end

    def present(parent)
      build.present(parent)
    end

    # Upstream's update: called whenever the row backing this dialog refreshes
    # while the dialog is still open.
    def update(process_entry)
      @process_entry = process_entry
      refresh_usage
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |alert|
        alert.width_request = 360
        alert.content_width = 480
        alert.content_height = 600
        alert.title = "Process Information"
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.title_widget = window_title }
    def window_title = @window_title ||= Adwaita::WindowTitle.new("", "").tap { |title| title.visible = false }
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

    def usage_group = @usage_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = "Usage" }

    def properties_group
      @properties_group ||= Adwaita::PreferencesGroup.new.tap { |group| group.title = "Properties" }
    end

    ROW_TITLES = {
      cpu_usage_row:         "Processor",
      memory_usage_row:      "Memory",
      swap_usage_row:        "Swap",
      drive_read_speed_row:  "Drive Read",
      drive_read_total_row:  "Drive Read Total",
      drive_write_speed_row: "Drive Write",
      drive_write_total_row: "Drive Write Total",
      gpu_usage_row:         "GPU",
      vram_usage_row:        "Video Memory",
      encoder_usage_row:     "Video Encoder",
      decoder_usage_row:     "Video Decoder",
      total_cpu_time_row:    "Total CPU Time",
      user_cpu_time_row:     "User CPU Time",
      system_cpu_time_row:   "System CPU Time",
      pid_row:               "Process ID",
      running_since_row:     "Running Since",
      commandline_row:       "Commandline",
      user_row:              "User",
      cgroup_row:            "Control Group",
      containerized_row:     "Containerized",
    }.freeze

    ROW_TITLES.each_key do |name|
      define_method(name) do
        @rows ||= {}
        @rows[name] ||= Adwaita::ActionRow.new.tap do |row|
          row.title = ROW_TITLES.fetch(name)
          row.css_classes = ["property"]
          row.subtitle_selectable = true
        end
      end
    end

    private

      def setup_widgets
        name_label.label = @process_entry.name
        user_row.subtitle = @user
        pid_row.subtitle = @process_entry.pid.to_s
        running_since_row.subtitle = @process_entry.running_since || NOT_AVAILABLE

        commandline = @process_entry.commandline.to_s.empty? ? NOT_AVAILABLE : @process_entry.commandline
        commandline_row.subtitle = commandline
        commandline_row.tooltip_text = commandline

        cgroup_row.subtitle = NOT_AVAILABLE
        cgroup_row.tooltip_text = NOT_AVAILABLE
        containerized_row.subtitle = NOT_AVAILABLE

        refresh_usage
      end

      def refresh_usage
        cpu_usage_row.subtitle = Units.convert_fraction(@process_entry.cpu_usage, false)
        memory_usage_row.subtitle = Units.convert_storage(@process_entry.memory_usage, false)
        swap_usage_row.subtitle = Units.convert_storage(@process_entry.swap_usage, false)

        drive_read_speed_row.subtitle = rate_or_na(@process_entry.read_speed) do |speed|
          Units.convert_speed(speed, false)
        end
        drive_read_total_row.subtitle = total_or_na(@process_entry.read_total) do |total|
          Units.convert_storage(total, false)
        end
        drive_write_speed_row.subtitle = rate_or_na(@process_entry.write_speed) do |speed|
          Units.convert_speed(speed, false)
        end
        drive_write_total_row.subtitle = total_or_na(@process_entry.write_total) do |total|
          Units.convert_storage(total, false)
        end

        gpu_usage_row.subtitle = NOT_AVAILABLE
        vram_usage_row.subtitle = NOT_AVAILABLE
        encoder_usage_row.subtitle = NOT_AVAILABLE
        decoder_usage_row.subtitle = NOT_AVAILABLE

        total_cpu_time_row.subtitle = Units.format_time(@process_entry.total_cpu_time)
        user_cpu_time_row.subtitle = Units.format_time(@process_entry.user_cpu_time)
        system_cpu_time_row.subtitle = Units.format_time(@process_entry.system_cpu_time)
      end

      def rate_or_na(speed)
        if speed == -1.0
          NOT_AVAILABLE
        else
          yield speed
        end
      end

      def total_or_na(total)
        if total == -1
          NOT_AVAILABLE
        else
          yield total
        end
      end
  end
end
