# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class NodeSpec < NodeBase
  tag "node"

  def initialize(hostalias, index, params = {})
    super({:hostalias => hostalias, :index => index }.merge(params))
  end

end

class NodeGroup
  include ChainedSetter

  chained_forward :groups, :group => :push
  chained_forward :nodes, :node => :push
  chained_forward :distribution, :distribution => :partitions
  chained_forward :config, :config => :add
  chained_setter :cpu_socket_affinity

  def initialize(index, name)
    @index = index
    @cpu_socket_affinity = nil
    @name = name
    @groups = []
    @nodes = []
    @distribution = NodeGroupDistribution.new
    @config = ConfigOverrides.new
  end

  def default_nodes(count, bias)
    count.times do |i|
      node(NodeSpec.new("node1", i + bias))
    end
    self
  end

  def strip_name()
    @name = nil;
    self
  end

  def to_xml(indent)
    builder = XmlHelper.new(indent)
    if (@name == nil)
        if (@cpu_socket_affinity != nil) then
            builder = builder.tag("group", :"cpu-socket-affinity" => @cpu_socket_affinity)
        else
            builder = builder.tag("group")
        end
    else
        if (@cpu_socket_affinity != nil) then
            builder = builder.tag("group", :"distribution-key" => @index,
                                  :name => @name, :"cpu-socket-affinity" => @cpu_socket_affinity)
        else
            builder = builder.tag("group", :"distribution-key" => @index,
                                  :name => @name)
        end
    end
    builder.to_xml(@config).
        to_xml(@distribution).
        to_xml(@groups).
        to_xml(@nodes, :to_xml_with_distribution_key).to_s
  end

end
