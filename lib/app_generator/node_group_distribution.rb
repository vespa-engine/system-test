# Copyright Vespa.ai. All rights reserved.
class NodeGroupDistribution
  include ChainedSetter

  chained_setter :partitions

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("distribution", :partitions => @partitions).to_s
  end
end
