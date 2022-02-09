# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Gateway < NodeBase
  tag "node"

  def initialize(hostalias, jvmargs=nil, baseport="")
    super(:hostalias => hostalias, :jvmargs => jvmargs)
    set_baseport(baseport) if !baseport.empty?
  end

end

class LoadType
  def initialize(name, pri=nil)
    @name = name
    @pri = pri
  end

  def to_xml(indent="")
    node = XmlHelper.new(indent)
    if (@pri != nil)
      #node = node.tag("type", :name => @name, ":default-priority" => @pri)
      node = node.tag("type", :name => @name)
    else
      node = node.tag("type", :name => @name)
    end
    node.close_tag.to_s
  end
end

class Clients
  include ChainedSetter

  attr_accessor :accept_no_clients

  chained_setter :gateways_jvmargs
  chained_setter :feeder_options

  chained_forward :load_types, :load_type => :push

  def gateways_jvmargs= args
    @gateways_jvmargs = args
    @default_jvmargs = args
  end

  def initialize
    @gateways = []
    @gateways_jvmargs = nil
    @load_types = []
    @feeder_options = nil
    @accept_no_clients = true
  end

  def gateway_list
    return @gateways unless @gateways.empty?
    return [Gateway.new("node1")]
  end

  def create_gateways(indent)
    if (@accept_no_clients && @gateways.empty?)
      return ""
    end

    if !gateway_list.empty?
      return XmlHelper.new(indent).
        tag("container", :version => "1.0", :id => "doc-api").
        tag_always("document-api").to_xml(@feeder_options).close_tag.
        tag("http").tag("server", :id => "default", :port => "19020").close_tag.close_tag.
        tag("nodes", :jvmargs => @gateways_jvmargs).to_xml(gateway_list).close_tag.
        close_tag.to_s
    end

    return ""
  end

  def to_xml(indent)
    if @load_types.empty?
      return ""
    end

    helper = XmlHelper.new(indent)

    helper.tag("clients", :version => "2.0").
      tag("load-types").
      to_xml(@load_types).
      close_tag
    return helper.to_s
  end
end
