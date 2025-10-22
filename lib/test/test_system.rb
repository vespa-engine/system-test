# Copyright Vespa.ai. All rights reserved.

require 'performance/system'
require 'test/unit'

class SystemTest < Test::Unit::TestCase

  def test_cpuutil
    system = Perf::System.create_for_testing('localhost')
    start_cpu_used, start_cpu_total = system.calculate_cpu_usage(IO.read(File.join(File.dirname(__FILE__), "stat_output_start.txt")))
    end_cpu_used, end_cpu_total = system.calculate_cpu_usage(IO.read(File.join(File.dirname(__FILE__), "stat_output_end.txt")))
    system.set_cpu_util([start_cpu_used, start_cpu_total], [end_cpu_used, end_cpu_total])

    assert_in_delta(0.03661832197254973,
                    system.cpu_util,
                    0.00000001)
  end

end
