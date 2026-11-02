# frozen_string_literal: true

require "adwaita"

require_relative "cpu"
require_relative "graph_box"
require_relative "settings"
require_relative "units"

module Resources
  # CpuPage is the Processor view: total usage, per-thread usage, temperature
  # and the static properties `lscpu` reports.
  #
  # Ported from upstream's data/resources/ui/pages/cpu.ui and
  # src/ui/pages/cpu.rs. The sidebar metadata upstream exposes as GObject
  # properties (tab name, icon, usage, ordering) are plain readers here.
  class CpuPage
    TAB_ID = "cpu"
    PRIMARY_ORD = 2

    MAIN_GRAPH_COLOR = [0x35, 0x84, 0xe4].freeze
    TEMPERATURE_GRAPH_COLOR = [0x1a, 0x5f, 0xb4].freeze
    THREAD_GRAPH_COLOR = [28, 113, 216].freeze

    THREAD_GRAPH_HEIGHT = 72

    NOT_AVAILABLE = "N/A"

    def initialize(info)
      @info = info
      @logical_cpus = info.logical_cpus || 0
      @thread_boxes = []
      @old_total_usage = [0, 0]
      @old_thread_usages = []
      @usage = 0.0
      @tab_usage_string = ""
      @tab_detail_string = info.model_name.to_s
      seed_usage
    end

    # The sidebar metadata, mirroring upstream's page properties.
    def tab_id = TAB_ID
    def tab_name = "Processor"
    def icon_name = "processor-symbolic"
    def primary_ord = PRIMARY_ORD
    def secondary_ord = 0
    def uses_progress_bar = true
    def graph_locked_max_y = true
    def main_graph_color = MAIN_GRAPH_COLOR

    attr_reader :usage, :tab_usage_string, :tab_detail_string

    def build
      bin.tap do |page|
        page.child = scrolled_window

        scrolled_window.tap do |window|
          window.child = clamp

          clamp.tap do |area|
            area.child = box

            box.tap do |column|
              column.append(options_group)
              column.append(stack)
              column.append(sensors_group)
              column.append(properties_group)

              options_group.add(logical_switch)
              sensors_group.add(temperature_box.build)

              stack.tap do |pages|
                pages.add_named(total_group, "total")
                pages.add_named(logical_page, "logical")

                total_group.add(total_cpu.build)

                logical_page.tap do |logical|
                  logical.append(logical_heading)
                  logical.append(thread_box)

                  @thread_boxes.each { |graph_box| thread_box.append(thread_child(graph_box)) }
                end
              end

              PROPERTY_ROWS.each_key { |name| properties_group.add(property_row(name)) }
            end
          end
        end

        logical_switch.tap do |switch|
          switch.signal_connect("notify::active") { |widget| on_logical_toggled(widget) }
        end

        setup_widgets
      end
    end

    # Upstream's refresh_page: deltas against the previous reading, since
    # /proc/stat counts time since boot.
    def refresh_page(data)
      total_fraction = refresh_total(data.thread_usages)
      refresh_threads(data)
      refresh_temperature(data.temperature)
      refresh_uptime

      @usage = total_fraction
      @tab_usage_string = usage_string(total_fraction, data.temperature)
    end

    def bin = @bin ||= Adwaita::Bin.new
    def scrolled_window = @scrolled_window ||= Gtk::ScrolledWindow.new

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |area|
        area.maximum_size = 768
      end
    end

    def box
      @box ||= Gtk::Box.new(:vertical, 24).tap do |column|
        column.margin_top = 24
        column.margin_bottom = 24
        column.margin_start = 16
        column.margin_end = 16
        column.hexpand = true
        column.valign = :start
        column.vexpand = true
      end
    end

    def options_group
      @options_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Options"
      end
    end

    def logical_switch
      @logical_switch ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = "Show Usages of Logical CPUs"
        row.subtitle_selectable = true
        row.sensitive = false
      end
    end

    def stack
      @stack ||= Gtk::Stack.new.tap do |pages|
        pages.vhomogeneous = false
      end
    end

    def total_group
      @total_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Usage"
      end
    end

    def logical_page
      @logical_page ||= Gtk::Box.new(:vertical, 16).tap do |logical|
        logical.margin_top = 6
      end
    end

    def logical_heading
      @logical_heading ||= Gtk::Label.new("Usage").tap do |label|
        label.xalign = 0
        label.css_classes = ["heading", "h4"]
      end
    end

    def thread_box
      @thread_box ||= Gtk::FlowBox.new.tap do |flow|
        flow.row_spacing = 6
        flow.column_spacing = 6
        flow.homogeneous = true
        flow.selection_mode = :none
      end
    end

    def sensors_group
      @sensors_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Sensors"
      end
    end

    def properties_group
      @properties_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Properties"
      end
    end

    def total_cpu = @total_cpu ||= GraphBox.new
    def temperature_box = @temperature_box ||= GraphBox.new

    PROPERTY_ROWS = {
      max_speed:      "Max Frequency",
      logical_cpus:   "Logical Cores",
      physical_cpus:  "Physical Cores",
      sockets:        "Sockets",
      uptime:         "Uptime",
      virtualization: "Virtualization",
      architecture:   "Architecture",
    }.freeze

    def property_row(name)
      @property_rows ||= {}
      @property_rows[name] ||= Adwaita::ActionRow.new.tap do |row|
        row.title = PROPERTY_ROWS.fetch(name)
        row.css_classes = ["property"]
        row.subtitle_selectable = true
      end
    end

    private

      # Upstream's setup_widgets: seed the counters, build one box per logical
      # CPU, and fill in the static properties.
      def setup_widgets
        total_cpu.set_title_label("Total Usage")
        total_cpu.set_subtitle(NOT_AVAILABLE)
        colour(total_cpu.graph, MAIN_GRAPH_COLOR)

        temperature_box.set_title_label("Temperature")
        colour(temperature_box.graph, TEMPERATURE_GRAPH_COLOR)
        temperature_box.graph.locked_max_y = nil

        logical_switch.sensitive = @logical_cpus.positive?
        logical_switch.active = Settings.instance.show_logical_cpus?
        on_logical_toggled(logical_switch)

        fill_properties
      end

      def seed_usage
        usages = Cpu.usage
        @old_total_usage = sum_usages(usages)
        @old_thread_usages = Array.new(@logical_cpus) { |index| usages.fetch(index, [0, 0]) }
        @thread_boxes = Array.new(@logical_cpus) { |index| thread_graph_box(index) }
      end

      def thread_graph_box(index)
        GraphBox.new.tap do |graph_box|
          graph_box.set_title_label("CPU #{index + 1}")
          graph_box.set_subtitle(NOT_AVAILABLE)
          graph_box.graph.css_classes = ["small-graph"]
          graph_box.graph.height_request = THREAD_GRAPH_HEIGHT
          colour(graph_box.graph, THREAD_GRAPH_COLOR)
        end
      end

      def thread_child(graph_box)
        Gtk::FlowBoxChild.new.tap do |child|
          child.child = graph_box.build
          child.css_classes = ["tile", "card"]
          child.can_target = false
        end
      end

      def colour(graph, rgb)
        graph.set_graph_color(rgb[0], rgb[1], rgb[2])
      end

      def fill_properties
        property_row(:max_speed).subtitle = frequency_or_na(@info.max_speed)
        property_row(:logical_cpus).subtitle = count_or_na(@info.logical_cpus)
        property_row(:physical_cpus).subtitle = count_or_na(@info.physical_cpus)
        property_row(:sockets).subtitle = count_or_na(@info.sockets)
        property_row(:virtualization).subtitle = @info.virtualization || NOT_AVAILABLE
        property_row(:architecture).subtitle = @info.architecture || NOT_AVAILABLE
        refresh_uptime
      end

      def frequency_or_na(hertz)
        if hertz
          Units.convert_frequency(hertz)
        else
          NOT_AVAILABLE
        end
      end

      def count_or_na(count)
        if count
          count.to_s
        else
          NOT_AVAILABLE
        end
      end

      def refresh_uptime
        Cpu.uptime.then do |seconds|
          if seconds
            property_row(:uptime).subtitle = Units.format_time_integer(seconds.to_i)
          else
            property_row(:uptime).subtitle = NOT_AVAILABLE
          end
        end
      end

      def on_logical_toggled(switch)
        if switch.active?
          stack.visible_child_name = "logical"
        else
          stack.visible_child_name = "total"
        end
        Settings.instance.show_logical_cpus = switch.active?
      end

      def refresh_total(thread_usages)
        new_total = sum_usages(thread_usages)
        fraction = busy_fraction(@old_total_usage, new_total)
        @old_total_usage = new_total

        total_cpu.graph.push_data_point(fraction)
        total_cpu.set_subtitle(Units.convert_fraction(display_fraction(fraction), true))

        fraction
      end

      # Upstream multiplies the normalised fraction back up by the thread count
      # when the user has turned normalisation off.
      def display_fraction(fraction)
        if Settings.instance.normalize_cpu_usage?
          fraction
        else
          fraction * @logical_cpus
        end
      end

      def refresh_threads(data)
        unless @logical_cpus < 2
          @old_thread_usages.each_with_index do |old_usage, index|
            refresh_thread(data, index, old_usage)
          end
        end
      end

      def refresh_thread(data, index, old_usage)
        new_usage = data.thread_usages.fetch(index, [0, 0])
        fraction = busy_fraction(old_usage, new_usage)
        @old_thread_usages[index] = new_usage

        @thread_boxes.fetch(index).then do |graph_box|
          graph_box.graph.push_data_point(fraction)
          graph_box.set_subtitle(Units.convert_fraction(fraction, true))
          graph_box.set_title_label(thread_title(index, data.frequencies[index]))
        end
      end

      def thread_title(index, frequency)
        if frequency
          "CPU #{index + 1} · #{Units.convert_frequency(frequency.to_f)}"
        else
          "CPU #{index + 1}"
        end
      end

      def refresh_temperature(temperature)
        temperature_box.add_temperature_point(temperature)
      end

      def usage_string(fraction, temperature)
        percentage = Units.convert_fraction(display_fraction(fraction), true)
        if temperature
          "#{percentage} · #{Units.convert_temperature(temperature)}"
        else
          percentage
        end
      end

      def sum_usages(usages)
        usages.reduce([0, 0]) do |accumulator, usage|
          [accumulator[0] + usage[0], accumulator[1] + usage[1]]
        end
      end

      # Busy time is total time minus idle time, both as deltas.
      def busy_fraction(old_usage, new_usage)
        idle_delta = [new_usage[0] - old_usage[0], 0].max
        total_delta = [new_usage[1] - old_usage[1], 0].max
        busy = [total_delta - idle_delta, 0].max

        finite_or_zero(busy.to_f / total_delta)
      end

      def finite_or_zero(value)
        if value.finite?
          value
        else
          0.0
        end
      end
  end
end
