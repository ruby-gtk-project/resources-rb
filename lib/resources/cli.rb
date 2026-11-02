# frozen_string_literal: true

require "optparse"

module Resources
  # Cli parses the command line and turns it into the options the application
  # passes down to the window.
  #
  # Ported from upstream's src/gui.rs, whose `Args` struct is a clap parser
  # with one flag per monitoring backend plus the tab to open. The flags, their
  # short forms and their help text are upstream's; OptionParser stands in for
  # clap's derive.
  module Cli
    FLAGS = {
      disable_gpu_monitoring:               ["-g", "Disable GPU monitoring"],
      disable_network_interface_monitoring: ["-n", "Disable network interface monitoring"],
      disable_drive_monitoring:             ["-d", "Disable drive monitoring"],
      disable_battery_monitoring:           ["-b", "Disable battery monitoring"],
      disable_cpu_monitoring:               ["-c", "Disable CPU monitoring"],
      disable_memory_monitoring:            ["-m", "Disable memory monitoring"],
      disable_npu_monitoring:               ["-v", "Disable NPU monitoring"],
      disable_process_monitoring:           ["-p", "Disable process monitoring"],
      no_suspend_pause:                     [
        "-s",
        "Do not pause graphical updates when the application is suspended",
      ],
    }.freeze

    OPEN_TAB_DESCRIPTION = <<~TEXT.chomp
      Open tab specified by ID. Valid IDs are: "applications", "processes", "cpu", "memory",
      "gpu-$PCI_SLOT$", "drive-$MODEL_NAME_OR_DEVICE_NAME$", "network-$INTERFACE_NAME$",
      "battery-$MANUFACTURER$-$MODEL_NAME$-$DEVICE_NAME$"
    TEXT

    def self.parse(argv)
      {}.tap do |options|
        parser(options).parse(argv)
      end
    end

    def self.parser(options)
      OptionParser.new do |parser|
        parser.banner = "Usage: resources [OPTIONS]"

        FLAGS.each do |name, (short, description)|
          parser.on(short, "--#{name.to_s.tr("_", "-")}", description) do
            options[name] = true
          end
        end

        parser.on("-t", "--open-tab-id ID", OPEN_TAB_DESCRIPTION) do |id|
          options[:open_tab_id] = id
        end

        parser.on("-V", "--version", "Print version information") do
          options[:version] = true
        end
      end
    end
  end
end
