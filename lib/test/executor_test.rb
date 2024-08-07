# Copyright Vespa.ai. All rights reserved.

require 'test/unit'
require 'executor'

class ExecutorTest < Test::Unit::TestCase

  def test_executor
    executor = Executor.new("")
    assert_equal("hello\n", executor.execute("echo hello", nil))
  end

end
