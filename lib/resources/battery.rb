# frozen_string_literal: true

require_relative "units"

module Resources
  # Battery gathers the sysfs power-supply data for every real battery in
  # the system, and the per-refresh readings derived from it.
  #
  # Ported from upstream's src/utils/battery.rs. Upstream's `Battery` is the
  # unchanging description of one battery (manufacturer, model, technology,
  # design capacity) and `BatteryData` wraps it with that battery's current
  # charge, power usage, health and state, each kept as a `Result` so one
  # failed sysfs read does not take down the others — mirrored here as a
  # plain value that is `nil` when the upstream `Result` would have been an
  # `Err`.
  module Battery
    POWER_SUPPLY_DIR = "/sys/class/power_supply"

    # For (at least) Lenovo Yoga 6 13ALC7: some manufacturers re-encode the
    # manufacturer/model strings as a run of "0xNN" hex bytes.
    HEX_ENCODED_REGEX = /^(0x[0-9a-fA-F]{2}\s*)*$/

    Info = Struct.new(
      :sysfs_path,
      :manufacturer,
      :model_name,
      :design_capacity,
      :technology,
      keyword_init: true,
    ) do
      # Upstream's Battery::display_name.
      def display_name
        if design_capacity
          "#{Units.convert_energy(design_capacity, true)} Battery"
        else
          "Battery"
        end
      end
    end

    Data = Struct.new(
      :inner,
      :charge,
      :power_usage,
      :health,
      :state,
      :charge_cycles,
      keyword_init: true,
    )

    class << self
      # Upstream's Battery::get_sysfs_paths, filtered through
      # Battery::is_valid_power_supply.
      def sysfs_paths
        return [] unless Dir.exist?(POWER_SUPPLY_DIR)

        Dir.children(POWER_SUPPLY_DIR)
          .map { |name| File.join(POWER_SUPPLY_DIR, name) }
          .select { |path| valid_power_supply?(path) }
          .sort
      end

      def valid_power_supply?(path)
        read_string(File.join(path, "type")) == "Battery" &&
          read_string(File.join(path, "scope")) != "Device"
      end

      # Upstream's BatteryData::new: one Info plus the readings taken from it.
      def all
        sysfs_paths.map { |path| data_for(path) }
      end

      def data_for(sysfs_path)
        info = info_for(sysfs_path)

        Data.new(
          inner:         info,
          charge:        charge(sysfs_path),
          power_usage:   power_usage(sysfs_path),
          health:        health(sysfs_path),
          state:         state(sysfs_path),
          charge_cycles: charge_cycles(sysfs_path),
        )
      end

      # Upstream's Battery::from_sysfs.
      def info_for(sysfs_path)
        design_capacity = read_float(File.join(sysfs_path, "energy_full_design"))

        Info.new(
          sysfs_path:      sysfs_path,
          manufacturer:    untangled(read_string(File.join(sysfs_path, "manufacturer"))),
          model_name:      untangled(read_string(File.join(sysfs_path, "model_name"))),
          design_capacity: design_capacity && design_capacity / 1_000_000.0,
          technology:      technology(read_string(File.join(sysfs_path, "technology"))),
        )
      end

      # Upstream's Battery::charge, falling back to charge_from_energy.
      def charge(sysfs_path)
        percent = read_integer(File.join(sysfs_path, "capacity"))
        return percent / 100.0 if percent

        charge_from_energy(sysfs_path)
      end

      def charge_from_energy(sysfs_path)
        now = read_integer(File.join(sysfs_path, "energy_now"))
        full = read_integer(File.join(sysfs_path, "energy_full"))
        now.to_f / full if now && full && !full.zero?
      end

      # Upstream's Battery::health: energy-based, falling back to charge-based.
      def health(sysfs_path)
        full = read_integer(File.join(sysfs_path, "energy_full"))
        design = read_integer(File.join(sysfs_path, "energy_full_design"))
        return full.to_f / design if full && design && !design.zero?

        charge_full = read_integer(File.join(sysfs_path, "charge_full"))
        charge_design = read_integer(File.join(sysfs_path, "charge_full_design"))
        charge_full.to_f / charge_design if charge_full && charge_design && !charge_design.zero?
      end

      # Upstream's Battery::power_usage, falling back to voltage × current.
      def power_usage(sysfs_path)
        microwatts = read_float(File.join(sysfs_path, "power_now"))
        return microwatts.abs / 1_000_000.0 if microwatts

        power_usage_from_voltage_and_current(sysfs_path)
      end

      def power_usage_from_voltage_and_current(sysfs_path)
        voltage = read_float(File.join(sysfs_path, "voltage_now"))
        current = read_float(File.join(sysfs_path, "current_now"))
        return nil unless voltage && current

        (voltage / 1_000_000.0 * (current / 1_000_000.0)).abs
      end

      # Upstream's Battery::state.
      def state(sysfs_path)
        status_to_state(read_string(File.join(sysfs_path, "status")))
      end

      # Upstream's Battery::charge_cycles.
      def charge_cycles(sysfs_path)
        read_integer(File.join(sysfs_path, "cycle_count"))
      end

      # Upstream's State::from_str / Display.
      def status_to_state(status)
        case status&.downcase
        when "charging" then "Charging"
        when "discharging" then "Discharging"
        when "empty" then "Empty"
        when "full" then "Full"
        else "Unknown"
        end
      end

      # Upstream's Technology::from_str / Display.
      def technology(raw)
        case raw&.downcase
        when "nimh" then "Nickel-Metal Hydride"
        when "nicd" then "Nickel-Cadmium"
        when "nizn" then "Nickel-Zinc"
        when "pb", "pbac" then "Lead-Acid"
        when "li-i", "li-ion", "lion" then "Lithium-Ion"
        when "life" then "Lithium Iron Phosphate"
        when "lip", "lipo", "li-poly" then "Lithium Polymer"
        when "ram" then "Rechargeable Alkaline Manganese"
        else "N/A"
        end
      end

      # Upstream's Battery::untangle_weird_encoding.
      def untangled(raw)
        return nil if raw.nil?

        if HEX_ENCODED_REGEX.match?(raw)
          raw.split.map { |hex| hex.sub("0x", "").to_i(16) }
            .map { |byte| byte.zero? ? 0x20 : byte }
            .pack("C*")
            .force_encoding(Encoding::UTF_8)
        else
          raw
        end
      end

      private

        def read_string(path)
          return nil unless File.exist?(path)

          File.read(path).strip.then { |s| s.empty? ? nil : s }
        rescue Errno::ENOENT, Errno::EACCES, Errno::EIO
          nil
        end

        def read_integer(path)
          read_string(path)&.to_i
        end

        def read_float(path)
          read_string(path)&.to_f
        end
    end
  end
end
