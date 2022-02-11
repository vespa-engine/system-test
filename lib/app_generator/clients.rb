# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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

  chained_forward :load_types, :load_type => :push

  def initialize
    @load_types = []
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
