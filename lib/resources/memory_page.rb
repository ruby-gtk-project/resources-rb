# frozen_string_literal: true

require "adwaita"

require_relative "graph_box"
require_relative "memory"
require_relative "units"

module Resources
  # MemoryPage is the Memory view: memory and swap usage, and the per-slot
  # description of the installed modules.
  #
  # Ported from upstream's data/resources/ui/pages/memory.ui and
  # src/ui/pages/memory.rs, including the banner upstream shows when the
  # module description needs elevated privileges to read.
  class MemoryPage
    TAB_ID = "memory"
    PRIMARY_ORD = 3

    MAIN_GRAPH_COLOR = [0xc5, 0x2f, 0x90].freeze
    SWAP_GRAPH_COLOR = [0x94, 0x29, 0x7c].freeze

    NOT_AVAILABLE = "N/A"

    def initialize
      @memory_devices = []
      @usage = 0.0
      @tab_usage_string = ""
      @tab_detail_string = ""
    end

    # The sidebar metadata, mirroring upstream's page properties.
    def tab_id = TAB_ID
    def tab_name = "Memory"
    def icon_name = "memory-symbolic"
    def primary_ord = PRIMARY_ORD
    def secondary_ord = 0
    def uses_progress_bar = true
    def graph_locked_max_y = true
    def main_graph_color = MAIN_GRAPH_COLOR

    attr_reader :usage, :tab_usage_string, :tab_detail_string

    def build
      bin.tap do |page|
        page.child = box

        box.tap do |column|
          column.append(authentication_banner)
          column.append(scrolled_window)

          scrolled_window.tap do |window|
            window.child = clamp

            clamp.tap do |area|
              area.child = content_box

              content_box.tap do |content|
                content.append(usage_group)
                content.append(properties_group)

                usage_group.add(memory_box.build)
                usage_group.add(swap_box.build)

                PROPERTY_ROWS.each_key { |name| properties_group.add(property_row(name)) }
              end
            end
          end
        end

        authentication_banner.tap do |banner|
          banner.signal_connect("button-clicked") { authenticate }
        end

        setup_widgets
      end
    end

    # Upstream's refresh_page.
    def refresh_page(data)
      used_mem = [data.total_mem - data.available_mem, 0].max
      used_swap = [data.total_swap - data.free_swap, 0].max

      memory_box.add_storage_point(used_mem, data.total_mem)
      swap_box.add_storage_point(used_swap, data.total_swap)

      @usage = finite_or_zero(used_mem.to_f / data.total_mem)
      @tab_usage_string = usage_string(used_mem, used_swap, data)
      @tab_detail_string = detail_string
    end

    def bin = @bin ||= Adwaita::Bin.new
    def box = @box ||= Gtk::Box.new(:vertical, 0)

    def authentication_banner
      @authentication_banner ||= Adwaita::Banner
        .new("You need to authenticate to see memory properties")
        .tap do |banner|
          banner.button_label = "Authenticate"
        end
    end

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

    def memory_box = @memory_box ||= GraphBox.new
    def swap_box = @swap_box ||= GraphBox.new

    PROPERTY_ROWS = {
      slots_used:  "Slots Used",
      speed:       "Speed",
      form_factor: "Form Factor",
      memory_type: "Type",
      type_detail: "Type Detail",
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

      def setup_widgets
        memory_box.set_title_label("Memory")
        colour(memory_box.graph, MAIN_GRAPH_COLOR)
        swap_box.set_title_label("Swap")
        colour(swap_box.graph, SWAP_GRAPH_COLOR)

        Memory.devices.then do |devices|
          if devices
            setup_properties(devices)
          else
            properties_group.visible = false
            authentication_banner.revealed = true
          end
        end
      end

      # Upstream's setup_properties.
      def setup_properties(devices)
        @memory_devices = devices
        installed = devices.select(&:installed)

        property_row(:slots_used).subtitle = "#{installed.length} of #{devices.length}"
        property_row(:speed).subtitle = speed_string(installed)
        property_row(:form_factor).subtitle = first_of(installed, :form_factor)
        property_row(:memory_type).subtitle = first_of(installed, :type)
        property_row(:type_detail).subtitle = first_of(installed, :type_detail)

        @tab_detail_string = detail_string
      end

      # Upstream's authentication banner runs dmidecode through pkexec.
      def authenticate
        Memory.pkexec_devices.then do |devices|
          if devices
            setup_properties(devices)
            properties_group.visible = true
          end
        end
        authentication_banner.revealed = false
      end

      def speed_string(installed)
        installed.map { |device| device.speed_mts || 0 }.max.then do |speed|
          if speed
            "#{speed} MT/s"
          else
            "#{NOT_AVAILABLE} MT/s"
          end
        end
      end

      def first_of(installed, field)
        installed.first.then do |device|
          if device
            device[field] || NOT_AVAILABLE
          else
            NOT_AVAILABLE
          end
        end
      end

      # Upstream's sidebar detail is the installed capacity plus the module
      # type, e.g. "32.00 GB DDR4".
      def detail_string
        total = @memory_devices.sum { |device| device.size || 0 }
        type = @memory_devices.find(&:installed)&.type

        "#{Units.convert_storage(total.to_f, false)} #{type}".strip
      end

      def usage_string(used_mem, used_swap, data)
        used = Units.convert_storage(used_mem.to_f, false)
        total = Units.convert_storage(data.total_mem.to_f, false)

        if data.total_swap.zero?
          "#{used} / #{total}"
        else
          swap_percentage = (used_swap.to_f / data.total_swap * 100.0).round
          "#{used} / #{total} · Swap: #{swap_percentage} %"
        end
      end

      def colour(graph, rgb)
        graph.set_graph_color(rgb[0], rgb[1], rgb[2])
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
