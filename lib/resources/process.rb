# frozen_string_literal: true

require "etc"

module Resources
  # Process represents one running process read from procfs, plus the
  # previous reading needed to turn its cumulative counters into per-tick
  # rates.
  #
  # Ported from upstream's src/utils/process.rs. Upstream reads procfs through
  # a separate privileged companion process (`resources-processes`) and talks
  # to it over a msgpack pipe; that companion binary is `lib/resources/
  # privileged.rb`, not yet ported, so this port reads /proc directly in the
  # main process instead. Everything downstream of a `ProcessData` snapshot —
  # the CPU/IO ratios, the executable-name heuristic, process actions — is
  # ported as upstream has it. GPU and NPU usage are left out: `gpu.rb` and
  # `npu.rb` do not exist yet in this port.
  class Process
    PROC = "/proc"

    # Upstream's ProcessAction enum.
    module Action
      TERM = "TERM"
      STOP = "STOP"
      KILL = "KILL"
      CONT = "CONT"
    end

    SIGNALS = {
      Action::TERM => "TERM",
      Action::STOP => "STOP",
      Action::KILL => "KILL",
      Action::CONT => "CONT",
    }.freeze

    # Upstream's ProcessData: one point-in-time snapshot read from procfs.
    Snapshot = Struct.new(
      :pid,
      :parent_pid,
      :uid,
      :user,
      :comm,
      :commandline,
      :state,
      :user_cpu_time,
      :system_cpu_time,
      :starttime,
      :timestamp,
      :memory_usage,
      :swap_usage,
      :read_bytes,
      :write_bytes,
      keyword_init: true,
    )

    class << self
      # Upstream's Process::all_data, minus the companion-process indirection:
      # one Process per numeric entry under /proc, built straight from this
      # read.
      def all
        Dir.children(PROC).filter_map { |entry| process_for(entry) if entry.match?(/\A\d+\z/) }
      end

      def tick_rate
        @tick_rate ||= read_clk_tck
      end

      def num_cpus = @num_cpus ||= Etc.nprocessors

      private

        def process_for(entry)
          snapshot(entry.to_i)&.then { |data| new(data) }
        end

        def snapshot(pid)
          stat = read_file(File.join(PROC, pid.to_s, "stat"))
          stat&.then { |text| snapshot_from_files(pid, text) }
        end

        def snapshot_from_files(pid, stat_text)
          fields = parse_stat(stat_text)
          fields&.then do |parsed|
            Snapshot.new(
              pid:             pid,
              parent_pid:      parsed[:ppid],
              uid:             uid_of(pid),
              user:            user_of(uid_of(pid)),
              comm:            parsed[:comm],
              commandline:     read_cmdline(pid),
              state:           parsed[:state],
              user_cpu_time:   parsed[:utime],
              system_cpu_time: parsed[:stime],
              starttime:       parsed[:starttime],
              timestamp:       monotonic_ms,
              memory_usage:    rss_bytes(pid),
              swap_usage:      swap_bytes(pid),
              read_bytes:      io_field(pid, "read_bytes"),
              write_bytes:     io_field(pid, "write_bytes"),
            )
          end
        end

        # /proc/<pid>/stat's fields are space separated except for comm, which
        # is parenthesised and may itself contain spaces or parentheses; the
        # outermost parens are the ones that matter.
        def parse_stat(text)
          open_paren = text.index("(")
          close_paren = text.rindex(")")
          (open_paren && close_paren)&.then do
            comm = text[(open_paren + 1)...close_paren]
            rest = text[(close_paren + 2)..].to_s.split

            {
              comm:      comm,
              state:     rest.fetch(0, "?"),
              ppid:      rest.fetch(1, "0").to_i,
              utime:     rest.fetch(11, "0").to_i,
              stime:     rest.fetch(12, "0").to_i,
              starttime: rest.fetch(19, "0").to_i,
            }
          end
        end

        def read_cmdline(pid)
          contents = read_file(File.join(PROC, pid.to_s, "cmdline")).to_s
          contents.tr("\0", " ").strip
        end

        def uid_of(pid)
          File.stat(File.join(PROC, pid.to_s)).uid
        rescue SystemCallError
          nil
        end

        def user_of(uid)
          uid&.then { |value| Etc.getpwuid(value)&.name }
        rescue ArgumentError
          nil
        end

        def rss_bytes(pid)
          statm = read_file(File.join(PROC, pid.to_s, "statm"))
          statm&.split&.fetch(1, nil)&.then { |pages| pages.to_i * page_size }
        end

        def swap_bytes(pid)
          status = read_file(File.join(PROC, pid.to_s, "status"))
          status&.then { |text| text[/^VmSwap:\s*(\d+) kB/, 1]&.to_i&.*(1024) }
        end

        def io_field(pid, name)
          io = read_file(File.join(PROC, pid.to_s, "io"))
          io&.then { |text| text[/^#{name}:\s*(\d+)/, 1]&.to_i }
        end

        def page_size
          @page_size ||= read_getconf("PAGESIZE") || 4096
        end

        def read_clk_tck = read_getconf("CLK_TCK") || 100

        def read_getconf(name)
          output = IO.popen(["getconf", name], &:read)
          Integer(output.strip)
        rescue SystemCallError, ArgumentError, TypeError
          nil
        end

        def monotonic_ms = (::Process.clock_gettime(::Process::CLOCK_MONOTONIC) * 1000).to_i

        def read_file(path)
          File.read(path)
        rescue SystemCallError, IOError
          nil
        end
    end

    attr_reader :data, :executable_path, :executable_name, :display_name
    attr_reader :cpu_time_last, :timestamp_last, :read_bytes_last, :write_bytes_last

    def initialize(data)
      @data = data
      @executable_path, @executable_name = parse_executable(data.commandline)
      @display_name = compute_display_name(data.comm, @executable_name)
      @cpu_time_last = 0
      @timestamp_last = 0
      @read_bytes_last = data.read_bytes&.then { 0 }
      @write_bytes_last = data.write_bytes&.then { 0 }
    end

    def pid = @data.pid

    # Upstream's Process::update (implicit in the processes page's refresh
    # loop): rolls the current snapshot into "last" before replacing it with
    # a fresh one.
    def update(new_data)
      @cpu_time_last = @data.user_cpu_time + @data.system_cpu_time
      @timestamp_last = @data.timestamp
      @read_bytes_last = @data.read_bytes || @read_bytes_last
      @write_bytes_last = @data.write_bytes || @write_bytes_last
      @data = new_data
    end

    # Upstream's Process::cpu_time_ratio.
    def cpu_time_ratio
      if @cpu_time_last.zero?
        0.0
      else
        delta_cpu_time = [(@data.user_cpu_time + @data.system_cpu_time) - @cpu_time_last, 0].max * 1000.0
        delta_time = [@data.timestamp - @timestamp_last, 0].max

        finite_or_zero(delta_cpu_time / (delta_time * self.class.tick_rate * self.class.num_cpus))
      end
    end

    # Upstream's Process::read_speed, in bytes per second.
    def read_speed
      speed_of(@data.read_bytes, @read_bytes_last)
    end

    # Upstream's Process::write_speed, in bytes per second.
    def write_speed
      speed_of(@data.write_bytes, @write_bytes_last)
    end

    def starttime = @data.starttime.to_f / self.class.tick_rate

    # Upstream's Process::adjust: renice the process, going through `pkexec`
    # when the plain attempt is refused. Upstream also sets CPU affinity
    # through the same privileged helper; that is left out here along with
    # the helper itself.
    def adjust(niceness)
      ::Process.setpriority(::Process::PRIO_PROCESS, @data.pid, niceness)
    rescue Errno::EPERM, Errno::EACCES
      system("pkexec", "renice", "-n", niceness.to_s, "-p", @data.pid.to_s, exception: true)
    end

    # Upstream's Process::execute_process_action, again going through
    # `pkexec` when unprivileged delivery is refused.
    def execute_process_action(action)
      signal = SIGNALS.fetch(action)
      ::Process.kill(signal, @data.pid)
    rescue Errno::EPERM
      system("pkexec", "kill", "-s", signal, @data.pid.to_s, exception: true)
    end

    private

      def speed_of(current, last)
        if current && last
          if @timestamp_last.zero?
            0.0
          else
            bytes_delta = [current - last, 0].max.to_f
            time_delta = [@data.timestamp - @timestamp_last, 0].max.to_f

            (bytes_delta / time_delta) * 1000.0
          end
        end
      end

      # Upstream splits on NUL first and then on " --" because Chromium (and
      # everything based on it) does not NUL-delimit its own argv.
      def parse_executable(commandline)
        first_arg = commandline.split("\0").first.to_s.split(" --").first.to_s
        path = first_arg.empty? ? commandline : first_arg
        name = path.split("/").last || path

        [path, name]
      end

      def compute_display_name(comm, executable_name)
        if executable_name.start_with?(comm.to_s)
          executable_name
        else
          comm.to_s
        end
      end

      def finite_or_zero(value)
        if value.finite?
          value
        else
          0.0
        end
      end
  end
end
