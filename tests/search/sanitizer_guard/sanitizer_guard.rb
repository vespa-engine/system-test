# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'

class SanitizerGuardTest < SearchTest

  def setup
    set_owner('havardpe')
  end

  def test_sanitizer_none
    set_description('Make sure we are not compiled with any sanitizers')
    node_proxy = vespa.nodeproxies.values.first
    command="#{Environment.instance.vespa_home}/bin/vespa-print-default sanitizers"
    (exitcode, output) = node_proxy.execute(command, {:exitcode => true, :exceptiononfailure => false})
    assert_equal(0, exitcode.to_i)
    assert_equal("none", output.chomp)
  end

  def teardown
    stop
  end

end
