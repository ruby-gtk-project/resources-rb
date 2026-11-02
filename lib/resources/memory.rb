# frozen_string_literal: true

require "English"

module Resources
  # Memory gathers memory and swap usage, plus the per-slot description of the
  # installed memory modules.
  #
  # Ported from upstream's src/utils/memory.rs: usage comes from /proc/meminfo,
  # and the module description from `udevadm`'s view of the virtual DMI tree,
  # falling back to `dmidecode` (unprivileged, then through pkexec) when udev
  # reports no memory devices.
  module Memory
    PROC_MEMINFO = "/proc/meminfo"

    BYTES_IN_GIB = 1_073_741_824

    MEMINFO_FIELDS = {
      total_mem:     /MemTotal:\s*(\d*) kB/,
      available_mem: /MemAvailable:\s*(\d*) kB/,
      total_swap:    /SwapTotal:\s*(\d*) kB/,
      free_swap:     /SwapFree:\s*(\d*) kB/,
    }.freeze

    DMIDECODE_FIELDS = {
      configured_speed: /Configured Memory Speed: (\d+) MT\/s/,
      speed:            /Speed: (\d+) MT\/s/,
      form_factor:      /Form Factor: (.+)/,
      type:             /^\s*Type: (.+)$/,
      type_detail:      /Type Detail: (.+)/,
      size:             /Size: (\d+) GB/,
    }.freeze

    RE_NUM_MEMORY_DEVICES = /MEMORY_ARRAY_NUM_DEVICES=(\d*)/

    # Upstream's MemoryData.
    Data = Struct.new(
      :total_mem,
      :available_mem,
      :total_swap,
      :free_swap,
      keyword_init: true,
    )

    # Upstream's MemoryDevice: one physical slot, installed or not.
    Device = Struct.new(
      :speed_mts,
      :form_factor,
      :type,
      :type_detail,
      :size,
      :installed,
      keyword_init: true,
    )

    class << self
      # Upstream's MemoryData::new. Returns nil when /proc/meminfo cannot be
      # read or is missing a field, which is upstream's Err case.
      def data
        parse_meminfo(read_file(PROC_MEMINFO).to_s)
      end

      def parse_meminfo(meminfo)
        kilobytes = MEMINFO_FIELDS.transform_values do |pattern|
          meminfo[pattern, 1]
        end

        if kilobytes.value?(nil)
          nil
        else
          Data.new(**kilobytes.transform_values { |value| value.to_i * 1024 })
        end
      end

      # Upstream's MemoryDevice::get: udevadm first, dmidecode as a fallback.
      # Returns nil when neither can describe the slots, which is the case
      # upstream answers with its authentication banner.
      def devices
        from_udev = parse_virtual_dmi(udevadm_output)
        if from_udev.empty?
          unprivileged_dmidecode
        else
          from_udev
        end
      end

      # Upstream's MemoryDevice::pkexec_dmidecode.
      def pkexec_devices
        output = capture(
          [
            "pkexec",
            "--disable-internal-agent",
            "dmidecode",
            "-t",
            "17",
            "-q",
          ],
        )

        output&.then { |text| parse_dmidecode(text) }
      end

      def parse_dmidecode(output)
        output.split("\n\n").reject(&:empty?).map do |block|
          captured = DMIDECODE_FIELDS.transform_values { |pattern| block[pattern, 1] }

          Device.new(
            speed_mts:   (captured[:configured_speed] || captured[:speed])&.to_i,
            form_factor: captured[:form_factor],
            type:        captured[:type],
            type_detail: captured[:type_detail],
            size:        captured[:size]&.then { |gib| gib.to_i * BYTES_IN_GIB },
            installed:   !captured[:speed].nil?,
          )
        end
      end

      def parse_virtual_dmi(output)
        amount = output[RE_NUM_MEMORY_DEVICES, 1].to_i

        Array.new(amount) { |index| virtual_dmi_device(output, index) }
      end

      private

        def virtual_dmi_device(output, index)
          installed = output[/MEMORY_DEVICE_#{index}_PRESENT=(\d)/, 1] != "0"

          Device.new(
            speed_mts:   virtual_dmi_speed(output, index, installed),
            form_factor: output[/MEMORY_DEVICE_#{index}_FORM_FACTOR=(.*)/, 1],
            type:        virtual_dmi_type(output, index),
            type_detail: output[/MEMORY_DEVICE_#{index}_TYPE_DETAIL=(.*)/, 1],
            size:        output[/MEMORY_DEVICE_#{index}_SIZE=(\d*)/, 1]&.to_i,
            installed:   installed,
          )
        end

        def virtual_dmi_speed(output, index, installed)
          if installed
            configured = output[/MEMORY_DEVICE_#{index}_CONFIGURED_SPEED_MTS=(\d*)/, 1]
            (configured || output[/MEMORY_DEVICE_#{index}_SPEED_MTS=(\d*)/, 1])&.to_i
          end
        end

        def virtual_dmi_type(output, index)
          output[/MEMORY_DEVICE_#{index}_TYPE=(.*)/, 1]&.then do |type|
            unless type == "<OUT OF SPEC>"
              type
            end
          end
        end

        def udevadm_output
          capture(["udevadm", "info", "-p", "/sys/devices/virtual/dmi/id"]).to_s
        end

        # dmidecode exits 1 without the privileges to read the DMI tables;
        # upstream treats that as "ask the user to authenticate".
        def unprivileged_dmidecode
          output = capture(["dmidecode", "-t", "17", "-q"])

          output&.then { |text| parse_dmidecode(text) }
        end

        def capture(command)
          begin
            output = IO.popen(command, err: File::NULL, &:read)
          rescue Errno::ENOENT
            output = nil
          end

          if $CHILD_STATUS&.success?
            output
          end
        end

        def read_file(path)
          begin
            contents = File.read(path)
          rescue SystemCallError, IOError
            contents = nil
          end

          contents
        end
    end
  end
end
