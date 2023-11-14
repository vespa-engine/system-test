# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'test/unit'
require 'executor'

class ExecutorTest < Test::Unit::TestCase

  def test_executor
    executor = Executor.new("")
    assert_equal("hello\n", executor.execute("echo hello", nil))
  end

end
