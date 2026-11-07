# frozen_string_literal: true

require "adwaita"

require_relative "settings"

module Resources
  # SettingsDialog is the preferences dialog: four pages of switches, choices
  # and one spin row, each one wired straight to a settings key.
  #
  # Ported from upstream's data/resources/ui/dialogs/settings_dialog.ui and
  # src/ui/dialogs/settings_dialog.rs. Upstream declares the rows in the .ui
  # file and binds each one to its GSettings key in Rust; the tables below hold
  # the same rows, in the same order, each naming the key it reads and writes,
  # so adding a setting is one table entry rather than a widget and a binding.
  class SettingsDialog
    # title, subtitle, settings key — one row per switch.
    SWITCHES = {
      "network-bits"                     => ["Show Network Speeds in Bits per Second", nil],
      "show-graph-grids"                 => ["Show Graph Grids", nil],
      "sidebar-details"                  => [
        "Show Usage Details in Sidebar",
        "If enabled, the usage along with other information will be displayed",
      ],
      "sidebar-description"              => [
        "Show Device Descriptions in Sidebar",
        "If enabled, a device identifier like its name or device type will be displayed",
      ],
      "normalize-cpu-usage"              => [
        "Normalize Processor Usage",
        "If enabled, the total usage of all cores will be divided by the amount of cores",
      ],
      "apps-show-memory"                 => ["Memory", nil],
      "apps-show-cpu"                    => ["Processor", nil],
      "apps-show-drive-read-speed"       => ["Drive Read", nil],
      "apps-show-drive-read-total"       => ["Drive Read Total", nil],
      "apps-show-drive-write-speed"      => ["Drive Write", nil],
      "apps-show-drive-write-total"      => ["Drive Write Total", nil],
      "apps-show-gpu"                    => ["GPU", nil],
      "apps-show-gpu-memory"             => ["Video Memory", nil],
      "apps-show-encoder"                => ["Video Encoder", nil],
      "apps-show-decoder"                => ["Video Decoder", nil],
      "apps-show-swap"                   => ["Swap", nil],
      "apps-show-combined-memory"        => ["Combined Memory", nil],
      "detailed-priority"                => ["Show Niceness Values", nil],
      "processes-show-id"                => ["Process ID", nil],
      "processes-show-user"              => ["User", nil],
      "processes-show-memory"            => ["Memory", nil],
      "processes-show-cpu"               => ["Processor", nil],
      "processes-show-drive-read-speed"  => ["Drive Read", nil],
      "processes-show-drive-read-total"  => ["Drive Read Total", nil],
      "processes-show-drive-write-speed" => ["Drive Write", nil],
      "processes-show-drive-write-total" => ["Drive Write Total", nil],
      "processes-show-gpu"               => ["GPU", nil],
      "processes-show-gpu-memory"        => ["Video Memory", nil],
      "processes-show-encoder"           => ["Video Encoder", nil],
      "processes-show-decoder"           => ["Video Decoder", nil],
      "processes-show-total-cpu-time"    => ["Total CPU Time", nil],
      "processes-show-user-cpu-time"     => ["User CPU Time", nil],
      "processes-show-system-cpu-time"   => ["System CPU Time", nil],
      "processes-show-priority"          => ["Priority", nil],
      "processes-show-swap"              => ["Swap", nil],
      "processes-show-combined-memory"   => ["Combined Memory", nil],
      "processes-show-commandline"       => ["Commandline", nil],
      "show-virtual-drives"              => [
        "Show Virtual Drives",
        "Virtual drives are for example ZFS volumes or mapped devices",
      ],
      "show-virtual-network-interfaces"  => [
        "Show Virtual Network Interfaces",
        "Virtual network interfaces are for example bridges or VPN tunnels",
      ],
    }.freeze

    # title, subtitle, [label, stored value] pairs — one row per choice.
    CHOICES = {
      "base"               => [
        "Data Unit Prefix",
        nil,
        [["Decimal", "Decimal"], ["Binary", "Binary"]],
      ],
      "temperature-unit"   => [
        "Temperature Unit",
        nil,
        [["Celsius", "Celsius"], ["Kelvin", "Kelvin"], ["Fahrenheit", "Fahrenheit"]],
      ],
      "refresh-speed"      => [
        "Refresh Speed",
        "Higher refresh speeds can lead to higher processor usage",
        [
          ["Very Slow", "VerySlow"],
          ["Slow", "Slow"],
          ["Normal", "Normal"],
          ["Fast", "Fast"],
          ["Very Fast", "VeryFast"],
        ],
      ],
      "sidebar-meter-type" => [
        "Sidebar Meter Type",
        nil,
        [["Bar", "ProgressBar"], ["Graph", "Graph"]],
      ],
    }.freeze

    GRAPH_DATA_POINTS_RANGE = (10..600)

    # page title, page icon, then group title => the keys in that group.
    PAGES = [
      [
        "General",
        "generic-settings-symbolic",
        {
          "Units"          => ["base", "network-bits", "temperature-unit"],
          "User Interface" => [
            "refresh-speed",
            "show-graph-grids",
            "graph-data-points",
            "sidebar-details",
            "sidebar-description",
            "sidebar-meter-type",
            "normalize-cpu-usage",
          ],
        },
      ],
      [
        "Apps",
        "app-symbolic",
        {
          "Information Columns" => [
            "apps-show-memory",
            "apps-show-cpu",
            "apps-show-drive-read-speed",
            "apps-show-drive-read-total",
            "apps-show-drive-write-speed",
            "apps-show-drive-write-total",
            "apps-show-gpu",
            "apps-show-gpu-memory",
            "apps-show-encoder",
            "apps-show-decoder",
            "apps-show-swap",
            "apps-show-combined-memory",
          ],
        },
      ],
      [
        "Processes",
        "generic-process-symbolic",
        {
          "Options"             => ["detailed-priority"],
          "Information Columns" => [
            "processes-show-id",
            "processes-show-user",
            "processes-show-memory",
            "processes-show-cpu",
            "processes-show-drive-read-speed",
            "processes-show-drive-read-total",
            "processes-show-drive-write-speed",
            "processes-show-drive-write-total",
            "processes-show-gpu",
            "processes-show-gpu-memory",
            "processes-show-encoder",
            "processes-show-decoder",
            "processes-show-total-cpu-time",
            "processes-show-user-cpu-time",
            "processes-show-system-cpu-time",
            "processes-show-priority",
            "processes-show-swap",
            "processes-show-combined-memory",
            "processes-show-commandline",
          ],
        },
      ],
      [
        "Devices",
        "device-settings-symbolic",
        {
          "Drives"             => ["show-virtual-drives"],
          "Network Interfaces" => ["show-virtual-network-interfaces"],
        },
      ],
    ].freeze

    def initialize(settings: Settings.instance)
      @settings = settings
      @rows = {}
    end

    # A `SettingsDialog` is built once: `MainWindow` hands out a fresh
    # instance every time Preferences is opened (direct menu item, the
    # `app.settings` action, or `<Control>comma`), since `Adwaita::Dialog`
    # cannot be re-presented once closed. This guard still protects a direct
    # second call to `build` on the same instance, where `preferences.add` on
    # already-parented rows would be a GTK critical rather than a no-op.
    def build
      dialog.tap do |preferences|
        unless @built
          @built = true
          PAGES.each { |title, icon, groups| preferences.add(page(title, icon, groups)) }
        end
      end
    end

    def present(parent)
      dialog.present(parent)
    end

    def dialog
      @dialog ||= Adwaita::PreferencesDialog.new.tap do |preferences|
        preferences.title = "Preferences"
      end
    end

    def row(key) = @rows[key] ||= build_row(key)

    private

      def page(title, icon, groups)
        Adwaita::PreferencesPage.new.tap do |preferences_page|
          preferences_page.title = title
          preferences_page.icon_name = icon
          groups.each { |group_title, keys| preferences_page.add(group(group_title, keys)) }
        end
      end

      def group(title, keys)
        Adwaita::PreferencesGroup.new.tap do |preferences_group|
          preferences_group.title = title
          keys.each { |key| preferences_group.add(row(key)) }
        end
      end

      def build_row(key)
        if key == "graph-data-points"
          spin_row(key)
        elsif CHOICES.key?(key)
          choice_row(key, *CHOICES.fetch(key))
        else
          switch_row(key, *SWITCHES.fetch(key))
        end
      end

      def switch_row(key, title, subtitle)
        Adwaita::SwitchRow.new.tap do |switch|
          switch.title = title
          switch.subtitle = subtitle.to_s
          switch.active = @settings[key] == true
          switch.signal_connect("notify::active") do |widget|
            @settings[key] = widget.active?
          end
        end
      end

      def choice_row(key, title, subtitle, options)
        Adwaita::ComboRow.new.tap do |combo|
          combo.title = title
          combo.subtitle = subtitle.to_s
          combo.model = Gtk::StringList.new(options.map(&:first))
          combo.selected = selected_index(key, options)
          combo.signal_connect("notify::selected") do |widget|
            @settings[key] = options.dig(widget.selected, 1)
          end
        end
      end

      def selected_index(key, options)
        options.index { |_label, value| value == @settings[key] } || 0
      end

      def spin_row(key)
        Adwaita::SpinRow.new(adjustment, 1, 0).tap do |spin|
          spin.title = "Graph Data Points"
          spin.snap_to_ticks = true
          spin.value = @settings[key]
          spin.signal_connect("notify::value") do |widget|
            @settings[key] = widget.value.to_i
          end
        end
      end

      def adjustment
        Gtk::Adjustment.new(
          @settings["graph-data-points"].to_f,
          GRAPH_DATA_POINTS_RANGE.first.to_f,
          GRAPH_DATA_POINTS_RANGE.last.to_f,
          1.0,
          10.0,
          0.0,
        )
      end
  end
end
