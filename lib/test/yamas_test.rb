# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'nodetypes/yamas.rb'
require 'test/unit'

class YamasTest < Test::Unit::TestCase

  include Yamas

  def testGetMetric
    messages = [
                {
                  'metrics' => {
                    'metric_1_name' => 1,
                    'metric_2_name' => 2
                  },
                  'dimensions' => {
                    'clustername' => 'search',
                    'node-type' => 'storage'
                  }
                }, {
                  'metrics' => {
                    'metric_a_name' => 3,
                    'metric_b_name' => 4
                  },
                  'dimensions' => {
                    'clustername' => 'ads',
                    'node-type' => 'storage'
                  }
                }, {
                  'metrics' => {
                    'metric_a_name' => 5,
                    'metric_b_name' => 6
                  },
                  'dimensions' => {
                    'clustername' => 'ads',
                    'node-type' => 'distributor'
                  }
                }
               ]

    assert_equal(1, get_metric(messages, 'metric_1_name'))
    assert_equal(2, get_metric(messages, 'metric_2_name'))

    assert_equal(0, get_metric(messages, 'unknown'))
    assert_equal(100, get_metric(messages, 'unknown', 100))

    assert_equal(1, get_metric(messages, 'metric_1_name', 0,
                               {'clustername' => 'search'}))
    assert_equal(0, get_metric(messages, 'metric_1_name', 0,
                               {'clustername' => 'ads'}))

    # There are two metrics named metric_a_name, but they have
    # different dimensions.
    assert_equal(3, get_metric(messages, 'metric_a_name', 0,
                               {'node-type' => 'storage'}))
    assert_equal(5, get_metric(messages, 'metric_a_name', 0,
                               {'node-type' => 'distributor'}))
  end
end
