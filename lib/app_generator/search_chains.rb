# Copyright Vespa.ai. All rights reserved.
class Renderer
  include ChainedSetter

  chained_setter :bundle
  chained_setter :config

  def initialize(id, cclass)
    @id = id
    @cclass = cclass
  end
  def to_xml(indent)
    XmlHelper.new(indent).
      tag("renderer", :id => @id, :class => @cclass, :bundle => @bundle).
        to_xml(@config).to_s
  end
end

class Searcher < Processor
  def initialize(id, after=nil, before=nil, klass=nil, bundle=nil)
    super(id, after, before, klass, bundle)
  end

  def to_xml(indent="")
    return dump_xml(indent, "searcher")
  end
end

class Federation < Searcher
  chained_forward :sources, :add => :push

  def initialize(id, after=nil, before=nil)
    super(id, after, before)
    @sources = []
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("federation", :id => @id).
      list_do(@sources) { |helper, id|
        helper.tag("source", :id => id).close_tag }.to_s
  end
end

class SearchChain
  include ChainedSetter

  chained_setter :inherits
  chained_setter :excludes
  chained_setter :config
  chained_forward :searchers, :add => :push

  def initialize(id="default", inherits="vespa", excludes="")
    @id = id
    @inherits = inherits
    @searchers = []
    @excludes = excludes
  end

  def to_container_xml(indent)
    XmlHelper.new(indent).
        tag("chain", :id => @id, :inherits => @inherits).
        to_xml(@config).
        to_xml(@searchers).to_s
  end
end

class ProviderNode
  def initialize(host, port)
    @host = host
    @port = port
  end
  def to_xml(indent)
     XmlHelper.new(indent).tag("node", :host => @host, :port => @port).to_s
  end
end

class Provider < SearchChain
  chained_setter :cluster
  chained_setter :cache_weight
  chained_setter :cache_size
  chained_setter :path

  def initialize(id, type)
    super(id)
    @type = type
    @cluster = nil
    @path = nil
    @cache_weight = nil
    @cache_size = nil
    @nodes = []
  end

  def node(host, port)
    @nodes.push(ProviderNode.new(host, port))
    return self
  end

  def to_xml(indent="")
    XmlHelper.new(indent).
      tag("provider", :id => @id, :type => @type, :path => @path,
                      :cluster => @cluster, :cacheweight => @cache_weight, :cachesize => @cache_size,
                      :excludes => @excludes).
        to_xml(@config).
        tag("nodes").
          to_xml(@nodes).close_tag.
        to_xml(@searchers).to_s
  end

  def to_container_xml(indent)
    to_xml(indent)
  end
end

class SearchChains
  include ChainedSetter

  chained_forward :search_chains, :add => :push
  chained_forward :config, :config => :add

  def initialize()
    @search_chains = []
    @config = ConfigOverrides.new
  end

  def to_container_xml(indent)
    XmlHelper.new(indent).
      to_xml(@config).
      to_xml(@search_chains, :to_container_xml).to_s
  end
end

