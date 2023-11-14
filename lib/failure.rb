# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'backtracefilter'

class Failure
  include BacktraceFilter

  attr_reader :location, :message

  # Creates a new Failure with the given location and
  # message.
  def initialize(name, location, message)
    @test_name = name
    @location = location
    @message = message
    @location.each do |line|
      if line =~ /\/.*\/tests\/.*:\d+/
        @message += "\n" + line
      end
    end
  end

  # Returns a brief version of the error description.
  def short_desc
    message
  end

  # Returns a verbose version of the error description.
  def long_desc
    backtrace = filter_backtrace(location).join("\n     at ")
    "FAILURE IN '#{@test_name}': #@message\n\n     at #{backtrace}"
  end

  # Overridden to return long_desc.
  def to_s
    long_desc
  end
end
