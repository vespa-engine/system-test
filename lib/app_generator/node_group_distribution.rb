# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class NodeGroupDistribution
  include ChainedSetter

  chained_setter :partitions

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("distribution", :partitions => @partitions).to_s
  end
end
