# Copyright Vespa.ai. All rights reserved.
require 'rubygems'
require 'test/unit'
require 'flexmock/test_unit'

require 'performance/system'

class SystemTest < Test::Unit::TestCase
  class MockResult
    attr_reader :metrics
    def initialize
      @metrics = {}
    end

    def add_metric(name, value, tag)
      @metrics[name + ':' + tag] = value
    end
  end

  def test_cpuutil
    node = flexmock('node')
    node.should_receive(:file?).and_return(true)
    node.should_receive(:execute).times(2).
      and_return(IO.read(File.join(File.dirname(__FILE__), "ysar_gather_output.txt")),
                 IO.read(File.join(File.dirname(__FILE__), "ysar_gather_output2.txt")))
    node.should_receive(:hostname).
      and_return('localhost')
    system = flexmock(Perf::System.new(node, {}))
    system.start
    system.end
    filler = system.fill
    result = MockResult.new
    filler.call(result)
    assert_in_delta(0.999900049975012,
                    result.metrics['cpuutil:localhost'],
                    0.00000001)
  end

end
