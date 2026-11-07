# frozen_string_literal: true

require "socket"
require "json"

module Resources
  # Snapd resolves a running snap's app into the freedesktop desktop ID of
  # the launcher that started it, by querying the local snapd REST API over
  # its Unix socket.
  #
  # Ported from upstream's src/utils/snapd.rs. Upstream caches a `Shared`
  # future per (snap name, snap app name) pair so concurrent lookups for the
  # same app share one in-flight request; this port has no async runtime, so
  # it caches the resolved (or failed) result directly and does the request
  # synchronously, once, the first time a given pair is asked for.
  module Snapd
    SNAPD_SOCKET = "/var/run/snapd.socket"

    class << self
      # Upstream's get_desktop_id (minus the future wrapper).
      def desktop_id(snap_name, snap_app_name)
        cache.fetch([snap_name, snap_app_name]) do
          cache[[snap_name, snap_app_name]] = desktop_id_uncached(snap_name, snap_app_name)
        end
      end

      private

        def cache
          @cache ||= {}
        end

        # Upstream's get_desktop_id_uncached.
        def desktop_id_uncached(snap_name, snap_app_name)
          json = request_json("/v2/snaps/#{snap_name}")
          if json
            apps = json.dig("result", "apps")
            if apps.is_a?(Array)
              app = apps.find { |candidate| candidate["name"] == snap_app_name }
              desktop_file = app&.[]("desktop-file")
              if desktop_file
                File.basename(desktop_file, File.extname(desktop_file))
              else
                nil
              end
            else
              nil
            end
          else
            nil
          end
        end

        def request_json(path)
          socket = UNIXSocket.new(SNAPD_SOCKET)
          begin
            socket.write("GET #{path} HTTP/1.1\r\nHost: localhost\r\nX-Allow-Interaction: false\r\nConnection: close\r\n\r\n")

            body = read_with_timeout(socket, 3)&.split("\r\n\r\n", 2)&.[](1)

            body && JSON.parse(body)
          ensure
            socket.close
          end
        rescue SystemCallError, IOError, JSON::ParserError
          nil
        end

        # Reads until the server closes the connection (it sent
        # `Connection: close`), giving up if no data arrives within
        # `seconds`. Returns `nil` on a timeout with nothing read yet, and
        # whatever was read so far once the socket stops being readable.
        def read_with_timeout(socket, seconds)
          data = +""
          done = false

          until done
            if IO.select(
              [socket],
              nil,
              nil,
              seconds,
            )
              chunk = socket.read_nonblock(4096, exception: false)
              case chunk
              when :wait_readable
                nil
              when nil
                done = true
              else
                data << chunk
              end
            else
              done = true
            end
          end

          data.empty? ? nil : data
        end
    end
  end
end
