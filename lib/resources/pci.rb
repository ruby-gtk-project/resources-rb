# frozen_string_literal: true

module Resources
  # Pci parses the system's `pci.ids` database into vendor/device/subdevice
  # names, so a PCI vendor:device pair (as reported by sysfs for a GPU, NPU
  # or network card) can be turned into a human-readable name.
  #
  # Ported from upstream's src/utils/pci.rs. Upstream keeps the parsed
  # database behind a `LazyLock`; this port keeps it behind a memoized class
  # method so nothing is parsed until the first lookup.
  module Pci
    PATH_PCI_IDS = "/usr/share/hwdata/pci.ids"
    PATH_PCI_IDS_FLATPAK = "/run/host/usr/share/hwdata/pci.ids"

    # Upstream's Subdevice.
    Subdevice = Struct.new(
      :id,
      :vendor_id,
      :name,
      keyword_init: true,
    )

    # Upstream's Device.
    Device = Struct.new(
      :id,
      :vendor_id,
      :name,
      :sub_devices,
      keyword_init: true,
    ) do
      def subdevices = sub_devices.each

      def vendor = Pci.vendor_from_vid(vendor_id)

      def pid = id
    end

    # Upstream's Vendor.
    Vendor = Struct.new(
      :id,
      :name,
      :devices,
      keyword_init: true,
    ) do
      def devices_list = devices.values

      def device(pid) = devices[pid]

      def vid = id
    end

    class << self
      # Upstream's Device::from_vid_pid.
      def device_from_vid_pid(vid, pid)
        vendors[vid]&.devices&.[](pid)
      end

      # Upstream's Vendor::from_vid.
      def vendor_from_vid(vid) = vendors[vid]

      def vendors
        @vendors ||= parse_pci_ids(pci_ids_contents)
      end

      # Upstream's parse_pci_ids, operating on an already-read string's lines
      # rather than a BufRead, which Ruby has no equivalent of here.
      def parse_pci_ids(contents)
        current_vendor_id = nil
        current_device_id = nil

        {}.tap do |seen|
          contents.to_s.each_line(chomp: true) do |line|
            case line
            when /\AC/
              break
            when /\A#/, ""
              next
            when /\A\t\t/
              sub_vid, sub_pid, name = parse_subdevice_line(line)
              vendor = seen.fetch(current_vendor_id) { raise "no preceding vendor (line: #{line})" }
              device = vendor.devices.fetch(current_device_id) { raise "no preceding device (line: #{line})" }
              device.sub_devices << Subdevice.new(id: sub_pid, vendor_id: sub_vid, name: name)
            when /\A\t/
              pid, name = parse_device_line(line)
              vendor = seen.fetch(current_vendor_id) { raise "no preceding device (line: #{line})" }
              vendor.devices[pid] = Device.new(id: pid, vendor_id: current_vendor_id, name: name, sub_devices: [])
              current_device_id = pid
            else
              vid, name = parse_vendor_line(line)
              seen[vid] = Vendor.new(id: vid, name: name, devices: {})
              current_vendor_id = vid
              current_device_id = nil
            end
          end
        end
      end

      private

        def parse_vendor_line(line)
          vid_text, name = line.split("  ", 2)
          unless name
            raise "this vendor has no name (line: #{line})"
          end

          [Integer(vid_text, 16), name]
        end

        def parse_device_line(line)
          pid_text, name = line.strip.split("  ", 2)
          unless name
            raise "this device has no name (line: #{line})"
          end

          [Integer(pid_text, 16), name]
        end

        def parse_subdevice_line(line)
          fields = line.strip.split(/ /, 4)
          unless fields[0]
            raise "this subdevice has no vid (line: #{line})"
          end
          unless fields[1]
            raise "this subdevice has no pid (line: #{line})"
          end
          if fields[3].nil? || fields[3].empty?
            raise "this vendor has no name (line: #{line})"
          end

          [Integer(fields[0], 16), Integer(fields[1], 16), fields[3]]
        end

        def pci_ids_contents
          File.read(PATH_PCI_IDS_FLATPAK)
        rescue SystemCallError, IOError
          begin
            File.read(PATH_PCI_IDS)
          rescue SystemCallError, IOError
            ""
          end
        end
    end
  end
end
