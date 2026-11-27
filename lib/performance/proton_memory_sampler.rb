# Copyright Vespa.ai. All rights reserved.

module Perf

  # Samples memory usage (RSS) of all proton processes on a set of nodes in a background
  # thread. Processes are looked up on every sample, so proton can be started (or restarted)
  # after the sampler has been started. Each sample is the max RSS over all proton processes.
  #
  # Samples are grouped into phases. A phase is ended either explicitly (by starting a new one)
  # or when its stats are used in a report.
  class ProtonMemorySampler

    METRIC_PREFIX = 'memory.proton.rss'
    SAMPLE_COMMAND = "for p in $(pgrep -f 'sbin/[v]espa-proton-bin'); do " +
                     "echo \"$p $(grep -E '^(VmRSS|VmHWM):' /proc/$p/status | tr -s ' \\t\\n' ' ')\"; " +
                     "done 2>/dev/null"

    def initialize(nodes_proc, interval = 1.0)
      @nodes_proc = nodes_proc
      @interval = interval
      @lock = Mutex.new
      @phases = []
      @hwm = nil
      @failed_nodes = {}
      @stop = false
      @thread = nil
      new_phase('startup')
    end

    def start
      return if @thread
      @stop = false
      @thread = Thread.new do
        Thread.current.report_on_exception = false
        until @stop
          sample
          sleep @interval
        end
      end
    end

    def stop
      return unless @thread
      @stop = true
      @thread.join
      @thread = nil
      sample
    end

    # Starts a new phase, subsequent samples are attributed to this phase.
    def new_phase(label = nil)
      @lock.synchronize { @phases << { :label => label, :samples => [] } }
    end

    # Takes a sample and adds RSS stats for the current phase to the given result (unless it
    # already has them), then starts a new phase. The finished phase is labeled with
    # the result's 'label' parameter if it was not explicitly labeled when started.
    def fill_and_end_phase(result)
      sample
      phase = @lock.synchronize do
        p = @phases.last
        p[:label] ||= result.parameter('label') || "report_#{@phases.size}"
        @phases << { :label => nil, :samples => [] }
        p
      end
      samples = phase[:samples]
      return if samples.empty? || result.has_metric?("#{METRIC_PREFIX}.max")
      result.add_metric("#{METRIC_PREFIX}.max", samples.max)
      result.add_metric("#{METRIC_PREFIX}.avg", samples.sum / samples.size)
      result.add_metric("#{METRIC_PREFIX}.last", samples.last)
    end

    # Filler with stats for the whole run, for tests that want to write a summary report
    def summary_filler
      Proc.new do |result|
        all = all_samples
        unless all.empty?
          result.add_metric("#{METRIC_PREFIX}.max", all.max)
          result.add_metric("#{METRIC_PREFIX}.avg", all.sum / all.size)
          result.add_metric("#{METRIC_PREFIX}.end", all.last)
          result.add_metric("#{METRIC_PREFIX}.peak", @hwm) if @hwm
        end
      end
    end

    def summary
      phases = @lock.synchronize { @phases.reject { |p| p[:samples].empty? }.map(&:dup) }
      return 'No proton memory samples' if phases.empty?
      lines = ['Proton memory usage (RSS MB) per phase:',
               format('  %-40s %8s %10s %10s %10s', 'phase', 'samples', 'min', 'avg', 'max')]
      phases.each_with_index do |p, i|
        s = p[:samples]
        lines << format('  %-40s %8d %10s %10s %10s', p[:label] || "phase_#{i}", s.size,
                        mb(s.min), mb(s.sum / s.size), mb(s.max))
      end
      lines << "Proton RSS max sampled: #{mb(all_samples.max)} MB, peak (VmHWM): #{mb(@hwm || 0)} MB"
      lines.join("\n")
    end

    private

    def all_samples
      @lock.synchronize { @phases.flat_map { |p| p[:samples] } }
    end

    def sample
      rss = nil
      hwm = nil
      nodes.each do |node|
        read_node(node).each do |values|
          rss = [rss || 0, values['VmRSS']].max if values['VmRSS']
          hwm = [hwm || 0, values['VmHWM']].max if values['VmHWM']
        end
      end
      return unless rss
      @lock.synchronize do
        @phases.last[:samples] << rss
        @hwm = [@hwm || 0, hwm].max if hwm
      end
    end

    def nodes
      @nodes_proc.call.to_a
    rescue StandardError
      []
    end

    # Returns an array with one { 'VmRSS' => bytes, 'VmHWM' => bytes } hash per proton process on node
    def read_node(node)
      out = node.execute(SAMPLE_COMMAND, :noecho => true, :exceptiononfailure => false)
      out.to_s.each_line.map do |line|
        line.scan(/(VmRSS|VmHWM):\s+(\d+)\s+kB/).to_h { |k, v| [k, v.to_i * 1024] }
      end.reject(&:empty?)
    rescue StandardError => e
      name = node.respond_to?(:name) ? node.name : node.to_s
      unless @failed_nodes[name]
        puts "Failed sampling proton memory on #{name}: #{e.message}"
        @failed_nodes[name] = true
      end
      []
    end

    def mb(bytes)
      format('%.1f', bytes.to_f / (1024 * 1024))
    end

  end

end
