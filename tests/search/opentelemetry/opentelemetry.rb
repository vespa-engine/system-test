# Copyright Vespa.ai. All rights reserved.

require 'search_test'

class OpenTelemetryTest < SearchTest

  def setup
    set_owner('toregge')
  end

  def test_opentelemetry_smoketest
    set_description('Check that traces are propagated from vespa binaries using opentelemetry-cpp sdk')
    node_proxy = vespa.nodeproxies.values.first
    command="#{Environment.instance.vespa_home}/bin/vespa-opentelemetry-test"
    (exitcode, output) = node_proxy.execute(command, {:exitcode => true, :exceptiononfailure => false, :stderr => true})
    assert_equal(0, exitcode.to_i)
  end

end
