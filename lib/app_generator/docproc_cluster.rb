# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class DocumentProcessor < Processor
  def initialize(id, after=nil, before=nil, klass=nil, bundle=nil)
    super(id, after, before, klass, bundle)
  end

  def to_xml(indent="")
    return dump_xml(indent, "documentprocessor")
  end
end

class DocProcChain
  def initialize(name = "default")
    @name = name
    @docprocs = []
  end

  def docproc(id, bundle = nil)
    @docprocs.push(DocumentProcessor.new(id).bundle(bundle))
    self
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("docprocchain", :id => @name).
        to_xml(@docprocs).to_s
  end
end

class DocProcClusterNode < NodeBase
  tag "node"

  def initialize(hostalias, jvmargs, baseport=0)
    if baseport == 0
      super(:hostalias => hostalias, :jvmargs => jvmargs)
    else
      super(:hostalias => hostalias, :jvmargs => jvmargs, :baseport => baseport)
    end
  end
end

class DocProcCluster
  include ChainedSetter

  chained_setter :baseport
  chained_setter :jvmargs

  def initialize(name = "default")
    @name = name
    @baseport = 0
    @chains = []
    @jvmargs = nil
    @nodes = []
  end

  def chain(value)
    if value.is_a? DocProcChain
      @chains.push(value)
    else
      @chains.push(DocProcChain.new(value))
    end
    self
  end

  def node(hostalias, jvmargs = nil, baseport=0)
    port = @baseport
    port = baseport if baseport != 0

    @nodes.push(DocProcClusterNode.new(hostalias, jvmargs, port))
    self
  end

  def node_list
    return @nodes unless @nodes.empty?
    return [DocProcClusterNode.new("node1", nil, @baseport)]
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("cluster", :name => @name).
        tag("nodes", :jvmargs => @jvmargs).
          to_xml(node_list).close_tag.
        tag("docprocchains").
          to_xml(@chains).to_s
  end
end
