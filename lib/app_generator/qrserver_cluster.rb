# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class QrserverCluster
  include ChainedSetter

  attr_reader :name, :_jvm_options

  chained_setter :baseport
  chained_setter :cache
  chained_setter :jvmoptions, :_jvm_options
  chained_setter :options
  chained_forward :renderers, :renderer => :push
  chained_forward :components, :component => :push
  chained_forward :search_chains,
                  :search_chain => :add,
                  :search_chains_config => :config
  chained_setter :processing

  def initialize(name = "default")
    @name = name
    @baseport = 0
    @cache = nil
    @components = []
    @_jvm_options = nil
    @options = nil
    @renderers = []
    @search_chains = SearchChains.new
    @nodes = []
    @processing = nil
    @hhttp = nil
    @should_add_default_docproc = false
  end

  class ComponentWithType
    def initialize(type, id, bundle, config, binding)
      @_type = type
      @_id = id
      @_bundle = bundle
      @_config = config
      @_binding = binding
    end

    def to_xml(indent)
      XmlHelper.new(indent).
        tag(@_type, :id => @_id, :bundle => @_bundle).
          to_xml(@_config).
          to_xml(@_binding).to_s
    end
  end

  def handler(id, config = nil, binding = nil)
    @components.push(ComponentWithType.new("handler", id, nil, config, binding))
    self
  end

  def filter(id, bundle = nil, config = nil, binding = nil)
    @components.push(ComponentWithType.new("filter", id, bundle, config, binding))
    self
  end

  def http
    @hhttp = Http.new if @hhttp == nil
    return @hhttp
  end

  class QrsNode < NodeBase
    tag "node"
    def body(indent)
      if @server_port
          return indent + "<server-port id=\"#{@server_id}\" port=\"#{@server_port}\"/>\n"
      end
      return ""
    end
    def server_port(id, port)
        @server_id = id
        @server_port = port
        self
    end
  end

  class Http
    def server(id, port)
      @server_id = id
      @server_port = port
      self
    end
    def to_xml(indent)
      XmlHelper.new(indent).
        tag("http").
          tag("server", { :id => @server_id, :port => @server_port }).close_tag.
        close_tag.to_s
    end
  end

  def node(params={})
    @nodes.push(QrsNode.new(params))
    self
  end

  def node_list
    return [QrsNode.new] if @nodes.empty?
    return @nodes
  end

  def set_baseport(baseport)
    @baseport = baseport
  end

  def add_default_docproc()
    @should_add_default_docproc = true
  end

  def to_xml(indent)
    nodes = node_list
    if @baseport > 0
      nodes.each { |node|
        node.set_baseport(@baseport)
      }
    end
    jvm_options = @_jvm_options ? { :options => @_jvm_options } : {}

    XmlHelper.new(indent).
      tag("cluster", :name => @name).
        tag("cache", :size => @cache).close_tag.
        to_xml(@renderers).
        to_xml(@options).
        to_xml(@components).
        to_xml(@processing).
        to_xml(@hhttp).
        tag("nodes").tag("jvm", jvm_options).close_tag.to_xml(nodes).close_tag.
        to_xml(@search_chains).to_s
  end

  def to_container_xml(indent)
    helper = XmlHelper.new(indent)
    if @baseport > 0
      helper.tag("container", :version => "1.0", :id => @name, :baseport => @baseport)
    else
      helper.tag("container", :version => "1.0", :id => @name)
    end
    helper.tag_always("search").to_xml(@search_chains, :to_container_xml).close_tag
    helper.tag_always("document-processing").close_tag if @should_add_default_docproc
    jvm_options = @_jvm_options ? { :options => @_jvm_options } : {}
    helper.tag("cache", :size => @cache).close_tag.
        to_xml(@renderers).
        to_xml(@components).
        to_xml(@processing).
        to_xml(@hhttp).
        tag("nodes").tag("jvm", jvm_options).close_tag.to_xml(node_list).close_tag.
        to_s
  end
end
