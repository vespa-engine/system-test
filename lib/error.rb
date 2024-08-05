# Copyright Vespa.ai. All rights reserved.

require 'backtracefilter'

class Error
  include BacktraceFilter
  attr_reader :short_desc, :long_desc, :message

  # Creates a new Error with the given test_name and
  # exception message.
  # All strings are generated and the exception is dropped because
  # this class may be marshaled to be sent using drb. Some exception
  # like NoMethodError are not serializable.
  def initialize(name, exception)
    @message = _message(exception)
    @short_desc = _short_desc
    @long_desc = _long_desc(name, exception)
  end

  # Returns the message associated with the error.
  def _message(exception)
    "#{exception.class.name}: #{exception.message}"
  end

  # Returns a brief version of the error description.
  def _short_desc
    "#{message.split("\n")[0]}"
  end

  # Returns a verbose version of the error description.
  def _long_desc(test_name, exception)
    backtrace = filter_backtrace(exception.backtrace).join("\n     at ")
    "ERROR IN '#{test_name}': #{message}\n\n     at #{backtrace}"
  end

  # Overridden to return long_desc.
  def to_s
    long_desc
  end
end
