# Copyright Vespa.ai. All rights reserved.
class ResourceLimits
  include ChainedSetter

  chained_setter :disk
  chained_setter :memory

  def initialize()
    @disk = nil
    @memory = nil
  end

  def to_xml(indent)
    helper = XmlHelper.new(indent)
    if @disk != nil || @memory != nil
      helper.tag("resource-limits")
      helper.tag("disk").content(@disk).close_tag
      helper.tag("memory").content(@memory).close_tag
      helper.close_tag
    end
    helper.to_s
  end

end

