# frozen_string_literal: true

require_relative "settings"

module Resources
  # Units turns the raw numbers the backends gather into the strings the views
  # show: byte counts, speeds, frequencies, temperatures, durations.
  #
  # Ported from upstream's src/utils/units.rs. Upstream enumerates one match
  # arm per SI prefix per quantity; the prefix tables below collapse those arms
  # into a single lookup, which keeps the rounding rules (integer counts round,
  # fractional ones get two decimal places, and an unprefixed value always
  # rounds) in one place rather than eleven.
  module Units
    # Upstream's Prefix enum: None, Kilo … Quetta.
    DECIMAL_PREFIXES = ["", "k", "M", "G", "T", "P", "E", "Z", "Y", "R", "Q"].freeze
    BINARY_PREFIXES = ["", "Ki", "Mi", "Gi", "Ti", "Pi", "Ei", "Zi", "Yi", "Ri", "Qi"].freeze
    PREFIX_COUNT = DECIMAL_PREFIXES.length

    DECIMAL_BASE = 1000.0
    BINARY_BASE = 1024.0

    NOT_AVAILABLE = "N/A"

    class << self
      # Upstream's format_time: a floating point duration as H∶MM∶SS.hh, using
      # U+2236 RATIO rather than a colon so the digits stay aligned.
      def format_time(time_in_seconds)
        if time_in_seconds.finite?
          finite_time(time_in_seconds)
        else
          float_to_s(time_in_seconds).sub("inf", "∞")
        end
      end

      # Upstream's format_time_integer: the same layout without the hundredths.
      def format_time_integer(time_in_seconds)
        absolute = time_in_seconds.abs
        clock = [
          absolute / 3600,
          pad((absolute / 60) % 60),
          pad(absolute % 60),
        ].join("∶")

        "#{sign_of(time_in_seconds)}#{clock}"
      end

      def convert_temperature(celsius)
        case Settings.instance.temperature_unit
        when "Kelvin" then "#{(celsius + 273.15).round} K"
        when "Fahrenheit" then "#{((celsius * 1.8) + 32.0).round} °F"
        else "#{celsius.round} °C"
        end
      end

      def convert_fraction(fraction, integer)
        percentage = fraction * 100.0
        if integer
          "#{number_string(percentage, 0, 0)} %"
        else
          "#{number_string(percentage, 1, 1)} %"
        end
      end

      def convert_storage(bytes, integer)
        case Settings.instance.base
        when "Binary" then convert_storage_binary(bytes, integer)
        else convert_storage_decimal(bytes, integer)
        end
      end

      def convert_storage_decimal(bytes, integer)
        prefixed(
          bytes,
          DECIMAL_BASE,
          DECIMAL_PREFIXES,
          "B",
          places_for(integer),
        )
      end

      def convert_storage_binary(bytes, integer)
        prefixed(
          bytes,
          BINARY_BASE,
          BINARY_PREFIXES,
          "B",
          places_for(integer),
        )
      end

      # Network speeds optionally switch to bits per second; everything else
      # follows the configured prefix base.
      def convert_speed(bytes_per_second, network)
        if network && Settings.instance.network_bits?
          convert_speed_bits_decimal(bytes_per_second * 8.0)
        else
          convert_speed_bytes(bytes_per_second)
        end
      end

      def convert_speed_decimal(bytes_per_second)
        prefixed(
          bytes_per_second,
          DECIMAL_BASE,
          DECIMAL_PREFIXES,
          "B/s",
          2,
        )
      end

      def convert_speed_binary(bytes_per_second)
        prefixed(
          bytes_per_second,
          BINARY_BASE,
          BINARY_PREFIXES,
          "B/s",
          2,
        )
      end

      def convert_speed_bits_decimal(bits_per_second)
        convert_speed_bits_decimal_with_places(bits_per_second, 2)
      end

      def convert_speed_bits_decimal_with_places(bits_per_second, decimal_places)
        prefixed(
          bits_per_second,
          DECIMAL_BASE,
          DECIMAL_PREFIXES,
          "b/s",
          decimal_places,
        )
      end

      def convert_speed_bits_binary(bits_per_second)
        prefixed(
          bits_per_second,
          BINARY_BASE,
          BINARY_PREFIXES,
          "b/s",
          2,
        )
      end

      # Frequencies print two decimal places even unprefixed, so the Hertz case
      # cannot go through the shared integer-rounding rule.
      def convert_frequency(hertz)
        numbered = to_largest_prefix(hertz, DECIMAL_BASE)
        "#{number_string(numbered[0], 1, 2)} #{DECIMAL_PREFIXES[numbered[1]]}Hz"
      end

      # Watts print one decimal place unprefixed and two once prefixed.
      def convert_power(watts)
        numbered = to_largest_prefix(watts, DECIMAL_BASE)
        "#{power_number(numbered[0], numbered[1])} #{DECIMAL_PREFIXES[numbered[1]]}W"
      end

      def convert_energy(watthours, integer)
        numbered = to_largest_prefix(watthours, DECIMAL_BASE)
        if integer
          "#{number_string(numbered[0], 0, 0)} #{DECIMAL_PREFIXES[numbered[1]]}Wh"
        else
          "#{power_number(numbered[0], numbered[1])} #{DECIMAL_PREFIXES[numbered[1]]}Wh"
        end
      end

      def convert_tops(tops) = "#{float_to_s(tops)} TOPs"

      # Upstream's to_largest_prefix: divides by the base until the value fits
      # under it, and reports which prefix that landed on.
      def to_largest_prefix(amount, base)
        if amount.finite?
          scaled_prefix(amount, base)
        else
          [amount, 0]
        end
      end

      # Rust's f64 Display drops a trailing ".0" and spells the specials
      # "NaN" / "inf"; Ruby's Float#to_s does neither.
      def float_to_s(value)
        if value.nan?
          "NaN"
        elsif value.infinite?
          infinity_to_s(value)
        elsif value == value.truncate
          value.truncate.to_s
        else
          value.to_s
        end
      end

      private

        def finite_time(time_in_seconds)
          absolute = time_in_seconds.abs
          clock = [
            (absolute / 3600.0).to_i,
            pad(((absolute / 60.0) % 60.0).to_i),
            pad((absolute % 60.0).to_i),
          ].join("∶")
          hundredths = pad(((absolute - absolute.floor) * 100.0).to_i)

          "#{sign_of(time_in_seconds)}#{clock}.#{hundredths}"
        end

        def sign_of(value)
          if value.negative?
            "-"
          else
            ""
          end
        end

        def pad(value) = format("%02d", value)

        def places_for(integer)
          if integer
            0
          else
            2
          end
        end

        def convert_speed_bytes(bytes_per_second)
          case Settings.instance.base
          when "Binary" then convert_speed_binary(bytes_per_second)
          else convert_speed_decimal(bytes_per_second)
          end
        end

        def prefixed(amount, base, prefixes, suffix, places)
          numbered = to_largest_prefix(amount, base)
          number = number_string(numbered[0], numbered[1], places)

          "#{number} #{prefixes[numbered[1]]}#{suffix}"
        end

        # An unprefixed value always rounds; a prefixed one keeps `places`.
        def number_string(number, index, places)
          if !number.finite?
            float_to_s(number)
          elsif index.zero? || places.zero?
            number.round.to_s
          else
            format("%.#{places}f", number)
          end
        end

        def power_number(number, index)
          if index.zero?
            number_string(number, 1, 1)
          else
            number_string(number, index, 2)
          end
        end

        def scaled_prefix(amount, base)
          factor = 1.0
          if amount.negative?
            factor = -1.0
          end

          value = amount.abs
          index = 0
          while index < PREFIX_COUNT && value >= base
            value /= base
            index += 1
          end

          [value * factor, [index, PREFIX_COUNT - 1].min]
        end

        def infinity_to_s(value)
          if value.positive?
            "inf"
          else
            "-inf"
          end
        end
    end
  end
end
