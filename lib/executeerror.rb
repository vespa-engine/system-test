# Copyright Vespa.ai. All rights reserved.
class ExecuteError < RuntimeError
  attr_accessor :output

  def initialize(*args)
    super(*args)
  end
end
