# Copyright Vespa.ai. All rights reserved.

require 'search_test'

class TensorConformanceTest < SearchTest

  def setup
    set_owner('arnej')
  end

  def test_tensor_evaluation
    set_description('Test tensor evaluation conformance in production implementations')
    node_proxy = vespa.nodeproxies.values.first
    command="B=#{Environment.instance.vespa_home}/bin/ && " +
        '${B}vespa-tensor-conformance generate |' +
        '${B}vespa-evaluate-tensor-conformance.sh |' +
        '${B}vespa-tensor-conformance evaluate |' +
        '${B}vespa-tensor-conformance verify'
    (exitcode, output) = node_proxy.execute(command, {:exitcode => true, :exceptiononfailure => false})
    puts "Exit code from vespa-tensor-conformance verify: #{exitcode}"
    assert_equal(0, exitcode.to_i)
  end


end
