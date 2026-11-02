# frozen_string_literal: true

require "json"
require "fileutils"

module Resources
  # Settings holds the same keys, defaults and semantics as upstream's
  # net.nokyan.Resources GSettings schema.
  #
  # Ported from data/net.nokyan.Resources.gschema.xml.in and
  # src/utils/settings.rs. Upstream reads the schema through GSettings, which
  # needs a compiled schema installed into the system's glib-2.0/schemas
  # directory; requiring an install step before the app will run from a
  # checkout is worse than the alternative, so the same keys are backed by a
  # JSON file under XDG_CONFIG_HOME. The change notifications upstream gets
  # from GSettings::changed are kept as `on_change`, which the sidebar relies
  # on to follow the meter-type and detail settings live.
  class Settings
    DEFAULTS = {
      "window-width"                     => 1024,
      "window-height"                    => 900,
      "is-maximized"                     => false,
      "temperature-unit"                 => "Celsius",
      "base"                             => "Decimal",
      "refresh-speed"                    => "Normal",
      "show-virtual-drives"              => false,
      "show-virtual-network-interfaces"  => false,
      "sidebar-details"                  => false,
      "sidebar-description"              => false,
      "sidebar-meter-type"               => "Graph",
      "network-bits"                     => false,
      "apps-show-memory"                 => true,
      "apps-show-cpu"                    => true,
      "apps-show-drive-read-speed"       => false,
      "apps-show-drive-read-total"       => false,
      "apps-show-drive-write-speed"      => false,
      "apps-show-drive-write-total"      => false,
      "apps-show-gpu"                    => true,
      "apps-show-encoder"                => false,
      "apps-show-decoder"                => false,
      "apps-show-gpu-memory"             => false,
      "apps-show-swap"                   => false,
      "apps-show-combined-memory"        => false,
      "processes-show-id"                => true,
      "processes-show-user"              => true,
      "processes-show-memory"            => true,
      "processes-show-cpu"               => true,
      "processes-show-drive-read-speed"  => false,
      "processes-show-drive-read-total"  => false,
      "processes-show-drive-write-speed" => false,
      "processes-show-drive-write-total" => false,
      "processes-show-gpu"               => true,
      "processes-show-encoder"           => false,
      "processes-show-decoder"           => false,
      "processes-show-gpu-memory"        => false,
      "processes-show-total-cpu-time"    => false,
      "processes-show-user-cpu-time"     => false,
      "processes-show-system-cpu-time"   => false,
      "processes-show-priority"          => false,
      "processes-show-swap"              => false,
      "processes-show-combined-memory"   => false,
      "processes-show-commandline"       => false,
      "show-logical-cpus"                => false,
      "show-graph-grids"                 => false,
      "graph-data-points"                => 60,
      "apps-sort-by"                     => 0,
      "apps-sort-by-ascending"           => true,
      "processes-sort-by"                => 3,
      "processes-sort-by-ascending"      => false,
      "last-viewed-page"                 => "applications",
      "normalize-cpu-usage"              => true,
      "detailed-priority"                => false,
    }.freeze

    # Upstream's Base::base().
    PREFIX_BASES = {
      "Decimal" => 1000.0,
      "Binary"  => 1024.0,
    }.freeze

    # Upstream's RefreshSpeed::ui_refresh_interval(), in seconds.
    REFRESH_INTERVALS = {
      "VerySlow" => 3.0,
      "Slow"     => 2.0,
      "Normal"   => 1.0,
      "Fast"     => 0.5,
      "VeryFast" => 0.25,
    }.freeze

    TEMPERATURE_UNITS = ["Celsius", "Kelvin", "Fahrenheit"].freeze
    SIDEBAR_METER_TYPES = ["ProgressBar", "Graph"].freeze

    def self.instance = @instance ||= new

    def initialize(path: nil)
      @path = path || default_path
      @values = DEFAULTS.merge(read)
      @observers = {}
    end

    def location = @path

    def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

    def []=(key, value)
      @values[key.to_s] = value
      write
      notify(key.to_s, value)
      value
    end

    # Upstream's SETTINGS.connect_<key>: run `block` whenever the key changes.
    def on_change(key, &block)
      @observers[key.to_s] ||= []
      @observers[key.to_s].push(block)
      block
    end

    DEFAULTS.each_key do |key|
      name = key.tr("-", "_")
      define_method(name) { self[key] }
      define_method(:"#{name}=") { |value| self[key] = value }
      case DEFAULTS[key]
      when true, false
        define_method(:"#{name}?") { self[key] == true }
      end
    end

    # Upstream names this accessor `maximized` even though the key is
    # `is-maximized`; both spellings are kept so neither surprises a caller.
    def maximized = is_maximized

    def maximized=(value)
      self.is_maximized = value
    end

    def maximized? = is_maximized?

    def prefix_base = PREFIX_BASES.fetch(base, PREFIX_BASES.fetch("Decimal"))

    def ui_refresh_interval
      REFRESH_INTERVALS.fetch(refresh_speed, REFRESH_INTERVALS.fetch("Normal"))
    end

    def sidebar_graphs? = sidebar_meter_type == "Graph"
    def sidebar_progress_bars? = sidebar_meter_type == "ProgressBar"

    # Restores the window geometry the previous run recorded, as upstream's
    # MainWindow::load_window_size does.
    def apply_to(window)
      window.set_default_size(window_width, window_height)
      if maximized?
        window.maximize
      end
    end

    # Records the window geometry, as upstream's save_window_size does.
    def remember(window)
      self.window_width = window.default_width
      self.window_height = window.default_height
      self.maximized = window.maximized?
    end

    private

      def notify(key, value)
        @observers.fetch(key, []).each { |block| block.call(value) }
      end

      def default_path
        File.join(
          ENV.fetch("XDG_CONFIG_HOME", File.join(Dir.home, ".config")),
          "resources-rb",
          "settings.json",
        )
      end

      def read
        begin
          parsed = JSON.parse(File.read(@path))
        rescue Errno::ENOENT, JSON::ParserError
          parsed = {}
        end

        parsed.select { |key, _value| DEFAULTS.key?(key) }
      end

      def write
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, "#{JSON.pretty_generate(@values)}\n")
      end
  end
end
