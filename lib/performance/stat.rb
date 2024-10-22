# Copyright Vespa.ai. All rights reserved.
require 'performance/text_report_builder'

module Perf
  module Stat

    # Used for /proc/net and /proc/netstat, which have the format:
    # Name0: Field0Desc Field1Desc ...
    # Name0: Field0Value Field1Value ...
    # Name1: <repeat the above for NameN*2 lines>
    class ProcInfo

      def initialize(data)
        desc = {}
        data.each_line do |line|
          if line =~ /^([\w\d]+):\s+([-\w\d\s]+)$/
            key = $~[1]
            desc[key] = [] if not desc[key]
            desc[key] << $~[2].split
          else
            puts "unknown line: #{line}"
          end
        end
        @fields = {}
        desc.each do |group, vals|
          raise "No key-value mapping found for #{group}" if vals.size != 2
          @fields[group] = {}
          vals[0].zip(vals[1]).each do |k, v|
            @fields[group][k] = v.to_i
          end
        end
      end

      def [](k)
        @fields[k]
      end

      def as_map
        @fields
      end
      
    end

    class NetworkDeviceInfo
      
      def initialize(data)
        @info = {}
        data.each_line do |line|
          if line =~ /^\s*([\w\d_-]+):\s*([\d\s]+)$/
            dev = $~[1]
            v = $~[2].split.map { |v| v.to_i }
            @info[dev] = Stat::assoc_array([:in_bytes, :in_packets, :in_errs,
                                            :in_drop, :in_fifo, :in_frame,
                                            :in_compressed, :in_multicast,
                                            :out_bytes, :out_packets, :out_errs,
                                            :out_drop, :out_fifo, :out_colls,
                                            :out_carrier, :out_compressed], v)
          end
        end
      end

      def [](dev)
        @info[dev]
      end

      def as_map
        @info
      end

    end
    
    # /proc/diskstats
    class DiskInfo

      def initialize(data)
        @info = {}
        data.each_line do |line|
          if line =~ /^\s*(\d+)\s+(\d+)\s+([\w\d\/-]+)\s+([\d\s]+)$/
            dev = $~[3]
            v = $~[4].split.map { |v| v.to_i }
            raise 'Unknown /proc/diskstats format' if v.size < 11
            # Based on http://www.kernel.org/doc/Documentation/iostats.txt
            # Note: ios_in_progress is not a counter, i.e. it's unusable.
            @info[dev] = Stat::assoc_array([:reads_completed, :reads_merged,
                                            :sectors_read, :read_time_ms,
                                            :writes_completed, :writes_merged,
                                            :sectors_written, :write_time_ms,
                                            :ios_in_progress, :io_time_ms,
                                            :weighted_io_time_ms], v)
          else
            puts "unknown line: #{line}"
          end
        end
      end

      def [](dev)
        @info[dev]
      end

      def as_map
        @info
      end

    end

    class VmInfo
      
      def initialize(data)
        @info = {}
        data.each_line do |line|
          if line =~ /([\w\d_-]+)\s+(\d+)/
            @info[$~[1]] = $~[2].to_i
          else
            raise "unknown line in /proc/vmstat: #{line}"
          end
        end
      end

      def [](key)
        @info[key]
      end

      def as_map
        @info
      end

    end

    # /proc/stat
    # format: key metric0 metric1 ... metricN
    class CpuInfo

      def initialize(data)
        @info = {}
        data.each_line do |line|
          if line =~ /([\w\d_-]+)\s+([\d\s]+)/
            key = $~[1]
            v = $~[2].split.map { |v| v.to_i }
            if key =~ /^cpu/
              @info[key] = Stat::assoc_array([:user, :nice, :system, :idle,
                                              :iowait, :irq, :softirq], v)
            else
              @info[key] = v
            end
          elsif not line.strip.empty?
            raise "unknown line in /proc/stat: #{line}"
          end
        end
      end

      def [](key)
        @info[key]
      end

      def as_map
        @info
      end

    end

    class HostToInternalMetricConverter

      def get_cpu_util(metrics)
        cpu = metrics[:cpu]['cpu']
        total = cpu.values.reduce(:+)
        used = total - cpu[:idle]
        used.to_f / total
      end

      def get_forks(metrics)
        metrics[:cpu]['processes'][0]
      end

      def get_network(metrics)
        net = metrics[:net]
        {
          :ip => {
            :in_receives    => net['Ip']['InReceives'],
            :out_requests   => net['Ip']['OutRequests']
          },
          :udp => {
            :in_datagrams  => net['Udp']['InDatagrams'],
            :out_datagrams => net['Udp']['OutDatagrams'],
            :in_errors     => net['Udp']['InErrors']
          },
          :tcp => {
            :in_segs       => net['Tcp']['InSegs'],
            :out_segs      => net['Tcp']['OutSegs'],
            :retrans_segs  => net['Tcp']['RetransSegs'],
            :conn_est      => net['Tcp']['ActiveOpens'] + net['Tcp']['PassiveOpens'],
            :conn_drop     => 0, ##net['TcpExt']['ConnDrop'], FIXME
            :conn_timeout  => net['TcpExt']['TCPAbortOnTimeout'],
            :listen_overflow => net['TcpExt']['ListenOverflows']
          },
          # Filter away all interfaces that don't have any traffic.
          :if => net[:if].reject { |k, v|
            (v[:in_packets] == 0 and v[:out_packets] == 0 and
             v[:in_errs] == 0 and v[:out_errs] = 0)
          }
        }
      end

      def get_swap(metrics)
        {
          :swapped_out => metrics[:vm]['pswpout'],
          :swapped_in => metrics[:vm]['pswpin'],
          :paged_out => metrics[:vm]['pgpgout'],
          :paged_in => metrics[:vm]['pgpgin']
        }
      end

      def get_disks(metrics)
        return if metrics[:disk].nil? # not present on VMs.
        # Return already parsed structure verbatim for disks that are
        # not partitions or memory pseudo-devices.
        # Filter away all idle devices.
        metrics[:disk].reject { |k, v|
          k =~ /p\d$|^ram|^dm/ || (v[:reads_completed] == 0 and v[:writes_completed] == 0)
        }
      end

      def host_to_internal(metrics)
        {
          :cpu_util => get_cpu_util(metrics),
          :fork     => get_forks(metrics),
          :network  => get_network(metrics),
          :swap     => get_swap(metrics),
          :disk     => get_disks(metrics)
        }
      end

    end

    class Snapshot

      attr_accessor :fields, :time_taken, :metrics

      def initialize(fields, params={})
        @fields = fields
        @time_taken = Time.now

        if not params[:disable_metric_building]
          converter = HostToInternalMetricConverter.new
          @metrics = converter.host_to_internal(@fields)
        end
      end

      def [](x)
        @fields[x]
      end

      def entry_delta(this, that)
        if this.class != that.class
          raise "Class mismatch when subtracting metrics: #{this.class} != #{that.class}"
        end
        if this.is_a? Hash
          map_delta(this, that)
        elsif this.is_a? Array
          array_delta(this, that)
        else
          this - that
        end
      end

      def map_delta(this, that)
        ret = {}
        this.each do |k, v|
          other = that[k]
          raise "Field '#{k}' not found in other map" if other.nil?
          ret[k] = entry_delta(v, other)
        end
        ret
      end

      def array_delta(this, that)
        this.zip(that).map do |a, b|
          entry_delta(a, b)
        end
      end

      def subtract(other, params={})
        # Recursive delta calculation of maps and arrays.
        Snapshot.new(entry_delta(@fields, other.fields), params)
      end

    end

    def Stat::assoc_array(names, values)
      ret = {}
      # Take the minimum intersected size, since columns may be missing at the end.
      len = [names.size, values.size].min
      names[0, len].zip(values[0, len]).each { |k, v| ret[k] = v  }
      ret
    end

    def Stat::system_snapshot(proc_fs)
      state = {}
      state[:cpu] = CpuInfo.new(proc_fs['stat']).as_map
      state[:net] = ProcInfo.new(proc_fs['net/snmp']).as_map # For Ip, Tcp, Udp, ...
      state[:net].merge! ProcInfo.new(proc_fs['net/netstat']).as_map # For TcpExt
      state[:net][:if] = NetworkDeviceInfo.new(proc_fs['net/dev']).as_map
      state[:vm] = VmInfo.new(proc_fs['vmstat']).as_map
      # If we're running on a jail, diskstats won't be available
      if proc_fs['diskstats']
        state[:disk] = DiskInfo.new(proc_fs['diskstats']).as_map
      end
      Snapshot.new state
    end

    class Period
      attr_reader :snapshot_start, :snapshot_end, :duration, :metrics

      def initialize(snapshot_start, snapshot_end)
        @snapshot_start = snapshot_start
        @snapshot_end = snapshot_end
        @duration = snapshot_end.time_taken - snapshot_start.time_taken
        @metrics = (snapshot_end.subtract(snapshot_start)).metrics
      end

      # Prints delta between start and end snapshots provided in constructor.
      def printable_result(params={})
        m = @metrics
        title = ("System metrics across %.2f second period%s:" %
                 [duration,
                  params[:n_ops] ? " (with #{params[:n_ops]} load operations)" : ''])

        rb = TextReport::Builder.new(title,
                                     :duration => @duration,
                                     :n_ops => params[:n_ops])

        rb.open_group('System')
        rb.single_metric('CPU utilization', m[:cpu_util] * 100.0, :suffix => '%')
        rb.avg_metric('Number of forks done', m[:fork])
        rb.avg_metric('Pages swapped out', m[:swap][:swapped_out], :warn_if_exceeding => 0)
        rb.avg_metric('Pages swapped in', m[:swap][:swapped_in], :warn_if_exceeding => 0)
        rb.close_group

        rb.open_group('Network')
        rb.open_group('IP')
        rb.avg_metric('Packets sent', m[:network][:ip][:out_requests])
        rb.avg_metric('Packets received', m[:network][:ip][:in_receives])
        rb.close_group
        rb.open_group('UDP')
        rb.avg_metric('Datagrams sent', m[:network][:udp][:out_datagrams])
        rb.avg_metric('Datagrams received', m[:network][:udp][:in_datagrams])
        rb.avg_metric('Datagram receive errors', m[:network][:udp][:in_errors], :warn_if_exceeding => 0)
        rb.close_group
        rb.open_group('TCP')
        rb.avg_metric('Connections established', m[:network][:tcp][:conn_est])
        rb.avg_metric('Connections dropped', m[:network][:tcp][:conn_drop])
        rb.avg_metric('Connections timed out', m[:network][:tcp][:conn_timeout], :warn_if_exceeding => 0)
        rb.avg_metric('Segments sent', m[:network][:tcp][:out_segs])
        rb.avg_metric('Segments received', m[:network][:tcp][:in_segs])
        rb.avg_metric('Segments retransmitted', m[:network][:tcp][:retrans_segs])
        rb.avg_metric('Listen overflows', m[:network][:tcp][:listen_overflow], :warn_if_exceeding => 0)
        rb.close_group
        m[:network][:if].each do |ni, ni_m|
          rb.open_group("Interface '#{ni}'")
          rb.avg_metric('Packets sent', ni_m[:out_packets])
          rb.avg_metric('KiB sent', ni_m[:out_bytes] / 1024.0, :unit => 'KiB')
          rb.single_metric('Avg sent packet size', ni_m[:out_bytes] / ni_m[:out_packets].to_f / 1024, :suffix => ' KiB')
          rb.avg_metric('Packets received', ni_m[:in_packets])
          rb.avg_metric('KiB received', ni_m[:in_bytes] / 1024, :unit => 'KiB')
          rb.single_metric('Avg received packet size', ni_m[:in_bytes] / ni_m[:in_packets].to_f / 1024, :suffix => ' KiB')
          rb.close_group
        end
        rb.close_group
        if m[:disk] # not present on VMs
          rb.open_group('Disks')
          bytes_per_sector = 512
          m[:disk].each do |dev, s|
            rb.open_group("Disk device '#{dev}'")

            rb.avg_metric('Reads completed', s[:reads_completed])
            bytes_read = s[:sectors_read] * bytes_per_sector
            rb.avg_metric('KiB read', bytes_read / 1024.0, :unit => 'KiB')
            if s[:reads_completed] > 0
              avg_read_size = bytes_read.to_f / s[:reads_completed]
              avg_read_time = s[:read_time_ms].to_f / s[:reads_completed]
            else
              avg_read_size = 0
              avg_read_time = 0
            end
            rb.single_metric('Avg read size', avg_read_size / 1024, :suffix => ' KiB')
            rb.single_metric('Avg time per read', avg_read_time, :suffix => ' ms')

            rb.avg_metric('Writes completed', s[:writes_completed])
            bytes_written = s[:sectors_written] * bytes_per_sector
            rb.avg_metric('KiB written', bytes_written / 1024.0, :unit => 'KiB')
            if s[:writes_completed] > 0
              avg_write_size = bytes_written.to_f / s[:writes_completed]
              avg_write_time = s[:write_time_ms].to_f / s[:writes_completed]
            else
              avg_write_size = 0
              avg_write_time = 0
            end
            rb.single_metric('Avg write size', avg_write_size / 1024, :suffix => ' KiB')
            rb.single_metric('Avg time per write', avg_write_time, :suffix => ' ms')

            # This should match iostat's disk utilization calculations.
            ops_total = (s[:reads_completed] + s[:writes_completed])
            ops_sec = ops_total / @duration.to_f
            avg_op_time_sec = (s[:io_time_ms] / 1000.0) / ops_total
            disk_util = ops_sec * avg_op_time_sec
            rb.single_metric('Disk utilization', disk_util * 100, :suffix => '%')
            rb.close_group
          end
        end
        
        rb.close_group

        rb.to_s
      end

    end

    class RealProcFs

      def [](name)
        begin
          File.read("/proc/#{name}")
        rescue
          nil
        end
      end

    end

    def Stat::create_snapshot
      fs = RealProcFs.new
      Stat::system_snapshot(fs)
    end

    def Stat::snapshot_period(old_snapshot, new_snapshot)
      Period.new(old_snapshot, new_snapshot)
    end

  end
end
