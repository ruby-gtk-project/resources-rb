# frozen_string_literal: true

require_relative "cpu"
require_relative "process"

module Resources
  # ProcessEntry is the display-ready wrapper the Processes page's list model
  # holds one of per row: a Process's raw counters turned into the derived
  # values a row shows (CPU percentage, combined memory, I/O rates).
  #
  # Ported from upstream's src/ui/pages/processes/process_entry.rs. Upstream
  # wraps a GObject around the same fields so property bindings and the
  # column view's sorters can read them; this port is a plain object instead,
  # since nothing here needs GObject's property machinery on its own.
  # `gpu_usage`, `enc_usage`, `dec_usage`, `gpu_mem_usage`, `cgroup` and
  # `containerization` are left out: they depend on `gpu.rb` and `app.rb`,
  # neither of which exist yet in this port.
  class ProcessEntry
    attr_reader :pid, :name, :commandline, :user, :running_since
    attr_reader :cpu_usage, :memory_usage, :swap_usage, :combined_memory_usage
    attr_reader :read_speed, :read_total, :write_speed, :write_total
    attr_reader :user_cpu_time, :system_cpu_time, :total_cpu_time
    attr_reader :niceness

    def initialize(process)
      @pid = process.pid
      @name = process.display_name
      @commandline = process.data.commandline
      @user = process.data.user
      @running_since = running_since_of(process)
      update(process)
    end

    # Upstream's ProcessEntry::update: the counters that change every refresh,
    # as opposed to the ones fixed at creation (pid, name, user).
    def update(process)
      @cpu_usage = process.cpu_time_ratio
      @memory_usage = process.data.memory_usage || 0
      @swap_usage = process.data.swap_usage || 0
      @combined_memory_usage = @memory_usage + @swap_usage
      @read_speed = process.read_speed || -1.0
      @read_total = process.data.read_bytes || -1
      @write_speed = process.write_speed || -1.0
      @write_total = process.data.write_bytes || -1
      @user_cpu_time = process.data.user_cpu_time.to_f / Process.tick_rate
      @system_cpu_time = process.data.system_cpu_time.to_f / Process.tick_rate
      @total_cpu_time = @user_cpu_time + @system_cpu_time
      @niceness = niceness_of(process)
    end

    private

      # Upstream's Process::running_since: the process's recorded start, as
      # seconds since boot, converted to a wall-clock time via the current
      # uptime.
      def running_since_of(process)
        uptime = Cpu.uptime
        if uptime
          (Time.now - uptime + process.starttime).strftime("%c")
        end
      end

      def niceness_of(process)
        ::Process.getpriority(::Process::PRIO_PROCESS, process.pid)
      rescue Errno::ESRCH
        0
      end
  end
end
