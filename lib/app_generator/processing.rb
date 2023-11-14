# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class Processing
  include ChainedSetter

  chained_forward :config, :config => :add
  chained_forward :processors, :processor => :push
  chained_forward :chains, :chain => :push
  chained_forward :renderers, :renderer => :push
  chained_forward :bindings, :binding => :push

  def initialize()
    @config = ConfigOverrides.new
    @chains = []
    @renderers = []
    @processors = []
    @bindings = []
  end

  def to_xml(indent="")
    XmlHelper.new(indent)\
      .tag("processing")\
      .to_xml(@renderers)\
      .to_xml(@processors)\
      .to_xml(@chains)\
      .to_xml(@bindings)\
      .to_xml(@config)\
      .to_s
  end
end

class Processor
  include ChainedSetter

  chained_setter :klass
  chained_setter :config
  chained_setter :provides
  chained_setter :bundle

  def initialize(id, after=nil, before=nil, klass=nil, bundle=nil)
    @id = id
    @after = after
    @before = before
    @bundle = bundle
    @config = nil
    @provides = nil
    @klass = klass
  end

  def to_xml(indent="")
    return dump_xml(indent)
  end

  def dump_xml(indent="", tagname="processor")
    XmlHelper.new(indent).
      tag(tagname, :id => @id, :bundle => @bundle,
                      :provides => @provides, :class => @klass).
        tag("after").content(@after).close_tag.
        tag("before").content(@before).close_tag.
        to_xml(@config).to_s
  end
end

class Chain
  include ChainedSetter

  chained_setter :inherits
  chained_setter :config
  chained_forward :components, :add => :push

  def initialize(id="default", inherits=nil)
    @id = id
    @inherits = inherits
    @components = []
  end

  def to_xml(indent="")
    XmlHelper.new(indent)\
      .tag("chain", :id => @id, :inherits => @inherits)\
        .to_xml(@config)\
        .to_xml(@components).to_s
  end
end

class ProcessorChain < Chain
  def initialize(id="default", inherits=nil)
    super(id, inherits)
  end
end
