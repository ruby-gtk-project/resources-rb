# frozen_string_literal: true

module Resources
  # Cpu gathers processor information and per-refresh processor statistics.
  #
  # Ported from upstream's src/utils/cpu.rs: the static description comes from
  # `lscpu`, the per-refresh counters from /proc/stat and sysfs, and the
  # temperature from whichever hwmon or thermal zone matches the known names.
  module Cpu
    PROC_STAT = "/proc/stat"

    KNOWN_HWMONS = ["zenpower", "coretemp", "k10temp", "ibmpowernv"].freeze

    KNOWN_THERMAL_ZONES = ["cpu-thermal", "x86_pkg_temp", "acpitz"].freeze

    LSCPU_FIELDS = {
      model_name:       /^\s*Model name:\s*(.*)$/,
      architecture:     /^\s*Architecture:\s*(.*)$/,
      logical_cpus:     /^\s*CPU\(s\):\s*(.*)$/,
      cores_per_socket: /^\s*Core\(s\) per socket:\s*(.*)$/,
      sockets:          /^\s*Socket\(s\):\s*(.*)$/,
      virtualization:   /^\s*Virtualization:\s*(.*)$/,
      max_mhz:          /^\s*CPU max MHz:\s*(.*)$/,
    }.freeze

    TRADE_MARK_SYMBOLS = {
      "(R)"  => "®",
      "(tm)" => "™",
      "(TM)" => "™",
    }.freeze

    # Upstream's CpuInfo: the unchanging description of the processor.
    Info = Struct.new(
      :model_name,
      :architecture,
      :logical_cpus,
      :physical_cpus,
      :sockets,
      :virtualization,
      :max_speed,
      keyword_init: true,
    )

    # Upstream's CpuData: one refresh's worth of counters. `thread_usages` is
    # one [idle_time, total_time] pair per logical CPU, straight out of
    # /proc/stat, so the caller does its own delta arithmetic.
    Data = Struct.new(
      :thread_usages,
      :temperature,
      :frequencies,
      keyword_init: true,
    )

    class << self
      # Upstream's CpuInfo::get: parse `lscpu` under the C locale.
      def info = parse_lscpu(lscpu_output)

      def parse_lscpu(output)
        captured = LSCPU_FIELDS.transform_values do |pattern|
          output[pattern, 1]
        end
        sockets = to_i_or_nil(captured[:sockets])

        Info.new(
          model_name:     trade_mark_symbols(captured[:model_name]),
          architecture:   captured[:architecture],
          logical_cpus:   to_i_or_nil(captured[:logical_cpus]),
          physical_cpus:  physical_cpus(captured[:cores_per_socket], sockets),
          sockets:        sockets,
          virtualization: captured[:virtualization],
          max_speed:      max_speed(captured[:max_mhz]),
        )
      end

      # Upstream's CpuData::new.
      def data(logical_cpus)
        Data.new(
          thread_usages: usage,
          temperature:   temperature,
          frequencies:   Array.new(logical_cpus) { |core| frequency(core) },
        )
      end

      # Upstream's get_cpu_usage: [idle_plus_iowait, total] per logical CPU.
      def usage = parse_proc_stat(read_file(PROC_STAT).to_s)

      def parse_proc_stat(stat)
        stat.lines.drop(1).select { |line| line.start_with?("cpu") }.map do |line|
          parse_proc_stat_line(line)
        end
      end

      # Upstream's get_cpu_freq: the average frequency if the kernel exposes
      # one, the current scaling frequency otherwise, converted kHz to Hz.
      def frequency(core)
        khz = read_file("/sys/devices/system/cpu/cpu#{core}/cpufreq/cpuinfo_avg_freq")
        khz ||= read_file("/sys/devices/system/cpu/cpu#{core}/cpufreq/scaling_cur_freq")

        khz&.then { |value| value.to_i * 1000 }
      end

      # Upstream's get_temperature, in degrees Celsius.
      def temperature
        temperature_path&.then do |path|
          read_file(path)&.then { |millidegrees| millidegrees.to_f / 1000.0 }
        end
      end

      # Upstream's boot_time, as the number of seconds the machine has been up.
      def uptime
        read_file("/proc/uptime")&.split&.first&.to_f
      end

      def temperature_path
        unless defined?(@temperature_path)
          @temperature_path = search_for_hwmons(KNOWN_HWMONS) ||
            search_for_thermal_zones(KNOWN_THERMAL_ZONES)
        end

        @temperature_path
      end

      private

        def lscpu_output
          begin
            output = IO.popen({ "LC_ALL" => "C" }, ["lscpu"], &:read)
          rescue Errno::ENOENT
            output = ""
          end

          output.to_s
        end

        def physical_cpus(cores_per_socket, sockets)
          to_i_or_nil(cores_per_socket)&.then { |cores| cores * (sockets || 1) }
        end

        def max_speed(max_mhz)
          to_f_or_nil(max_mhz)&.then { |mhz| mhz * 1_000_000.0 }
        end

        def to_i_or_nil(value)
          value&.strip&.then do |text|
            if text.match?(/\A\d+\z/)
              text.to_i
            end
          end
        end

        def to_f_or_nil(value)
          value&.strip&.then do |text|
            if text.match?(/\A\d+(\.\d+)?\z/)
              text.to_f
            end
          end
        end

        def trade_mark_symbols(value)
          value&.then do |text|
            TRADE_MARK_SYMBOLS.reduce(text) do |result, (from, to)|
              result.gsub(from, to)
            end
          end
        end

        # /proc/stat's per-CPU line: user nice system idle iowait irq softirq
        # steal guest guest_nice. Upstream sums every field for the total and
        # counts idle plus iowait as idle.
        def parse_proc_stat_line(line)
          times = line.split[1, 10].to_a.map(&:to_i)

          [times.fetch(3, 0) + times.fetch(4, 0), times.sum]
        end

        def search_for_hwmons(names)
          hwmons = {}
          Dir.glob("/sys/class/hwmon/hwmon*").each do |path|
            name = read_file(File.join(path, "name"))
            sensor = search_for_cpu_temp(path)
            if name && sensor
              hwmons[name] = sensor
            end
          end

          names.filter_map { |name| hwmons[name] }.first
        end

        def search_for_thermal_zones(types)
          zones = {}
          Dir.glob("/sys/class/thermal/thermal_zone*").each do |path|
            read_file(File.join(path, "type"))&.then do |type|
              zones[type] = File.join(path, "temp")
            end
          end

          types.filter_map { |type| zones[type] }.first
        end

        # Prefer a sensor the driver labels as a core (ibmpowernv exposes DIMM
        # and VRM sensors alongside the cores), and fall back to the first
        # temperature input otherwise.
        def search_for_cpu_temp(base)
          labelled = Dir.glob(File.join(base, "temp*_label")).sort.find do |label_path|
            read_file(label_path).to_s.downcase.include?("core") &&
              File.exist?(label_path.sub("_label", "_input"))
          end

          labelled&.sub("_label", "_input") ||
            Dir.glob(File.join(base, "temp*_input")).sort.first
        end

        def read_file(path)
          begin
            contents = File.read(path).strip
          rescue SystemCallError, IOError
            contents = nil
          end

          contents
        end
    end
  end
end
