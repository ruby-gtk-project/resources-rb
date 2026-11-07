# frozen_string_literal: true

require "adwaita"

require_relative "battery"
require_relative "graph_box"
require_relative "units"

module Resources
  # BatteryPage is one battery's view: charge and power-usage graphs plus a
  # group of static properties (health, design capacity, cycles, technology,
  # manufacturer, model, sysfs device name).
  #
  # Ported from upstream's data/resources/ui/pages/battery.ui and
  # src/ui/pages/battery.rs. Upstream creates one `ResBattery` per detected
  # battery (`secondary_ord` disambiguating the sidebar sort when there is
  # more than one); this mirrors that with one `BatteryPage` per sysfs path.
  class BatteryPage
    TAB_ID_PREFIX = "battery"
    PRIMARY_ORD = 5

    MAIN_GRAPH_COLOR = [0x33, 0xd1, 0x7a].freeze
    POWER_GRAPH_COLOR = [0x26, 0xa2, 0x69].freeze

    NOT_AVAILABLE = "N/A"

    def initialize(sysfs_path, secondary_ord)
      @sysfs_path = sysfs_path
      @secondary_ord = secondary_ord
      @usage = 0.0
      @tab_usage_string = ""
      @tab_detail_string = ""
    end

    def tab_id = @tab_id ||= "#{TAB_ID_PREFIX}-#{manufacturer}-#{model_name}-#{File.basename(@sysfs_path)}"
    def tab_name = @info.display_name
    def icon_name = "battery-symbolic"
    def primary_ord = PRIMARY_ORD
    def secondary_ord = @secondary_ord
    def uses_progress_bar = true
    def graph_locked_max_y = true
    def main_graph_color = MAIN_GRAPH_COLOR

    attr_reader :usage, :tab_usage_string, :tab_detail_string, :sysfs_path

    def build
      @info = Battery.info_for(@sysfs_path)
      @initial_data = Battery.data_for(@sysfs_path)
      @tab_detail_string = File.basename(@sysfs_path)

      bin.tap do |page|
        page.child = scrolled_window

        scrolled_window.tap do |window|
          window.child = clamp

          clamp.tap do |area|
            area.child = content_box

            content_box.tap do |content|
              content.append(usage_group)
              content.append(properties_group)

              usage_group.add(charge_box.build)
              usage_group.add(power_box.build)

              properties_group.add(health_row)
              properties_group.add(design_capacity_row)
              properties_group.add(charge_cycles_row)
              properties_group.add(technology_row)
              properties_group.add(manufacturer_row)
              properties_group.add(model_name_row)
              properties_group.add(device_row)
            end
          end
        end

        setup_widgets
      end
    end

    # Upstream's refresh_page.
    def refresh_page(data)
      usage_string = []

      if data.charge
        charge_box.graph.visible = true
        charge_box.graph.push_data_point(data.charge)
        percentage = Units.convert_fraction(data.charge, true)
        state = Battery.status_to_state(data.state)
        charge_box.set_subtitle("#{percentage} (#{state})")
        usage_string << percentage
      else
        charge_box.graph.visible = false
        charge_box.set_subtitle(NOT_AVAILABLE)
      end
      @usage = data.charge || 0.0

      if data.power_usage
        usage_string << Units.convert_power(data.power_usage)
      end
      power_box.add_power_point(data.power_usage, nil)

      @tab_usage_string = usage_string.join(" · ")

      health_row.subtitle = data.health ? Units.convert_fraction(data.health, true) : NOT_AVAILABLE
    end

    def bin = @bin ||= Adwaita::Bin.new
    def scrolled_window = @scrolled_window ||= Gtk::ScrolledWindow.new

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |area|
        area.maximum_size = 768
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 24).tap do |content|
        content.margin_top = 24
        content.margin_bottom = 24
        content.margin_start = 16
        content.margin_end = 16
        content.hexpand = true
        content.valign = :start
        content.vexpand = true
      end
    end

    def usage_group
      @usage_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Usage"
      end
    end

    def properties_group
      @properties_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Properties"
      end
    end

    def charge_box = @charge_box ||= GraphBox.new
    def power_box = @power_box ||= GraphBox.new

    def health_row
      @health_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = "Health"
        row.css_classes = ["property"]
        row.subtitle_selectable = true
      end
    end

    def design_capacity_row
      @design_capacity_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = "Design Capacity"
        row.css_classes = ["property"]
        row.subtitle_selectable = true
      end
    end

    def charge_cycles_row
      @charge_cycles_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = "Charge Cycles"
        row.css_classes = ["property"]
        row.subtitle_selectable = true
      end
    end

    def technology_row
      @technology_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = "Technology"
        row.css_classes = ["property"]
        row.subtitle_selectable = true
      end
    end

    def manufacturer_row
      @manufacturer_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = "Manufacturer"
        row.css_classes = ["property"]
        row.subtitle_selectable = true
      end
    end

    def model_name_row
      @model_name_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = "Model Name"
        row.css_classes = ["property"]
        row.subtitle_selectable = true
      end
    end

    def device_row
      @device_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = "Device"
        row.css_classes = ["property"]
        row.subtitle_selectable = true
      end
    end

    private

      def manufacturer = @info.manufacturer || ""
      def model_name = @info.model_name || ""

      def setup_widgets
        charge_box.set_title_label("Battery Charge")
        charge_box.graph.set_graph_color(*MAIN_GRAPH_COLOR)

        power_box.set_title_label("Power Usage")
        power_box.graph.set_graph_color(*POWER_GRAPH_COLOR)
        power_box.graph.locked_max_y = nil

        design_capacity_row.subtitle = @info.design_capacity ? Units.convert_energy(@info.design_capacity, false) : NOT_AVAILABLE
        charge_cycles_row.subtitle = @initial_data.charge_cycles ? @initial_data.charge_cycles.to_s : NOT_AVAILABLE
        technology_row.subtitle = @info.technology
        manufacturer_row.subtitle = @info.manufacturer || NOT_AVAILABLE
        model_name_row.subtitle = @info.model_name || NOT_AVAILABLE
        device_row.subtitle = File.basename(@sysfs_path)
      end
  end
end
