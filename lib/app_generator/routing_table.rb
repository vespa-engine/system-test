# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Hop
  include ChainedSetter

  chained_forward :sessions, :recipient => :push

  def initialize(name, elastic_selector=nil)
    @name = name
    @elastic_selector = elastic_selector
    @sessions = []
  end

  def ignore
    @ignore = true
    self
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("hop", :name => @name,
                 :selector => @elastic_selector,
                 :"ignore-result" => @ignore && "true").
        list_do(@sessions) { |helper, session|
          helper.tag("recipient", :session => session) }.to_s
  end
end

class Route
  def initialize(name, hops)
    @name = name
    @hops = hops
  end

  def to_xml(indent)
    XmlHelper.new(indent).tag("route", :name => @name, :hops => @hops).to_s
  end
end

class RoutingTable
  include ChainedSetter

  chained_forward :entries, :add => :push

  def initialize
    @entries = []
  end

  def no_verify
    @verify = "false"
    self
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("routingtable", :protocol => "document", :verify => @verify).
      to_xml(@entries, :to_xml).to_s
  end
end

class Routing
  def initialize
    @routing_table = nil
  end

  def table(routing_table)
    @routing_table = routing_table
  end

  def to_xml(indent)
    return "" unless @routing_table
    XmlHelper.new(indent).
      tag("routing", :version => "1.0").
        to_xml(@routing_table, :to_xml).to_s
  end
end
