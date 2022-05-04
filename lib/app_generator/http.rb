# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Http
  include ChainedSetter

  chained_forward :config, :config => :add
  chained_forward :server, :server => :push
  chained_forward :filter, :filter => :push
  chained_forward :filter_chain, :filter_chain => :push
  chained_setter :strict_mode

  def initialize()
    @config = ConfigOverrides.new
    @filter = []
    @filter_chain = []
    @server = []
    @strict_mode = nil
  end

  def to_xml(indent="")
    filtering_attrs = {}
    if @strict_mode != nil
      filtering_attrs['strict-mode'] = @strict_mode
    end
    XmlHelper.new(indent).
    tag("http").
    tag("filtering", filtering_attrs).
      to_xml(@filter).
      to_xml(@filter_chain).close_tag.
    to_xml(@server).
    to_xml(@config).
    to_s
  end
end

class Server
  include ChainedSetter

  chained_setter :config
  chained_setter :ssl

  def initialize(id, port)
    @id = id
    @port = port
    @config = nil
    @ssl = nil
  end

  def to_xml(indent="")
    xml = XmlHelper.new(indent)

    xml.tag("server", :id => @id, :port => @port)

    xml.to_xml(@config)

    xml.to_xml(@ssl)

    xml.to_s
  end
end

module HttpModule
  class Component
    include ChainedSetter

    chained_forward :component, :component => :push

    def initialize(id, class_id = nil, bundle = nil, config = nil, type = "component")
      @type = type
      @id = id
      @class_id = class_id
      @bundle = bundle
      @config = config

      @component = []
    end

    def to_xml(indent)
      to_xml_not_string(indent).to_s
    end

    def to_xml_not_string(indent)
      xml = XmlHelper.new(indent).
        tag(@type, :id => @id, :class => @class_id, :bundle => @bundle).
        to_xml(@config)

      @component.each { |c|
        xml.to_xml(c)
      }
      xml
    end
  end
end

class HttpFilter < HttpModule::Component
  include ChainedSetter

  chained_forward :config, :config => :add

  def initialize(id, class_id = nil, bundle = nil, filter_config=nil)
    super(id,  class_id, bundle, ConfigOverrides.new, "filter")
    @filter_config=filter_config
  end

  def to_xml(indent)
    xml = to_xml_not_string(indent)

    if !@filter_config.nil?
      xml.to_xml(@filter_config.to_xml(indent + '  '))
    end
    xml.to_s
  end

end

class FilterConfig
  include ChainedSetter

  def initialize
    @map = {}
  end
  def add(key, value)
    @map[key] = [] unless @map.has_key?(key)
    @map[key].push(value)
    self
  end

  def to_xml(indent)
    helper = XmlHelper.new(indent)
    xml = helper.tag("filter-config")

      helper.list_do(@map.keys.sort) { |map_helper, key|
          map_helper.tag(key).to_xml(@map[key]).close_tag }.to_s

    xml.to_s
  end
end

class FilterChain
  include ChainedSetter

  chained_forward :filters, :filter => :push
  chained_forward :bindings, :binding => :push

  def initialize(tagName, id)
    @tagName = tagName
    @id = id
    @filters = []
    @bindings = []
  end

  def to_xml(indent)
    out = XmlHelper.new(indent).tag(@tagName, :id => @id).
        to_xml(@filters)
    @bindings.each { |b|
      out.tag("binding").content(b).close_tag
    }
    out.close_tag.to_s
  end
end

class RequestFilterChain < FilterChain

  def initialize(id)
    super("request-chain", id)
  end
end

class ResponseFilterChain < FilterChain

  def initialize(id)
    super("response-chain", id)
  end
end

class Ssl
    include ChainedSetter

    def initialize(private_key_file, certificate_file, ca_certificates_file, client_authentication)
        @private_key_file = private_key_file
        @certificate_file = certificate_file
        @ca_certificates_file = ca_certificates_file
        @client_authentication = client_authentication
    end

    def to_xml(indent)
       out = XmlHelper.new(indent).
           tag("ssl").
           tag("private-key-file").content(@private_key_file).close_tag.
           tag("certificate-file").content(@certificate_file).close_tag.
           tag('client-authentication').content(@client_authentication).close_tag
       unless @ca_certificates_file == nil
         out.tag("ca-certificates-file").content(@ca_certificates_file).close_tag
       end
       out.close_tag.
           to_s
   end
end
