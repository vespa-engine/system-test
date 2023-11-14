# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'test/unit'
require '../proc_tools'

class ProcToolsTest < Test::Unit::TestCase
  include Perf

  def setup
    @signal = [0, 2, 4, 6]
  end

  def test_first_intersection
    assert_equal(0, ProcTools.first_intersection(@signal, 0))
    assert_equal(1, ProcTools.first_intersection(@signal, 1))
    assert_equal(2, ProcTools.first_intersection(@signal, 2))
    assert_equal(-1, ProcTools.first_intersection(@signal, 6))
  end


end