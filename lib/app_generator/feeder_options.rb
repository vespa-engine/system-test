# Copyright Vespa.ai. All rights reserved.
class FeederOptions
  include ChainedSetter

  chained_setter :timeout

  def timeout(timeout)
    @timeout = timeout
    self
  end

  def to_xml(indent)
    XmlHelper.new(indent).
        tag("timeout").content(@timeout).close_tag.
        to_s
  end
end
