# Copyright Vespa.ai. All rights reserved.

require 'tempfile'

require 'performance/system'
require 'performance/resultmodel'
require 'test/unit'

class MockModel
  def initialize(value)
    @value = value
  end
  def has_parameter?(param)
    true
  end

  def metric(name, source)
    @value
  end

  def parameter(name)
    @value
  end
end

class ResultModelTest < Test::Unit::TestCase

  def notest_readwrite
    begin
      f = Tempfile.new('result.xml')
      path = f.path
      f.close
      r = Perf::Result.new('5.0')

      r.fbench = { 'runtime' => 555, '99p' => '5.5', '95p' => '1.5', 'successfulrequests' => 5 }
      host = flexmock(Perf::System.new('localhost'))
      host.should_receive(:data).and_return({ 'cpu_util' => 99.98 })
      r.add_host host

      r.write(path)

      r2 = Perf::Result.read(path)

      assert_equal(r.vespa_version, r2.vespa_version)
      assert_equal(r.fbench['successfulrequests'], r2.fbench['successfulrequests'])
      assert_equal(r.hosts.size, r2.hosts.size)
      assert_equal(r.host('localhost').data['cpu_util'], r2.host('localhost').data['cpu_util'])
    ensure
      File.unlink(path)
    end
  end

  def test_custom_producer_parsing
    # Float
    m1 = MockModel.new("1.5")
    assert_equal(1.5, Perf.customproducer('a').call(m1))
    # Integer
    m2 = MockModel.new("5")
    assert_equal(5, Perf.customproducer('a').call(m2))
    # Float
    m3 = MockModel.new("howdy")
    assert_equal("howdy", Perf.customproducer('a').call(m3))
  end

end
