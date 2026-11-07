# frozen_string_literal: true

module Resources
  # Os reads the distro's pretty name and the running kernel version.
  #
  # Ported from upstream's src/utils/os.rs. Upstream reads
  # /run/host/etc/os-release instead when running under Flatpak; this port
  # has no Flatpak packaging, so only the plain /etc/os-release path is
  # implemented.
  module Os
    PATH_OS_RELEASE = "/etc/os-release"
    PATH_KERNEL_VERSION = "/proc/sys/kernel/osrelease"

    RE_PRETTY_NAME = /PRETTY_NAME="(.*)"/

    # Upstream's OsInfo.
    Info = Struct.new(:name, :kernel_version, keyword_init: true)

    class << self
      # Upstream's OsInfo::get.
      def get
        name = RE_PRETTY_NAME.match(read_file(PATH_OS_RELEASE).to_s)&.[](1)&.strip
        kernel_version = read_file(PATH_KERNEL_VERSION)&.strip

        Info.new(name: name, kernel_version: kernel_version)
      end

      private

        def read_file(path)
          File.read(path)
        rescue SystemCallError, IOError
          nil
        end
    end
  end
end
