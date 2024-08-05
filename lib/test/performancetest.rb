# Copyright Vespa.ai. All rights reserved.
require 'test/unit'

ENV['VESPA_FACTORY_NO_AUTORUNNER'] = "true"

require 'performance_test'
require 'performance/resultmodel'

class PerfTestOne < PerformanceTest

end

class PerfTestTwo < PerformanceTest

end

class PerfResultModelTest < Test::Unit::TestCase

  def test_cpuutil
    r = Perf::Result.read(File.join(File.dirname(__FILE__), 'data', 'perfresult.xml'))
    puts Perf.customproducer('cpuutil').call(r)
    assert_equal Perf.customproducer('cpuutil', 'test4-eirik.trondheim.corp.yahoo.com').call(r), 0.260960334029228
  end
end
